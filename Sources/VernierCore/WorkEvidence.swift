import Foundation

/// A recognized report in the cited record, with its speaker retained through
/// the source ID. This is neither a verified result nor a conflict verdict.
public struct WorkEvidenceReport: Codable, Sendable, Equatable {
    public let sourceID: String
    public let quote: String
    public let status: WorkEvidenceStatus
}

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
        let reports = reports(references: proposal.references, context: context)
        return reports.last(where: { [.humanReported, .agentReported].contains($0.status) })?.status
            ?? (reports.isEmpty ? .noResult : .buildOnly)
    }
    /// Retain both speakers' reports rather than treating the latest report as
    /// confirmation of an earlier speaker's claim. Quotations stay unchanged.
    static func reports(references: [WorkReference], context: DecisionContext) -> [WorkEvidenceReport] {
        func match(_ pattern: String, _ text: String) -> Bool { text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil }
        // Determine quotation scope in the visible SOURCE before inspecting a
        // selected substring. Otherwise selecting only the inner "I tested..."
        // could erase who originally said it. Keep raw quotations for display.
        func unquotedText(_ quote: String, source: DecisionSource) -> String {
            let visible = String((source.origin == .mixed ? source.novelText : source.text).prefix(source.role == "assistant" ? 650 : 1400))
            let text = visible as NSString
            let span = text.range(of: quote)
            guard span.location != NSNotFound else { return "" }
            let pattern = #"```[\s\S]*?(?:```|$)|`[^`]*(?:`|$)|"(?:\\.|[^"\\])*(?:"|$)|“[^”]*(?:”|$)|‘[^’]*(?:’|$)|(?<![\p{L}\p{N}])'(?:[^']|'(?=[\p{L}\p{N}]))*'(?![\p{L}\p{N}])"#
            guard let expression = try? NSRegularExpression(pattern: pattern) else { return "" }
            var units = Array(quote.utf16)
            for quoted in expression.matches(in: visible, range: NSRange(location: 0, length: text.length)) {
                let overlap = NSIntersectionRange(span, quoted.range)
                if overlap.length > 0 {
                    for index in (overlap.location - span.location)..<(NSMaxRange(overlap) - span.location) { units[index] = 32 }
                }
            }
            return String(decoding: units, as: UTF16.self)
        }
        let cited = references.compactMap { ref -> (WorkReference, DecisionSource)? in
            guard [.change, .result, .response, .boundary].contains(ref.use), let source = context.sources.first(where: { $0.id == ref.sourceID }), source.sessionID == context.sessionID,
                  !context.recalledMessageIDs.contains(source.messageID),
                  ["user", "assistant", "user_report"].contains(source.role), source.origin != .reusedAgent,
                  source.role == "assistant" || source.novelText.contains(ref.quote) else { return nil }
            if source.role == "user_report" {
                guard context.perspectives.contains(where: { source.messageID == "feedback:" + $0.id && $0.anchorMessageID == context.anchor?.messageID }) else { return nil }
            }
            return (ref, source)
        }.sorted { left, right in
            (context.sources.firstIndex { $0.id == left.1.id } ?? 0) < (context.sources.firstIndex { $0.id == right.1.id } ?? 0)
        }
        let negative = #"\b(?:have not|haven['’]t|has not|hasn['’]t|did not|didn['’]t|not yet)\b.{0,40}\b(?:run|ran|test|tested|replay|replayed|check|checked|tried|verified|clicked|pressed|opened|sorted|refreshed|dragged|selected|switched|disconnected|reconnected|renamed|entered)\b|\b(?:if I|if we|should I|would I|could I|I would|I might)\b"#
        let buildReport = #"\b(?:build|compile|compilation|CI)\b.{0,35}\b(?:pass\w*|succeed\w*|clean|green|complete\w*)\b|\b(?:passing|successful|clean|green)\s+(?:build|CI)\b|\bcompiled? (?:successfully|cleanly)\b|\b(?:code|project|patch) (?:builds|compiles)\b"#
        let quotedExample = #"\b(?:fictional|fiction)\b|\b(?:sample|example|quoted?|quotation)\b.{0,70}[\"“]"#
        func isQuotedExample(_ source: DecisionSource) -> Bool {
            let visible = source.origin == .mixed ? source.novelText : source.text
            return match(quotedExample, String(visible.prefix(source.role == "assistant" ? 650 : 1400)))
        }
        var reports: [WorkEvidenceReport] = []
        for (ref, source) in cited {
            // A boundary can include an explicit build report and a denied
            // replay. It cannot supply the performed-interaction result here.
            guard ref.use != .boundary else { continue }
            let reportText = unquotedText(ref.quote, source: source)
            let action = #"\b(?:tested|replayed|ran|tried|clicked|imported|importing|exported|downloaded|compared|saved|pressed|opened|reproduced|checked|verified|passed|passes|failed)\b"#
            let personalAttempt = #"\bI(?:['’]ve| have)?\s+(?:(?:just|also|already|actually|only)\s+)?(?:tested|replayed|ran|tried|(?:double[- ]?)?clicked|imported|exported|downloaded|compared|saved|pressed|opened|reproduced|checked|verified)\b"#
            let outcome = #"\b(?:pass\w*|fail\w*|got|saw|returned|created|exactly|once|one|two|still|error|worked|works|correct|result|no (?:duplicate|extra))\b"#
            let interaction = #"\b(?:replayed|clicked|imported|importing|pressed|opened|reproduced|unit tests?|behavior tests?)\b"#
            let firsthandAction = #"\bI(?:['’]ve| have)?\s+(?:(?:just|also|already|actually|only)\s+)?(?:sorted|refreshed|dragged|selected|switched|disconnected|reconnected|renamed|entered)\b"#
            let observedOutcome = #"\b(?:observed|saw|got|heard|returned|became|stayed|remained|jumped)\b"#
            let resultingState = #"\b(?:was|were|is|remained|stayed|became|become)\s+(?:still\s+)?(?:blank|empty|missing|locked|enabled)\b"#
            let legacyReport = match(action, reportText) && match(outcome, reportText) && (source.role == "assistant" || match(personalAttempt, reportText))
            // New wording needs a first-person past action and an explicit
            // observation/state, rather than a choice or a completed code edit.
            let expandedReport = (
                (match(firsthandAction, reportText) && match(observedOutcome, reportText)) ||
                (match(personalAttempt, reportText) && match(resultingState, reportText)))
            guard !reportText.contains("?"), !match(negative, reportText),
                  !isQuotedExample(source), legacyReport || expandedReport,
                  !match(buildReport, reportText) || match(interaction, reportText) else { continue }
            let report = WorkEvidenceReport(sourceID: source.id, quote: ref.quote, status: source.role == "assistant" ? .agentReported : .humanReported)
            if !reports.contains(report) { reports.append(report) }
        }
        let uncertainBuild = #"\b(?:if|when|once|whether|ensure|make sure|show that)\b.{0,25}\b(?:builds?|compil(?:e[sd]?|ation)|CI)\b|\b(?:build|compile|compilation|CI)\b.{0,25}\b(?:not|never|isn['’]t|hasn['’]t|didn['’]t)\b.{0,15}\b(?:pass\w*|succeed\w*|clean|green|complete\w*)\b|\b(?:not|never|haven['’]t|hasn['’]t|didn['’]t)\b[^.!?;\n]{0,45}\b(?:builds?|compiles?|compiled)\b"#
        for (ref, source) in cited where !isQuotedExample(source) {
            let reportText = unquotedText(ref.quote, source: source)
            guard match(buildReport, reportText), !match(uncertainBuild, reportText) else { continue }
            let report = WorkEvidenceReport(sourceID: source.id, quote: ref.quote, status: .buildOnly)
            if !reports.contains(where: { $0.sourceID == source.id && $0.quote == ref.quote }) { reports.append(report) }
        }
        return reports
    }
}
