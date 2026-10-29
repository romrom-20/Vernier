import Foundation
import CSQLite

extension SessionStore {
    /// A bounded day query reads the archive, not the resident 300-message preview. Undated records are never assigned to a day.
    public func dailyInput(day: WorkDay, limit: Int = 4000) throws -> DailyInput {
        let values: [Any?] = [day.start.timeIntervalSince1970, day.end.timeIntervalSince1970]
        let count = try dailyRows("SELECT COUNT(*) FROM messages WHERE source_at>=? AND source_at<?", values: values) { Int(sqlite3_column_int64($0, 0)) }.first ?? 0
        let undated = try rows("SELECT COUNT(*) FROM messages WHERE source_at IS NULL") { Int(sqlite3_column_int64($0, 0)) }.first ?? 0
        let cap = min(4000, max(1, limit))
        let messages = try dailyRows("SELECT id,session_id,turn_id,speaker,phase,SUBSTR(body,1,4096),source_at,observed_at,redactions,CASE WHEN LENGTH(body)>4096 THEN 1 ELSE truncated END,attachments_omitted FROM messages WHERE source_at>=? AND source_at<? ORDER BY source_at DESC,id DESC LIMIT \(cap)", values: values) { row in
            func text(_ column: Int32) -> String { String(cString: sqlite3_column_text(row, column)) }
            return ConversationMessage(id: text(0), sessionID: text(1), turnID: text(2), speaker: text(3), phase: text(4), text: text(5), sourceAt: Date(timeIntervalSince1970: sqlite3_column_double(row, 6)), observedAt: Date(timeIntervalSince1970: sqlite3_column_double(row, 7)), redactions: Int(sqlite3_column_int(row, 8)), textTruncated: sqlite3_column_int(row, 9) == 1, attachmentsOmitted: sqlite3_column_int(row, 10) == 1)
        }
        var preceding: [ConversationMessage] = []
        for (sessionID, group) in Dictionary(grouping: messages, by: \.sessionID) {
            guard group.min(by: { ($0.sourceAt ?? .distantFuture) < ($1.sourceAt ?? .distantFuture) })?.speaker == "user" else { continue }
            let context = try dailyRows("SELECT id,turn_id,speaker,phase,SUBSTR(body,1,4096),source_at,observed_at,redactions,CASE WHEN LENGTH(body)>4096 THEN 1 ELSE truncated END,attachments_omitted FROM messages WHERE session_id=? AND source_at<? ORDER BY source_at DESC,id DESC LIMIT 1", values: [sessionID, day.start.timeIntervalSince1970]) { row in
                func text(_ c: Int32) -> String { String(cString: sqlite3_column_text(row, c)) }
                return ConversationMessage(id: text(0), sessionID: sessionID, turnID: text(1), speaker: text(2), phase: text(3), text: text(4), sourceAt: Date(timeIntervalSince1970: sqlite3_column_double(row, 5)), observedAt: Date(timeIntervalSince1970: sqlite3_column_double(row, 6)), redactions: Int(sqlite3_column_int(row, 7)), textTruncated: sqlite3_column_int(row, 8) == 1, attachmentsOmitted: sqlite3_column_int(row, 9) == 1)
            }
            preceding += context
        }
        return DailyInput(messages: messages, datedTotal: count, undatedTotal: undated, precedingContext: preceding)
    }
    public func dailyReflectionGeneration() -> Int { reflectionGeneration }
    public func saveDailyReflection(_ reflection: DailyReflection, expectedGeneration: Int? = nil) throws {
        guard expectedGeneration == nil || expectedGeneration == reflectionGeneration else { throw StoreFailure.unavailable }
        guard reflection.note.count <= 500 else { throw StoreFailure.unavailable }
        let data = try JSONEncoder().encode(reflection)
        try write("INSERT INTO daily_reflections VALUES(?,?,?) ON CONFLICT(day_key) DO UPDATE SET day_start=excluded.day_start,payload=excluded.payload", values: [reflection.dayKey, reflection.dayStart.timeIntervalSince1970, String(decoding: data, as: UTF8.self)])
    }
    public func dailyReflections() throws -> [DailyReflection] {
        try rows("SELECT payload FROM daily_reflections ORDER BY day_start DESC") { row in
            try? JSONDecoder().decode(DailyReflection.self, from: Data(String(cString: sqlite3_column_text(row, 0)).utf8))
        }.compactMap { $0 }
    }
    private func dailyRows<T>(_ sql: String, values: [Any?], transform: (OpaquePointer) -> T) throws -> [T] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection.handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw StoreFailure.corrupt }
        defer { sqlite3_finalize(statement) }
        for (i, value) in values.enumerated() {
            if let value = value as? Double { sqlite3_bind_double(statement, Int32(i + 1), value) }
            else if let value = value as? String { sqlite3_bind_text(statement, Int32(i + 1), value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
            else { throw StoreFailure.unavailable }
        }
        var result: [T] = []
        while true {
            switch sqlite3_step(statement) {
            case SQLITE_ROW: result.append(transform(statement))
            case SQLITE_DONE: return result
            default: throw StoreFailure.corrupt
            }
        }
    }
}
