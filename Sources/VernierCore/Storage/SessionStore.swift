import Foundation
import CSQLite

/// Shared synchronous gate closes immediately on pause/disconnect, including already-running sync requests.
public final class ObservationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var allowed = false
    private var generation = 0
    private var contentAllowed = false
    private var analysisAllowed = false
    public init() {}
    @discardableResult public func configure(enabled: Bool, contentEnabled: Bool = false, analysisEnabled: Bool = false) -> Int {
        lock.lock(); defer { lock.unlock() }
        allowed = enabled; contentAllowed = contentEnabled; analysisAllowed = analysisEnabled; generation += 1; return generation
    }
    public func token() -> Int? { lock.lock(); defer { lock.unlock() }; return allowed ? generation : nil }
    func captureBrief(_ token: Int, _ body: () throws -> Void) rethrows -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard allowed && contentAllowed && analysisAllowed && token == generation else { return false }
        try body(); return true
    }
    func capture(_ token: Int, _ body: (Bool) throws -> Void) rethrows -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard allowed && token == generation else { return false }
        try body(contentAllowed); return true
    }
}

public struct RecordedChange: Codable, Identifiable, Sendable {
    public let id: Int64
    public let sessionID: String
    public let kind: String
    public let observedAt: Date
}

public struct SessionDigest: Codable, Sendable {
    public let sessionID: String
    public let promptExcerpt: String?
    public let messageCount: Int
    public let signalCount: Int
}

public struct SessionLibrary: Codable, Sendable {
    public let sessions: [SessionMetadata]
    public let turns: [TurnMetadata]
    public let notes: [String: String]
    public let changes: [RecordedChange]
    public let messages: [ConversationMessage]
    public let signals: [AgentToolSignal]
    public let memoryCoverage: [MemoryCoverage]
    public let totalMessageCount: Int
    public let totalSignalCount: Int
    public let digests: [SessionDigest]
    public let workBriefs: [WorkBrief]
    public static let empty = SessionLibrary(sessions: [], turns: [], notes: [:])
    public func title(for session: SessionMetadata) -> String {
        if let note = notes[session.id], let excerpt = SessionDisplay.excerpt(note) { return excerpt }
        return digests.first { $0.sessionID == session.id }?.promptExcerpt ?? SessionDisplay.fallback(createdAt: session.createdAt)
    }
    public func digest(for session: SessionMetadata) -> SessionDigest? { digests.first { $0.sessionID == session.id } }
    public func workspaceName(_ id: String) -> String {
        let ids = Array(Set(sessions.map(\.workspaceID))).sorted()
        return "Workspace \((ids.firstIndex(of: id) ?? 0) + 1)"
    }
    public func turns(for session: SessionMetadata) -> [TurnMetadata] { turns.filter { $0.sessionID == session.id } }
    public init(sessions: [SessionMetadata], turns: [TurnMetadata], notes: [String: String], changes: [RecordedChange] = [], messages: [ConversationMessage] = [], signals: [AgentToolSignal] = [], memoryCoverage: [MemoryCoverage] = [], totalMessageCount: Int = 0, totalSignalCount: Int = 0, digests: [SessionDigest] = [], workBriefs: [WorkBrief] = []) {
        self.sessions = sessions; self.turns = turns; self.notes = notes; self.changes = changes; self.messages = messages; self.signals = signals; self.memoryCoverage = memoryCoverage; self.totalMessageCount = totalMessageCount; self.totalSignalCount = totalSignalCount; self.digests = digests; self.workBriefs = workBriefs
    }
}

public enum StoreFailure: Error, LocalizedError {
    case unavailable, corrupt
    public var errorDescription: String? { "The local session store could not be opened or updated. No provider data was changed." }
}
final class SQLiteConnection: @unchecked Sendable {
    let handle: OpaquePointer
    init(url: URL) throws {
        var pointer: OpaquePointer?
        guard sqlite3_open_v2(url.path, &pointer, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK, let pointer else {
            if let pointer { sqlite3_close(pointer) }; throw StoreFailure.unavailable
        }
        handle = pointer
        sqlite3_busy_timeout(pointer, 2000)
    }
    deinit { sqlite3_close(handle) }
}

public actor SessionStore {
    public let directory: URL
    let connection: SQLiteConnection
    let gate: ObservationGate
    public private(set) var lastWriteSummary = StoreWriteSummary()
    var reflectionGeneration = 0
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    public init(directory: URL, gate: ObservationGate) throws {
        self.directory = directory; self.gate = gate
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        let url = directory.appendingPathComponent("sessions.sqlite")
        let connection = try SQLiteConnection(url: url)
        self.connection = connection
        let db = connection.handle
        func execute(_ sql: String) throws { if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK { throw StoreFailure.unavailable } }
        try execute("PRAGMA foreign_keys=ON; PRAGMA journal_mode=WAL; PRAGMA secure_delete=ON;")
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA user_version", -1, &statement, nil) == SQLITE_OK, let statement else { throw StoreFailure.corrupt }
        let version = sqlite3_step(statement) == SQLITE_ROW ? sqlite3_column_int(statement, 0) : -1
        sqlite3_finalize(statement)
        guard version >= 0 && version <= 6 else { throw StoreFailure.corrupt }
        if version == 0 {
            try execute("""
            BEGIN IMMEDIATE;
            CREATE TABLE sessions(id TEXT PRIMARY KEY, workspace_id TEXT NOT NULL, created_at REAL NOT NULL, updated_at REAL NOT NULL, observed_at REAL NOT NULL, source_kind TEXT NOT NULL, turns_complete INTEGER NOT NULL);
            CREATE TABLE turns(id TEXT PRIMARY KEY, session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE, outcome TEXT NOT NULL, started_at REAL, completed_at REAL, observed_at REAL NOT NULL);
            CREATE TABLE notes(session_id TEXT PRIMARY KEY REFERENCES sessions(id) ON DELETE CASCADE, note TEXT NOT NULL);
            CREATE INDEX sessions_updated ON sessions(updated_at);
            CREATE INDEX turns_session ON turns(session_id);
            CREATE TABLE schema_migrations(version INTEGER PRIMARY KEY, applied_at REAL NOT NULL);
            INSERT INTO schema_migrations VALUES(1, unixepoch());
            PRAGMA user_version=1;
            COMMIT;
            """)
        }
        if version < 2 {
            try execute("""
            BEGIN IMMEDIATE;
            CREATE TABLE sync_state(connector_id TEXT PRIMARY KEY, checked_at REAL NOT NULL, reconciled_at REAL);
            CREATE TABLE change_log(id INTEGER PRIMARY KEY AUTOINCREMENT, session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE, kind TEXT NOT NULL, observed_at REAL NOT NULL);
            CREATE INDEX change_log_observed ON change_log(observed_at);
            INSERT INTO schema_migrations VALUES(2, unixepoch());
            PRAGMA user_version=2;
            COMMIT;
            """)
        }
        if version < 3 {
            try execute("""
            BEGIN IMMEDIATE;
            CREATE TABLE messages(id TEXT PRIMARY KEY,session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,turn_id TEXT NOT NULL,speaker TEXT NOT NULL,phase TEXT NOT NULL,body TEXT NOT NULL,source_at REAL,observed_at REAL NOT NULL,redactions INTEGER NOT NULL,truncated INTEGER NOT NULL,attachments_omitted INTEGER NOT NULL);
            CREATE INDEX messages_session ON messages(session_id);
            CREATE INDEX messages_time ON messages(observed_at);
            CREATE TABLE agent_signals(id TEXT PRIMARY KEY,session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,kind TEXT NOT NULL,outcome TEXT NOT NULL,item_count INTEGER NOT NULL,source_at REAL,observed_at REAL NOT NULL);
            CREATE TABLE memory_progress(session_id TEXT PRIMARY KEY REFERENCES sessions(id) ON DELETE CASCADE,mode TEXT NOT NULL,checked_updated_at REAL,head_target REAL,head_cursor TEXT,backfill_cursor TEXT,backfill_complete INTEGER NOT NULL,issue INTEGER NOT NULL);
            INSERT INTO schema_migrations VALUES(3,unixepoch());
            PRAGMA user_version=3;
            COMMIT;
            """)
        }
        if version < 4 {
            try execute("""
            BEGIN IMMEDIATE;
            CREATE TABLE work_briefs(session_id TEXT PRIMARY KEY REFERENCES sessions(id) ON DELETE CASCADE,payload TEXT NOT NULL);
            INSERT INTO schema_migrations VALUES(4,unixepoch());
            PRAGMA user_version=4;
            COMMIT;
            """)
        }
        if version < 5 {
            try execute("""
            BEGIN IMMEDIATE;
            CREATE TABLE decision_revisions(id TEXT PRIMARY KEY,session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,anchor_id TEXT NOT NULL REFERENCES messages(id) ON DELETE CASCADE,created_at REAL NOT NULL,input_digest TEXT NOT NULL,payload TEXT NOT NULL);
            CREATE INDEX decision_revisions_session ON decision_revisions(session_id,created_at);
            CREATE TABLE decision_perspectives(id TEXT PRIMARY KEY,session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,revision_id TEXT NOT NULL REFERENCES decision_revisions(id) ON DELETE CASCADE,body TEXT NOT NULL,created_at REAL NOT NULL);
            CREATE TABLE decision_sources(revision_id TEXT NOT NULL REFERENCES decision_revisions(id) ON DELETE CASCADE,message_id TEXT REFERENCES messages(id) ON DELETE CASCADE,perspective_id TEXT REFERENCES decision_perspectives(id) ON DELETE CASCADE,CHECK((message_id IS NOT NULL)!=(perspective_id IS NOT NULL)));
            CREATE INDEX decision_sources_message ON decision_sources(message_id);
            CREATE TRIGGER decision_message_delete BEFORE DELETE ON messages BEGIN DELETE FROM decision_revisions WHERE id IN (SELECT revision_id FROM decision_sources WHERE message_id=OLD.id); END;
            CREATE TRIGGER decision_message_edit BEFORE UPDATE OF body,phase,source_at ON messages WHEN OLD.body IS NOT NEW.body OR OLD.phase IS NOT NEW.phase OR OLD.source_at IS NOT NEW.source_at BEGIN DELETE FROM decision_revisions WHERE id IN (SELECT revision_id FROM decision_sources WHERE message_id=OLD.id); END;
            CREATE TRIGGER decision_perspective_delete BEFORE DELETE ON decision_perspectives BEGIN DELETE FROM decision_revisions WHERE id IN (SELECT revision_id FROM decision_sources WHERE perspective_id=OLD.id); END;
            INSERT INTO schema_migrations VALUES(5,unixepoch());
            PRAGMA user_version=5;
            COMMIT;
            """)
        }
        if version < 6 {
            try execute("""
            BEGIN IMMEDIATE;
            CREATE TABLE daily_reflections(day_key TEXT PRIMARY KEY,day_start REAL NOT NULL,payload TEXT NOT NULL);
            CREATE INDEX messages_source_time ON messages(source_at);
            CREATE INDEX messages_session_source_time ON messages(session_id,source_at);
            INSERT INTO schema_migrations VALUES(6,unixepoch());
            PRAGMA user_version=6;
            COMMIT;
            """)
        }
        try execute("CREATE INDEX IF NOT EXISTS agent_signals_session ON agent_signals(session_id)")
        for suffix in ["", "-wal", "-shm"] {
            let path = url.path + suffix
            if FileManager.default.fileExists(atPath: path) { try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path) }
        }
    }
    @discardableResult public func apply(_ snapshot: SessionSnapshot, token: Int, retentionDays: Int = 30) throws -> Bool {
        var changedSessions = 0
        var changedTurns = 0
        var changedMemory = 0
        let applied = try gate.capture(token) { contentAllowed in
            try execute("BEGIN IMMEDIATE")
            do {
                let cutoff = RetentionPolicy.cutoff(days: retentionDays)
                try write("DELETE FROM daily_reflections WHERE day_start < ?", values: [cutoff.timeIntervalSince1970])
                let sessions = snapshot.sessions.filter { $0.updatedAt >= cutoff }
                let ids = Set(sessions.map(\.id))
                for session in sessions {
                    try write("INSERT INTO sessions VALUES(?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET workspace_id=excluded.workspace_id,source_kind=excluded.source_kind,updated_at=excluded.updated_at,observed_at=excluded.observed_at,turns_complete=excluded.turns_complete WHERE sessions.updated_at IS NOT excluded.updated_at OR sessions.workspace_id IS NOT excluded.workspace_id OR sessions.source_kind IS NOT excluded.source_kind OR sessions.turns_complete IS NOT excluded.turns_complete", values: [session.id, session.workspaceID, session.createdAt.timeIntervalSince1970, session.updatedAt.timeIntervalSince1970, session.observedAt.timeIntervalSince1970, session.sourceKind, session.turnsComplete ? 1 : 0])
                    if sqlite3_changes(connection.handle) > 0 {
                        changedSessions += 1
                        try write("INSERT INTO change_log(session_id,kind,observed_at) VALUES(?,?,?)", values: [session.id, "session_metadata", snapshot.observedAt.timeIntervalSince1970])
                    }
                }
                for turn in snapshot.turns where ids.contains(turn.sessionID) {
                    try write("INSERT INTO turns VALUES(?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET outcome=excluded.outcome,started_at=excluded.started_at,completed_at=excluded.completed_at,observed_at=excluded.observed_at WHERE turns.outcome IS NOT excluded.outcome OR turns.started_at IS NOT excluded.started_at OR turns.completed_at IS NOT excluded.completed_at", values: [turn.id, turn.sessionID, turn.outcome.rawValue, turn.startedAt?.timeIntervalSince1970, turn.completedAt?.timeIntervalSince1970, turn.observedAt.timeIntervalSince1970])
                    if sqlite3_changes(connection.handle) > 0 {
                        changedTurns += 1
                        try write("INSERT INTO change_log(session_id,kind,observed_at) VALUES(?,?,?)", values: [turn.sessionID, "turn_metadata", snapshot.observedAt.timeIntervalSince1970])
                    }
                }
                if contentAllowed { changedMemory = try applyMemory(snapshot) }
                try write("DELETE FROM sessions WHERE updated_at < ?", values: [cutoff.timeIntervalSince1970])
                changedSessions += Int(sqlite3_changes(connection.handle))
                try write("INSERT INTO sync_state VALUES('codex',?,?) ON CONFLICT(connector_id) DO UPDATE SET checked_at=excluded.checked_at,reconciled_at=COALESCE(excluded.reconciled_at,sync_state.reconciled_at)", values: [snapshot.observedAt.timeIntervalSince1970, snapshot.diagnostics.reconciliation ? snapshot.observedAt.timeIntervalSince1970 : nil])
                try write("DELETE FROM change_log WHERE observed_at < ?", values: [cutoff.timeIntervalSince1970])
                try execute("DELETE FROM change_log WHERE id NOT IN (SELECT id FROM change_log ORDER BY id DESC LIMIT 10000)")
                try execute("COMMIT")
            } catch { try? execute("ROLLBACK"); throw error }
        }
        if applied { lastWriteSummary = .init(sessions: changedSessions, turns: changedTurns, memory: changedMemory) }
        return applied
    }
    public func checkpoint() throws -> SyncCheckpoint {
        try rows("SELECT checked_at,reconciled_at FROM sync_state WHERE connector_id='codex'") { row in
            SyncCheckpoint(checkedAt: date(row, 0), reconciledAt: optionalDate(row, 1))
        }.first ?? .init()
    }
    public func recordedChangeCount() throws -> Int {
        try rows("SELECT COUNT(*) FROM change_log") { Int(sqlite3_column_int64($0, 0)) }.first ?? 0
    }
    public func load(messageLimit: Int? = 300) throws -> SessionLibrary {
        let sessions = try rows("SELECT id,workspace_id,created_at,updated_at,observed_at,source_kind,turns_complete FROM sessions ORDER BY updated_at DESC") { row in
            SessionMetadata(id: string(row, 0), workspaceID: string(row, 1), createdAt: date(row, 2), updatedAt: date(row, 3), observedAt: date(row, 4), sourceKind: string(row, 5), turnsComplete: sqlite3_column_int(row, 6) == 1)
        }
        let turns = try rows("SELECT id,session_id,outcome,started_at,completed_at,observed_at FROM turns ORDER BY COALESCE(started_at,observed_at) DESC") { row in
            TurnMetadata(id: string(row, 0), sessionID: string(row, 1), outcome: SessionOutcome(rawValue: string(row, 2)) ?? .unknown, startedAt: optionalDate(row, 3), completedAt: optionalDate(row, 4), observedAt: date(row, 5))
        }
        let notes = try rows("SELECT session_id,note FROM notes") { row in (string(row, 0), string(row, 1)) }
        let changes = try rows("SELECT id,session_id,kind,observed_at FROM change_log ORDER BY id DESC") { row in
            RecordedChange(id: sqlite3_column_int64(row, 0), sessionID: string(row, 1), kind: string(row, 2), observedAt: date(row, 3))
        }
        let messages = try memoryMessages(limit: messageLimit)
        let totalMessages = try rows("SELECT COUNT(*) FROM messages") { Int(sqlite3_column_int64($0, 0)) }.first ?? 0
        let signals = try rows("SELECT id,session_id,kind,outcome,item_count,source_at,observed_at FROM agent_signals ORDER BY observed_at DESC" + (messageLimit == nil ? "" : " LIMIT 3000")) { row in
            AgentToolSignal(id: string(row, 0), sessionID: string(row, 1), kind: string(row, 2), outcome: string(row, 3), count: Int(sqlite3_column_int(row, 4)), sourceAt: optionalDate(row, 5), observedAt: date(row, 6))
        }
        let updatedDates = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0.updatedAt) })
        let coverage = try memoryState().values.map { MemoryCoverage(sessionID: $0.sessionID, complete: $0.availableComplete && $0.checkedUpdatedAt == updatedDates[$0.sessionID], issue: $0.issue) }
        let totalSignals = try rows("SELECT COUNT(*) FROM agent_signals") { Int(sqlite3_column_int64($0, 0)) }.first ?? 0
        let digests = try rows("""
        SELECT s.id,
          (SELECT SUBSTR(body,1,16384) FROM messages WHERE session_id=s.id AND speaker='user' ORDER BY COALESCE(source_at,observed_at),rowid LIMIT 1),
          (SELECT COUNT(*) FROM messages WHERE session_id=s.id),
          (SELECT COUNT(*) FROM agent_signals WHERE session_id=s.id)
        FROM sessions s
        """) { row in
            SessionDigest(sessionID: string(row, 0), promptExcerpt: sqlite3_column_type(row, 1) == SQLITE_NULL ? nil : SessionDisplay.excerpt(string(row, 1)), messageCount: Int(sqlite3_column_int64(row, 2)), signalCount: Int(sqlite3_column_int64(row, 3)))
        }
        return SessionLibrary(sessions: sessions, turns: turns, notes: Dictionary(uniqueKeysWithValues: notes), changes: changes, messages: messages, signals: signals, memoryCoverage: coverage, totalMessageCount: totalMessages, totalSignalCount: totalSignals, digests: digests, workBriefs: try loadWorkBriefs())
    }
    public func saveNote(sessionID: String, text: String) throws {
        guard text.utf8.count <= 16_000 else { throw StoreFailure.unavailable }
        try write("INSERT INTO notes VALUES(?,?) ON CONFLICT(session_id) DO UPDATE SET note=excluded.note", values: [sessionID, text])
    }
    public func enforceRetention(days: Int) throws {
        try write("DELETE FROM daily_reflections WHERE day_start < ?", values: [RetentionPolicy.cutoff(days: days).timeIntervalSince1970])
        try write("DELETE FROM sessions WHERE updated_at < ?", values: [RetentionPolicy.cutoff(days: days).timeIntervalSince1970])
        try execute("PRAGMA wal_checkpoint(TRUNCATE)")
    }
    public func exportJSON() throws -> Data {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(load(messageLimit: nil))
        var value = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        value["decisionRevisions"] = try JSONSerialization.jsonObject(with: encoder.encode(loadDecisionRevisions(limit: nil)))
        value["decisionPerspectives"] = try JSONSerialization.jsonObject(with: encoder.encode(loadDecisionPerspectives()))
        value["dailyReflections"] = try JSONSerialization.jsonObject(with: encoder.encode(dailyReflections()))
        return try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
    }
    public func deleteAll() throws {
        reflectionGeneration += 1
        try execute("DELETE FROM daily_reflections; DELETE FROM sessions; DELETE FROM sync_state; PRAGMA wal_checkpoint(TRUNCATE); VACUUM;")
    }
    func execute(_ sql: String) throws { if sqlite3_exec(connection.handle, sql, nil, nil, nil) != SQLITE_OK { throw StoreFailure.unavailable } }
    func write(_ sql: String, values: [Any?]) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection.handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw StoreFailure.unavailable }
        defer { sqlite3_finalize(statement) }
        for (index, value) in values.enumerated() {
            let column = Int32(index + 1)
            switch value {
            case let value as String: sqlite3_bind_text(statement, column, value, -1, transient)
            case let value as Double: sqlite3_bind_double(statement, column, value)
            case let value as Int: sqlite3_bind_int64(statement, column, Int64(value))
            case nil: sqlite3_bind_null(statement, column)
            default: throw StoreFailure.unavailable
            }
        }
        guard sqlite3_step(statement) == SQLITE_DONE else { throw StoreFailure.unavailable }
    }
    func rows<T>(_ sql: String, transform: (OpaquePointer) -> T) throws -> [T] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection.handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw StoreFailure.corrupt }
        defer { sqlite3_finalize(statement) }
        var result: [T] = []
        while true {
            switch sqlite3_step(statement) {
            case SQLITE_ROW: result.append(transform(statement))
            case SQLITE_DONE: return result
            default: throw StoreFailure.corrupt
            }
        }
    }
    func string(_ row: OpaquePointer, _ column: Int32) -> String { String(cString: sqlite3_column_text(row, column)) }
    func date(_ row: OpaquePointer, _ column: Int32) -> Date { Date(timeIntervalSince1970: sqlite3_column_double(row, column)) }
    func optionalDate(_ row: OpaquePointer, _ column: Int32) -> Date? { sqlite3_column_type(row, column) == SQLITE_NULL ? nil : date(row, column) }
}
