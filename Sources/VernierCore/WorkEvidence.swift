import Foundation

/// What the cited record supports, separately from usefulness, comprehension or verified truth.
public enum WorkEvidenceStatus: String, Codable, Sendable {
    case buildOnly = "build_only", agentReported = "agent_reported", humanReported = "human_reported", noResult = "no_result", unknown
    public var label: String {
        switch self {
        case .buildOnly: "A build was reported"
        case .agentReported: "AI reports a check"
        case .humanReported: "You reported a check"
        case .noResult: "The outcome is not established here"
        case .unknown: "Outcome evidence is unclear"
        }
    }
    public var explanation: String {
        switch self {
        case .buildOnly: "A build report does not establish that the original interaction works."
        case .agentReported: "The result is an agent report. Its sources are available to inspect; Vernier has not verified the behavior."
        case .humanReported: "Your saved words describe an attempt and result. This is your report, separately from an agent claim."
        case .noResult: "This reading does not establish an outcome. You may have checked it outside the conversation."
        case .unknown: "This reading does not have enough classified evidence to describe the outcome."
        }
    }
    static func classify(_ proposal: WorkProposal, context: DecisionContext) -> Self {
        guard proposal.resultState != nil else { return .unknown }
        guard proposal.focus != .directionChange && proposal.focus != .none else { return .unknown }
        func match(_ pattern: String, _ text: String) -> Bool { text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil }
        let cited = proposal.references.compactMap { ref -> (WorkReference, DecisionSource)? in
            guard [.change, .result, .response].contains(ref.use), let source = context.sources.first(where: { $0.id == ref.sourceID }), source.sessionID == context.sessionID,
                  ["user", "assistant", "user_report"].contains(source.role), source.origin != .reusedAgent,
                  source.role == "assistant" || source.novelText.contains(ref.quote) else { return nil }
            if source.role == "user_report" {
                guard context.perspectives.contains(where: { source.messageID == "feedback:" + $0.id && $0.anchorMessageID == context.anchor?.messageID }) else { return nil }
            }
            return (ref, source)
        }.sorted { left, right in
            (context.sources.firstIndex { $0.id == left.1.id } ?? 0) < (context.sources.firstIndex { $0.id == right.1.id } ?? 0)
        }
        let negative = #"\b(?:have not|haven['’]t|has not|hasn['’]t|did not|didn['’]t|not yet)\b.{0,40}\b(?:run|ran|test|tested|replay|replayed|check|checked|tried|verified)\b|\b(?:if I|if we|should I|would I|could I|I would|I might)\b"#
        let buildReport = #"\b(?:build|compile|compilation|CI)\b.{0,35}\b(?:pass\w*|succeed\w*|clean|green|complete\w*)\b|\b(?:passing|successful|clean|green)\s+(?:build|CI)\b|\bcompiled? (?:successfully|cleanly)\b|\b(?:code|project) builds\b"#
        for (ref, source) in cited.reversed() {
            let action = #"\b(?:tested|replayed|ran|tried|clicked|imported|importing|exported|downloaded|compared|saved|pressed|opened|reproduced|checked|verified|passed|passes|failed)\b"#
            let personalAttempt = #"\bI(?:['’]ve| have)?\s+(?:(?:just|also|already|actually|only)\s+)?(?:tested|replayed|ran|tried|(?:double[- ]?)?clicked|imported|exported|downloaded|compared|saved|pressed|opened|reproduced|checked|verified)\b"#
            let outcome = #"\b(?:pass\w*|fail\w*|got|saw|returned|created|exactly|once|one|two|still|error|worked|works|correct|result|no (?:duplicate|extra))\b"#
            let interaction = #"\b(?:replayed|clicked|imported|importing|pressed|opened|reproduced|unit tests?|behavior tests?)\b"#
            guard !ref.quote.contains("?"), !match(negative, ref.quote), match(action, ref.quote), match(outcome, ref.quote),
                  source.role == "assistant" || match(personalAttempt, ref.quote),
                  !match(buildReport, ref.quote) || match(interaction, ref.quote) else { continue }
            return source.role == "assistant" ? .agentReported : .humanReported
        }
        let uncertainBuild = #"\b(?:if|when|once)\b.{0,25}\b(?:build|CI)\b|\b(?:build|compile|compilation|CI)\b.{0,25}\b(?:not|never|isn['’]t|hasn['’]t|didn['’]t)\b.{0,15}\b(?:pass\w*|succeed\w*|clean|green|complete\w*)\b"#
        if cited.contains(where: { match(buildReport, $0.0.quote) && !match(uncertainBuild, $0.0.quote) }) { return .buildOnly }
        return .noResult
    }
}
