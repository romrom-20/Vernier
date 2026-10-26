import Foundation
import VernierCore

public enum MemoryChecks {
    public static let cases: [(String, @Sendable () async throws -> Void)] = [
        ("Conversation normalization, best-effort redaction and honest wording flags", boundary),
        ("Separate content consent, local search, export and memory deletion", storage),
        ("Conversation backfill advances independently of metadata", protocolBackfill)
    ]
    private static func expect(_ value: @autoclosure () -> Bool, _ message: String) throws {
        if !value() { throw CoreCheckFailure(description: message) }
    }
    private static func user(_ id: String = "u1", text: String = "Please proceed", now: Date = Date()) -> [String: Any] {
        ["turnId": "turn1", "startedAtMs": floor(now.timeIntervalSince1970) * 1000, "completedAtMs": NSNull(),
         "item": ["id": id, "type": "userMessage", "content": [["type": "text", "text": text], ["type": "localImage", "path": "/private/attachment.png"]]]]
    }
    private static func agent() -> [String: Any] {
        ["turnId": "turn1", "item": ["id": "a1", "type": "agentMessage", "phase": "final_answer", "text": "I report that the change is complete. Verification remains the user's decision."]]
    }
    private static func tool() -> [String: Any] {
        ["turnId": "turn1", "item": ["id": "tool1", "type": "commandExecution", "command": "SECRET_COMMAND", "aggregatedOutput": "SECRET_OUTPUT", "cwd": "/private/path", "exitCode": 0]]
    }
    private static func boundary() async throws {
        let now = Date()
        let raw = user(text: "Bearer abcdef123456789 password=super-private sk-12345678901234567890")
        guard let value = ConversationBoundary.message(raw, sessionID: "hash", salt: "salt", now: now) else { throw CoreCheckFailure(description: "User text rejected") }
        try expect(value.redactions == 3 && !value.text.contains("super-private") && !value.text.contains("1234567890"), "Credential patterns not redacted")
        try expect(value.attachmentsOmitted && value.sourceAt != nil, "Attachments/timestamp null handling")
        try expect(ConversationBoundary.message(tool(), sessionID: "hash", salt: "salt", now: now) == nil, "Raw tool content entered message memory")
        let signal = ConversationBoundary.signal(tool(), sessionID: "hash", salt: "salt", now: now)
        let json = String(decoding: try JSONEncoder().encode(signal), as: UTF8.self)
        try expect(!json.contains("SECRET") && !json.contains("/private/"), "Raw command content entered metadata")
        try expect(PromptSignals.isContinuationCue("yes, please proceed.") && !PromptSignals.isContinuationCue("Proceed with the migration and verify rollback."), "Wording flag overreaches its definition")
        let jsonSecret = ConversationBoundary.redact(#"{"OPENAI_API_KEY":"private json token", "password":"two word secret"}"#)
        try expect(jsonSecret.count == 2 && !jsonSecret.text.contains("private json") && !jsonSecret.text.contains("two word"), "Quoted/JSON credential patterns")
        let partialKey = ConversationBoundary.redact("-----BEGIN PRIVATE KEY-----\n" + String(repeating: "secret-key-material", count: 20000))
        try expect(!partialKey.text.contains("secret-key-material"), "Truncation leaked an unfinished private key")
        let large = ConversationBoundary.redact(String(repeating: "a", count: 300_000))
        try expect(large.truncated && large.text.utf8.count <= 262_144, "Message-size bound missing")
    }
    private static func storage() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("vernier-memory-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let gate = ObservationGate(); var token = gate.configure(enabled: true)
        let store = try SessionStore(directory: dir, gate: gate)
        let now = Date()
        let session = MetadataBoundary.session(SessionChecks.rawSession(1), root: SessionChecks.root, salt: "memory", now: now, turnsComplete: true)!
        let message = ConversationBoundary.message(user(text: "SYNTHETIC_PROJECT_MEMORY password=must-redact"), sessionID: session.id, salt: "memory", now: now)!
        let signal = ConversationBoundary.signal(tool(), sessionID: session.id, salt: "memory", now: now)!
        let snapshot = SessionSnapshot(sessions: [session], turns: [], truncated: false, observedAt: now, messages: [message], signals: [signal])
        _ = try await store.apply(snapshot, token: token)
        var library = try await store.load()
        try expect(library.totalMessageCount == 0 && library.signals.isEmpty, "Metadata opt-in incorrectly authorized content capture")
        token = gate.configure(enabled: true, contentEnabled: true)
        _ = try await store.apply(snapshot, token: token)
        _ = try await store.apply(snapshot, token: token)
        library = try await store.load()
        try expect(library.totalMessageCount == 1 && library.signals.count == 1, "Memory deduplication")
        let archive = (0..<400).compactMap { index in
            ConversationBoundary.message(user("archive-\(index)", text: "ARCHIVE_SEARCH_MARKER_\(index)", now: now.addingTimeInterval(-Double(index + 1))), sessionID: session.id, salt: "memory", now: now)
        }
        _ = try await store.apply(SessionSnapshot(sessions: [], turns: [], truncated: false, observedAt: now, messages: archive), token: token)
        library = try await store.load()
        try expect(library.messages.count == 300 && library.totalMessageCount == 401, "Resident memory must load a bounded preview while preserving the archive")
        try expect(library.totalSignalCount == 1 && library.digest(for: session)?.messageCount == 401 && library.digest(for: session)?.signalCount == 1, "Session inventory must count the complete archive")
        try expect(library.title(for: session) == "ARCHIVE_SEARCH_MARKER_399", "Session title must use the first stored prompt, including beyond the preview")
        try await store.saveNote(sessionID: session.id, text: "My expected result and checked evidence.")
        library = try await store.load()
        try expect(library.title(for: session) == "My expected result and checked evidence.", "A personal takeaway must take precedence over the prompt excerpt")
        let archiveData = try await store.exportJSON()
        let fullExport = try JSONSerialization.jsonObject(with: archiveData) as? [String: Any]
        try expect((fullExport?["messages"] as? [Any])?.count == 401, "Export silently omitted archived messages")
        let archivedSearch = try await store.memoryMessages(query: "ARCHIVE_SEARCH_MARKER_399")
        try expect(archivedSearch.count == 1, "Search did not reach older stored messages")
        let search = try await store.memoryMessages(query: "synthetic_project_memory")
        try expect(search.count == 1, "Private local search failed")
        let export = String(decoding: try await store.exportJSON(), as: UTF8.self)
        try expect(export.contains("SYNTHETIC_PROJECT_MEMORY") && !export.contains("must-redact") && !export.contains("SECRET_OUTPUT"), "Memory export/redaction boundary")
        let stale = token; token = gate.configure(enabled: true, contentEnabled: false)
        let revoked = try await store.apply(snapshot, token: stale)
        try expect(!revoked, "Revocation did not reject an in-flight content result")
        try await store.eraseConversationMemory()
        library = try await store.load()
        try expect(library.sessions.count == 1 && library.totalMessageCount == 0 && library.signals.isEmpty, "Memory erasure removed metadata or retained content")
        _ = try await store.apply(snapshot, token: token)
        library = try await store.load()
        try expect(library.totalMessageCount == 0, "Erased content reappeared without permission")
        try await store.deleteAll()
        library = try await store.load()
        try expect(library.sessions.isEmpty && library.memoryCoverage.isEmpty, "Complete deletion left memory state")
    }
    private static func protocolBackfill() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("vernier-memory-protocol-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let script = dir.appendingPathComponent("codex-fixture")
        func b64(_ value: Any) throws -> String { try JSONSerialization.data(withJSONObject: value).base64EncodedString() }
        let body = """
        #!/usr/bin/python3
        import json,sys,base64
        session=json.loads(base64.b64decode('\(try b64(SessionChecks.rawSession(5)))'))
        user=json.loads(base64.b64decode('\(try b64(user()))'))
        older=json.loads(base64.b64decode('\(try b64(user("u2",text:"An earlier project question")))'))
        agent=json.loads(base64.b64decode('\(try b64(agent()))'))
        tool=json.loads(base64.b64decode('\(try b64(tool()))'))
        for line in sys.stdin:
            msg=json.loads(line); method=msg.get('method'); params=msg.get('params',{})
            if method=='initialize': result={}
            elif method=='thread/list': result={'data':[session],'nextCursor':None}
            elif method=='thread/turns/list': result={'data':[],'nextCursor':None}
            elif method=='thread/items/list':
                if params.get('sortDirection')=='desc': result={'data':[agent,tool],'nextCursor':None}
                elif params.get('cursor'): result={'data':[older],'nextCursor':None}
                else: result={'data':[user],'nextCursor':'older-page'}
            else: continue
            print(json.dumps({'id':msg['id'],'result':result}),flush=True)
        """
        try Data(body.utf8).write(to: script)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)
        let connector = CodexMetadataConnector()
        let first = try await connector.fetch(root: SessionChecks.root, salt: "memory", binary: script, captureConversation: true)
        try expect(first.messages.count == 2 && first.memoryProgress.first?.backfillComplete == false, "Initial memory capture/backfill state")
        let library = SessionLibrary(sessions: first.sessions, turns: first.turns, notes: [:])
        let progress = Dictionary(uniqueKeysWithValues: first.memoryProgress.map { ($0.sessionID, $0) })
        let known = Set(first.messages.map(\.id) + first.signals.map(\.id))
        let second = try await connector.fetch(root: SessionChecks.root, salt: "memory", previous: library, binary: script, captureConversation: true, memoryStates: progress, knownMemoryIDs: known)
        try expect(second.sessions.isEmpty && second.messages.count == 1 && second.memoryProgress.first?.availableComplete == true, "Backfill did not advance when metadata was unchanged")
        let completed = Dictionary(uniqueKeysWithValues: second.memoryProgress.map { ($0.sessionID, $0) })
        let third = try await connector.fetch(root: SessionChecks.root, salt: "memory", previous: library, binary: script, captureConversation: true, memoryStates: completed, knownMemoryIDs: known)
        try expect(third.messages.isEmpty && third.signals.isEmpty, "Completed unchanged memory was read again")
        var pending = MemoryProgress(sessionID: first.sessions[0].id)
        pending.checkedUpdatedAt = Date(); pending.backfillComplete = true; pending.headCursor = "pending-recent-page"
        try expect(!pending.availableComplete, "Pending recent pages were declared complete")
        let fallback = """
        #!/usr/bin/python3
        import json,sys,base64,time
        session=json.loads(base64.b64decode('\(try b64(SessionChecks.rawSession(5)))'))
        user=json.loads(base64.b64decode('\(try b64(user()))'))
        agent=json.loads(base64.b64decode('\(try b64(agent()))'))
        for line in sys.stdin:
            msg=json.loads(line); method=msg.get('method'); params=msg.get('params',{})
            if method=='initialize': result={}
            elif method=='thread/list': result={'data':[session],'nextCursor':None}
            elif method=='thread/items/list':
                print(json.dumps({'id':msg['id'],'error':{'code':-32601,'message':'Unsupported legacy items'}}),flush=True)
                continue
            elif method=='thread/turns/list':
                result={'data':[{'id':'turn1','startedAt':int(time.time()),'items':[user['item'],agent['item']]}] if params.get('itemsView')=='full' else [],'nextCursor':None}
            else: continue
            print(json.dumps({'id':msg['id'],'result':result}),flush=True)
        """
        try Data(fallback.utf8).write(to: script)
        let old = try await connector.fetch(root: SessionChecks.root, salt: "memory", binary: script, captureConversation: true)
        try expect(old.memoryProgress.first?.mode == "turns", "Unsupported item pagination did not select documented turn-history fallback")
        let oldStates = Dictionary(uniqueKeysWithValues: old.memoryProgress.map { ($0.sessionID, $0) })
        let legacy = try await connector.fetch(root: SessionChecks.root, salt: "memory", previous: library, binary: script, captureConversation: true, memoryStates: oldStates)
        try expect(Set(legacy.messages.map(\.id)).count == 2 && legacy.memoryProgress.first?.availableComplete == true, "Legacy text history was not captured through the full-turn API")
    }
}
