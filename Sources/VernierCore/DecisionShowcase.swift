import Foundation

extension ShowcaseFixtures {
    /// Invented presentation records, never generated from a personal archive.
    public static func decisionHistory(library: SessionLibrary, now: Date = Date()) -> [DecisionRevision] {
        guard let session = library.sessions.first else { return [] }
        let messages = library.messages.filter { $0.sessionID == session.id }
        let early = messages.filter { ($0.sourceAt ?? .distantPast) <= (messages.first { $0.id == "showcase-story-message-9" }?.sourceAt ?? now) }
        guard let first = DecisionContext.make(sessionID: session.id, messages: early, storedMessages: early.count), let firstAgent = first.sources.last(where: { $0.role == "assistant" }) else { return [] }
        let earlyRefs = [WorkReference(sourceID: firstAgent.id, quote: String(firstAgent.quote.prefix(100)), use: .change), .init(sourceID: first.anchorID, quote: String(first.anchor!.quote.prefix(100)), use: .response)]
        let firstFrame = WorkFrame(resultState: .proposed, focus: .handoff, goal: "Fix duplicate contacts without redesigning the importer", nextStep: "Keep the change limited to the identity key and compare repeated-import counts.", references: earlyRefs)
        let earlier = DecisionRevision.contextual(context: first, proposal: firstFrame.proposal(in: first), challenge: approved(earlyRefs), engine: "Invented example · no model ran", now: now.addingTimeInterval(-600))
        guard let next = DecisionContext.make(sessionID: session.id, messages: messages, previous: earlier, storedMessages: messages.count), let agent = next.sources.last(where: { $0.role == "assistant" }) else { return [earlier] }
        let refs = [WorkReference(sourceID: agent.id, quote: String(agent.quote.prefix(100)), use: .change), .init(sourceID: next.anchorID, quote: String(next.anchor!.quote.prefix(100)), use: .response)]
        let frame = WorkFrame(resultState: .proposed, focus: .check, goal: "Prevent duplicate contacts, including rows with blank emails", nextStep: "Import a file with blank emails twice and compare the contact counts.", references: refs)
        let latest = DecisionRevision.contextual(context: next, proposal: frame.proposal(in: next), challenge: approved(refs), engine: "Invented example · no model ran", previousID: earlier.id, now: now)
        return [latest, earlier]
    }
    private static func approved(_ references: [WorkReference]) -> WorkChallenge {
        .init(goalSupported: true, accountSupported: true, nextStepRelevant: true, directionMismatchSupported: true, sourceIDs: references.map(\.sourceID))
    }
    public static func directionLibrary(now: Date = Date()) -> SessionLibrary {
        let session = workLibrary(now: now).sessions[0]
        let text = ["The contact search must work offline. No query may leave this device.", "I recommend sending each query to a hosted search API.", "Okay, go ahead."]
        let messages = text.enumerated().map { i, body in
            ConversationMessage(id: "invented-direction-\(i)", sessionID: session.id, turnID: "invented-turn-\(i)", speaker: i == 1 ? "assistant" : "user", phase: i == 1 ? "final_answer" : "user", text: body, sourceAt: now.addingTimeInterval(Double(i - 3) * 60), observedAt: now, redactions: 0, textTruncated: false, attachmentsOmitted: false)
        }
        return SessionLibrary(sessions: [session], turns: [], notes: [:], messages: messages, memoryCoverage: [.init(sessionID: session.id, complete: true, issue: false)], totalMessageCount: 3, digests: [.init(sessionID: session.id, promptExcerpt: text[0], messageCount: 3, signalCount: 0)])
    }
    public static func directionHistory(library: SessionLibrary) -> [DecisionRevision] {
        guard let context = DecisionContext.make(sessionID: library.sessions[0].id, messages: library.messages, storedMessages: 3) else { return [] }
        let refs = context.sources.enumerated().map { i, source in WorkReference(sourceID: source.id, quote: String(source.quote.prefix(100)), use: i == 0 ? .boundary : i == 1 ? .change : .response) }
        let frame = WorkFrame(resultState: .proposed, focus: .directionChange, goal: "Keep contact search offline", nextStep: "Choose whether the earlier boundary should change.", references: refs)
        return [.contextual(context: context, proposal: frame.proposal(in: context), challenge: approved(refs), engine: "Invented example · no model ran")]
    }
}
