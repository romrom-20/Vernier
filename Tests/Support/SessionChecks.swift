import Foundation
import VernierCore

public enum SessionChecks {
    public static let cases: [(String, @Sendable () async throws -> Void)] = [
        ("Metadata allowlist, salted identities and workspace scope", boundary),
        ("1,000 records: deduplication, pause race, export, retention and deletion", storage),
        ("Read-only protocol fixture and content exclusion", protocolFixture),
        ("Resident cadence, checkpoints and hourly rhythm", residentPolicy),
        ("Schema v1 upgrade preserves sessions and personal notes", migration),
        ("Incremental pagination overlaps timestamp ties", pagination),
        ("Quick-view sizing and quiet pill presentation", interaction),
        ("Readable session excerpts exclude injected context", sessionExcerpts)
    ]
    static func expect(_ value: @autoclosure () -> Bool, _ message: String) throws {
        if !value() { throw CoreCheckFailure(description: message) }
    }
    static let root = URL(fileURLWithPath: "/test/conductor/workspaces")
    static func rawSession(_ index: Int, now: Date = Date()) -> [String: Any] {
        ["id": "provider-session-\(index)", "cwd": root.appendingPathComponent("repo/workspace-\(index)").path,
         "createdAt": now.timeIntervalSince1970 - 10, "updatedAt": now.timeIntervalSince1970, "source": "vscode",
         "preview": "PRIVATE_PROMPT_Bearer_sk-secret", "name": "private-document-name", "gitInfo": ["originUrl": "https://secret.example"]]
    }
    static func rawTurn(_ index: Int, now: Date = Date()) -> [String: Any] {
        ["id": "turn-\(index)", "status": "completed", "startedAt": now.timeIntervalSince1970 - 2, "completedAt": now.timeIntervalSince1970,
         "items": [["content": "PRIVATE_RESPONSE_sk-secret"]], "error": ["message": "private-credential"]]
    }
    private static func boundary() async throws {
        let now = Date()
        let value = rawSession(1, now: now)
        guard let a = MetadataBoundary.session(value, root: root, salt: "a", now: now, turnsComplete: true),
              let b = MetadataBoundary.session(value, root: root, salt: "b", now: now, turnsComplete: true) else { throw CoreCheckFailure(description: "Valid fixture rejected") }
        try expect(a.id != b.id && a.workspaceID != b.workspaceID, "IDs must use a local salt")
        try expect(a.id.count == 64 && !a.label.contains("provider"), "Raw provider identity leaked")
        let encoder = JSONEncoder()
        let json = String(decoding: try encoder.encode(a), as: UTF8.self)
        for secret in ["PRIVATE", "Bearer", "sk-secret", "private-document", "/test/", "originUrl"] { try expect(!json.contains(secret), "Dropped session content leaked: \(secret)") }
        var malformed = value; malformed["createdAt"] = true
        try expect(MetadataBoundary.session(malformed, root: root, salt: "a", now: now, turnsComplete: true) == nil, "Boolean timestamp accepted")
        malformed["createdAt"] = Double.nan
        try expect(MetadataBoundary.session(malformed, root: root, salt: "a", now: now, turnsComplete: true) == nil, "NaN timestamp accepted")
        try expect(!MetadataBoundary.isConductorWorkspace(root.path + "-evil/repo/workspace", root: root), "Sibling prefix accepted")
        try expect(!MetadataBoundary.isConductorWorkspace(root.path + "/repo/../../elsewhere", root: root), "Path traversal accepted")
        try expect(!MetadataBoundary.isConductorWorkspace("/different/repo/workspace", root: root), "Unrelated workspace accepted")
        var turn = rawTurn(1); turn["status"] = "brand-new-provider-status"
        let normalized = MetadataBoundary.turn(turn, sessionID: a.id, salt: "a", now: now)
        try expect(normalized?.outcome == .unknown, "New statuses must remain unknown")
        let turnJSON = String(decoding: try encoder.encode(normalized), as: UTF8.self)
        try expect(!turnJSON.contains("PRIVATE") && !turnJSON.contains("credential"), "Turn item/error content leaked")
    }
    private static func storage() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("vernier-store-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let gate = ObservationGate()
        let token = gate.configure(enabled: true)
        let store = try SessionStore(directory: dir, gate: gate)
        let now = Date()
        let sessions = (0..<1000).compactMap { MetadataBoundary.session(rawSession($0, now: now), root: root, salt: "test", now: now, turnsComplete: true) }
        let turns = sessions.enumerated().compactMap { MetadataBoundary.turn(rawTurn($0.offset, now: now), sessionID: $0.element.id, salt: "test", now: now) }
        let snapshot = SessionSnapshot(sessions: sessions, turns: turns, truncated: false, observedAt: now)
        let first = try await store.apply(snapshot, token: token)
        let initialWrites = await store.lastWriteSummary
        let initialLogCount = try await store.recordedChangeCount()
        let second = try await store.apply(snapshot, token: token)
        let duplicateWrites = await store.lastWriteSummary
        let duplicateLogCount = try await store.recordedChangeCount()
        let checkpoint = try await store.checkpoint()
        try expect(initialWrites.changes == 2000 && duplicateWrites.changes == 0, "Unchanged snapshots must not rewrite history")
        try expect(initialLogCount == 2000 && duplicateLogCount == initialLogCount, "Duplicate snapshot added false change events")
        try expect(checkpoint.checkedAt != nil, "Durable check timestamp missing")
        try expect(first && second, "Enabled snapshot import rejected")
        var library = try await store.load()
        try expect(library.sessions.count == 1000 && library.turns.count == 1000, "Duplicate/missing session or turn records")
        gate.configure(enabled: false)
        let paused = try await store.apply(snapshot, token: token)
        try expect(!paused, "Paused request was persisted")
        let fresh = gate.configure(enabled: true)
        let raced = try await store.apply(snapshot, token: token)
        try expect(!raced, "An in-flight request survived pause/resume generation change")
        try await store.saveNote(sessionID: sessions[0].id, text: "USER_NOTE_TO_DELETE_7f983")
        let export = try await store.exportJSON()
        let json = String(decoding: export, as: UTF8.self)
        try expect(json.contains("USER_NOTE_TO_DELETE"), "Explicit user notes should export")
        try expect(!json.contains("PRIVATE_") && !json.contains("sk-secret") && !json.contains("provider-session") && !json.contains("/test/"), "Private provider content leaked into storage/export")
        let reopened = try SessionStore(directory: dir, gate: gate)
        library = try await reopened.load()
        try expect(library.sessions.count == 1000 && library.notes.count == 1, "Reopening migrated database lost data")
        let oldDate = Date().addingTimeInterval(-20 * 86400)
        guard let old = MetadataBoundary.session(rawSession(0, now: oldDate), root: root, salt: "test", now: now, turnsComplete: true) else { throw CoreCheckFailure(description: "Old fixture rejected") }
        _ = try await store.apply(SessionSnapshot(sessions: [old], turns: [], truncated: false, observedAt: now), token: fresh, retentionDays: 30)
        try await store.enforceRetention(days: 10)
        library = try await store.load()
        try expect(library.sessions.count == 999 && library.turns.count == 999 && library.notes.isEmpty, "Retention failed to cascade")
        let permissions = try FileManager.default.attributesOfItem(atPath: dir.path)[.posixPermissions] as? NSNumber
        try expect(permissions?.intValue == 0o700, "Data directory must be private")
        for suffix in ["", "-wal", "-shm"] {
            let path = dir.appendingPathComponent("sessions.sqlite").path + suffix
            if FileManager.default.fileExists(atPath: path) {
                let mode = try FileManager.default.attributesOfItem(atPath: path)[.posixPermissions] as? NSNumber
                try expect(mode?.intValue == 0o600, "Database sidecar is not private")
            }
        }
        try await store.deleteAll()
        library = try await store.load()
        try expect(library.sessions.isEmpty && library.turns.isEmpty && library.notes.isEmpty && library.changes.isEmpty, "Deletion left derived/user records")
        let deletedCheckpoint = try await store.checkpoint()
        try expect(deletedCheckpoint.checkedAt == nil, "Deletion left a sync checkpoint")
        let deleted = try await store.exportJSON()
        let parsed = try JSONSerialization.jsonObject(with: deleted) as? [String: Any]
        try expect((parsed?["sessions"] as? [Any])?.isEmpty == true, "Deleted data still exports")
    }
    private static func protocolFixture() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("vernier-protocol-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let script = dir.appendingPathComponent("codex-fixture")
        let log = dir.appendingPathComponent("methods.jsonl")
        let sessionJSON = String(decoding: try JSONSerialization.data(withJSONObject: rawSession(5)), as: UTF8.self)
        let turnJSON = String(decoding: try JSONSerialization.data(withJSONObject: rawTurn(5)), as: UTF8.self)
        let logJSON = String(decoding: try JSONSerialization.data(withJSONObject: log.path, options: .fragmentsAllowed), as: UTF8.self)
        let body = """
        #!/usr/bin/python3
        import sys,json,base64
        log=json.loads(base64.b64decode('\(Data(logJSON.utf8).base64EncodedString())'))
        session=json.loads(base64.b64decode('\(Data(sessionJSON.utf8).base64EncodedString())'))
        turn=json.loads(base64.b64decode('\(Data(turnJSON.utf8).base64EncodedString())'))
        for line in sys.stdin:
            msg=json.loads(line)
            with open(log,'a') as f: f.write(json.dumps(msg)+'\\n')
            method=msg.get('method')
            if method=='initialize':
                print(json.dumps({'id':999,'method':'run/command','params':{'command':'do-not-execute'}}),flush=True)
                result={}
            elif method=='thread/list': result={'data':[session],'nextCursor':None}
            elif method=='thread/turns/list': result={'data':[turn],'nextCursor':None}
            else: continue
            print(json.dumps({'id':msg['id'],'result':result}),flush=True)
        """
        try Data(body.utf8).write(to: script)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)
        let snapshot = try await CodexMetadataConnector().fetch(root: root, salt: "fixture", binary: script)
        try expect(snapshot.sessions.count == 1 && snapshot.turns.count == 1, "Read-only fixture did not normalize")
        let messages = try String(contentsOf: log, encoding: .utf8).split(separator: "\n").map { try JSONSerialization.jsonObject(with: Data($0.utf8)) as! [String: Any] }
        let methods = messages.compactMap { $0["method"] as? String }
        try expect(methods == ["initialize", "initialized", "thread/list", "thread/turns/list"], "Adapter issued a non-read-only or extra request")
        let listing = messages.first { $0["method"] as? String == "thread/list" }?["params"] as? [String: Any]
        let history = messages.first { $0["method"] as? String == "thread/turns/list" }?["params"] as? [String: Any]
        try expect(listing?["useStateDbOnly"] as? Bool == true, "Adapter must not request transcript repair")
        try expect(history?["itemsView"] as? String == "notLoaded", "Adapter requested conversation items")
        let rejection = messages.first { $0["id"] as? Int == 999 }?["error"] as? [String: Any]
        try expect(rejection?["code"] as? Int == -32601, "Unsolicited tool request was not rejected")
        let previous = SessionLibrary(sessions: snapshot.sessions, turns: snapshot.turns, notes: [:])
        let delta = try await CodexMetadataConnector().fetch(root: root, salt: "fixture", previous: previous, binary: script)
        try expect(delta.sessions.isEmpty && delta.turns.isEmpty && delta.diagnostics.historyReads == 0, "Unchanged history was fetched again")
        let reconciled = try await CodexMetadataConnector().fetch(root: root, salt: "fixture", previous: previous, binary: script, reconcile: true)
        try expect(reconciled.diagnostics.reconciliation && reconciled.diagnostics.historyReads == 1, "Explicit reconciliation did not recheck known history")
        // Regression for blocked pipe reads: even a silent child must respect the deadline.
        try Data("#!/usr/bin/python3\nimport time\ntime.sleep(10)\n".utf8).write(to: script)
        let start = Date()
        do {
            _ = try await CodexMetadataConnector().fetch(root: root, salt: "fixture", binary: script, timeout: 0.15)
            throw CoreCheckFailure(description: "Silent child did not time out")
        } catch ConnectorFailure.timedOut { }
        try expect(Date().timeIntervalSince(start) < 2, "Pipe deadline was not enforced")
    }
}
