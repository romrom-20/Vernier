import Foundation
import VernierCore

public enum WorkOverviewChecks {
    public static func projection() async throws {
        func expect(_ condition: @autoclosure () -> Bool, _ detail: String) throws {
            if !condition() { throw CoreCheckFailure(description: detail) }
        }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let fixture = ShowcaseFixtures.workLibrary(now: now)
        let overview = WorkOverview.make(library: fixture, messages: fixture.messages, now: now)
        try expect(overview.workspaces == 3 && overview.sessions.count == 3 && overview.loadedMessages == 18, "Cross-workspace coverage lost a quieter thread")
        try expect(overview.count(.goAhead) == 1 && overview.count(.handoff) == 1, "Wording cues lost explicit handoff vs go-ahead distinction")
        try expect(overview.count(.question) > 0 && overview.count(.direction) > 0, "Checks or constraints disappeared")
        try expect(overview.agentLastCount == 2 && overview.failureCount == 1, "Last-speaker or latest-turn status misreported")
        try expect(overview.requests.count == RequestCue.allCases.reduce(0) { $0 + overview.count($1) }, "Mixed prompts were counted multiple times")
        try expect(overview.requests.allSatisfy { source in fixture.messages.contains { $0.id == source.id && $0.sessionID == source.message.sessionID && $0.text.contains(source.excerpt) } }, "A request example has no literal source")
        let reversed = WorkOverview.make(library: fixture, messages: fixture.messages.reversed(), now: now)
        try expect(overview.requests.map(\.id) == reversed.requests.map(\.id) && overview.agentLastCount == reversed.agentLastCount, "Input order changes cross-session results")
        let capped = WorkOverview.make(library: fixture, messages: fixture.messages, now: now, limit: 1)
        try expect(capped.sessions.count == 1 && capped.eligibleSessions == 3 && capped.loadedMessages == 12, "Session cap hidden or cross-session contamination")
        var crowded = fixture.sessions
        for index in 0..<4 {
            var raw = try JSONSerialization.jsonObject(with: JSONEncoder().encode(fixture.sessions[0])) as! [String: Any]
            raw["id"] = "synthetic-busy-\(index)"
            raw["updatedAt"] = now.addingTimeInterval(-Double(index)).timeIntervalSinceReferenceDate
            crowded.append(try JSONDecoder().decode(SessionMetadata.self, from: JSONSerialization.data(withJSONObject: raw)))
        }
        let crowdedLibrary = SessionLibrary(sessions: crowded, turns: fixture.turns, notes: [:], messages: fixture.messages)
        let balanced = WorkOverview.make(library: crowdedLibrary, messages: fixture.messages, now: now, limit: 3)
        try expect(balanced.workspaces == 3 && balanced.eligibleSessions == 7, "One busy workspace displaced quieter workspaces")
        let unknownTurn = MetadataBoundary.turn(["id": "unknown-latest", "status": "inProgress"], sessionID: fixture.sessions[2].id, salt: "synthetic", now: now)!
        let unknownLibrary = SessionLibrary(sessions: fixture.sessions, turns: fixture.turns + [unknownTurn], notes: [:])
        try expect(WorkOverview.make(library: unknownLibrary, messages: fixture.messages, now: now).failureCount == 0, "An undated newer observation left an older failure labeled latest")
        let old = WorkOverview.make(library: fixture, messages: fixture.messages, now: now.addingTimeInterval(172800))
        try expect(old.sessions.isEmpty && old.requests.isEmpty, "Old activity counted as current work")
        let noTimes = fixture.messages.map { message -> ConversationMessage in
            // The normalizer gives these entries no source timestamps; import time must not become usage time.
            let item: [String: Any] = ["id": message.id, "type": "userMessage", "content": [["type": "text", "text": "Please proceed."]]]
            return ConversationBoundary.message(["turnId": message.turnID, "item": item], sessionID: message.sessionID, salt: "synthetic", now: now)!
        }
        let undated = WorkOverview.make(library: fixture, messages: noTimes, now: now)
        try expect(undated.requests.isEmpty && undated.agentLastCount == 0, "Import time invented dated activity")
        try expect(RequestCue.classify("<system_instruction>Build this.</system_instruction>\nWhy did that fail?") == .question, "Injected block contaminated request classification")
        try expect(RequestCue.classify("Proceed with the migration and verify rollback.") == .question, "Detailed acceptance check called an empty go-ahead")
        try expect(RequestCue.classify("Don't deploy; only change the preview.") == .direction, "A deployment constraint called delegation")
        try expect(RequestCue.classify("This looks good.") == .other, "Unmatched wording was treated as a review or task handoff")
        let partial = WorkOverview.make(library: fixture, messages: Array(fixture.messages.prefix(1)), now: now)
        try expect(partial.sessions.allSatisfy(\.hasPartialMemory), "Unloaded saved text presented as complete memory")
    }
}
