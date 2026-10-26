import Foundation

public struct SyncCheckpoint: Sendable, Equatable {
    public let checkedAt: Date?
    public let reconciledAt: Date?
    public init(checkedAt: Date? = nil, reconciledAt: Date? = nil) { self.checkedAt = checkedAt; self.reconciledAt = reconciledAt }
    public func needsReconciliation(at now: Date = Date()) -> Bool { reconciledAt.map { now.timeIntervalSince($0) >= 6 * 3600 } ?? true }
}

public struct SyncDiagnostics: Sendable, Equatable {
    public let listPages: Int
    public let historyReads: Int
    public let memoryReads: Int
    public let reconciliation: Bool
    public init(listPages: Int = 0, historyReads: Int = 0, memoryReads: Int = 0, reconciliation: Bool = false) {
        self.listPages = listPages; self.historyReads = historyReads; self.memoryReads = memoryReads; self.reconciliation = reconciliation
    }
}

public struct StoreWriteSummary: Sendable, Equatable {
    public let sessions: Int
    public let turns: Int
    public let memory: Int
    public var changes: Int { sessions + turns + memory }
    public init(sessions: Int = 0, turns: Int = 0, memory: Int = 0) { self.sessions = sessions; self.turns = turns; self.memory = memory }
}

public enum SyncCadence {
    public static func delay(visible: Bool, quietChecks: Int, failures: Int, lowPower: Bool, suspended: Bool) -> TimeInterval {
        if suspended { return 300 }
        let errorDelay = failures > 0 ? min(900, 30 * pow(2, Double(min(failures - 1, 5)))) : 0
        if lowPower { return max(300, errorDelay) }
        if failures > 0 { return errorDelay }
        if quietChecks >= 3 { return 180 }
        return visible ? 20 : 60
    }
}

public enum WorkRhythm {
    /// Available provider history only. Counts are work records, never attention or cognition measurements.
    public static func hourlyTurns(_ turns: [TurnMetadata], now: Date = Date(), calendar: Calendar = .current, hours: Int = 24) -> [Int] {
        let end = calendar.dateInterval(of: .hour, for: now)?.start ?? now
        let start = calendar.date(byAdding: .hour, value: -(hours - 1), to: end) ?? end
        var bins = [Int](repeating: 0, count: max(1, hours))
        for turn in turns {
            guard let timestamp = turn.completedAt ?? turn.startedAt, timestamp <= now else { continue }
            let index = calendar.dateComponents([.hour], from: start, to: timestamp).hour ?? -1
            if timestamp >= start, bins.indices.contains(index) { bins[index] += 1 }
        }
        return bins
    }
    public static func todaySessions(_ sessions: [SessionMetadata], now: Date = Date(), calendar: Calendar = .current) -> Int {
        sessions.filter { $0.updatedAt <= now && calendar.isDate($0.updatedAt, inSameDayAs: now) }.count
    }
}

public enum RetentionPolicy {
    public static func cutoff(days: Int, now: Date = Date()) -> Date {
        days == 0 ? .distantPast : now.addingTimeInterval(-Double(max(1, days)) * 86400)
    }
}
