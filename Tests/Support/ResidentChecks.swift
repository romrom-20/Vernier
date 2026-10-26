import Foundation
import CSQLite
import VernierCore

extension SessionChecks {
    static func residentPolicy() async throws {
        try expect(SyncCadence.delay(visible: true, quietChecks: 0, failures: 0, lowPower: false, suspended: false) == 20, "Visible cadence")
        try expect(SyncCadence.delay(visible: false, quietChecks: 0, failures: 0, lowPower: false, suspended: false) == 60, "Background cadence")
        try expect(SyncCadence.delay(visible: true, quietChecks: 3, failures: 0, lowPower: false, suspended: false) == 180, "Quiet cadence")
        try expect(SyncCadence.delay(visible: true, quietChecks: 0, failures: 1, lowPower: true, suspended: false) >= 300, "Battery-saving floor")
        try expect(SyncCadence.delay(visible: false, quietChecks: 0, failures: 30, lowPower: false, suspended: false) == 900, "Retry cap")
        // Provider timestamps are integer Unix seconds; freeze the fixture at that precision.
        let now = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970))
        try expect(SyncCheckpoint().needsReconciliation(at: now), "First connection needs reconciliation")
        try expect(!SyncCheckpoint(reconciledAt: now).needsReconciliation(at: now), "Fresh checkpoint unexpectedly rescans")
        try expect(SyncCheckpoint(reconciledAt: now.addingTimeInterval(-6 * 3600)).needsReconciliation(at: now), "Six-hour reconciliation missing")
        try expect(RetentionPolicy.cutoff(days: 0, now: now) == .distantPast, "Explicit indefinite retention was shortened")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let turns = [-25 * 3600, -23 * 3600, -3600, 0, 60].enumerated().compactMap { index, offset in
            MetadataBoundary.turn(rawTurn(index, now: now.addingTimeInterval(Double(offset))), sessionID: "fixture", salt: "fixture", now: now)
        }
        let bins = WorkRhythm.hourlyTurns(turns, now: now, calendar: calendar)
        try expect(bins.count == 24 && bins.reduce(0, +) == 3, "Rhythm included future/out-of-window history")
    }

    static func migration() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("vernier-v1-upgrade-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("sessions.sqlite")
        var handle: OpaquePointer?
        guard sqlite3_open(url.path, &handle) == SQLITE_OK, let handle else { throw CoreCheckFailure(description: "Create v1 fixture") }
        let schema = """
        CREATE TABLE sessions(id TEXT PRIMARY KEY,workspace_id TEXT NOT NULL,created_at REAL NOT NULL,updated_at REAL NOT NULL,observed_at REAL NOT NULL,source_kind TEXT NOT NULL,turns_complete INTEGER NOT NULL);
        CREATE TABLE turns(id TEXT PRIMARY KEY,session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,outcome TEXT NOT NULL,started_at REAL,completed_at REAL,observed_at REAL NOT NULL);
        CREATE TABLE notes(session_id TEXT PRIMARY KEY REFERENCES sessions(id) ON DELETE CASCADE,note TEXT NOT NULL);
        CREATE TABLE schema_migrations(version INTEGER PRIMARY KEY,applied_at REAL NOT NULL);
        INSERT INTO schema_migrations VALUES(1,unixepoch());
        INSERT INTO sessions VALUES('old-session','workspace',unixepoch(),unixepoch(),unixepoch(),'vscode',1);
        INSERT INTO turns VALUES('old-turn','old-session','completed',unixepoch(),unixepoch(),unixepoch());
        INSERT INTO notes VALUES('old-session','A personal takeaway that must survive migration.');
        PRAGMA user_version=1;
        """
        let result = sqlite3_exec(handle, schema, nil, nil, nil)
        sqlite3_close(handle)
        try expect(result == SQLITE_OK, "Build v1 fixture")
        let store = try SessionStore(directory: dir, gate: ObservationGate())
        let library = try await store.load()
        try expect(library.sessions.count == 1 && library.turns.count == 1, "Upgrade lost source records")
        try expect(library.notes["old-session"] == "A personal takeaway that must survive migration.", "Upgrade lost user note")
        try expect(library.changes.isEmpty, "Upgrade invented observed activity")
        let checkpoint = try await store.checkpoint()
        try expect(checkpoint.checkedAt == nil, "Upgrade invented a successful sync")
    }

    static func pagination() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("vernier-pagination-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let now = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970))
        let first = (0..<32).map { rawSession($0, now: now) }
        let tied = rawSession(999, now: now.addingTimeInterval(-60))
        let older = rawSession(1000, now: now.addingTimeInterval(-61))
        let previous = SessionLibrary(sessions: first.compactMap { MetadataBoundary.session($0, root: root, salt: "page", now: now, turnsComplete: true) }, turns: [], notes: [:])
        let firstData = try JSONSerialization.data(withJSONObject: first).base64EncodedString()
        let secondData = try JSONSerialization.data(withJSONObject: [tied, older]).base64EncodedString()
        let script = dir.appendingPathComponent("codex-fixture")
        let body = """
        #!/usr/bin/python3
        import json,sys,base64
        first=json.loads(base64.b64decode('\(firstData)'))
        second=json.loads(base64.b64decode('\(secondData)'))
        for line in sys.stdin:
            msg=json.loads(line); method=msg.get('method'); params=msg.get('params',{})
            if method=='initialize': result={}
            elif method=='thread/list': result={'data':second if params.get('cursor') else first,'nextCursor':'more'}
            elif method=='thread/turns/list': result={'data':[],'nextCursor':None}
            else: continue
            print(json.dumps({'id':msg['id'],'result':result}),flush=True)
        """
        try Data(body.utf8).write(to: script)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)
        let delta = try await CodexMetadataConnector().fetch(root: root, salt: "page", previous: previous, binary: script)
        let tiedID = MetadataBoundary.hash("provider-session-999", salt: "page")
        try expect(delta.diagnostics.listPages == 2 && !delta.truncated, "Pagination stopped before overlap boundary")
        try expect(delta.sessions.contains { $0.id == tiedID }, "Timestamp-tied new session was skipped")
        try expect(!delta.sessions.contains { previous.sessions.map(\.id).contains($0.id) }, "Unchanged records leaked into the delta")
    }
}
