import Foundation
import CSQLite

extension SessionStore {
    func applyMemory(_ snapshot: SessionSnapshot) throws -> Int {
        let parentIDs = Set(try rows("SELECT id FROM sessions") { string($0, 0) })
        var changes = 0
        for message in snapshot.messages where parentIDs.contains(message.sessionID) {
            try write("""
            INSERT INTO messages VALUES(?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET body=excluded.body,phase=excluded.phase,source_at=excluded.source_at,observed_at=excluded.observed_at,redactions=excluded.redactions,truncated=excluded.truncated,attachments_omitted=excluded.attachments_omitted
            WHERE messages.body IS NOT excluded.body OR messages.phase IS NOT excluded.phase OR messages.source_at IS NOT excluded.source_at OR messages.redactions IS NOT excluded.redactions OR messages.truncated IS NOT excluded.truncated OR messages.attachments_omitted IS NOT excluded.attachments_omitted
            """, values: [message.id, message.sessionID, message.turnID, message.speaker, message.phase, message.text, message.sourceAt?.timeIntervalSince1970, message.observedAt.timeIntervalSince1970, message.redactions, message.textTruncated ? 1 : 0, message.attachmentsOmitted ? 1 : 0])
            changes += Int(sqlite3_changes(connection.handle))
        }
        for signal in snapshot.signals where parentIDs.contains(signal.sessionID) {
            try write("""
            INSERT INTO agent_signals VALUES(?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET outcome=excluded.outcome,item_count=excluded.item_count,observed_at=excluded.observed_at
            WHERE agent_signals.outcome IS NOT excluded.outcome OR agent_signals.item_count IS NOT excluded.item_count
            """, values: [signal.id, signal.sessionID, signal.kind, signal.outcome, signal.count, signal.sourceAt?.timeIntervalSince1970, signal.observedAt.timeIntervalSince1970])
            changes += Int(sqlite3_changes(connection.handle))
        }
        for progress in snapshot.memoryProgress where parentIDs.contains(progress.sessionID) {
            try write("""
            INSERT INTO memory_progress VALUES(?,?,?,?,?,?,?,?) ON CONFLICT(session_id) DO UPDATE SET mode=excluded.mode,checked_updated_at=excluded.checked_updated_at,head_target=excluded.head_target,head_cursor=excluded.head_cursor,backfill_cursor=excluded.backfill_cursor,backfill_complete=excluded.backfill_complete,issue=excluded.issue
            WHERE memory_progress.mode IS NOT excluded.mode OR memory_progress.checked_updated_at IS NOT excluded.checked_updated_at OR memory_progress.head_target IS NOT excluded.head_target OR memory_progress.head_cursor IS NOT excluded.head_cursor OR memory_progress.backfill_cursor IS NOT excluded.backfill_cursor OR memory_progress.backfill_complete IS NOT excluded.backfill_complete OR memory_progress.issue IS NOT excluded.issue
            """, values: [progress.sessionID, progress.mode, progress.checkedUpdatedAt?.timeIntervalSince1970, progress.headTarget?.timeIntervalSince1970, progress.headCursor, progress.backfillCursor, progress.backfillComplete ? 1 : 0, progress.issue ? 1 : 0])
            changes += Int(sqlite3_changes(connection.handle))
        }
        return changes
    }
    public func memoryState() throws -> [String: MemoryProgress] {
        let values = try rows("SELECT session_id,mode,checked_updated_at,head_target,head_cursor,backfill_cursor,backfill_complete,issue FROM memory_progress") { row in
            var progress = MemoryProgress(sessionID: string(row, 0))
            progress.mode = string(row, 1)
            progress.checkedUpdatedAt = optionalDate(row, 2); progress.headTarget = optionalDate(row, 3)
            progress.headCursor = sqlite3_column_type(row, 4) == SQLITE_NULL ? nil : string(row, 4)
            progress.backfillCursor = sqlite3_column_type(row, 5) == SQLITE_NULL ? nil : string(row, 5)
            progress.backfillComplete = sqlite3_column_int(row, 6) == 1
            progress.issue = sqlite3_column_int(row, 7) == 1
            return progress
        }
        return Dictionary(uniqueKeysWithValues: values.map { ($0.sessionID, $0) })
    }
    public func knownMemoryIDs() throws -> Set<String> {
        Set(try rows("SELECT id FROM messages UNION SELECT id FROM agent_signals") { string($0, 0) })
    }
    public func memoryMessages(query: String = "", sessionID: String? = nil, limit: Int? = 100) throws -> [ConversationMessage] {
        // Bind values manually here to keep user search text out of SQL source.
        let sql = "SELECT id,session_id,turn_id,speaker,phase,body,source_at,observed_at,redactions,truncated,attachments_omitted FROM messages WHERE (?='' OR INSTR(LOWER(body),LOWER(?))>0) AND (? IS NULL OR session_id=?) ORDER BY COALESCE(source_at,observed_at) DESC,id DESC" + (limit == nil ? "" : " LIMIT \(min(500, max(1, limit!)))")
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection.handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw StoreFailure.corrupt }
        defer { sqlite3_finalize(statement) }
        let copy = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, 1, query, -1, copy); sqlite3_bind_text(statement, 2, query, -1, copy)
        if let sessionID { sqlite3_bind_text(statement, 3, sessionID, -1, copy); sqlite3_bind_text(statement, 4, sessionID, -1, copy) }
        else { sqlite3_bind_null(statement, 3); sqlite3_bind_null(statement, 4) }
        var values: [ConversationMessage] = []
        while true {
            let status = sqlite3_step(statement)
            if status == SQLITE_DONE { return values }
            guard status == SQLITE_ROW else { throw StoreFailure.corrupt }
            values.append(ConversationMessage(id: string(statement, 0), sessionID: string(statement, 1), turnID: string(statement, 2), speaker: string(statement, 3), phase: string(statement, 4), text: string(statement, 5), sourceAt: optionalDate(statement, 6), observedAt: date(statement, 7), redactions: Int(sqlite3_column_int(statement, 8)), textTruncated: sqlite3_column_int(statement, 9) == 1, attachmentsOmitted: sqlite3_column_int(statement, 10) == 1))
        }
    }
    public func eraseConversationMemory() throws {
        try execute("DELETE FROM messages; DELETE FROM agent_signals; DELETE FROM memory_progress; PRAGMA wal_checkpoint(TRUNCATE); VACUUM;")
    }
}
