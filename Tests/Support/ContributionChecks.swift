import Foundation
import VernierCore

public enum ContributionChecks {
    private static func check(_ value: Bool, _ message: String) throws { if !value { throw CoreCheckFailure(description: message) } }
    private static func messages() -> [ConversationMessage] {
        let now = WorkDay(containing: Date()).start.addingTimeInterval(3600)
        return ["Keep this private.", "I suggest a hosted service.", "Keep it offline and explain the tradeoff.", "I can explain that.", "Go ahead."].enumerated().map { i, text in
            .init(id: "contribution-\(i)", sessionID: "contribution", turnID: "turn-\(i)", speaker: i % 2 == 0 ? "user" : "assistant", phase: "user", text: text, sourceAt: now.addingTimeInterval(Double(i)), observedAt: now, redactions: 0, textTruncated: false, attachmentsOmitted: false)
        }
    }
    public static func validation() async throws {
        let context = DecisionContext.make(sessionID: "contribution", messages: messages(), storedMessages: 5)!
        let source = context.sources.first { $0.messageID == "contribution-2" }!
        let claims = [ContributionClaim(action: .directed, quote: "Keep it offline"), .init(action: .checked, quote: "explain the tradeoff")]
        let draft = ContributionDraft(sourceID: source.id, primary: .directed, claims: claims)
        let accepted = ContributionReading.validate([draft], supportedIDs: [source.id], context: context, engine: "invented")
        try check(accepted.first { $0.messageID == source.messageID }?.claims.count == 2, "Mixed contributions must retain both exact-source signals")
        let wrongActor = ContributionDraft(sourceID: source.id, primary: .directed, claims: [.init(action: .directed, quote: "I suggest a hosted service.")])
        try check(ContributionReading.validate([wrongActor], supportedIDs: [source.id], context: context, engine: "invented").allSatisfy { !$0.accepted }, "An agent quote must not establish a human contribution")
        try check(ContributionReading.validate([draft, draft], supportedIDs: [source.id], context: context, engine: "invented").allSatisfy { !$0.accepted }, "Duplicate target labels must be withheld")
        try check(ContributionReading.validate([draft], supportedIDs: [], context: context, engine: "invented").allSatisfy { !$0.accepted }, "The host must respect a critic withholding the classification")
        let excluded = Set(accepted.map(\.messageID))
        try check(ContributionReading.batchTargets(in: context, excluding: excluded).isEmpty, "Catch-up must skip unchanged messages already attempted, including withheld ones")
        let encoded = try JSONEncoder().encode(accepted)
        try check(try JSONDecoder().decode([ContributionReading].self, from: encoded).first?.fingerprint == accepted.first?.fingerprint, "Contribution provenance must survive persistence")
    }
    public static func projection() async throws {
        let messages = messages(), day = WorkDay(containing: messages[0].sourceAt!)
        let context = DecisionContext.make(sessionID: "contribution", messages: messages, storedMessages: messages.count)!
        let source = context.sources.first { $0.messageID == "contribution-2" }!
        let draft = ContributionDraft(sourceID: source.id, primary: .directed, claims: [.init(action: .directed, quote: "Keep it offline"), .init(action: .checked, quote: "explain the tradeoff")])
        let readings = ContributionReading.validate([draft], supportedIDs: [source.id], context: context, engine: "invented", now: Date())
        let input = DailyInput(messages: messages, datedTotal: messages.count, undatedTotal: 0)
        let report = DailyParticipation.make(day: day, input: input, sessions: [], interpretations: readings, contextual: true)
        try check(report.count(.directed) == 1 && report.count(.checked) == 0 && report.moments[0].wordingAction == .checked, "The model's main role must replace first-match wording while retaining the wording comparison")
        try check(report.moments[0].interpretation?.claims.count == 2 && report.moments[1].action == .other, "Secondary signals and withheld replies must remain distinguishable")
        let pending = DailyParticipation.make(day: day, input: input, sessions: [], contextual: true)
        try check(pending.pendingFollowUps == 2 && pending.count(.other) == 2, "Unread replies must never silently inherit rule labels")
        let withheld = ContributionReading.validate([], supportedIDs: [], context: context, engine: "invented", now: Date().addingTimeInterval(20))
        let newer = DailyParticipation.make(day: day, input: input, sessions: [], interpretations: readings + withheld, contextual: true)
        try check(newer.count(.directed) == 0 && newer.reviewedFollowUps == 2 && newer.acceptedFollowUps == 0, "A newer withheld interpretation must supersede an older accepted category")
        let changed = ConversationMessage(id: messages[2].id, sessionID: messages[2].sessionID, turnID: messages[2].turnID, speaker: "user", phase: "user", text: "A changed requirement", sourceAt: messages[2].sourceAt, observedAt: Date(), redactions: 0, textTruncated: false, attachmentsOmitted: false)
        try check(ContributionReading.latest(readings, for: changed) == nil, "An edited message must invalidate its old interpretation")
        try check(DailyAction.allCases.reduce(0) { $0 + report.count($1) } == report.followUps, "Primary-category counts must retain an honest non-overlapping denominator")
    }
}
