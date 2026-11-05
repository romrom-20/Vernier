import Foundation

/// A revisit aid from one validated conversation reading, never a percentage of human effort.
public struct WorkDayInsight: Identifiable, Sendable {
    public let revision: DecisionRevision
    public let historical: Bool
    public var id: String { revision.id }
    public var reading: WorkReading { revision.reading! }
    public var evidenceStatus: WorkEvidenceStatus { reading.evidenceStatus ?? .unknown }
    public var title: String {
        if reading.focus == .recurringIssue { return "This may be a returning problem." }
        if reading.focus == .handoff { return "A checkpoint for your handoff." }
        switch evidenceStatus {
        case .buildOnly: return "Connect the build to the actual behavior."
        case .humanReported: return "You brought a result back."
        case .agentReported: return "A reported result to inspect."
        case .noResult, .unknown: return "One outcome worth reconnecting with."
        }
    }
    public var detail: String {
        if reading.focus == .recurringIssue { return "The reading links two reports of a similar fault. Check whether the same input and requirement are involved." }
        if reading.focus == .handoff { return "Delegating execution can be deliberate. This saved checkpoint gives you a way back into the work." }
        return reading.evidenceExplanation
    }
    public var priority: Int {
        if reading.focus == .recurringIssue { return 0 }
        if evidenceStatus == .buildOnly { return 1 }
        if reading.focus == .check { return 2 }
        if reading.focus == .handoff { return 3 }
        return 4
    }
    /// Keeps the latest reading in each active conversation, including a withheld result that supersedes an earlier reading.
    public static func make(day: WorkDay, activeSessionIDs: Set<String>, revisions: [DecisionRevision], currentIDs: Set<String>? = nil) -> [Self] {
        let eligible = revisions.filter { day.contains($0.createdAt) && activeSessionIDs.contains($0.sessionID) }
        let latest = Dictionary(grouping: eligible, by: \.sessionID).values.compactMap { group in
            group.max { $0.createdAt == $1.createdAt ? $0.id < $1.id : $0.createdAt < $1.createdAt }
        }
        return latest.compactMap { revision -> Self? in
            guard let reading = revision.reading, reading.focus != .none, reading.focus != .directionChange,
                  reading.evidenceStatus != nil, reading.evidenceStatus != .unknown,
                  currentIDs == nil || currentIDs!.contains(revision.id) else { return nil }
            return Self(revision: revision, historical: currentIDs == nil)
        }.sorted { $0.priority == $1.priority ? $0.revision.createdAt > $1.revision.createdAt : $0.priority < $1.priority }
    }
}
