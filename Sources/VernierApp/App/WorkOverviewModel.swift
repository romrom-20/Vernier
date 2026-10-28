import Foundation
import VernierCore

extension AppModel {
    var workOverviewKey: String {
        let sessionKeys: [String] = library.sessions.map { session in
            let count = library.digest(for: session)?.messageCount ?? 0
            let complete = library.memoryCoverage.first { $0.sessionID == session.id }?.complete ?? false
            return [session.id, String(session.updatedAt.timeIntervalSince1970), String(count), String(complete)].joined(separator: ":")
        }
        return sessionKeys.joined(separator: "|") + ":" + String(Int(Date().timeIntervalSince1970 / 300)) + ":" + String(library.totalMessageCount)
    }
    func clearWorkOverview() {
        workOverviewGeneration += 1; selectedParticipationID = nil; workOverview = nil; workOverviewLoadedKey = nil; workOverviewLoading = false; workOverviewError = nil
    }
    func loadWorkOverview() async {
        let key = workOverviewKey
        if workOverviewLoadedKey == key, workOverview != nil { return }
        workOverviewGeneration += 1
        let generation = workOverviewGeneration
        workOverviewLoading = true; workOverviewError = nil
        defer { if generation == workOverviewGeneration { workOverviewLoading = false } }
        let now = Date()
        let snapshot = library
        let candidates = WorkOverview.make(library: snapshot, messages: [], now: now).sessions
        do {
            var messages: [ConversationMessage] = []
            for work in candidates {
                guard !Task.isCancelled, generation == workOverviewGeneration, key == workOverviewKey else { return }
                if isolatedEnvironment {
                    messages += snapshot.messages.filter { $0.sessionID == work.id }.sorted {
                        ($0.sourceAt ?? $0.observedAt) > ($1.sourceAt ?? $1.observedAt)
                    }.prefix(100)
                } else { messages += try await store?.memoryMessages(sessionID: work.id, limit: 100, characterLimit: 4096) ?? [] }
            }
            guard !Task.isCancelled, generation == workOverviewGeneration, key == workOverviewKey else { return }
            workOverview = WorkOverview.make(library: snapshot, messages: messages, now: now)
            workOverviewLoadedKey = key
        } catch {
            guard generation == workOverviewGeneration, key == workOverviewKey, !Task.isCancelled else { return }
            workOverview = nil
            workOverviewError = "Recent work couldn’t be read. Your saved records have not changed."
        }
    }
    var participationMoments: [ParticipationMoment] { workOverview?.moments ?? [] }
    var selectedParticipation: ParticipationMoment? {
        participationMoments.first { $0.id == selectedParticipationID } ?? participationMoments.first
    }
    func openParticipation(_ moment: ParticipationMoment) {
        selectedParticipationID = moment.id
        openStudio(.overview)
    }
    func readParticipation(_ moment: ParticipationMoment) {
        guard let work = workOverview?.sessions.first(where: { $0.id == moment.sessionID }) else { return }
        selectedParticipationID = moment.id
        inspectWork(work, messageID: moment.anchorID)
    }
    func inspectWork(_ work: WorkSession, messageID: String? = nil) {
        cancelWorkBrief(); briefSessionID = work.id; storyFocusID = messageID ?? work.agentLast?.id ?? work.requests.last?.id; storyFocusRevision += 1
        workDetailExpanded = true
        openStudio(.overview)
    }
}
