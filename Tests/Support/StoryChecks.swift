import Foundation
import VernierCore

public enum StoryChecks {
    public static func projection() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let fixture = ShowcaseFixtures.visualLibrary(now: now)
        let id = fixture.sessions[0].id
        let story = SessionStory.make(sessionID: id, messages: fixture.messages, storedMessages: 12)
        try expect(story.loadedMessages == 12 && story.userMessages == 5 && story.agentMessages == 7, "Map counts lost session scope or role attribution")
        try expect(story.followUps == 4 && story.longestAgentRun == 2 && story.runs.count == 9, "Follow-ups or contiguous agent reply runs were miscounted")
        try expect(story.latestFollowUp?.priorAgentMessages == 1 && story.latestFollowUp?.excerpt.contains("blank emails") == true, "The latest request was paired with the wrong reply stretch")
        let reversed = SessionStory.make(sessionID: id, messages: fixture.messages.reversed(), storedMessages: 12)
        try expect(story.signature == reversed.signature, "Map depends on database result order")
        for moment in fixture.workBriefs[0].visibleMoments {
            for source in moment.evidence {
                try expect(story.run(containing: source.messageID)?.messages.contains(where: { $0.id == source.messageID && $0.text.contains(source.quote) }) == true, "An AI map marker does not resolve to its literal source")
            }
        }
        try expect(story.runs.allSatisfy { run in run.messages.contains { $0.text.contains(run.sourceQuote) } }, "Map source navigation constructs text absent from the source")
        try expect(story.runs[1].excerpt.contains("importer is implemented") && story.runs[1].progressExcerpt?.contains("preview") == true,
                   "A progress update hid the substantive agent reply")
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        try expect(encoder.encode(fixture) == encoder.encode(ShowcaseFixtures.visualLibrary(now: now)), "Visual showcase is not deterministic")
        var messages: [ConversationMessage] = []
        for index in 0..<2 {
            let raw: [String: Any] = ["turnId": "turn\(index)", "item": ["id": "user\(index)", "type": "userMessage", "content": [["type": "text", "text": "Add this acceptance check \(index)."]]]]
            messages.append(ConversationBoundary.message(raw, sessionID: "scope", salt: "synthetic", now: now)!)
        }
        let noReplies = SessionStory.make(sessionID: "scope", messages: messages, storedMessages: 90)
        try expect(noReplies.runs.count == 2 && noReplies.followUps == 0, "Separate user turns were collapsed or counted as agent follow-ups")
        try expect(noReplies.missingSourceTimes == 2 && noReplies.loadedMessages == 2 && noReplies.storedMessages == 90, "Partial coverage or missing times were hidden")
        let empty = SessionStory.make(sessionID: "unrelated", messages: fixture.messages, storedMessages: 0)
        try expect(empty.runs.isEmpty && empty.userMessages == 0, "Another session leaked into an empty map")
    }
    private static func expect(_ value: @autoclosure () throws -> Bool, _ message: String) throws {
        if try !value() { throw CoreCheckFailure(description: message) }
    }
}
