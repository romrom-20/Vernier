import CoreFoundation
import Foundation
import CryptoKit

public enum SessionOutcome: String, Codable, Sendable, CaseIterable {
    case completed, interrupted, failed, inProgress, unknown
    public var label: String {
        switch self {
        case .completed: "Completed"
        case .interrupted: "Interrupted"
        case .failed: "Failed"
        case .inProgress: "In progress at observation"
        case .unknown: "Unknown"
        }
    }
    public init(providerValue: String) {
        switch providerValue {
        case "completed": self = .completed
        case "interrupted": self = .interrupted
        case "failed": self = .failed
        case "inProgress": self = .inProgress
        default: self = .unknown
        }
    }
}

public struct SessionMetadata: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let workspaceID: String
    public let createdAt: Date
    public let updatedAt: Date
    public let observedAt: Date
    public let sourceKind: String
    public let turnsComplete: Bool
    public var label: String { "Session \(id.prefix(8))" }
    public var workspaceLabel: String { "Workspace \(workspaceID.prefix(6))" }
}

public struct TurnMetadata: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let sessionID: String
    public let outcome: SessionOutcome
    public let startedAt: Date?
    public let completedAt: Date?
    public let observedAt: Date
}

public struct SessionSnapshot: Sendable {
    public let sessions: [SessionMetadata]
    public let turns: [TurnMetadata]
    public let truncated: Bool
    public let observedAt: Date
    public let diagnostics: SyncDiagnostics
    public let messages: [ConversationMessage]
    public let signals: [AgentToolSignal]
    public let memoryProgress: [MemoryProgress]
    public init(sessions: [SessionMetadata], turns: [TurnMetadata], truncated: Bool, observedAt: Date, diagnostics: SyncDiagnostics = .init(), messages: [ConversationMessage] = [], signals: [AgentToolSignal] = [], memoryProgress: [MemoryProgress] = []) {
        self.sessions = sessions; self.turns = turns; self.truncated = truncated; self.observedAt = observedAt; self.diagnostics = diagnostics
        self.messages = messages; self.signals = signals; self.memoryProgress = memoryProgress
    }
}

public enum MetadataBoundary {
    public static func hash(_ value: String, salt: String) -> String {
        SHA256.hash(data: Data((salt + ":" + value).utf8)).map { String(format: "%02x", $0) }.joined()
    }
    public static func isConductorWorkspace(_ cwd: String, root: URL) -> Bool {
        guard cwd.hasPrefix("/"), !cwd.contains("\0") else { return false }
        let components = URL(fileURLWithPath: cwd).standardizedFileURL.pathComponents
        let rootComponents = root.standardizedFileURL.pathComponents
        // Conductor creates <root>/<repository>/<workspace>; do not include a sibling path prefix.
        return components.count >= rootComponents.count + 2 && Array(components.prefix(rootComponents.count)) == rootComponents
    }
    public static func session(_ value: [String: Any], root: URL, salt: String, now: Date, turnsComplete: Bool) -> SessionMetadata? {
        guard let id = value["id"] as? String, !id.isEmpty, id.utf8.count < 512,
              let cwd = value["cwd"] as? String, isConductorWorkspace(cwd, root: root),
              let created = finiteDate(value["createdAt"]), let updated = finiteDate(value["updatedAt"]) else { return nil }
        let source = value["source"] as? String ?? "unknown"
        let safeSource = ["cli", "vscode", "exec", "appServer"].contains(source) ? source : "unknown"
        // Titles, previews, raw paths, model messages and git URLs are deliberately not copied.
        return SessionMetadata(id: hash(id, salt: salt), workspaceID: hash(URL(fileURLWithPath: cwd).standardizedFileURL.path, salt: salt), createdAt: created, updatedAt: updated, observedAt: now, sourceKind: safeSource, turnsComplete: turnsComplete)
    }
    public static func turn(_ value: [String: Any], sessionID: String, salt: String, now: Date) -> TurnMetadata? {
        guard let id = value["id"] as? String, !id.isEmpty, id.utf8.count < 512 else { return nil }
        // The API is requested with itemsView=notLoaded. Even unexpected item/error data is dropped.
        return TurnMetadata(id: hash(sessionID + ":" + id, salt: salt), sessionID: sessionID,
                            outcome: SessionOutcome(providerValue: value["status"] as? String ?? "unknown"),
                            startedAt: finiteDate(value["startedAt"]), completedAt: finiteDate(value["completedAt"]), observedAt: now)
    }
    private static func finiteDate(_ value: Any?) -> Date? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(), number.doubleValue.isFinite else { return nil }
        let seconds = number.doubleValue
        // Current protocol uses Unix seconds. Reject implausible/millisecond values instead of guessing.
        guard seconds > 0, seconds < 32_503_680_000 else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }
}
