import Foundation

extension ShowcaseFixtures {
    /// Hand-written presentation fixtures, passed through production source validation. No inference runs.
    public static func decisionHistory(library: SessionLibrary, now: Date = Date()) -> [DecisionRevision] {
        guard let session = library.sessions.first else { return [] }
        let messages = library.messages.filter { $0.sessionID == session.id }
        let early = messages.filter { ($0.sourceAt ?? .distantPast) <= (messages.first { $0.id == "showcase-story-message-9" }?.sourceAt ?? now) }
        guard let first = DecisionContext.make(sessionID: session.id, messages: early, storedMessages: early.count) else { return [] }
        let firstActs = DecisionActions(choosesOrLimitsApproach: true, delegatesNextStep: true)
        let earlier = DecisionRevision.validated(context: first, draft: .grounded(context: first, kind: .humanDirection, sourceIDs: [first.anchorID], actions: firstActs),
            critique: .init(supported: true, reason: "Hand-written synthetic example: the cited request explicitly limits scope.", sourceIDs: [first.anchorID]),
            engine: "Synthetic example · no model ran", now: now.addingTimeInterval(-600), actions: firstActs)
        guard let next = DecisionContext.make(sessionID: session.id, messages: messages, previous: earlier, storedMessages: messages.count),
              let agent = next.sources.last(where: { $0.role == "assistant" }) else { return [earlier] }
        let nextActs = DecisionActions(requestsConcreteCheck: true, delegatesNextStep: true)
        let latest = DecisionRevision.validated(context: next, draft: .grounded(context: next, kind: .evidenceRequest, sourceIDs: [agent.id, next.anchorID], actions: nextActs),
            critique: .init(supported: true, reason: "Hand-written synthetic example: the request names the missing case; it does not establish a passing test or understanding.", sourceIDs: [next.anchorID]),
            engine: "Synthetic example · no model ran", previousID: earlier.id, now: now, actions: nextActs)
        return [latest, earlier]
    }
}
