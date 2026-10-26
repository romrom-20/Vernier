import Foundation

public struct ConversationMessage: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let sessionID: String
    public let turnID: String
    public let speaker: String
    public let phase: String
    public let text: String
    public let sourceAt: Date?
    public let observedAt: Date
    public let redactions: Int
    public let textTruncated: Bool
    public let attachmentsOmitted: Bool
    public var isContinuationCue: Bool { speaker == "user" && PromptSignals.isContinuationCue(text) }
}

public struct AgentToolSignal: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let sessionID: String
    public let kind: String
    public let outcome: String
    public let count: Int
    public let sourceAt: Date?
    public let observedAt: Date
}

/// Opaque pagination state stays private in connector storage and is never shown as conversation content.
public struct MemoryProgress: Sendable {
    public let sessionID: String
    public var mode = "items"
    public var checkedUpdatedAt: Date?
    public var headTarget: Date?
    public var headCursor: String?
    public var backfillCursor: String?
    public var backfillComplete = false
    public var issue = false
    public var availableComplete: Bool { checkedUpdatedAt != nil && headCursor == nil && backfillComplete && !issue }
    public init(sessionID: String) { self.sessionID = sessionID }
}

public struct MemoryCoverage: Codable, Sendable {
    public let sessionID: String
    public let complete: Bool
    public let issue: Bool
}

public enum PromptSignals {
    /// A wording flag only: not evidence of fatigue, disengagement, or understanding.
    public static func isContinuationCue(_ text: String) -> Bool {
        guard text.count <= 100 else { return false }
        return text.range(of: #"(?i)^\s*(?:yes[,!. ]*)?(?:please\s+)?(?:continue|proceed|go ahead|keep going|do it|carry on)[.!\s]*$"#, options: .regularExpression) != nil
    }
}

public enum ConversationBoundary {
    public static func redact(_ input: String) -> (text: String, count: Int, truncated: Bool) {
        let truncated = input.utf8.count > 262_144
        var text = String(decoding: input.utf8.prefix(262_144), as: UTF8.self)
        var count = 0
        let patterns = [
            #"-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?(?:-----END [A-Z ]*PRIVATE KEY-----|$)"#,
            #"(?i)\bBearer\s+[A-Za-z0-9._~+/=-]+"#,
            #"\b(?:sk-[A-Za-z0-9_-]{12,}|gh[pousr]_[A-Za-z0-9]{20,}|AKIA[A-Z0-9]{16})\b"#,
            #"(?i)\b[A-Z0-9_]*(?:api[_-]?key|access[_-]?token|client[_-]?secret|password)[\"']?\s*[:=]\s*(?:"[^"]*"|'[^']*'|[^\s\"',;}]+)"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            count += regex.numberOfMatches(in: text, range: range)
            text = regex.stringByReplacingMatches(in: text, range: range, withTemplate: "[REDACTED_CREDENTIAL]")
        }
        return (text, count, truncated)
    }
    public static func message(_ entry: [String: Any], sessionID: String, salt: String, now: Date) -> ConversationMessage? {
        guard let item = entry["item"] as? [String: Any], let id = item["id"] as? String,
              let turnID = entry["turnId"] as? String, !id.isEmpty, id.count < 512, turnID.count < 512 else { return nil }
        let kind = item["type"] as? String
        let speaker: String
        let raw: String
        let attachments: Bool
        if kind == "userMessage", let content = item["content"] as? [[String: Any]] {
            speaker = "user"
            raw = content.filter { $0["type"] as? String == "text" }.compactMap { $0["text"] as? String }.joined(separator: "\n")
            attachments = content.contains { $0["type"] as? String != "text" }
        } else if kind == "agentMessage", let text = item["text"] as? String {
            speaker = "assistant"; raw = text; attachments = false
        } else { return nil }
        guard !raw.isEmpty else { return nil }
        let redacted = redact(raw)
        let phase = item["phase"] as? String ?? "unspecified"
        guard ["final_answer", "commentary", "unspecified"].contains(phase) else { return nil }
        return ConversationMessage(id: MetadataBoundary.hash(sessionID + ":" + id, salt: salt), sessionID: sessionID,
                                   turnID: MetadataBoundary.hash(sessionID + ":" + turnID, salt: salt), speaker: speaker,
                                   phase: ["final_answer", "commentary"].contains(phase) ? phase : "unspecified", text: redacted.text,
                                   sourceAt: timestamp(entry), observedAt: now, redactions: redacted.count,
                                   textTruncated: redacted.truncated, attachmentsOmitted: attachments)
    }
    public static func signal(_ entry: [String: Any], sessionID: String, salt: String, now: Date) -> AgentToolSignal? {
        guard let item = entry["item"] as? [String: Any], let id = item["id"] as? String, !id.isEmpty, id.count < 512 else { return nil }
        let type = item["type"] as? String
        let kind: String
        var count = 1
        var outcome = "unknown"
        if type == "fileChange" {
            kind = "file_changes"
            count = (item["changes"] as? [Any])?.count ?? 0
            outcome = item["status"] as? String == "completed" ? "reported_complete" : "unknown"
        } else if type == "commandExecution" {
            kind = "command_execution"
            if let code = item["exitCode"] as? Int { outcome = code == 0 ? "exit_zero" : "exit_nonzero" }
        } else { return nil }
        // Never copy command, cwd, aggregatedOutput, diffs, paths or tool arguments.
        return AgentToolSignal(id: MetadataBoundary.hash(sessionID + ":" + id, salt: salt), sessionID: sessionID, kind: kind, outcome: outcome,
                               count: count, sourceAt: timestamp(entry), observedAt: now)
    }
    private static func timestamp(_ entry: [String: Any]) -> Date? {
        guard let value = (entry["completedAtMs"] as? NSNumber) ?? (entry["startedAtMs"] as? NSNumber),
              value.doubleValue.isFinite, value.doubleValue > 0, value.doubleValue < 32_503_680_000_000 else { return nil }
        return Date(timeIntervalSince1970: value.doubleValue / 1000)
    }
}

struct MemoryRead {
    var pages = 0
    var messages: [ConversationMessage] = []
    var signals: [AgentToolSignal] = []
    var progress: MemoryProgress
}

extension CodexMetadataConnector {
    func readMemory(client: ReadOnlyCodexClient, rawID: String, session: SessionMetadata, previous: MemoryProgress?, knownIDs: Set<String>, salt: String, now: Date) throws -> MemoryRead {
        var result = MemoryRead(progress: previous ?? MemoryProgress(sessionID: session.id))
        if result.progress.availableComplete && result.progress.checkedUpdatedAt == session.updatedAt { return result }
        result.progress.issue = false
        func page(direction: String, cursor: String?) throws -> (rows: [[String: Any]], cursor: String?) {
            result.pages += 1
            var params: [String: Any] = ["threadId": rawID, "limit": 100, "sortDirection": direction]
            if let cursor { params["cursor"] = cursor }
            if result.progress.mode == "items" {
                let response = try client.request("thread/items/list", params: params)
                guard let rows = response["data"] as? [[String: Any]] else { throw ConnectorFailure.invalidResponse }
                return (rows, response["nextCursor"] as? String)
            }
            params["limit"] = 20
            params["itemsView"] = "full"
            let response = try client.request("thread/turns/list", params: params)
            guard let turns = response["data"] as? [[String: Any]] else { throw ConnectorFailure.invalidResponse }
            let rows: [[String: Any]] = turns.flatMap { turn in
                (turn["items"] as? [[String: Any]] ?? []).map { item in
                    var entry: [String: Any] = ["item": item, "turnId": turn["id"] as? String ?? "unknown"]
                    // Fallback timestamp is the turn boundary, not an exact message-reading time.
                    if let seconds = turn["startedAt"] as? NSNumber { entry["startedAtMs"] = seconds.doubleValue * 1000 }
                    return entry
                }
            }
            return (rows, response["nextCursor"] as? String)
        }
        func keep(_ rows: [[String: Any]]) -> Bool {
            var intersects = false
            for row in rows {
                if let message = ConversationBoundary.message(row, sessionID: session.id, salt: salt, now: now) {
                    intersects = intersects || knownIDs.contains(message.id); result.messages.append(message)
                }
                if let signal = ConversationBoundary.signal(row, sessionID: session.id, salt: salt, now: now) {
                    intersects = intersects || knownIDs.contains(signal.id); result.signals.append(signal)
                }
            }
            return intersects
        }
        do {
            // Keep up with new text while a large older conversation backfills independently.
            if result.progress.checkedUpdatedAt != session.updatedAt || result.progress.headCursor != nil {
                if result.progress.headCursor == nil { result.progress.headTarget = session.updatedAt }
                let head = try page(direction: "desc", cursor: result.progress.headCursor)
                let intersects = keep(head.rows)
                result.progress.headCursor = intersects ? nil : head.cursor
                if result.progress.headCursor == nil { result.progress.checkedUpdatedAt = result.progress.headTarget }
            }
            if !result.progress.backfillComplete {
                let older = try page(direction: "asc", cursor: result.progress.backfillCursor)
                _ = keep(older.rows)
                result.progress.backfillCursor = older.cursor
                result.progress.backfillComplete = older.cursor == nil
            }
        } catch ConnectorFailure.unsupported {
            if result.progress.mode == "items" {
                result.progress = MemoryProgress(sessionID: session.id)
                result.progress.mode = "turns"
            } else { result.progress.issue = true }
        } catch {
            result.progress.issue = true
        }
        return result
    }
}
