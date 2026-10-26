import Foundation
import CoreGraphics
import VernierCore

public struct CoreCheckFailure: Error, CustomStringConvertible {
    public let description: String
    public init(description: String) { self.description = description }
}

public enum CoreChecks {
    public static let cases: [(String, @Sendable () throws -> Void)] = [
        ("Demo identity, chronology, counts, and attribution", demo),
        ("Unknown counts with no live coverage", empty),
        ("Pause overrides all preview states", pause),
        ("Preferences persist with opt-out defaults", preferences),
        ("Pill restores safely across display changes", placement),
        ("Public showcase is deterministic and entirely synthetic", showcase)
    ]
    private static func expect(_ value: @autoclosure () -> Bool, _ message: String) throws {
        if !value() { throw CoreCheckFailure(description: message) }
    }
    private static func showcase() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let library = ShowcaseFixtures.library(now: now)
        try expect(library.sessions.count == 3 && library.messages.count == 6 && library.signals.count == 3, "Showcase inventory differs from fixtures")
        try expect(library.totalMessageCount == library.messages.count && library.totalSignalCount == library.signals.count, "Showcase totals must be actual fixture counts")
        try expect(library.sessions.allSatisfy { $0.id.hasPrefix("showcase-") && $0.workspaceID.hasPrefix("showcase-") }, "Showcase contains a non-fixture identity")
        try expect(library.messages.allSatisfy { $0.id.hasPrefix("showcase-") && $0.observedAt == now }, "Showcase has unknown provenance")
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let first = try encoder.encode(library)
        let second = try encoder.encode(ShowcaseFixtures.library(now: now))
        try expect(first == second, "Showcase must be reproducible")
    }
    private static func demo() throws {
        let events = DemoFixtures.events
        try expect(events.count == 12, "Expected twelve fixed fixtures")
        try expect(Set(events.map(\.id)).count == events.count, "Duplicate demo IDs")
        try expect(events.allSatisfy { $0.id.hasPrefix("demo-") && $0.provenance.contains("not a provider event") }, "Ambiguous provenance")
        try expect(events.map(\.minute) == events.map(\.minute).sorted(by: >), "Timeline is out of order")
        let projection = InstrumentProjection(demoEnabled: true, paused: false)
        try expect(projection.taskCount == 3 && projection.eventCount == 12, "Counts differ from fixtures")
        try expect(projection.status.hasPrefix("Demo ·"), "Missing demo status")
        try expect(projection.coverage == "0 of 3 live sources connected", "Demo claims live coverage")
    }
    private static func empty() throws {
        for state in InstrumentState.allCases {
            let projection = InstrumentProjection(demoEnabled: false, paused: false, previewState: state)
            try expect(projection.state == .idle, "No-source state must be idle")
            try expect(projection.eventCount == nil && projection.taskCount == nil, "Unknown counts must not become zero")
            try expect(projection.events.isEmpty && !projection.status.contains("Demo"), "Fixtures leaked out of demo mode")
        }
    }
    private static func pause() throws {
        for state in InstrumentState.allCases {
            for demo in [true, false] {
                let projection = InstrumentProjection(demoEnabled: demo, paused: true, previewState: state)
                try expect(projection.state == .paused, "Pause must override \(state)")
                try expect(projection.events.count == (demo ? 12 : 0), "Pause should preserve only existing fixtures")
            }
        }
    }
    private static func preferences() throws {
        let suite = "vernier-tests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else { throw CoreCheckFailure(description: "Cannot create isolated defaults") }
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)
        try expect(preferences.demoEnabled && !preferences.paused && !preferences.pillEnabled && !preferences.onboardingComplete && preferences.pillOrigin == nil, "Incorrect first-launch defaults")
        preferences.paused = true
        preferences.demoEnabled = false
        preferences.pillEnabled = true
        preferences.onboardingComplete = true
        preferences.pillOrigin = CGPoint(x: 110, y: 120)
        guard let restoredDefaults = UserDefaults(suiteName: suite) else { throw CoreCheckFailure(description: "Cannot reopen defaults") }
        let restored = Preferences(defaults: restoredDefaults)
        try expect(restored.paused && !restored.demoEnabled && restored.pillEnabled && restored.onboardingComplete, "Settings did not persist")
        try expect(restored.pillOrigin == CGPoint(x: 110, y: 120), "Pill position did not persist")
        restored.pillOrigin = nil
        try expect(preferences.pillOrigin == nil, "Pill position did not reset")
    }
    private static func placement() throws {
        let primary = CGRect(x: 0, y: 0, width: 1440, height: 850)
        let secondary = CGRect(x: -1200, y: 0, width: 1200, height: 800)
        let size = CGSize(width: 206, height: 52)
        let saved = CGPoint(x: -700, y: 200)
        try expect(PanelPlacement.origin(saved: saved, size: size, screens: [primary, secondary]) == saved, "Secondary display position lost")
        let recovered = PanelPlacement.origin(saved: saved, size: size, screens: [primary])
        try expect(primary.contains(CGRect(origin: recovered, size: size)), "Offscreen position not recovered")
        let invalid = PanelPlacement.origin(saved: CGPoint(x: CGFloat.nan, y: CGFloat.infinity), size: size, screens: [primary])
        try expect(primary.contains(CGRect(origin: invalid, size: size)), "Corrupt coordinates not recovered")
        try expect(PanelPlacement.origin(saved: nil, size: size, screens: []).x.isFinite, "No-display fallback invalid")
    }
}
