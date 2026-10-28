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
    var isDecisionCurrent: Bool {
        guard let revision = currentDecision, let session = decisionSession else { return false }
        let relatedCurrent = revision.relatedMessageCounts.allSatisfy { id, count in
            library.sessions.first(where: { $0.id == id }).flatMap { library.digest(for: $0)?.messageCount } == count
        }
        return decisionDirtyAt[session.id] == nil && relatedCurrent && revision.storedMessages == library.digest(for: session)?.messageCount && !(currentPerspectives.last.map { $0.createdAt > revision.createdAt } ?? false)
    }
    func decisionTitle(_ session: SessionMetadata) -> String {
        if let goal = decisionRevisions.first(where: { $0.sessionID == session.id })?.goal, !goal.isEmpty { return goal }
        if let text = library.messages.first(where: { $0.sessionID == session.id && $0.speaker == "user" }).flatMap({ SessionDisplay.excerpt($0.text) }) { return text }
        return library.digest(for: session)?.promptExcerpt ?? "Saved conversation"
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
    }
    private func clearDecisionDirty(_ session: String, through time: Date) {
        if let dirty = decisionDirtyAt[session], dirty <= time { decisionDirtyAt.removeValue(forKey: session) }
    }
    func selectDecisionSession(_ id: String) {
        selectedDecisionSessionID = id; selectedDecisionRevisionID = nil; decisionError = nil; decisionNotice = nil
        guard let store, !isolatedEnvironment else { return }
        let generation = decisionGeneration
        Task { @MainActor [weak self] in
            guard let self, let values = try? await store.loadDecisionRevisions(sessionID: id), self.decisionGeneration == generation, self.selectedDecisionSessionID == id else { return }
            self.decisionRevisions.removeAll { $0.sessionID == id }
            self.decisionRevisions += values
            self.decisionRevisions.sort { $0.createdAt > $1.createdAt }
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
        selectedDecisionSessionID = nil; selectedDecisionRevisionID = nil; decisionError = nil; decisionNotice = nil; decisionDirtyAt = [:]
    }
    func scheduleDecisionReview() {
        guard !isolatedEnvironment, automaticDecisionReviews, localInsightsEnabled, codexEnabled, conversationMemoryEnabled, !paused, !systemSuspended,
              !reviewingDecision, !ProcessInfo.processInfo.isLowPowerModeEnabled, Date().timeIntervalSince(lastAutomaticDecision) >= 300 else { return }
        let recent = library.sessions.filter { $0.updatedAt >= Date().addingTimeInterval(-86400) && Date().timeIntervalSince($0.updatedAt) >= 45 && Date().timeIntervalSince(decisionDirtyAt[$0.id] ?? .distantPast) >= 45 && (library.digest(for: $0)?.messageCount ?? 0) >= 2 }
        let dirty = recent.filter { session in
            let latest = decisionRevisions.first { $0.sessionID == session.id }
            let freshPerspective = decisionPerspectives.contains { $0.sessionID == session.id && $0.createdAt > (latest?.createdAt ?? .distantPast) }
            let relatedChanged = latest?.relatedMessageCounts.contains { id, count in
                library.sessions.first(where: { $0.id == id }).flatMap { library.digest(for: $0)?.messageCount } != count
            } ?? false
            return decisionDirtyAt[session.id] != nil || relatedChanged || latest == nil || latest?.engine != reasoningModel + " · " + DecisionGenerator.promptVersion || latest?.storedMessages != library.digest(for: session)?.messageCount || freshPerspective
        }.filter { Date().timeIntervalSince(lastDecisionAttempt[$0.id] ?? .distantPast) >= 300 }
        guard let next = dirty.sorted(by: { left, right in
            let a = decisionRevisions.first { $0.sessionID == left.id }?.createdAt ?? .distantPast
            let b = decisionRevisions.first { $0.sessionID == right.id }?.createdAt ?? .distantPast
            return a == b ? left.updatedAt > right.updatedAt : a < b
        }).first else { return }
        lastAutomaticDecision = Date()
        reviewDecision(sessionID: next.id)
    }
    func reviewDecision(sessionID: String? = nil) {
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
                if previous?.inputDigest == context.inputDigest, previous?.engine == model + " · " + DecisionGenerator.promptVersion {
                    self.clearDecisionDirty(sessionID, through: startedAt)
                    if self.decisionSession?.id == sessionID { self.selectedDecisionRevisionID = nil }
                    self.decisionNotice = "The saved evidence is unchanged. The existing reading is still available."
                    return
                }
                let result = try await DecisionGenerator.shared.generate(context: context, model: model, previousID: previous?.id)
                try Task.checkCancellation()
                guard self.decisionGeneration == generation, self.captureGate.token() == token else { return }
                guard try await store.saveDecisionRevision(result.revision, context: context, token: token) else {
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
