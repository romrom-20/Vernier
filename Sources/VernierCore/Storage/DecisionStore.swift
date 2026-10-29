import Foundation
import CSQLite
import CryptoKit

extension SessionStore {
    public func loadDecisionRevisions(sessionID: String? = nil, limit: Int? = 200) throws -> [DecisionRevision] {
        var values: [Any?] = []
        var sql = "SELECT payload FROM decision_revisions"
        if let sessionID { sql += " WHERE session_id=?"; values = [sessionID] }
        sql += " ORDER BY created_at DESC,id DESC"
        if let limit { sql += " LIMIT \(max(1, min(1000, limit)))" }
        let payloads: [String] = try decisionRows(sql, values: values) { string($0, 0) }
        return payloads.compactMap { try? JSONDecoder().decode(DecisionRevision.self, from: Data($0.utf8)) }
    }
    public func loadLatestDecisionRevisions() throws -> [DecisionRevision] {
        let payloads: [String] = try decisionRows("SELECT d.payload FROM decision_revisions d WHERE d.id=(SELECT n.id FROM decision_revisions n WHERE n.session_id=d.session_id ORDER BY n.created_at DESC,n.id DESC LIMIT 1) ORDER BY d.created_at DESC,d.id DESC", values: []) { string($0, 0) }
        return payloads.compactMap { try? JSONDecoder().decode(DecisionRevision.self, from: Data($0.utf8)) }
    }
    public func loadDecisionPerspectives(sessionID: String? = nil) throws -> [DecisionPerspective] {
        let sql = "SELECT p.id,p.session_id,p.body,p.created_at,p.revision_id,d.anchor_id,d.payload FROM decision_perspectives p JOIN decision_revisions d ON d.id=p.revision_id" + (sessionID == nil ? "" : " WHERE p.session_id=?") + " ORDER BY p.created_at,p.id"
        return try decisionRows(sql, values: sessionID.map { [$0] } ?? []) { row in
            DecisionPerspective(id: string(row, 0), sessionID: string(row, 1), text: string(row, 2), createdAt: date(row, 3), revisionID: string(row, 4), anchorMessageID: string(row, 5), signalKey: (try? JSONDecoder().decode(DecisionRevision.self, from: Data(string(row, 6).utf8)))?.reading?.signalKey)
        }
    }
    /// User-authored local perspective, separate from observation and model inference.
    public func saveDecisionPerspective(_ perspective: DecisionPerspective, revisionID: String) throws {
        guard !perspective.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, perspective.text.count <= 1500,
              let anchor: String = try decisionRows("SELECT anchor_id FROM decision_revisions WHERE id=? AND session_id=?", values: [revisionID, perspective.sessionID], transform: { string($0, 0) }).first,
              perspective.revisionID == nil || perspective.revisionID == revisionID, perspective.anchorMessageID == nil || perspective.anchorMessageID == anchor else { throw StoreFailure.unavailable }
        try write("INSERT INTO decision_perspectives VALUES(?,?,?,?,?)", values: [perspective.id, perspective.sessionID, revisionID, perspective.text, perspective.createdAt.timeIntervalSince1970])
    }
    public func decisionContext(sessionID: String) throws -> DecisionContext? {
        let recent = try memoryMessages(sessionID: sessionID, limit: 60)
        let previous = try loadDecisionRevisions(sessionID: sessionID, limit: 1).first
        let perspectives = Array(try loadDecisionPerspectives(sessionID: sessionID).suffix(3))
        var messages = recent
        let latestUsers = Array(try memoryMessages(sessionID: sessionID, limit: 20, speaker: "user").filter { !SessionDisplay.visibleText($0.text).isEmpty }.prefix(3))
        for message in latestUsers where !messages.contains(where: { $0.id == message.id }) { messages.append(message) }
        if let anchor = latestUsers.first {
            let time = (anchor.sourceAt ?? anchor.observedAt).timeIntervalSince1970
            let ids: [String] = try decisionRows("SELECT id FROM messages WHERE session_id=? AND (COALESCE(source_at,observed_at)<? OR (COALESCE(source_at,observed_at)=? AND id<?)) ORDER BY COALESCE(source_at,observed_at) DESC,id DESC LIMIT 3", values: [sessionID, time, time, anchor.id]) { string($0, 0) }
            for id in ids where !messages.contains(where: { $0.id == id }) { if let message = try decisionMessage(id) { messages.append(message) } }
        }
        for report in perspectives {
            if let id = report.anchorMessageID, !messages.contains(where: { $0.id == id }), let target = try decisionMessage(id) { messages.append(target) }
        }
        let known = Set(messages.map(\.id))
        for evidence in previous?.evidence ?? [] where !evidence.messageID.hasPrefix("feedback:") && !known.contains(evidence.messageID) {
            if let message = try decisionMessage(evidence.messageID) { messages.append(message) }
        }
        // Search known agent text for long phrases in the current user message, including outside the recent window.
        if let user = latestUsers.first {
            let text = SessionDisplay.visibleText(user.text)
            let phrases = text.components(separatedBy: .newlines).filter { $0.count >= 70 }.prefix(4)
            for line in phrases {
                let query = String(line.prefix(100))
                let matches = try memoryMessages(query: query, sessionID: sessionID, limit: 3, speaker: "assistant")
                for match in matches where !messages.contains(where: { $0.id == match.id }) && (match.sourceAt ?? match.observedAt) <= (user.sourceAt ?? user.observedAt) { messages.append(match) }
            }
        }
        let opening = try memoryMessages(sessionID: sessionID, limit: 3, newestFirst: false, speaker: "user")
        for message in opening where !messages.contains(where: { $0.id == message.id }) { messages.append(message) }
        let preliminary = DecisionContext.make(sessionID: sessionID, messages: messages, perspectives: [], previous: previous, storedMessages: recent.count)
        let wording = preliminary?.anchor?.novelText ?? ""
        let query = wording.count < 80 ? wording + " " + (previous?.reading?.goal ?? "") : wording
        let related = try relatedDecisionMessages(sessionID: sessionID, query: query, previous: previous)
        let count: Int = try decisionRows("SELECT COUNT(*) FROM messages WHERE session_id=?", values: [sessionID]) { Int(sqlite3_column_int64($0, 0)) }.first ?? recent.count
        return DecisionContext.make(sessionID: sessionID, messages: messages, perspectives: perspectives, previous: previous, storedMessages: count, retrieved: related.0, relatedMessageCounts: related.1)
    }
    @discardableResult public func saveDecisionRevision(_ revision: DecisionRevision, context: DecisionContext, token: Int) throws -> Bool {
        guard revision.inputDigest == context.inputDigest, revision.sessionID == context.sessionID else { return false }
        var saved = false
        _ = try gate.captureBrief(token) {
            try execute("BEGIN IMMEDIATE")
            do {
                let latest = try memoryMessages(sessionID: context.sessionID, limit: 1).first
                let frontier = context.frontier
                guard let latest, latest.id == frontier?.messageID, DecisionSource.fingerprint(latest) == frontier?.fingerprint else { try execute("ROLLBACK"); return }
                let expectedCounts = context.relatedMessageCounts.merging([context.sessionID: context.storedMessages]) { _, current in current }
                for (id, expected) in expectedCounts {
                    let count: Int = try decisionRows("SELECT COUNT(*) FROM messages WHERE session_id=?", values: [id]) { Int(sqlite3_column_int64($0, 0)) }.first ?? 0
                    guard count == expected else { try execute("ROLLBACK"); return }
                }
                for source in context.sources {
                    if source.messageID.hasPrefix("feedback:") {
                        guard let report = try loadDecisionPerspectives(sessionID: context.sessionID).first(where: { "feedback:" + $0.id == source.messageID }),
                              Self.textDigest(report.text) == source.fingerprint else { try execute("ROLLBACK"); return }
                    } else {
                        guard let current = try decisionMessage(source.messageID), DecisionSource.fingerprint(current) == source.fingerprint else { try execute("ROLLBACK"); return }
                    }
                }
                let currentReports = try loadDecisionPerspectives(sessionID: context.sessionID)
                guard Array(currentReports.suffix(3)).map(\.id) == context.perspectives.map(\.id) else { try execute("ROLLBACK"); return }
                let data = try JSONEncoder().encode(revision)
                guard data.count < 96_000 else { throw StoreFailure.unavailable }
                try write("INSERT INTO decision_revisions VALUES(?,?,?,?,?,?)", values: [revision.id, revision.sessionID, revision.anchorMessageID, revision.createdAt.timeIntervalSince1970, revision.inputDigest, String(decoding: data, as: UTF8.self)])
                for source in context.sources {
                    let reportID: String? = source.messageID.hasPrefix("feedback:") ? String(source.messageID.dropFirst(9)) : nil
                    try write("INSERT INTO decision_sources VALUES(?,?,?)", values: [revision.id, reportID == nil ? source.messageID : nil, reportID])
                }
                if let frontier = context.frontier, !context.sources.contains(where: { $0.messageID == frontier.messageID }) {
                    try write("INSERT INTO decision_sources VALUES(?,?,NULL)", values: [revision.id, frontier.messageID])
                }
                // Keep a bounded history, retaining revisions with an attached human perspective.
                try write("""
                DELETE FROM decision_revisions WHERE session_id=? AND id NOT IN
                (SELECT id FROM decision_revisions WHERE session_id=? ORDER BY created_at DESC,id DESC LIMIT 40)
                AND id NOT IN (SELECT revision_id FROM decision_perspectives)
                """, values: [revision.sessionID, revision.sessionID])
                try execute("COMMIT"); saved = true
            } catch { try? execute("ROLLBACK"); throw error }
        }
        return saved
    }
    /// Lexical ranking retrieves candidates only. It never declares two conversations the same task.
    private func relatedDecisionMessages(sessionID: String, query: String, previous: DecisionRevision?) throws -> ([ConversationMessage], [String: Int]) {
        guard let workspace: String = try decisionRows("SELECT workspace_id FROM sessions WHERE id=?", values: [sessionID], transform: { string($0, 0) }).first else { return ([], [:]) }
        let payloads: [String] = try decisionRows("SELECT d.payload FROM decision_revisions d JOIN sessions s ON s.id=d.session_id WHERE s.workspace_id=? AND d.session_id<>? ORDER BY d.created_at DESC LIMIT 60", values: [workspace, sessionID]) { string($0, 0) }
        let stop = Set("this that with from have want make work does again still please should there their when then only same been what your agent keep trying question answer explain user model before after just current change text request code".split(separator: " ").map(String.init))
        func terms(_ text: String) -> Set<String> { Set(text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count >= 4 && !stop.contains($0) }) }
        let wanted = terms(query)
        let previouslyUsed = Set(previous?.relatedMessageCounts.keys.map { $0 } ?? [])
        var seen = Set<String>()
        let candidates = payloads.compactMap { try? JSONDecoder().decode(DecisionRevision.self, from: Data($0.utf8)) }.filter { seen.insert($0.sessionID).inserted }
        let ranked = candidates.map { ($0, wanted.intersection(terms($0.goal)).count) }.filter { $0.1 >= 2 || previouslyUsed.contains($0.0.sessionID) }.sorted { $0.1 > $1.1 }
        var result: [ConversationMessage] = []; var counts: [String: Int] = [:]
        for (account, _) in ranked.prefix(2) {
            var values = try memoryMessages(sessionID: account.sessionID, limit: 2)
            for evidence in account.evidence.prefix(2) where !evidence.messageID.hasPrefix("feedback:") {
                if let message = try decisionMessage(evidence.messageID), message.sessionID == account.sessionID, !values.contains(where: { $0.id == message.id }) { values.append(message) }
            }
            for message in values where !result.contains(where: { $0.id == message.id }) { result.append(message) }
            counts[account.sessionID] = try decisionRows("SELECT COUNT(*) FROM messages WHERE session_id=?", values: [account.sessionID]) { Int(sqlite3_column_int64($0, 0)) }.first ?? 0
        }
        return (Array(result.prefix(4)), counts)
    }
    private static func textDigest(_ text: String) -> String { SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined() }
    public func memoryMessage(id: String) throws -> ConversationMessage? { try decisionMessage(id) }
    private func decisionMessage(_ id: String) throws -> ConversationMessage? {
        try decisionRows("SELECT id,session_id,turn_id,speaker,phase,body,source_at,observed_at,redactions,truncated,attachments_omitted FROM messages WHERE id=?", values: [id]) { row in
            ConversationMessage(id: string(row, 0), sessionID: string(row, 1), turnID: string(row, 2), speaker: string(row, 3), phase: string(row, 4), text: string(row, 5), sourceAt: optionalDate(row, 6), observedAt: date(row, 7), redactions: Int(sqlite3_column_int(row, 8)), textTruncated: sqlite3_column_int(row, 9) == 1, attachmentsOmitted: sqlite3_column_int(row, 10) == 1)
        }.first
    }
    private func decisionRows<T>(_ sql: String, values: [Any?], transform: (OpaquePointer) -> T) throws -> [T] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection.handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw StoreFailure.corrupt }
        defer { sqlite3_finalize(statement) }
        let copy = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (offset, value) in values.enumerated() {
            if let text = value as? String { sqlite3_bind_text(statement, Int32(offset + 1), text, -1, copy) }
            else if let number = value as? Double { sqlite3_bind_double(statement, Int32(offset + 1), number) }
            else { sqlite3_bind_null(statement, Int32(offset + 1)) }
        }
        var result: [T] = []
        while true {
            let status = sqlite3_step(statement)
            if status == SQLITE_DONE { return result }
            guard status == SQLITE_ROW else { throw StoreFailure.corrupt }
            result.append(transform(statement))
        }
    }
}
