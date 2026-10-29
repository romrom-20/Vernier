import Foundation
import CSQLite
import VernierCore

public enum DailyChecks {
    private static func check(_ value: Bool, _ detail: String) throws { if !value { throw CoreCheckFailure(description: detail) } }
    private static func message(_ id: String, _ role: String, _ text: String, _ at: Date?, session: String = "daily", turn: String? = nil) -> ConversationMessage {
        let object: [String: Any] = ["id": id, "sessionID": session, "turnID": turn ?? id, "speaker": role, "phase": role == "user" ? "user" : "final_answer", "text": text,
            "sourceAt": at.map { $0.timeIntervalSinceReferenceDate as Any } ?? NSNull(), "observedAt": Date().timeIntervalSinceReferenceDate, "redactions": 0, "textTruncated": false, "attachmentsOmitted": false]
        return try! JSONDecoder().decode(ConversationMessage.self, from: JSONSerialization.data(withJSONObject: object))
    }
    public static func projection() async throws {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let spring = cal.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12))!
        let day = WorkDay(containing: spring, calendar: cal)
        try check(day.end.timeIntervalSince(day.start) == 23 * 3600 && !day.contains(day.end), "Daily windows ignored daylight saving or counted the next midnight")
        let body = ["Build a search box.", "I will use an index.", "Go ahead.", "The index is ready.", "Proceed.", "I added a cache.", "Continue.", "The build passes.", "Verify offline search returns the same result.", "I report a pass.", "I tried it offline and got the right result.", "Thanks.", "Keep queries on this device.", "Understood.", "Fix it."]
        var values = body.enumerated().map { message("m\($0.offset)", $0.offset % 2 == 0 ? "user" : "assistant", $0.element, day.start.addingTimeInterval(Double($0.offset + 1) * 60)) }
        values.append(message("unknown", "user", "Proceed.", nil))
        values.append(message("tomorrow", "user", "Proceed.", day.end))
        values.append(message("other-agent", "assistant", "Do it.", day.start.addingTimeInterval(400), session: "other"))
        values.append(message("other-initial", "user", "Keep going.", day.start.addingTimeInterval(100), session: "other"))
        let report = DailyParticipation.make(day: day, input: .init(messages: values, datedTotal: 17, undatedTotal: 1), sessions: [])
        try check(report.followUps == 7 && report.count(.continued) == 3 && report.percent(.continued) == 43, "Daily denominator included openings, unknown times, another day or agent messages")
        try check(report.count(.checked) == 1 && report.count(.reported) == 1 && report.count(.directed) == 1 && report.repairRequests.count == 1, "Daily wording classification conflated reports, checks, direction or brief repairs")
        try check(report.longestContinuation.count == 3 && report.agentOnlyThreads.count == 1, "A continuation stretch or agent-only conversation was lost")
        try check(report.projects.count == 1 && report.hours.reduce(0) { $0 + $1.moments.count } == report.followUps, "Hourly or workspace aggregation double-counted follow-ups")
        try check(DailyParticipation.classify("Please proceed, but keep all edits offline.") == .directed && DailyParticipation.classify("How would I test this?") == .checked && DailyParticipation.classify("I haven't tried it.") != .reported, "Meaningful qualifiers or hypothetical tests became plain approval or a result")
        try check(DailyParticipation.classify("Do not test this yet.") == .directed && DailyParticipation.classify("Skip checking that.") != .checked, "Negated check instructions inflated the check-request metric")
        let compact = QuickRecap(report: report)
        try check(compact.headline.contains("3 times in a row") && compact.detail.contains("one saved conversation") && !compact.headline.contains("%"), "The compact recap lost its plain, bounded explanation")
        let copied = "Use the local index for search and keep the query on this machine."
        let copiedReport = DailyParticipation.make(day: day, input: .init(messages: [message("copy-a", "assistant", copied, spring), message("copy-u", "user", copied, spring.addingTimeInterval(2))], datedTotal: 2, undatedTotal: 0), sessions: [])
        try check(copiedReport.count(.other) == 1 && copiedReport.moments.first?.knownCopiedText == true, "Known copied agent text was attributed as independent direction")
        let clarification = DailyParticipation.make(day: day, input: .init(messages: [message("question", "assistant", "Is the button blue?", spring), message("answer", "user", "Yes.", spring.addingTimeInterval(1))], datedTotal: 2, undatedTotal: 0), sessions: [])
        try check(clarification.count(.continued) == 0, "A short answer to a clarification question was counted as delegation")
        let sameTurn = DailyParticipation.make(day: day, input: .init(messages: [message("agent-before", "assistant", "The plan is ready.", spring), message("detail", "user", "Explain why this works.", spring.addingTimeInterval(1), turn: "shared-turn"), message("later-short", "user", "Please proceed.", spring.addingTimeInterval(2), turn: "shared-turn")], datedTotal: 3, undatedTotal: 0), sessions: [])
        try check(sameTurn.followUps == 2 && sameTurn.count(.checked) == 1 && sameTurn.count(.continued) == 1, "Provider-turn grouping hid a separate human contribution or mislabeled the displayed source")
        try check(DailyParticipation.humanText(".context/attachments/synthetic/Screenshot 2026-10-29 at 11.11.25 PM.png  Explain the change.") == "Explain the change.", "An attachment path overwhelmed the human display excerpt")
        let morning = DailyParticipation.make(day: day, input: .init(messages: [message("morning", "user", "Go ahead.", day.start.addingTimeInterval(30))], datedTotal: 1, undatedTotal: 0, precedingContext: [message("last-night", "assistant", "The plan is ready.", day.start.addingTimeInterval(-30))]), sessions: [])
        try check(morning.count(.continued) == 1 && morning.loadedMessages == 1 && morning.moments.first?.agentID == "last-night", "A midnight boundary lost the preceding agent context or counted yesterday's message in today's denominator")
        let empty = DailyParticipation.make(day: day, input: .init(messages: [], datedTotal: 0, undatedTotal: 12), sessions: [])
        try check(empty.percent(.continued) == nil && empty.followUps == 0, "An empty day displayed a made-up percentage")
    }
    public static func storage() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("daily-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let gate = ObservationGate(); let token = gate.configure(enabled: true, contentEnabled: true, analysisEnabled: true)
        let library = ShowcaseFixtures.workLibrary(); let day = WorkDay(containing: Date())
        var old: SessionStore? = try SessionStore(directory: dir, gate: gate)
        _ = try await old!.apply(.init(sessions: library.sessions, turns: library.turns, truncated: false, observedAt: Date(), messages: library.messages), token: token)
        try await old!.saveNote(sessionID: library.sessions[0].id, text: "A preserved note")
        old = nil
        var db: OpaquePointer?
        try check(sqlite3_open(dir.appendingPathComponent("sessions.sqlite").path, &db) == SQLITE_OK, "Cannot open the daily migration fixture")
        try check(sqlite3_exec(db, "DROP TABLE daily_reflections; DROP INDEX messages_source_time; DROP INDEX messages_session_source_time; DELETE FROM schema_migrations WHERE version=6; PRAGMA user_version=5;", nil, nil, nil) == SQLITE_OK, "Cannot prepare a genuine v5 database")
        sqlite3_close(db)
        let store = try SessionStore(directory: dir, gate: gate)
        let upgraded = try await store.load()
        try check(upgraded.totalMessageCount == library.totalMessageCount && upgraded.notes[library.sessions[0].id] == "A preserved note", "v5 daily migration lost canonical records or notes")
        let input = try await store.dailyInput(day: day, limit: 2)
        try check(input.messages.count <= 2 && input.datedTotal >= input.messages.count && input.messages.allSatisfy { $0.sourceAt.map(day.contains) == true }, "Day query leaked another day or hid its cap")
        let reflection = DailyReflection(day: day, clarity: .mixed, energy: .steady, note: "SYNTHETIC_DAILY_CHECK_IN")
        let epoch = await store.dailyReflectionGeneration()
        try await store.saveDailyReflection(reflection, expectedGeneration: epoch)
        try await store.saveDailyReflection(reflection, expectedGeneration: epoch)
        let saved = try await store.dailyReflections()
        try check(saved.count == 1 && saved.first?.clarity == .mixed, "Check-in did not upsert by calendar day")
        let export = String(decoding: try await store.exportJSON(), as: UTF8.self)
        try check(export.contains("SYNTHETIC_DAILY_CHECK_IN") && export.contains("dailyReflections"), "Export omitted the daily check-in")
        try await store.eraseConversationMemory()
        let erased = try await store.dailyReflections()
        try check(erased.isEmpty, "Memory erasure retained personal daily reports")
        do { try await store.saveDailyReflection(reflection, expectedGeneration: epoch); throw CoreCheckFailure(description: "A stale check-in resurrected after erasure") }
        catch is StoreFailure { }
        try await store.saveDailyReflection(reflection)
        try await store.deleteAll()
        let deleted = try await store.dailyReflections()
        try check(deleted.isEmpty, "Full deletion retained personal daily reports")
        let pastDay = WorkDay(containing: Date().addingTimeInterval(-86400 * 50))
        try await store.saveDailyReflection(.init(day: pastDay, clarity: .clear, energy: nil, note: "Expired"))
        try await store.enforceRetention(days: 30)
        let retained = try await store.dailyReflections()
        try check(retained.isEmpty, "Retention retained expired daily reports")
    }
}
