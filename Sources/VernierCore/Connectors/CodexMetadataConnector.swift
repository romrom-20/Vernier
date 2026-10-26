import Foundation
import Darwin

public enum ConnectorFailure: Error, LocalizedError, Sendable {
    case binaryMissing, timedOut, invalidResponse, responseTooLarge, exited, unsupported(String)
    public var errorDescription: String? {
        switch self {
        case .binaryMissing: "Conductor’s Codex binary was not found. Open Conductor and start a Codex session, then retry."
        case .timedOut: "Codex did not answer within 20 seconds. Your agents were not changed."
        case .invalidResponse: "Codex returned an unsupported response. No raw content was saved."
        case .responseTooLarge: "Codex returned more data than the local safety limit. Try again after updating the adapter."
        case .exited: "The read-only Codex connection closed. Your agents were not changed."
        case .unsupported(let method): "This Codex version could not serve \(method). The adapter needs a compatibility update."
        }
    }
}

/// A disposable read-only stdio client. It never starts/resumes a thread, asks a model, or subscribes to agent content.
public actor CodexMetadataConnector {
    private var historyRetryAfter: [String: Date] = [:]
    public init() {}
    public static func findBinary(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL? {
        let root = home.appendingPathComponent("Library/Application Support/com.conductor.app/agent-binaries/codex", isDirectory: true)
        guard let directories = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return nil }
        return directories.sorted { $0.lastPathComponent.compare($1.lastPathComponent, options: .numeric) == .orderedDescending }
            .map { $0.appendingPathComponent("codex") }.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
    public func fetch(root: URL, salt: String, previous: SessionLibrary = .empty, retentionDays: Int = 30, binary: URL? = nil, timeout: TimeInterval = 20, reconcile: Bool = false, captureConversation: Bool = false, memoryStates: [String: MemoryProgress] = [:], knownMemoryIDs: Set<String> = []) throws -> SessionSnapshot {
        guard let executable = binary ?? Self.findBinary() else { throw ConnectorFailure.binaryMissing }
        let client = try ReadOnlyCodexClient(binary: executable, timeout: timeout)
        defer { client.close() }
        let now = Date()
        _ = try client.request("initialize", params: ["clientInfo": ["name": "vernier_metadata", "version": "0.2.0"], "capabilities": ["experimentalApi": false]])
        try client.notify("initialized")
        var rawSessions: [[String: Any]] = []
        var cursor: String?
        var truncated = false
        var listPages = 0
        var historyReads = 0
        let fullScan = reconcile || previous.sessions.isEmpty
        let memoryBacklog = captureConversation && previous.sessions.contains { session in
            let state = memoryStates[session.id]
            return state == nil || (state?.availableComplete != true && state?.issue != true)
        }
        let watermark = fullScan || memoryBacklog ? nil : previous.sessions.map(\.updatedAt).max()?.addingTimeInterval(-60)
        // Includes vscode: Conductor's local sessions on the verified Mac are reported with that source.
        for page in 0..<3 {
            var params: [String: Any] = ["limit": fullScan || memoryBacklog ? 100 : 32, "sortDirection": "desc", "sourceKinds": ["cli", "vscode", "exec", "appServer", "unknown"], "useStateDbOnly": true, "sortKey": "updated_at"]
            if let cursor { params["cursor"] = cursor }
            let result = try client.request("thread/list", params: params)
            guard let data = result["data"] as? [[String: Any]] else { throw ConnectorFailure.invalidResponse }
            listPages += 1
            rawSessions.append(contentsOf: data)
            cursor = result["nextCursor"] as? String
            // Overlap timestamp ties; only stop once sorted results reach strictly older history.
            let crossedWatermark = watermark.map { mark in data.contains { row in
                (row["updatedAt"] as? NSNumber).map { $0.doubleValue < mark.timeIntervalSince1970 } ?? false
            }} ?? false
            if cursor == nil || crossedWatermark { break }
            if page == 2 { truncated = true }
        }
        var sessions: [SessionMetadata] = []
        var turns: [TurnMetadata] = []
        var memoryReads = 0
        var memoryBudget = 8
        var messages: [ConversationMessage] = []
        var signals: [AgentToolSignal] = []
        var memoryProgress: [MemoryProgress] = []
        var historyBudget = 20
        var historyTimedOut = false
        let oldSessions = Dictionary(uniqueKeysWithValues: previous.sessions.map { ($0.id, $0) })
        var seenSessions = Set<String>()
        for raw in rawSessions {
            guard let candidate = MetadataBoundary.session(raw, root: root, salt: salt, now: now, turnsComplete: false), let rawID = raw["id"] as? String else { continue }
            guard candidate.updatedAt >= RetentionPolicy.cutoff(days: retentionDays, now: now),
                  seenSessions.insert(candidate.id).inserted else { continue }
            if captureConversation, memoryBudget > 0 {
                let state = memoryStates[candidate.id]
                if state?.availableComplete != true || state?.checkedUpdatedAt != candidate.updatedAt {
                    memoryBudget -= 1
                    let read = try readMemory(client: client, rawID: rawID, session: candidate, previous: state, knownIDs: knownMemoryIDs, salt: salt, now: now)
                    memoryReads += read.pages
                    messages.append(contentsOf: read.messages)
                    signals.append(contentsOf: read.signals)
                    memoryProgress.append(read.progress)
                }
            }
            if !fullScan, let old = oldSessions[candidate.id], old.updatedAt == candidate.updatedAt,
               old.turnsComplete || !previous.turns(for: old).isEmpty { continue }
            if let retry = historyRetryAfter[candidate.id], retry > now {
                if oldSessions[candidate.id]?.updatedAt != candidate.updatedAt { sessions.append(candidate) }
                continue
            }
            if historyBudget == 0 || historyTimedOut {
                if oldSessions[candidate.id]?.updatedAt != candidate.updatedAt { sessions.append(candidate) }
                continue
            }
            historyBudget -= 1
            var complete = false
            var turnCursor: String?
            // Bound each session to 100 most recent turns. Missing coverage is explicit.
            do {
                for _ in 0..<2 {
                    var params: [String: Any] = ["threadId": rawID, "limit": 50, "itemsView": "notLoaded", "sortDirection": "desc"]
                    if let turnCursor { params["cursor"] = turnCursor }
                    historyReads += 1
                    let result = try client.request("thread/turns/list", params: params)
                    guard let rows = result["data"] as? [[String: Any]] else { throw ConnectorFailure.invalidResponse }
                    turns.append(contentsOf: rows.compactMap { MetadataBoundary.turn($0, sessionID: candidate.id, salt: salt, now: now) })
                    turnCursor = result["nextCursor"] as? String
                    if turnCursor == nil { complete = true; break }
                }
            } catch ConnectorFailure.unsupported {
                historyRetryAfter[candidate.id] = now.addingTimeInterval(300)
            } catch ConnectorFailure.timedOut {
                historyRetryAfter[candidate.id] = now.addingTimeInterval(300)
                historyTimedOut = true
            }
            if let record = MetadataBoundary.session(raw, root: root, salt: salt, now: now, turnsComplete: complete) { sessions.append(record) }
        }
        return SessionSnapshot(sessions: sessions, turns: turns, truncated: truncated, observedAt: now, diagnostics: .init(listPages: listPages, historyReads: historyReads, memoryReads: memoryReads, reconciliation: fullScan && !truncated), messages: messages, signals: signals, memoryProgress: memoryProgress)
    }
}

final class ReadOnlyCodexClient {
    private let process = Process()
    private let input = Pipe()
    private let output = Pipe()
    private var buffer = Data()
    private var nextID = 0
    private let deadline: Date
    private var closed = false
    private static let methods: Set<String> = ["initialize", "thread/list", "thread/turns/list", "thread/items/list"]
    init(binary: URL, timeout: TimeInterval) throws {
        deadline = Date().addingTimeInterval(min(20, max(0.1, timeout)))
        process.executableURL = binary
        process.arguments = ["app-server", "--stdio", "-c", "analytics.enabled=false"]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice // Never log provider responses or errors containing content.
        try process.run()
    }
    func request(_ method: String, params: [String: Any]) throws -> [String: Any] {
        guard Self.methods.contains(method) else { throw ConnectorFailure.unsupported(method) }
        nextID += 1
        let id = nextID
        try send(["id": id, "method": method, "params": params])
        while true {
            let line = try readLine()
            guard let message = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any] else { throw ConnectorFailure.invalidResponse }
            guard (message["id"] as? Int) == id else {
                // This client opens no threads. Reject unsolicited server requests, don't execute tools.
                if let requestID = message["id"], message["method"] != nil {
                    try send(["id": requestID, "error": ["code": -32601, "message": "Read-only client"]])
                }
                continue
            }
            if message["error"] != nil { throw ConnectorFailure.unsupported(method) }
            guard let result = message["result"] as? [String: Any] else { throw ConnectorFailure.invalidResponse }
            return result
        }
    }
    func notify(_ method: String) throws { guard method == "initialized" else { throw ConnectorFailure.unsupported(method) }; try send(["method": method, "params": [:]]) }
    private func send(_ value: [String: Any]) throws {
        var data = try JSONSerialization.data(withJSONObject: value)
        data.append(10)
        try input.fileHandleForWriting.write(contentsOf: data)
    }
    private func readLine() throws -> Data {
        while true {
            if let newline = buffer.firstIndex(of: 10) {
                let line = Data(buffer[..<newline]); buffer.removeSubrange(...newline); return line
            }
            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 0 else { throw ConnectorFailure.timedOut }
            var descriptor = pollfd(fd: output.fileHandleForReading.fileDescriptor, events: Int16(POLLIN), revents: 0)
            let result = poll(&descriptor, 1, Int32(min(remaining * 1000, 1000)))
            if result < 0 { if errno == EINTR { continue }; throw ConnectorFailure.exited }
            if result == 0 { continue }
            // FileHandle.read(upToCount:) can wait to fill a pipe buffer on Darwin.
            // A single POSIX read after poll preserves the deadline and request/response flow.
            var bytes = [UInt8](repeating: 0, count: 65_536)
            let count = Darwin.read(descriptor.fd, &bytes, bytes.count)
            if count < 0 { if errno == EINTR || errno == EAGAIN { continue }; throw ConnectorFailure.exited }
            guard count > 0 else { throw ConnectorFailure.exited }
            buffer.append(contentsOf: bytes.prefix(count))
            if buffer.count > 16 * 1024 * 1024 { throw ConnectorFailure.responseTooLarge }
        }
    }
    func close() {
        guard !closed else { return }; closed = true
        try? input.fileHandleForWriting.close()
        if process.isRunning { process.terminate() }
        // A malformed or stalled child must not outlive its disposable metadata request indefinitely.
        let child = process
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) { if child.isRunning { kill(child.processIdentifier, SIGKILL) } }
    }
    deinit { close() }
}
