import AppKit
import Foundation
import VernierCore

extension AppModel {
    var decisionSession: SessionMetadata? {
        library.sessions.first { $0.id == selectedDecisionSessionID } ?? library.sessions.first
    }
    var currentDecision: DecisionRevision? {
        guard let session = decisionSession else { return nil }
        let values = decisionRevisions.filter { $0.sessionID == session.id }
        return values.first { $0.id == selectedDecisionRevisionID } ?? values.first
    }
    var decisionHistory: [DecisionRevision] { decisionRevisions.filter { $0.sessionID == decisionSession?.id } }
    var currentPerspectives: [DecisionPerspective] { decisionPerspectives.filter { $0.sessionID == decisionSession?.id } }
    var isDecisionCurrent: Bool { currentDecision.map(isReadingCurrent) ?? false }
    func isReadingCurrent(_ revision: DecisionRevision) -> Bool {
        guard let session = library.sessions.first(where: { $0.id == revision.sessionID }) else { return false }
        let relatedCurrent = revision.relatedMessageCounts.allSatisfy { id, count in
            library.sessions.first(where: { $0.id == id }).flatMap { library.digest(for: $0)?.messageCount } == count
        }
        let newerReport = decisionPerspectives.contains { $0.sessionID == session.id && $0.createdAt > revision.createdAt }
        return (isShowcase || revision.engine.hasSuffix(" · " + DecisionGenerator.promptVersion)) && decisionDirtyAt[session.id] == nil && relatedCurrent && revision.storedMessages == library.digest(for: session)?.messageCount && !newerReport
    }
    var directionToCheck: DecisionRevision? {
        guard !paused, !systemSuspended, localInsightsEnabled, conversationMemoryEnabled, codexEnabled else { return nil }
        return decisionRevisions.first { revision in
            revision.reading?.focus == .directionChange && revision.reading?.signalKey != nil && Date().timeIntervalSince(revision.createdAt) < 3600 && isReadingCurrent(revision) && !revision.directionAcknowledged(by: decisionPerspectives)
        }
    }
    func openDirectionCheck() {
        guard let revision = directionToCheck else { return }
        dailyConversationExpanded = true
        selectDecisionSession(revision.sessionID); selectedDecisionRevisionID = revision.id; openStudio(.overview)
    }
    func startFollowingWork() {
        guard !isolatedEnvironment, codexEnabled, conversationMemoryEnabled, !paused else { return }
        lastAutomaticDecision = Date() // One explicit review, rather than racing the preference-triggered scheduler.
        if !localInsightsEnabled { localInsightsEnabled = true }
        if !automaticDecisionReviews { automaticDecisionReviews = true }
        reviewDecision()
    }
    func copyNextCheck(_ reading: WorkReading) {
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(reading.nextStep, forType: .string)
        decisionNotice = "The suggested check was copied."
    }
    func decisionTitle(_ session: SessionMetadata) -> String {
        if let note = library.notes[session.id].flatMap({ SessionDisplay.excerpt($0) }) { return note }
        if let goal = decisionRevisions.first(where: { $0.sessionID == session.id })?.reading?.goal, !goal.isEmpty { return goal }
        let excerpt = library.messages.first(where: { $0.sessionID == session.id && $0.speaker == "user" }).flatMap { SessionDisplay.excerpt($0.text) } ?? library.digest(for: session)?.promptExcerpt
        if let excerpt {
            if excerpt.hasPrefix("http"), let host = URL(string: excerpt.components(separatedBy: .whitespacesAndNewlines).first ?? "")?.host { return "Article discussion · " + host }
            return excerpt
        }
        return SessionDisplay.fallback(createdAt: session.createdAt)
    }
    func reloadDecisionRecords() async throws {
        guard let store else { return }
        let generation = decisionGeneration, selected = selectedDecisionSessionID
        var records = try await store.loadLatestDecisionRevisions()
        if let selected {
            let own = try await store.loadDecisionRevisions(sessionID: selected)
            records.removeAll { $0.sessionID == selected }; records += own
            records.sort { $0.createdAt > $1.createdAt }
        }
        let reports = try await store.loadDecisionPerspectives()
        guard decisionGeneration == generation, selectedDecisionSessionID == selected else { return }
        decisionRevisions = records; decisionPerspectives = reports
        await loadRelatedMemory()
    }
    var visibleRelatedMemory: RelatedConversationMemory? {
        guard conversationMemoryEnabled, codexEnabled, localInsightsEnabled, !paused, !systemSuspended, relatedMemory?.sessionID == decisionSession?.id else { return nil }
        return relatedMemory
    }
    func loadRelatedMemory() async {
        relatedMemoryGeneration += 1
        let generation = relatedMemoryGeneration, analysis = decisionGeneration, selected = decisionSession?.id, token = captureGate.token()
        relatedMemory = nil
        guard !isolatedEnvironment, conversationMemoryEnabled, codexEnabled, localInsightsEnabled, !paused, !systemSuspended, let selected, let store else { return }
        let book = try? await store.relatedConversationMemory(sessionID: selected)
        guard relatedMemoryGeneration == generation, decisionGeneration == analysis, decisionSession?.id == selected, captureGate.token() == token,
              conversationMemoryEnabled, codexEnabled, localInsightsEnabled, !paused, !systemSuspended else { return }
        relatedMemory = book
    }
    private func clearDecisionDirty(_ session: String, through time: Date) {
        if let dirty = decisionDirtyAt[session], dirty <= time { decisionDirtyAt.removeValue(forKey: session) }
    }
    func selectDecisionSession(_ id: String) {
        selectedDecisionSessionID = id; selectedDecisionRevisionID = nil; decisionError = nil; decisionNotice = nil
        relatedMemoryGeneration += 1; relatedMemory = nil
        guard let store, !isolatedEnvironment else { return }
        let generation = decisionGeneration
        Task { @MainActor [weak self] in
            guard let self, let values = try? await store.loadDecisionRevisions(sessionID: id), self.decisionGeneration == generation, self.selectedDecisionSessionID == id else { return }
            self.decisionRevisions.removeAll { $0.sessionID == id }
            self.decisionRevisions += values
            self.decisionRevisions.sort { $0.createdAt > $1.createdAt }
            await self.loadRelatedMemory()
        }
    }
    func checkDecisionEngine() {
        guard !checkingEngine else { return }
        if isolatedEnvironment { engineHealth = "The isolated showcase does not contact a model."; return }
        let selected = reasoningModel
        checkingEngine = true; engineHealth = nil
        Task { @MainActor [weak self] in
            let message = await DecisionGenerator.shared.availability(model: selected)
            guard let self else { return }
            if self.reasoningModel == selected { self.engineHealth = message }
            self.checkingEngine = false
        }
    }
    func cancelDecisionReview() {
        decisionGeneration += 1; decisionTask?.cancel(); decisionTask = nil; reviewingDecision = false
    }
    func clearDecisionMemory() {
        cancelDecisionReview(); decisionRevisions = []; decisionPerspectives = []
        relatedMemoryGeneration += 1; relatedMemory = nil
        selectedDecisionSessionID = nil; selectedDecisionRevisionID = nil; decisionError = nil; decisionNotice = nil; decisionDirtyAt = [:]
    }
    func scheduleDecisionReview() {
        guard !isolatedEnvironment, automaticDecisionReviews, localInsightsEnabled, codexEnabled, conversationMemoryEnabled, !paused, !systemSuspended,
              !reviewingDecision, !ProcessInfo.processInfo.isLowPowerModeEnabled, Date().timeIntervalSince(lastAutomaticDecision) >= 120 else { return }
        let recent = library.sessions.filter { $0.updatedAt >= Date().addingTimeInterval(-86400) && Date().timeIntervalSince($0.updatedAt) >= 15 && Date().timeIntervalSince(decisionDirtyAt[$0.id] ?? .distantPast) >= 15 && (library.digest(for: $0)?.messageCount ?? 0) >= 2 }
        let dirty = recent.filter { session in
            let latest = decisionRevisions.first { $0.sessionID == session.id }
            let freshPerspective = decisionPerspectives.contains { $0.sessionID == session.id && $0.createdAt > (latest?.createdAt ?? .distantPast) }
            let relatedChanged = latest?.relatedMessageCounts.contains { id, count in
                library.sessions.first(where: { $0.id == id }).flatMap { library.digest(for: $0)?.messageCount } != count
            } ?? false
            let oldLabels = latest?.contributions?.contains { !$0.engine.hasSuffix(" · " + ContributionReading.version) } ?? false
            return decisionDirtyAt[session.id] != nil || relatedChanged || latest == nil || (contributionLabelsEnabled && (latest?.contributionsComplete != true || oldLabels)) || !(latest.map { $0.engine.hasSuffix(" · " + DecisionGenerator.promptVersion) && ($0.reading?.boundaryRule != nil || $0.engine == reasoningModel + " · " + DecisionGenerator.promptVersion) } ?? false) || latest?.storedMessages != library.digest(for: session)?.messageCount || freshPerspective
        }.filter { Date().timeIntervalSince(lastDecisionAttempt[$0.id] ?? .distantPast) >= 120 }
        guard let next = dirty.sorted(by: { left, right in
            let a = decisionRevisions.first { $0.sessionID == left.id }?.createdAt ?? .distantPast
            let b = decisionRevisions.first { $0.sessionID == right.id }?.createdAt ?? .distantPast
            return a == b ? left.updatedAt > right.updatedAt : a < b
        }).first else { return }
        lastAutomaticDecision = Date()
        reviewDecision(sessionID: next.id, retryUnknown: false)
    }
    func reviewDecision(sessionID: String? = nil, retryUnknown: Bool = true) {
        guard !isolatedEnvironment, localInsightsEnabled, !paused, !systemSuspended, codexEnabled, conversationMemoryEnabled,
              let sessionID = sessionID ?? decisionSession?.id, let token = captureGate.token(), let store else { return }
        cancelDecisionReview()
        let generation = decisionGeneration
        let startedAt = Date()
        let model = reasoningModel
        reviewingDecision = true; decisionError = nil; decisionNotice = nil
        lastDecisionAttempt[sessionID] = Date()
        decisionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { if self.decisionGeneration == generation { self.reviewingDecision = false; self.decisionTask = nil } }
            do {
                guard let context = try await store.decisionContext(sessionID: sessionID) else { self.decisionNotice = "No saved request is available in this conversation yet. History may still be filling."; return }
                let previous = try await store.loadDecisionRevisions(sessionID: sessionID, limit: 1).first
                let labelsCurrent = !self.contributionLabelsEnabled || (previous?.contributionsComplete == true && previous?.contributions?.allSatisfy { $0.engine == model + " · " + ContributionReading.version } == true)
                if (!retryUnknown || previous?.reading != nil), labelsCurrent, previous?.inputDigest == context.inputDigest, (previous?.engine == model + " · " + DecisionGenerator.promptVersion || (previous?.reading?.boundaryRule != nil && previous?.engine.hasSuffix(" · " + DecisionGenerator.promptVersion) == true)) {
                    self.clearDecisionDirty(sessionID, through: startedAt)
                    if self.decisionSession?.id == sessionID { self.selectedDecisionRevisionID = nil }
                    self.decisionNotice = "The saved evidence is unchanged. The existing reading is still available."
                    return
                }
                let result = try await DecisionGenerator.shared.review(context: context, model: model, previousID: previous?.id)
                var revision = result.revision
                let cached = (previous?.contributions ?? []).filter { reading in
                    reading.engine == model + " · " + ContributionReading.version && context.sources.contains { $0.messageID == reading.messageID && $0.fingerprint == reading.fingerprint }
                }
                if self.contributionLabelsEnabled { do {
                    let additions = try await DecisionGenerator.shared.interpretContributions(context: context, model: model, excluding: Set(cached.map(\.messageID)))
                    revision.contributions = cached + additions
                    let covered = Set((revision.contributions ?? []).map(\.messageID))
                    revision.contributionsComplete = ContributionReading.targets(in: context).allSatisfy { covered.contains($0.messageID) }
                } catch {
                    try Task.checkCancellation()
                    revision.contributions = cached; revision.contributionsComplete = false
                    self.decisionError = "The goal reading finished, but reply interpretation could not finish. Unread replies remain unclassified."
                } }
                try Task.checkCancellation()
                guard self.decisionGeneration == generation, self.captureGate.token() == token else { return }
                guard try await store.saveDecisionRevision(revision, context: context, token: token) else {
                    self.decisionNotice = "New evidence arrived during the review. The next review will use it."
                    return
                }
                try await self.reloadDecisionRecords()
                guard self.decisionGeneration == generation, self.captureGate.token() == token else { return }
                self.clearDecisionDirty(sessionID, through: startedAt)
                if self.decisionSession?.id == sessionID { self.selectedDecisionRevisionID = nil }
                self.decisionNotice = previous == nil ? "A first reading is ready." : "The account was revisited with new evidence. Earlier readings remain in history."
            } catch {
                guard self.decisionGeneration == generation, !Task.isCancelled else { return }
                self.decisionError = "The local review couldn’t finish. \(error.localizedDescription)"
            }
        }
    }
    func saveDecisionPerspective(_ text: String, about target: DecisionRevision? = nil) async -> Bool {
        guard let revision = target ?? currentDecision, let store, !isShowcase else { return false }
        let generation = decisionGeneration
        let perspective = DecisionPerspective(sessionID: revision.sessionID, text: text.trimmingCharacters(in: .whitespacesAndNewlines), revisionID: revision.id, anchorMessageID: revision.anchorMessageID)
        guard !perspective.text.isEmpty else { return false }
        do {
            try await store.saveDecisionPerspective(perspective, revisionID: revision.id)
            let reports = try await store.loadDecisionPerspectives()
            guard decisionGeneration == generation else { return true }
            decisionPerspectives = reports
            decisionNotice = "Your perspective is saved separately from the model’s interpretation."
            if localInsightsEnabled && !paused && !systemSuspended { reviewDecision(sessionID: revision.sessionID) }
            return true
        } catch { decisionError = "Your perspective could not be saved. The source records have not changed."; return false }
    }
    func showDecisionSource(_ revision: DecisionRevision) {
        cancelWorkBrief(); briefSessionID = revision.sessionID; workDetailExpanded = true
        storyFocusID = revision.anchorMessageID; storyFocusRevision += 1; openStudio(.overview)
    }
}
