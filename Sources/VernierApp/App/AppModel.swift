import AppKit
import SwiftUI
import VernierCore

enum Brand {
    private static let values: [String: String] = {
        guard let url = Bundle.main.url(forResource: "Brand", withExtension: "plist") ?? Bundle.module.url(forResource: "Brand", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let values = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] else { return [:] }
        return values
    }()
    static let name = values["DisplayName"] ?? "Instrument"
    static let tagline = values["Tagline"] ?? "Keep your agency in view."
}

enum StudioPage: String, CaseIterable, Identifiable {
    case overview = "Overview", sessions = "Sessions", memory = "Memory", decisions = "Decisions", connections = "Connections", privacy = "Privacy"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .sessions: "rectangle.stack"
        case .memory: "bubble.left.and.bubble.right"
        case .decisions: "text.alignleft"
        case .connections: "point.3.connected.trianglepath.dotted"
        case .privacy: "lock.shield"
        }
    }
}

@MainActor final class AppModel: ObservableObject {
    let preferences: Preferences
    let isShowcase: Bool
    @Published var localInsightsEnabled: Bool {
        didSet {
            preferences.localInsightsEnabled = localInsightsEnabled
            cancelWorkBrief()
            updateCaptureGate()
            if localInsightsEnabled { scheduleWorkBrief() }
        }
    }
    @Published var generatingBrief = false
    @Published var briefError: String?
    @Published var briefSessionID: String?
    @Published var memoryQuery = ""
    var briefTask: Task<Void, Never>?
    var briefDeadline: Task<Void, Never>?
    var briefGeneration = 0
    var lastAutomaticBrief = Date.distantPast
    @Published var demoEnabled: Bool { didSet { preferences.demoEnabled = demoEnabled } }
    @Published var paused: Bool {
        didSet {
            preferences.paused = paused
            if paused { cancelWorkBrief() }
            updateCaptureGate()
            resumePending = !paused && codexEnabled && !isolated && store != nil && !systemSuspended
            if !paused { Task { await syncSessions() } }
        }
    }
    @Published var pillEnabled: Bool { didSet { preferences.pillEnabled = pillEnabled } }
    @Published var pillHovered = false
    @Published var pillPinned = false
    @Published var pillAlwaysExpanded: Bool { didSet { preferences.pillAlwaysExpanded = pillAlwaysExpanded } }
    @Published var resumePending = false
    @Published var previewState: InstrumentState = .observing
    @Published var page: StudioPage = .overview
    @Published var selectedEvent: DemoEvent?
    @Published var providerFilter: Provider?
    @Published var codexEnabled: Bool {
        didSet {
            preferences.codexEnabled = codexEnabled
            if !codexEnabled { cancelWorkBrief() }
            updateCaptureGate()
            if codexEnabled { demoEnabled = false; Task { await syncSessions() } }
            else { connectionError = nil }
        }
    }
    @Published var conversationMemoryEnabled: Bool {
        didSet {
            preferences.conversationMemoryEnabled = conversationMemoryEnabled
            if !conversationMemoryEnabled { cancelWorkBrief() }
            updateCaptureGate()
            if conversationMemoryEnabled { checkpoint = .init(); Task { await syncSessions(reconcile: true) } }
        }
    }
    private var memoryStates: [String: MemoryProgress] = [:]
    private var knownMemoryIDs: Set<String> = []
    @Published var library: SessionLibrary = .empty
    @Published var syncing = false
    @Published var loginStatus: LoginItemState = .off
    @Published var loginError: String?
    @Published var systemSuspended = false
    @Published var studioVisible = false
    @Published var nextCheckAt: Date?
    @Published var lastWriteSummary = StoreWriteSummary()
    @Published var lastDiagnostics = SyncDiagnostics()
    @Published var checkpoint = SyncCheckpoint()
    private var quietChecks = 0
    private var consecutiveFailures = 0
    private var lastInteractiveCheck = Date.distantPast
    @Published var lastSync: Date?
    @Published var connectionError: String?
    @Published var storageError: String?
    @Published var coverageLimited = false
    @Published var selectedSessionID: String?
    @Published var memorySessionID: String?
    @Published var retentionDays: Int { didSet { preferences.retentionDays = retentionDays } }
    let captureGate = ObservationGate()
    private let connector = CodexMetadataConnector()
    var store: SessionStore?
    private var started = false
    private var pendingSync = false
    private var pendingReconcile = false
    private let isolated: Bool
    var isolatedEnvironment: Bool { isolated }
    var todaySessions: Int { WorkRhythm.todaySessions(library.sessions) }
    var hourlyRhythm: [Int] { WorkRhythm.hourlyTurns(library.turns) }
    var capturePhase: CapturePhase {
        if paused { return .paused }
        if systemSuspended { return .resting }
        if demoEnabled { return .demo }
        if !codexEnabled { return .disconnected }
        if syncing || resumePending { return .checking }
        if connectionError != nil || storageError != nil { return .issue }
        return lastSync == nil ? .waiting : .current
    }
    var captureDescription: String {
        if isShowcase { return paused ? "Showcase paused. No personal history is read or saved." : "Synthetic sessions only. No personal history is read or saved." }
        switch capturePhase {
        case .paused: return "New reads and saves are stopped. Your saved work is still here."
        case .resting: return "Capture resumes when this Mac’s session is active."
        case .disconnected: return "Connect Codex in Conductor to start building your local history."
        case .checking: return "Checking connected Codex history and saving new records on this Mac."
        case .issue: return "Your archive is safe. Check the connection to continue collecting."
        case .waiting: return "The connection is enabled. Waiting for a successful first check."
        case .demo: return "These are fictional examples. Demo records stay separate."
        case .current: return conversationMemoryEnabled ? "Prompts, replies and agent activity from Codex in Conductor are saved locally." : "Session timing and agent-turn status from Codex in Conductor are saved locally."
        }
    }
    var captureModeTitle: String { conversationMemoryEnabled ? "Conversations + activity" : "Activity metadata only" }
    var captureModeDescription: String { conversationMemoryEnabled ? "Prompts, visible agent replies, and file-change / command-outcome records." : "Session dates, turn boundaries, and recorded agent-turn outcomes." }
    func toggleCapture() {
        paused.toggle()
        if !isolated { NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now) }
    }
    func togglePillControls() { pillPinned.toggle() }
    var residentTitle: String {
        if paused { return "Taking a pause." }
        if systemSuspended { return "Resting with your Mac." }
        if connectionError != nil || storageError != nil { return "A connection needs care." }
        if syncing { return "Gathering the latest signals." }
        if !codexEnabled { return "A quiet place to begin." }
        if lastSync == nil { return "Waiting for a first signal." }
        return "Here, in the background."
    }
    var ambientLabel: String {
        if demoEnabled { return "Demo preview" }
        if paused { return "Paused" }
        if systemSuspended { return "Resting" }
        if syncing { return "Reading updates" }
        if connectionError != nil || storageError != nil { return "Check connection" }
        if !codexEnabled { return "Not connected" }
        return lastSync == nil ? "Waiting for metadata" : "Quietly connected"
    }
    private func updateCaptureGate() { captureGate.configure(enabled: codexEnabled && !paused && !systemSuspended, contentEnabled: conversationMemoryEnabled, analysisEnabled: localInsightsEnabled) }
    func setSystemSuspended(_ value: Bool) {
        guard value != systemSuspended else { return }
        systemSuspended = value
        if value { cancelWorkBrief() }
        updateCaptureGate()
        if !value { Task { await syncSessions() } }
    }
    func requestInteractiveCheck() {
        guard Date().timeIntervalSince(lastInteractiveCheck) > 10 else { return }
        lastInteractiveCheck = Date()
        refreshLoginStatus()
        Task { await syncSessions() }
    }
    var selectedSession: SessionMetadata? { library.sessions.first { $0.id == selectedSessionID } }
    var knownTurnCount: Int? {
        library.turns.isEmpty && library.sessions.contains { !$0.turnsComplete } ? nil : library.turns.count
    }
    var storedAt: Date? { library.sessions.map(\.observedAt).max() }
    var conductorRoot: URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("conductor/workspaces") }
    var openStudio: (StudioPage) -> Void = { _ in }
    var closeQuickPanel: () -> Void = {}
    var showWelcome: () -> Void = {}
    var resetPill: () -> Void = {}
    var quit: () -> Void = { NSApp.terminate(nil) }

    init(preferences: Preferences = Preferences(), isolated: Bool = false, showcase: Bool = false) {
        self.isolated = isolated || showcase
        self.isShowcase = showcase
        self.preferences = preferences
        localInsightsEnabled = preferences.localInsightsEnabled
        demoEnabled = preferences.demoEnabled
        paused = preferences.paused
        pillEnabled = preferences.pillEnabled
        pillAlwaysExpanded = preferences.pillAlwaysExpanded
        codexEnabled = preferences.codexEnabled
        conversationMemoryEnabled = preferences.conversationMemoryEnabled
        retentionDays = preferences.retentionDays
        captureGate.configure(enabled: preferences.codexEnabled && !preferences.paused, contentEnabled: preferences.conversationMemoryEnabled, analysisEnabled: preferences.localInsightsEnabled)
        if showcase {
            demoEnabled = false
            paused = false
            codexEnabled = true
            conversationMemoryEnabled = true
            pillEnabled = true
            preferences.onboardingComplete = true
            library = ShowcaseFixtures.library()
            lastSync = Date()
        }
    }
    var projection: InstrumentProjection {
        .init(demoEnabled: demoEnabled, paused: paused || systemSuspended, previewState: previewState,
              live: .init(sessions: library.sessions.count, turns: library.turns.count, connected: codexEnabled, verified: lastSync != nil, hasError: connectionError != nil || storageError != nil))
    }
    var visibleEvents: [DemoEvent] { projection.events.filter { providerFilter == nil || $0.provider == providerFilter } }
    func inspect(_ event: DemoEvent) { selectedEvent = event; openStudio(.decisions) }
    func startSessionSync() async {
        guard !started, !isolated else { return }; started = true
        do {
            let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("local.vernier.instrument.dev", isDirectory: true)
            store = try SessionStore(directory: directory, gate: captureGate)
            try await store?.enforceRetention(days: retentionDays)
            library = try await store?.load() ?? .empty
            checkpoint = try await store?.checkpoint() ?? .init()
            memoryStates = try await store?.memoryState() ?? [:]
            knownMemoryIDs = try await store?.knownMemoryIDs() ?? []
        } catch { storageError = error.localizedDescription }
        await syncSessions()
        scheduleWorkBrief()
        while !Task.isCancelled {
            let delay = SyncCadence.delay(visible: studioVisible && NSApp.isActive, quietChecks: quietChecks, failures: consecutiveFailures,
                                          lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled, suspended: systemSuspended || paused || !codexEnabled)
            nextCheckAt = Date().addingTimeInterval(delay)
            do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            await syncSessions()
        }
    }
    func syncSessions(reconcile: Bool = false) async {
        guard !isolated, codexEnabled, !paused, !systemSuspended, let token = captureGate.token(), let store else { return }
        guard !syncing else { pendingSync = true; pendingReconcile = pendingReconcile || reconcile; return }
        syncing = true
        resumePending = false
        defer {
            syncing = false
            if pendingSync {
                let full = pendingReconcile
                pendingSync = false; pendingReconcile = false
                Task { await syncSessions(reconcile: full) }
            }
        }
        do {
            let snapshot = try await connector.fetch(root: conductorRoot, salt: preferences.localSalt, previous: library, retentionDays: retentionDays, reconcile: reconcile || checkpoint.needsReconciliation(), captureConversation: conversationMemoryEnabled, memoryStates: memoryStates, knownMemoryIDs: knownMemoryIDs)
            guard try await store.apply(snapshot, token: token, retentionDays: retentionDays) else { return }
            // The gate can close while awaiting actor work; never project an in-flight result after disconnect.
            guard captureGate.token() == token else { return }
            let writes = await store.lastWriteSummary
            let loaded = writes.changes > 0 ? try await store.load() : nil
            let savedCheckpoint = try await store.checkpoint()
            let savedMemory = conversationMemoryEnabled ? try await store.memoryState() : memoryStates
            let savedIDs = conversationMemoryEnabled ? try await store.knownMemoryIDs() : knownMemoryIDs
            guard captureGate.token() == token else { return }
            if let loaded { library = loaded }
            lastWriteSummary = writes
            lastDiagnostics = snapshot.diagnostics
            checkpoint = savedCheckpoint
            memoryStates = savedMemory
            knownMemoryIDs = savedIDs
            quietChecks = writes.changes == 0 ? quietChecks + 1 : 0
            consecutiveFailures = 0
            lastSync = snapshot.observedAt
            coverageLimited = snapshot.truncated || snapshot.sessions.contains { !$0.turnsComplete }
            connectionError = nil
            storageError = nil
            scheduleWorkBrief()
        } catch {
            guard captureGate.token() == token else { return }
            consecutiveFailures += 1
            if error is StoreFailure { storageError = error.localizedDescription }
            else { connectionError = error.localizedDescription }
        }
    }
    func showMemory(sessionID: String? = nil, query: String = "") { memorySessionID = sessionID; memoryQuery = query; openStudio(.memory) }
    func inspectSession(_ session: SessionMetadata) { selectedSessionID = session.id; openStudio(.decisions) }
    func saveNote(_ text: String, session: SessionMetadata) async {
        guard !isShowcase else { storageError = "Showcase records are read-only."; return }
        do { try await store?.saveNote(sessionID: session.id, text: text); library = try await store?.load() ?? .empty }
        catch { storageError = error.localizedDescription }
    }
    func applyRetention() async {
        checkpoint = .init() // Expanding retention requires a full metadata reconciliation.
        do {
            try await store?.enforceRetention(days: retentionDays)
            library = try await store?.load() ?? .empty
            await syncSessions(reconcile: true)
        }
        catch { storageError = error.localizedDescription }
    }
    func searchMemory(_ query: String, sessionID: String? = nil) async -> [ConversationMessage] {
        if isShowcase {
            return library.messages.filter { (sessionID == nil || $0.sessionID == sessionID) && (query.isEmpty || $0.text.localizedCaseInsensitiveContains(query)) }
        }
        do { return try await store?.memoryMessages(query: query, sessionID: sessionID) ?? [] }
        catch { storageError = error.localizedDescription; return [] }
    }
    func eraseConversationMemory() async {
        conversationMemoryEnabled = false
        do {
            try await store?.eraseConversationMemory()
            memoryStates = [:]; knownMemoryIDs = []
            library = try await store?.load() ?? .empty
        } catch { storageError = error.localizedDescription }
    }
    func deleteLocalRecords() async {
        conversationMemoryEnabled = false
        codexEnabled = false
        connectionError = nil
        lastSync = nil
        do { try await store?.deleteAll(); library = try await store?.load() ?? .empty; selectedSessionID = nil; memorySessionID = nil; memoryStates = [:]; knownMemoryIDs = []; checkpoint = .init() }
        catch { storageError = error.localizedDescription }
    }
    func exportRecords() async {
        guard let store else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Vernier-session-metadata.json"
        panel.message = "This export contains captured conversations, activity metadata, local AI briefs and any notes you wrote. Choose a location you trust."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { let data = try await store.exportJSON(); try data.write(to: url, options: [.atomic]); try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path) }
        catch { storageError = "Could not export local records to the chosen location." }
    }
    func finishOnboarding() { preferences.onboardingComplete = true; openStudio(.overview) }
}
