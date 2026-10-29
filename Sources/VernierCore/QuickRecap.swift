import Foundation

/// Small, source-counted sentences for the compact view. No inference about thought or prompt quality.
public struct QuickRecap: Sendable {
    public let headline: String
    public let detail: String
    public let secondary: String
    public let question: String
    public init(report: DailyParticipation) {
        let streak = report.longestContinuation.count
        if streak >= 3 {
            headline = "You approved or continued \(streak) times in a row."
            detail = "In one saved conversation. A short reply can still be a deliberate choice."
            question = "Could I explain why one of those changes works?"
        } else if report.repairRequests.count >= 2 {
            headline = "You came back with short repair requests."
            detail = "\(report.repairRequests.count) replies asked for another fix without describing the expected result."
            question = "What should happen instead, and how will I check it?"
        } else {
            let kinds: [DailyAction] = [.checked, .directed, .reported, .continued]
            let focus = kinds.max { report.count($0) < report.count($1) } ?? .other
            if report.count(focus) == 0 {
                headline = "Your replies didn’t fit a simple pattern."
                detail = "The wording alone wasn’t clear enough to group \(report.followUps) saved replies."
                question = "Which change would I like to understand better?"
            } else {
                switch focus {
                case .checked:
                    headline = "You asked for explanations and checks."
                    question = "What did I try myself, and what happened?"
                case .directed:
                    headline = "You told AI what to change or keep."
                    question = "Which change did I choose, and why?"
                case .reported:
                    headline = "You reported results from your own checks."
                    question = "Could I repeat that check after the next change?"
                case .continued:
                    headline = "You asked AI to carry on."
                    question = "Could I explain why one of those changes works?"
                case .other:
                    headline = "Your saved replies are ready to revisit."
                    question = "Which change would I like to understand better?"
                }
                detail = "\(report.count(focus)) of \(report.followUps) saved replies."
            }
        }
        let continued = report.count(.continued), directed = report.count(.directed)
        var parts: [String] = []
        if continued > 0 { parts.append("\(continued) \(continued == 1 ? "short reply asked" : "short replies asked") AI to carry on.") }
        if directed > 0 { parts.append("\(directed) \(directed == 1 ? "reply added" : "replies added") a condition, choice or correction.") }
        secondary = parts.joined(separator: " ")
    }
}
