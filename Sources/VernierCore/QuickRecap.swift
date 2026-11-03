import Foundation

/// A source-linked moment for the compact view. Agent replies remain claims, not verified outcomes.
public struct QuickRecap: Sendable {
    public let headline: String
    public let detail: String
    public let moment: DailyMoment?
    public let focus: DailyAction?
    public let presence: String
    public init(report: DailyParticipation) {
        let streak = report.longestContinuation
        if streak.count >= 3 {
            headline = "\(streak.count) brief continuations in one conversation."
            detail = "In one saved conversation. A short reply can still be a deliberate choice."
            focus = .continued; moment = streak.last
            presence = "\(streak.count) brief continuations"
        } else if report.repairRequests.count >= 2 {
            headline = "\(report.repairRequests.count) short requests for another fix."
            detail = "These replies did not name a specific expected result. Open the exchange for context."
            focus = .other; moment = report.repairRequests.last
            presence = "\(report.repairRequests.count) short repair requests"
        } else {
            let kinds: [DailyAction] = [.checked, .directed, .reported, .continued]
            let largest = kinds.map { report.count($0) }.max() ?? 0
            let selected = kinds.first { report.count($0) == largest && largest > 0 }
            focus = selected
            moment = selected.flatMap { action in report.moments.last { $0.action == action } } ?? report.moments.last
            let count = selected.map { report.count($0) } ?? 0
            switch selected {
            case .checked:
                presence = "\(count) check \(count == 1 ? "request" : "requests")"
                headline = count == 1 ? "One request for a check or explanation." : "\(count) requests for checks or explanations."
                detail = "A request is not a result. Read what AI actually supplied in response."
            case .directed:
                presence = "\(count) \(count == 1 ? "condition or choice" : "conditions or choices")"
                headline = count == 1 ? "One reply set a condition or choice." : "\(count) replies set conditions or choices."
                detail = "Compare your requirement with the approach in the next agent reply."
            case .reported:
                presence = "\(count) \(count == 1 ? "result you reported" : "results you reported")"
                headline = count == 1 ? "You reported one result." : "You reported \(count) results."
                detail = "Your own report, separately from what AI claimed."
            case .continued:
                presence = "\(count) \(count == 1 ? "continuation" : "continuations")"
                headline = count == 1 ? "You asked AI to continue once." : "You asked AI to continue \(count) times."
                detail = "A short approval can be deliberate. Open the exchange to see what followed."
            default:
                presence = "Saved replies to revisit"
                headline = report.followUps == 0 ? "No saved follow-ups to describe." : "This reply needs its context."
                detail = "The wording rules could not confidently group these replies."
            }
        }
    }
}
