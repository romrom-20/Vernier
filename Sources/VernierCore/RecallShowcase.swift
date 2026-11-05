import Foundation

extension ShowcaseFixtures {
    /// Invented cross-conversation sources and an explicit later correction.
    public static func relatedMemoryExample(now: Date = Date()) -> (library: SessionLibrary, memory: RelatedConversationMemory) {
        let sessions = Array(library(now: now).sessions.prefix(2)), current = sessions[0], earlier = sessions[1]
        let text = ["I choose SQLite for the reference catalog database.", "I can prepare the reference catalog migration.", "Remind me of the reference catalog database choice in the other conversation."]
        let messages = text.enumerated().map { i, body in
            ConversationMessage(id: "invented-casebook-\(i)", sessionID: i == 2 ? current.id : earlier.id, turnID: "invented-casebook-turn-\(i == 2 ? 1 : 0)", speaker: i == 1 ? "assistant" : "user", phase: i == 1 ? "final_answer" : "user", text: body, sourceAt: now.addingTimeInterval(Double(i - 3) * 1800), observedAt: now, redactions: 0, textTruncated: false, attachmentsOmitted: false)
        }
        let statements: [RelatedConversationMemory.Statement] = messages.prefix(2).map {
            .init(id: $0.id, messageID: $0.id, speaker: $0.speaker, quote: $0.text, date: $0.sourceAt, isPerspective: false)
        } + [.init(id: "invented-casebook-perspective", messageID: messages[0].id, speaker: "user_report", quote: "I changed my reference catalog database choice to Postgres. The older SQLite decision is historical.", date: now.addingTimeInterval(-600), isPerspective: true)]
        let book = RelatedConversationMemory(sessionID: current.id, anchorMessageID: messages[2].id, candidates: [.init(sessionID: earlier.id, earlierGoal: "Choose the reference catalog database", readingCreatedAt: now.addingTimeInterval(-1800), matchedWords: ["catalog", "database", "reference"], statements: statements, hasNewerPerspective: true)], consideredConversations: 1)
        return (.init(sessions: sessions, turns: [], notes: [:], messages: messages, memoryCoverage: sessions.map { .init(sessionID: $0.id, complete: true, issue: false) }, totalMessageCount: messages.count), book)
    }
    /// Invented long history for source-recall presentation; never reads a store.
    public static func recallLibrary(now: Date = Date()) -> SessionLibrary {
        let session = library(now: now).sessions[0]
        var messages: [ConversationMessage] = [], turn = 0
        func add(_ role: String, _ text: String) {
            if role == "user" { turn += 1 }
            messages.append(.init(id: "invented-recall-\(messages.count)", sessionID: session.id, turnID: "invented-recall-turn-\(turn)", speaker: role, phase: role == "assistant" ? "final_answer" : "user", text: text, sourceAt: now.addingTimeInterval(Double(messages.count - 200) * 60), observedAt: now, redactions: 0, textTruncated: false, attachmentsOmitted: false))
        }
        add("user", "Help me work through the project questions.")
        add("assistant", "Which requirement should we start with?")
        for i in 0..<5 {
            add("user", "Keep the unrelated formatting example \(i) readable.")
            add("assistant", "The formatting example is ready.")
        }
        add("user", "The export shortcut must work using the keyboard alone, without a mouse.")
        add("assistant", "I will keep the export shortcut accessible from the keyboard.")
        add("user", "Continue organizing the example files.")
        for i in 0..<80 { add("assistant", "Invented background progress \(i).") }
        add("user", "Keep the status brief."); add("assistant", "The status is brief.")
        add("user", "Leave the formatting example alone.")
        add("assistant", "The export shortcut handler is ready. I have not tested its keyboard behavior.")
        add("user", "Check the export shortcut against the original accessibility requirement.")
        return SessionLibrary(sessions: [session], turns: [], notes: [:], messages: messages, memoryCoverage: [.init(sessionID: session.id, complete: true, issue: false)], totalMessageCount: messages.count, digests: [.init(sessionID: session.id, promptExcerpt: "Check keyboard access to the export shortcut", messageCount: messages.count, signalCount: 0)])
    }
    public static func recallHistory(library: SessionLibrary, now: Date = Date()) -> [DecisionRevision] {
        guard let session = library.sessions.first,
              let preliminary = DecisionContext.make(sessionID: session.id, messages: library.messages, storedMessages: library.messages.count),
              var recall = ConversationRecall.select(candidates: library.messages.filter { $0.speaker == "user" }, context: preliminary, totalHumanMessages: library.messages.filter { $0.speaker == "user" }.count) else { return [] }
        let existing = Set(preliminary.sources.map(\.messageID))
        for entry in recall.entries {
            if let parent = library.messages.first(where: { $0.id == entry.messageID }), let reply = library.messages.last(where: { $0.turnID == parent.turnID && $0.speaker == "assistant" }), !existing.contains(reply.id) { recall = recall.addingReply(reply, to: entry) }
        }
        guard let context = DecisionContext.make(sessionID: session.id, messages: library.messages, storedMessages: library.messages.count, memoryRecall: recall),
              let oldGoal = context.sources.first(where: { $0.text == "The export shortcut must work using the keyboard alone, without a mouse." }),
              let agent = context.sources.last(where: { $0.role == "assistant" && !context.recalledMessageIDs.contains($0.messageID) }), let anchor = context.anchor else { return [] }
        let refs = [WorkReference(sourceID: oldGoal.id, quote: oldGoal.text, use: .intent), .init(sourceID: agent.id, quote: agent.quote, use: .change), .init(sourceID: anchor.id, quote: anchor.quote, use: .response)]
        let frame = WorkFrame(resultState: .proposed, focus: .check, goal: "Use the export shortcut with the keyboard alone", nextStep: "Focus the export control with the keyboard and activate it without touching the mouse.", references: refs)
        let challenge = WorkChallenge(goalSupported: true, accountSupported: true, nextStepRelevant: true, directionMismatchSupported: false, sourceIDs: refs.map(\.sourceID))
        return [.contextual(context: context, proposal: frame.proposal(in: context), challenge: challenge, engine: "Invented example · no model ran", now: now)]
    }
}
