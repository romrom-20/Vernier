import Foundation

extension ShowcaseFixtures {
    private static let checkpointExamples: [(goal: String, agent: String, human: String, step: String, state: WorkResultState, focus: WorkFocus)] = [
        ("Import the same contact twice without creating duplicates.", "The project builds. I have not replayed a repeated import.", "Show what happens when the same contact is imported twice.", "Import one contact twice and compare the saved count.", .buildOnly, .check),
        ("Open one panel for each shortcut press.", "I pressed the shortcut once and one panel opened.", "I pressed the shortcut once and two panels opened.", "Keep the one-press case and investigate the duplicate panel.", .behaviorReported, .progress),
        ("Preview the export before saving a file.", "I can implement the agreed export preview.", "Proceed with the approved preview plan.", "Compare the preview with the file before releasing the change.", .proposed, .handoff)
    ]
    /// Three distinct invented conversations for multi-checkpoint rendering and navigation checks.
    public static func checkpointLibrary(now: Date = Date()) -> SessionLibrary {
        let sessions = library(now: now).sessions
        let messages = checkpointExamples.enumerated().flatMap { i, example in
            [example.goal, example.agent, example.human].enumerated().map { j, text in
                ConversationMessage(id: "invented-checkpoint-\(i)-\(j)", sessionID: sessions[i].id, turnID: "invented-checkpoint-\(i)", speaker: j == 1 ? "assistant" : "user", phase: j == 1 ? "final_answer" : "user", text: text, sourceAt: now.addingTimeInterval(Double(j - 3) * 60), observedAt: now, redactions: 0, textTruncated: false, attachmentsOmitted: false)
            }
        }
        return SessionLibrary(sessions: sessions, turns: [], notes: [:], messages: messages, memoryCoverage: sessions.map { .init(sessionID: $0.id, complete: true, issue: false) }, totalMessageCount: messages.count,
            digests: sessions.enumerated().map { i, session in .init(sessionID: session.id, promptExcerpt: checkpointExamples[i].goal, messageCount: 3, signalCount: 0) })
    }
    public static func checkpointHistory(library: SessionLibrary, now: Date = Date()) -> [DecisionRevision] {
        library.sessions.enumerated().compactMap { i, session in
            guard checkpointExamples.indices.contains(i), let context = DecisionContext.make(sessionID: session.id, messages: library.messages.filter { $0.sessionID == session.id }, storedMessages: 3) else { return nil }
            let example = checkpointExamples[i]
            let refs = context.sources.enumerated().map { j, source in
                WorkReference(sourceID: source.id, quote: source.quote, use: j == 0 ? .intent : j == 1 ? .change : example.focus == .progress ? .result : .response)
            }
            let frame = WorkFrame(resultState: example.state, focus: example.focus, goal: example.goal, nextStep: example.step, references: refs)
            return DecisionRevision.contextual(context: context, proposal: frame.proposal(in: context), challenge: approved(refs), engine: "Invented example · no model ran", now: now)
        }
    }
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
