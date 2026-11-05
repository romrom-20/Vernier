import Foundation
import VernierCore

public enum RelatedMemoryChecks {
    private static func check(_ value: Bool, _ message: String) throws { if !value { throw CoreCheckFailure(description: message) } }
    public static func scopeAndCorrections() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("vernier-related-memory-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let gate = ObservationGate(), token = gate.configure(enabled: true, contentEnabled: true, analysisEnabled: true)
        let store = try SessionStore(directory: directory, gate: gate), now = Date(), fixtures = ShowcaseFixtures.library(now: now)
        let current = fixtures.sessions[0], peer = fixtures.sessions[1], other = fixtures.sessions[2]
        var foreignFields = try JSONSerialization.jsonObject(with: JSONEncoder().encode(other)) as! [String: Any]
        foreignFields["workspaceID"] = "invented-unrelated-workspace"
        let foreign = try JSONDecoder().decode(SessionMetadata.self, from: JSONSerialization.data(withJSONObject: foreignFields))
        func message(_ id: String, _ sid: String, _ role: String, _ text: String, _ offset: Double) -> ConversationMessage {
            .init(id: id, sessionID: sid, turnID: "invented-turn-\(sid)", speaker: role, phase: role == "assistant" ? "final_answer" : "user", text: text, sourceAt: now.addingTimeInterval(offset), observedAt: now, redactions: 0, textTruncated: false, attachmentsOmitted: false)
        }
        let choice = message("related-owned-choice", peer.id, "user", "I choose SQLite for the reference catalog database.", -20)
        let values = [choice, message("related-owned-ai", peer.id, "assistant", "I can prepare the reference catalog migration.", -19), message("related-owned-anchor", peer.id, "user", "Prepare that selected migration.", -18), message("related-current", current.id, "user", "Remind me of the reference catalog database choice in the other conversation.", -1), message("foreign-choice", foreign.id, "user", "I choose a different reference catalog database.", -15)]
        _ = try await store.apply(.init(sessions: [current, peer, foreign], turns: [], truncated: false, observedAt: now, messages: values), token: token)
        func record(_ context: DecisionContext) -> DecisionRevision {
            let ids = context.sources.filter { $0.sessionID == context.sessionID }.map(\.id)
            return .validated(context: context, draft: .init(kind: .humanDirection, goal: "Reference catalog database selection", summary: "An invented choice", reason: "A saved statement is available.", alternative: "A later statement can revise it.", unknown: "The current task link is not established.", sourceIDs: ids), critique: .init(supported: true, reason: "An invented source check", sourceIDs: ids), engine: "invented · casebook-1", now: now)
        }
        let peerContext = try await store.decisionContext(sessionID: peer.id)!, peerRevision = record(peerContext)
        let saved = try await store.saveDecisionRevision(peerRevision, context: peerContext, token: token)
        try check(saved, "Cannot seed an earlier reviewed conversation")
        let foreignContext = try await store.decisionContext(sessionID: foreign.id)!
        _ = try await store.saveDecisionRevision(record(foreignContext), context: foreignContext, token: token)
        let book = try await store.relatedConversationMemory(sessionID: current.id)!
        try check(book.candidates.map(\.sessionID) == [peer.id], "Cross-conversation recall crossed a workspace boundary or lost the related conversation")
        try check(book.candidates.count <= 2 && book.consideredConversations <= 60 && book.candidates[0].statements.count <= 3, "Casebook retrieval is not bounded")
        try check(book.candidates[0].statements.contains { $0.messageID == choice.id && $0.quote == choice.text }, "The casebook did not preserve the actual human declaration")
        let unchanged = try await store.relatedConversationMemory(sessionID: current.id)
        try check(unchanged == book, "Unchanged sources caused casebook drift")
        // Saving another interpretation does not generate a reciprocal model job.
        let reread = record(try await store.decisionContext(sessionID: peer.id)!)
        _ = try await store.saveDecisionRevision(reread, context: try await store.decisionContext(sessionID: peer.id)!, token: token)
        let note = DecisionPerspective(sessionID: peer.id, text: "I changed my reference catalog database choice to Postgres.", createdAt: now.addingTimeInterval(5), revisionID: reread.id, anchorMessageID: reread.anchorMessageID)
        try await store.saveDecisionPerspective(note, revisionID: reread.id)
        let corrected = try await store.relatedConversationMemory(sessionID: current.id)!
        try check(corrected.candidates[0].hasNewerPerspective && corrected.candidates[0].statements.contains { $0.isPerspective && $0.quote == note.text }, "A newer owner correction disappeared behind the earlier model reading")
        let conservative = try await store.decisionContext(sessionID: current.id)!
        try check(!conservative.sources.contains { $0.sessionID == peer.id }, "Older cross-conversation source excerpts were fed to inference while their owner correction was unsupported")
        let changed = message(choice.id, peer.id, "user", "I choose a revised reference catalog database.", -20)
        _ = try await store.apply(.init(sessions: [], turns: [], truncated: false, observedAt: now, messages: [changed]), token: token)
        let invalidated = try await store.relatedConversationMemory(sessionID: current.id)!
        try check(invalidated.candidates.isEmpty, "An edited original left its old derived casebook interpretation available")
        try await store.eraseConversationMemory()
        let erased = try await store.relatedConversationMemory(sessionID: current.id)
        try check(erased == nil, "Erasure left a rebuilt cross-conversation memory")
    }
}
