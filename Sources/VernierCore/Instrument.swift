import CoreGraphics
import Foundation

public enum InstrumentState: String, CaseIterable, Sendable {
    case idle, observing, moment, paused, connectorIssue

    public var label: String {
        switch self {
        case .idle: "Waiting for activity"
        case .observing: "Observing quietly"
        case .moment: "A moment to consider"
        case .paused: "Observation paused"
        case .connectorIssue: "Source needs attention"
        }
    }
}

public enum Provider: String, CaseIterable, Identifiable, Sendable {
    case claudeCode, codex, cursor
    public var id: String { rawValue }
    public var name: String {
        switch self {
        case .claudeCode: "Claude Code"
        case .codex: "Codex"
        case .cursor: "Cursor"
        }
    }
    public var monogram: String {
        switch self {
        case .claudeCode: "Cl"
        case .codex: "Co"
        case .cursor: "Cu"
        }
    }
}

public enum EventKind: String, Sendable {
    case taskStarted, fileChanged, testCompleted, taskCompleted, approvalRequested
    public var label: String {
        switch self {
        case .taskStarted: "Task started"
        case .fileChanged: "Files changed"
        case .testCompleted: "Test run completed"
        case .taskCompleted: "Task completed"
        case .approvalRequested: "Approval requested"
        }
    }
    public var symbol: String {
        switch self {
        case .taskStarted: "play"
        case .fileChanged: "doc.text"
        case .testCompleted: "checkmark.circle"
        case .taskCompleted: "checkmark"
        case .approvalRequested: "hand.raised"
        }
    }
}

/// Bundled fiction only. Not a provider schema or an ingestion contract.
public struct DemoEvent: Identifiable, Equatable, Sendable {
    public let id: String
    public let provider: Provider
    public let kind: EventKind
    public let minute: Int
    public let taskID: String
    public let detail: String
    public var timeLabel: String { String(format: "10:%02d", minute) }
    public var provenance: String { "Bundled demo fixture · not a provider event" }
}

public enum DemoFixtures {
    public static let events: [DemoEvent] = [
        .init(id: "demo-12", provider: .claudeCode, kind: .taskCompleted, minute: 42, taskID: "sample-c", detail: "Sample task completed; verification outside this fixture is unknown."),
        .init(id: "demo-11", provider: .claudeCode, kind: .fileChanged, minute: 40, taskID: "sample-c", detail: "Three sample file changes. No file names or contents are collected."),
        .init(id: "demo-10", provider: .claudeCode, kind: .taskStarted, minute: 36, taskID: "sample-c", detail: "A fictional task boundary, attributed to Claude Code for this preview."),
        .init(id: "demo-09", provider: .codex, kind: .taskCompleted, minute: 34, taskID: "sample-b", detail: "Sample task completed after a fictional test run."),
        .init(id: "demo-08", provider: .codex, kind: .testCompleted, minute: 33, taskID: "sample-b", detail: "A fictional successful test event; not proof of coverage or correctness."),
        .init(id: "demo-07", provider: .codex, kind: .fileChanged, minute: 31, taskID: "sample-b", detail: "Two sample file changes. No real workspace was read."),
        .init(id: "demo-06", provider: .codex, kind: .approvalRequested, minute: 29, taskID: "sample-b", detail: "A fictional request for approval. No command or approval is executed."),
        .init(id: "demo-05", provider: .codex, kind: .taskStarted, minute: 27, taskID: "sample-b", detail: "A fictional task boundary in the sample sequence."),
        .init(id: "demo-04", provider: .cursor, kind: .taskCompleted, minute: 25, taskID: "sample-a", detail: "Sample task completed, with a fictional test event in its sequence."),
        .init(id: "demo-03", provider: .cursor, kind: .testCompleted, minute: 24, taskID: "sample-a", detail: "A fictional successful test event."),
        .init(id: "demo-02", provider: .cursor, kind: .fileChanged, minute: 22, taskID: "sample-a", detail: "One sample file change. No editor files were accessed."),
        .init(id: "demo-01", provider: .cursor, kind: .taskStarted, minute: 20, taskID: "sample-a", detail: "The first fictional task in this fixed demo sequence.")
    ]
}

public struct LiveSummary: Sendable {
    public let sessions: Int
    public let turns: Int
    public let connected: Bool
    public let verified: Bool
    public let hasError: Bool
    public init(sessions: Int, turns: Int, connected: Bool, verified: Bool, hasError: Bool) {
        self.sessions = sessions; self.turns = turns; self.connected = connected; self.verified = verified; self.hasError = hasError
    }
}

public struct InstrumentProjection: Sendable {
    public let demoEnabled: Bool
    public let paused: Bool
    public let previewState: InstrumentState
    public let live: LiveSummary?
    public init(demoEnabled: Bool, paused: Bool, previewState: InstrumentState = .observing, live: LiveSummary? = nil) {
        self.live = live
        self.demoEnabled = demoEnabled
        self.paused = paused
        self.previewState = previewState
    }
    public var state: InstrumentState {
        if paused { return .paused }
        if demoEnabled { return previewState }
        if live?.hasError == true { return .connectorIssue }
        return live?.connected == true && live?.verified == true ? .observing : .idle
    }
    public var status: String {
        if demoEnabled { return "Demo · \(state.label.lowercased())" }
        if paused { return "Session sync paused" }
        if live?.hasError == true { return "Codex connection needs attention" }
        if live?.connected == true { return live?.verified == true ? "Codex session metadata connected" : "Waiting for Codex metadata" }
        return "Waiting for a connection"
    }
    public var events: [DemoEvent] { demoEnabled ? DemoFixtures.events : [] }
    public var taskCount: Int? { demoEnabled ? Set(events.filter { $0.kind == .taskStarted }.map(\.taskID)).count : nil }
    public var eventCount: Int? { demoEnabled ? events.count : nil }
    public var coverage: String {
        if demoEnabled, live?.connected == true { return "Demo preview · Codex metadata enabled separately" }
        if !demoEnabled, live?.connected == true, live?.verified == true { return "Codex · Conductor workspace metadata only" }
        return "0 of 3 live sources connected"
    }
}

public struct Preferences {
    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    public var demoEnabled: Bool {
        get { defaults.object(forKey: "demoEnabled") as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: "demoEnabled") }
    }
    public var paused: Bool {
        get { defaults.bool(forKey: "paused") }
        nonmutating set { defaults.set(newValue, forKey: "paused") }
    }
    public var pillEnabled: Bool {
        get { defaults.bool(forKey: "pillEnabled") }
        nonmutating set { defaults.set(newValue, forKey: "pillEnabled") }
    }
    public var onboardingComplete: Bool {
        get { defaults.bool(forKey: "onboardingComplete") }
        nonmutating set { defaults.set(newValue, forKey: "onboardingComplete") }
    }
    public var pillAlwaysExpanded: Bool {
        get { defaults.bool(forKey: "pillAlwaysExpanded") }
        nonmutating set { defaults.set(newValue, forKey: "pillAlwaysExpanded") }
    }
    public var conversationMemoryEnabled: Bool {
        get { defaults.bool(forKey: "conversationMemoryEnabled") }
        nonmutating set { defaults.set(newValue, forKey: "conversationMemoryEnabled") }
    }
    public var localInsightsEnabled: Bool {
        get { defaults.bool(forKey: "localInsightsEnabled") }
        nonmutating set { defaults.set(newValue, forKey: "localInsightsEnabled") }
    }
    public var automaticDecisionReviews: Bool {
        get { defaults.bool(forKey: "automaticDecisionReviews") }
        nonmutating set { defaults.set(newValue, forKey: "automaticDecisionReviews") }
    }
    public var reasoningModel: String {
        get {
            let saved = defaults.string(forKey: "reasoningModel") ?? "apple"
            return ["apple", "qwen2.5:7b"].contains(saved) ? saved : "apple"
        }
        nonmutating set { defaults.set(newValue, forKey: "reasoningModel") }
    }
    public var codexEnabled: Bool {
        get { defaults.bool(forKey: "codexEnabled") }
        nonmutating set { defaults.set(newValue, forKey: "codexEnabled") }
    }
    public var retentionDays: Int {
        get { defaults.object(forKey: "retentionDays") as? Int ?? 30 }
        nonmutating set { defaults.set(newValue, forKey: "retentionDays") }
    }
    public var localSalt: String {
        if let value = defaults.string(forKey: "metadataSalt") { return value }
        let value = UUID().uuidString; defaults.set(value, forKey: "metadataSalt"); return value
    }
    public var pillOrigin: CGPoint? {
        get {
            guard defaults.object(forKey: "pillX") != nil, defaults.object(forKey: "pillY") != nil else { return nil }
            return CGPoint(x: defaults.double(forKey: "pillX"), y: defaults.double(forKey: "pillY"))
        }
        nonmutating set {
            if let newValue {
                defaults.set(newValue.x, forKey: "pillX")
                defaults.set(newValue.y, forKey: "pillY")
            } else {
                defaults.removeObject(forKey: "pillX")
                defaults.removeObject(forKey: "pillY")
            }
        }
    }
}

public enum PanelPlacement {
    /// Restores to a visible screen after monitor removal, resolution changes, or corrupt preferences.
    public static func origin(saved: CGPoint?, size: CGSize, screens: [CGRect]) -> CGPoint {
        let fallback = screens.first ?? CGRect(x: 0, y: 0, width: 1024, height: 768)
        let candidate = saved ?? CGPoint(x: fallback.midX - size.width / 2, y: fallback.minY + 36)
        let finite = candidate.x.isFinite && candidate.y.isFinite
        let screen = finite ? screens.first(where: { $0.contains(CGRect(origin: candidate, size: size)) }) : nil
        guard screen != nil else {
            return CGPoint(x: fallback.midX - size.width / 2, y: fallback.minY + 36)
        }
        return candidate
    }
}
