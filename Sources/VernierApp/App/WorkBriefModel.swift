import Foundation
import VernierCore

extension AppModel {
    var briefSession: SessionMetadata? {
        if let briefSessionID, let session = library.sessions.first(where: { $0.id == briefSessionID }) { return session }
        return library.sessions.first
    }
    var currentBrief: WorkBrief? {
        guard let session = briefSession else { return nil }
        return library.workBriefs.first { $0.sessionID == session.id }
    }
    var briefUnavailable: String? { LocalBriefGenerator.unavailabilityReason() }
    func cancelWorkBrief() {
        briefGeneration += 1
        briefTask?.cancel(); briefTask = nil
        briefDeadline?.cancel(); briefDeadline = nil
        generatingBrief = false
    }
    func scheduleWorkBrief() {
        guard !isolatedEnvironment, localInsightsEnabled, !paused, !systemSuspended,
              conversationMemoryEnabled, codexEnabled, !generatingBrief, let session = briefSession,
              briefUnavailable == nil else { return }
        if let currentBrief, currentBrief.sourceUpdatedAt >= session.updatedAt,
           currentBrief.storedMessages == library.digest(for: session)?.messageCount { return }
        guard Date().timeIntervalSince(lastAutomaticBrief) >= 300 else { return }
        lastAutomaticBrief = Date()
        generateWorkBrief()
    }
    func generateWorkBrief(sessionID: String? = nil) {
        if let sessionID, sessionID != briefSession?.id { cancelWorkBrief(); briefSessionID = sessionID }
        guard !isolatedEnvironment, !generatingBrief, localInsightsEnabled, !paused, !systemSuspended,
              conversationMemoryEnabled, codexEnabled, let session = briefSession,
              let token = captureGate.token(), let store else { return }
        briefGeneration += 1
        let generation = briefGeneration
        generatingBrief = true; briefError = nil
        briefDeadline = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(90)) } catch { return }
            guard let self, self.briefGeneration == generation, self.generatingBrief else { return }
            self.cancelWorkBrief()
            self.briefError = "The local review took too long. Try again with a shorter session."
        }
        briefTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { if self.briefGeneration == generation { self.generatingBrief = false; self.briefTask = nil; self.briefDeadline?.cancel(); self.briefDeadline = nil } }
            do {
                let recent = try await store.memoryMessages(sessionID: session.id, limit: 80)
                let latestUsers = try await store.memoryMessages(sessionID: session.id, limit: 2, speaker: "user")
                let opening = try await store.memoryMessages(sessionID: session.id, limit: 1, newestFirst: false, speaker: "user").first
                let total = self.library.digest(for: session)?.messageCount ?? recent.count
                let existing = Set(recent.map(\.id))
                let window = BriefWindow.make(session: session, messages: recent + latestUsers.filter { !existing.contains($0.id) }, opening: opening, storedMessages: total)
                guard window.hasEnoughContext else { throw BriefGenerationError.insufficient }
                try Task.checkCancellation()
                let brief = try await LocalBriefGenerator.shared.generate(window)
                try Task.checkCancellation()
                guard generation == self.briefGeneration, self.localInsightsEnabled, self.captureGate.token() == token else { return }
                guard try await store.saveWorkBrief(brief, token: token) else { return }
                let loaded = try await store.load()
                guard generation == self.briefGeneration, self.captureGate.token() == token else { return }
                self.library = loaded
            } catch {
                guard generation == self.briefGeneration, !Task.isCancelled else { return }
                self.briefError = "The local brief couldn’t be generated. \(error.localizedDescription)"
            }
        }
    }
    func dismissMoment(_ id: String) {
        guard let brief = currentBrief, brief.moments.contains(where: { $0.id == id }),
              let token = captureGate.token(), let store, !paused else { return }
        Task { @MainActor in
            do {
                guard try await store.dismissWorkBriefMoment(sessionID: brief.sessionID, momentID: id, token: token) else { return }
                let loaded = try await store.load()
                guard self.captureGate.token() == token else { return }
                self.library = loaded
            } catch { self.briefError = "Could not save that correction locally." }
        }
    }
}
