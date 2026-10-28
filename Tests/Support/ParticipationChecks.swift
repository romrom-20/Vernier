import Foundation
import VernierCore

public enum ParticipationChecks {
    public static func readings() async throws {
        func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
            if !condition() { throw CoreCheckFailure(description: message) }
        }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let fixture = ShowcaseFixtures.workLibrary(now: now)
        let overview = WorkOverview.make(library: fixture, messages: fixture.messages, now: now)
        let moments = overview.moments
        func moment(_ anchor: String) -> ParticipationMoment? { moments.first { $0.anchorID == anchor } }
        try expect(moment("showcase-story-message-3")?.kind == .returnedIssue, "A recurring duplicate report lost its related earlier request")
        try expect(moment("showcase-story-message-6")?.kind == .requestedEvidence, "A concrete repeated-import check was missed")
        try expect(moment("showcase-story-message-9")?.kind == .setBoundary, "An explicit scope constraint was missed")
        try expect(moment("showcase-work-0")?.kind == .continued, "A short continuation was confused with a lack of understanding")
        try expect(moment("showcase-story-message-6")?.sources.contains { $0.messageID == "showcase-story-message-5" } == true,
                   "The build report that prompted a test request disappeared behind a final reply")
        for reading in moments {
            try expect(reading.userSource?.speaker == "user", "A reading is not anchored in user-side text")
            for source in reading.sources {
                try expect(fixture.messages.contains { $0.id == source.messageID && $0.sessionID == reading.sessionID && $0.speaker == source.speaker && $0.text.contains(source.quote) }, "A reading fabricated or crossed a source boundary")
            }
        }
        let reversed = WorkOverview.make(library: fixture, messages: fixture.messages.reversed(), now: now)
        try expect(moments.map(\.id) == reversed.moments.map(\.id), "Reading order depends on query result order")
        try expect(WorkOverview.make(library: fixture, messages: fixture.messages, now: now.addingTimeInterval(172800)).moments.isEmpty, "Old instructions were described as recent participation")
        let sessionID = fixture.sessions[0].id
        func messages(_ texts: [(String, String)]) -> [ConversationMessage] {
            texts.enumerated().map { index, item in
                var raw: [String: Any] = ["turnId": "turn-\(index)", "startedAtMs": now.addingTimeInterval(Double(index) - 50).timeIntervalSince1970 * 1000]
                if item.0 == "user" { raw["item"] = ["id": "item-\(index)", "type": "userMessage", "content": [["type": "text", "text": item.1]]] }
                else { raw["item"] = ["id": "item-\(index)", "type": "agentMessage", "phase": "final_answer", "text": item.1] }
                return ConversationBoundary.message(raw, sessionID: sessionID, salt: "synthetic", now: now)!
            }
        }
        let unrelated = messages([("user", "Build the CSV importer."), ("assistant", "I made the importer."), ("user", "The floating pill keeps closing again.")])
        let unrelatedStory = SessionStory.make(sessionID: sessionID, messages: unrelated, storedMessages: 3)
        let unrelatedReadings = ParticipationReview.make(story: unrelatedStory, since: now.addingTimeInterval(-86400), until: now)
        try expect(!unrelatedReadings.contains { $0.kind == .returnedIssue }, "Unrelated topics in one provider session were merged into a recurring bug")
        let explain = messages([("user", "Add an importer."), ("assistant", "It is implemented."), ("user", "Explain why importing twice creates duplicates.")])
        let explanation = ParticipationReview.make(story: .make(sessionID: sessionID, messages: explain, storedMessages: 3), since: now.addingTimeInterval(-86400), until: now)
        try expect(explanation.contains { $0.kind == .soughtExplanation }, "An explanation request did not remain distinct from demonstrated understanding")
        let negated = messages([("user", "Add an importer."), ("assistant", "It is implemented."), ("user", "Do not explain; keep the change to deduplication.")])
        let negatedReadings = ParticipationReview.make(story: .make(sessionID: sessionID, messages: negated, storedMessages: 3), since: now.addingTimeInterval(-86400), until: now)
        try expect(!negatedReadings.contains { $0.kind == .soughtExplanation }, "A negated explanation request was described as seeking understanding")
        let confusion = messages([("user", "Add an importer."), ("assistant", "It is implemented."), ("user", "I don't know what this label means.")])
        let confusionReadings = ParticipationReview.make(story: .make(sessionID: sessionID, messages: confusion, storedMessages: 3), since: now.addingTimeInterval(-86400), until: now)
        try expect(confusionReadings.first?.kind == .soughtExplanation, "A statement of confusion was treated as an explicit requirement")
        let imagined = messages([("user", "Build a CSV importer without duplicate contacts."), ("assistant", "It is implemented."), ("user", "What if the CSV importer creates duplicate contacts again?")])
        let imaginedReadings = ParticipationReview.make(story: .make(sessionID: sessionID, messages: imagined, storedMessages: 3), since: now.addingTimeInterval(-86400), until: now)
        try expect(!imaginedReadings.contains { $0.kind == .returnedIssue }, "A hypothetical recurrence was treated as a reported recurring problem")
        let noReply = messages([("user", "Verify the importer works.")])
        let initial = ParticipationReview.make(story: .make(sessionID: sessionID, messages: noReply, storedMessages: 1), since: now.addingTimeInterval(-86400), until: now)
        try expect(initial.first?.kind == .instruction && initial.first?.precedingReply == nil, "An initial request was described as an intervention after an agent reply")
    }
}
