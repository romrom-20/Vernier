import Foundation
import CryptoKit

public enum WorkFocus: String, Codable, CaseIterable, Sendable {
    case directionChange = "direction_change", check, recurringIssue = "recurring_issue", handoff, progress, none
    public var label: String {
        switch self {
        case .directionChange: "A direction to check"
        case .check: "A useful next check"
        case .recurringIssue: "Something came back"
        case .handoff: "The next step you handed over"
        case .progress: "What moved forward"
        case .none: "The current picture"
        }
    }
}
public enum WorkReferenceUse: String, Codable, Sendable { case intent, change, boundary, response, result }
public struct WorkReference: Codable, Sendable {
    public let sourceID: String
    public let quote: String
    public let use: WorkReferenceUse
    public init(sourceID: String, quote: String, use: WorkReferenceUse) { self.sourceID = sourceID; self.quote = quote; self.use = use }
}
/// The model supplies a goal, a concrete checkpoint and literal evidence; the app composes the account.
public enum WorkResultState: String, Codable, Sendable { case behaviorReported = "behavior_reported", buildOnly = "build_only", proposed = "proposed_or_in_progress", none }
public struct WorkFrame: Codable, Sendable {
    public let resultState: WorkResultState
    public let focus: WorkFocus
    public let goal: String
    public let nextStep: String
    public let references: [WorkReference]
    public init(resultState: WorkResultState, focus: WorkFocus, goal: String, nextStep: String, references: [WorkReference]) {
        self.resultState = resultState; self.focus = focus; self.goal = goal; self.nextStep = nextStep; self.references = references
    }
    public func proposal(in context: DecisionContext) -> WorkProposal {
        var focus = self.focus
        var references = self.references
        var recalledGoal: WorkReference?
        if focus != .directionChange && WorkReading.asksAboutEarlierStatement(context) {
            recalledGoal = references.first { ref in
                [.intent, .boundary].contains(ref.use) && context.sources.contains { $0.id == ref.sourceID && $0.role == "user" && context.recalledMessageIDs.contains($0.messageID) && $0.novelText.contains(ref.quote) }
            }
            // A reminder can quote one unambiguous literal earlier declaration.
            // It is labelled historical, never promoted to current permission.
            if recalledGoal == nil, references.count < 5, context.anchor?.novelText.range(of: #"(?i)\b(?:remind|remember)\b|what.{0,30}\b(?:chose|choose|decided)\b"#, options: .regularExpression) != nil {
                let choices = context.sources.filter {
                    $0.role == "user" && context.recalledMessageIDs.contains($0.messageID) && $0.origin != .reusedAgent &&
                    $0.novelText.range(of: #"(?i)^\s*I (?:choose|chose|have chosen|selected)\b"#, options: .regularExpression) != nil && !$0.novelText.contains("?")
                }
                if choices.count == 1, let source = choices.first, let witness = WorkWitnessPacket(context: context).witnesses.first(where: { $0.sourceID == source.id }) {
                    let ref = WorkReference(sourceID: source.id, quote: witness.quote, use: .intent)
                    references.append(ref); recalledGoal = ref
                }
            }
        }
        if focus == .directionChange && !WorkReading.isBriefAssent(context.anchor?.novelText ?? "") { focus = .handoff }
        if focus == .progress && resultState != .behaviorReported { focus = resultState == .buildOnly ? .check : .handoff }
        let lastReported = references.last { $0.use == .result }?.quote ?? ""
        let notRun = #"(?i)\b(?:have not|haven't|not yet|has not|hasn't)\b.{0,35}\b(?:run|ran|rerun|re-run|tested|replayed|checked|verified)\b"#
        if focus == .progress && lastReported.range(of: notRun, options: .regularExpression) != nil { focus = .check }
        let human = references.filter { ref in context.sources.first { $0.id == ref.sourceID }?.role == "user" }
        let boundary = human.first { $0.sourceID != context.anchorID }
        let agents = references.filter { ref in context.sources.first { $0.id == ref.sourceID }?.role == "assistant" }
        let agent = agents.last
        let reports = WorkEvidenceStatus.reports(references: references, context: context)
        let latestReport = reports.last { [.humanReported, .agentReported].contains($0.status) }
        let humanReport = reports.last { $0.status == .humanReported }
        let agentReport = reports.last { $0.status == .agentReported }
        if focus == .recurringIssue && !WorkReading.hasRecurrenceContext(references, context: context) {
            // A requirement followed by a first result is not two failure
            // reports. Keep the source-backed result or question instead.
            let asks = context.anchor?.novelText.range(of: #"(?i)\?|\b(?:explain|compare|why|how|investigate|show|check)\b"#, options: .regularExpression) != nil
            focus = resultState == .behaviorReported && humanReport?.sourceID == context.anchorID && !asks ? .progress : .check
        }
        let separateReports: String? = humanReport.flatMap { human in
            agentReport.map { agent in
                "The agent reports: “" + agent.quote + "”. You report: “" + human.quote + "”. These are separate saved reports; neither has been independently verified here."
            }
        }
        let headline: String, account: String, step: String, practicalGoal: String
        let describesConversation = goal.range(of: #"(?i)^\s*(?:the\s+)?(?:user|human) is (?:reporting|experiencing)\b"#, options: .regularExpression) != nil
        let suppliedGoal = describesConversation ? human.first(where: { ref in
            ref.use == .intent && ref.sourceID != context.anchorID && ref.quote.count <= 160 &&
                context.sources.prefix(while: { $0.id != context.anchorID }).contains(where: {
                    $0.id == ref.sourceID && $0.sessionID == context.sessionID && $0.origin != .reusedAgent && $0.novelText.contains(ref.quote) && !context.recalledMessageIDs.contains($0.messageID)
                })
        })?.quote : nil
        // Preserve an already-cited human request rather than a model's
        // description of the conversation (which can invert success/failure).
        practicalGoal = focus == .directionChange ? (boundary?.quote ?? goal) : (recalledGoal.map { WorkReading.earlierStatementGoal($0.quote) } ?? suppliedGoal ?? goal)
        switch focus {
        case .directionChange:
            headline = "Does this proposal fit your requirement?"
            account = "The agent proposed: “" + (agent?.quote ?? "a different approach") + "”. Compare that approach with the saved requirement above."
            step = "Keep the original requirement, or change it deliberately?"
        case .check:
            headline = "A useful checkpoint before moving on."
            account = separateReports ?? latestReport.map {
                ($0.status == .humanReported ? "You report: “" : "The agent reports: “") + $0.quote + "”. The checkpoint below relates this report to the current goal."
            } ?? agent.map { "The agent reports: “" + $0.quote + "”. The proposed check below connects that report back to the current goal." } ?? "The request leaves a concrete question worth settling."
            step = nextStep
        case .handoff:
            headline = "The handoff has a checkpoint you can come back to."
            account = "The request leaves investigation or execution with the agent. This checkpoint gives you a concrete way back into that work."
            step = nextStep
        case .progress:
            headline = "There’s a reported result to build on."
            let result = latestReport.map { WorkReference(sourceID: $0.sourceID, quote: $0.quote, use: .result) } ?? references.last { $0.use == .result } ?? references.last
            let speaker = ["user", "user_report"].contains(context.sources.first { $0.id == result?.sourceID }?.role ?? "") ? "You report" : "The agent reports"
            account = separateReports ?? (speaker + ": “" + (result?.quote ?? "a result") + "”. This is a saved report, with its source available below.")
            step = "Keep this exact case as a regression check when the behavior changes again."
        case .recurringIssue:
            headline = "A previously reported problem came back."
            account = "An earlier report was “" + (boundary?.quote ?? "a failure") + "”. Your later report was “" + (human.last?.quote ?? "a similar failure") + "”. Check whether they concern the same input and requirement."
            step = nextStep
        case .none:
            headline = "No specific check is ready from this excerpt."
            account = "The available context did not establish a concrete next check. The original messages remain available."
            step = nextStep
        }
        return .init(focus: focus, goal: practicalGoal, headline: headline, account: account, nextStep: step, references: references, resultState: resultState, recalledGoalSourceID: recalledGoal?.sourceID)
    }
}
public struct WorkProposal: Codable, Sendable {
    public let focus: WorkFocus
    public let goal: String
    public let headline: String
    public let account: String
    public let nextStep: String
    public let references: [WorkReference]
    public let resultState: WorkResultState?
    public let recalledGoalSourceID: String?
    public init(focus: WorkFocus, goal: String, headline: String, account: String, nextStep: String, references: [WorkReference], resultState: WorkResultState? = nil, recalledGoalSourceID: String? = nil) {
        self.focus = focus; self.goal = goal; self.headline = headline; self.account = account; self.nextStep = nextStep; self.references = references; self.resultState = resultState
        self.recalledGoalSourceID = recalledGoalSourceID
    }
}
public struct WorkChallenge: Codable, Sendable {
    public let goalSupported: Bool
    public let accountSupported: Bool
    public let nextStepRelevant: Bool
    public let directionMismatchSupported: Bool
    public let sourceIDs: [String]
    public init(goalSupported: Bool, accountSupported: Bool, nextStepRelevant: Bool, directionMismatchSupported: Bool, sourceIDs: [String]) {
        self.goalSupported = goalSupported; self.accountSupported = accountSupported; self.nextStepRelevant = nextStepRelevant; self.directionMismatchSupported = directionMismatchSupported; self.sourceIDs = sourceIDs
    }
}
/// A contextual interpretation, never a capability assessment or verified outcome.
public struct WorkReading: Codable, Sendable {
    public let focus: WorkFocus
    public let goal: String
    public let headline: String
    public let account: String
    public let nextStep: String
    public let references: [WorkReference]
    public let signalKey: String?
    public let boundaryRule: String?
    /// Optional for decoding pre-v0.13 readings; it is never a health or understanding score.
    public let evidenceStatus: WorkEvidenceStatus?
    /// Absent in older saved readings. Source IDs use canonical message IDs,
    /// exactly as references do; no database migration is needed.
    public let evidenceReports: [WorkEvidenceReport]?
    public let recalledGoalSourceID: String?
    public var goalLabel: String { recalledGoalSourceID != nil ? "Earlier statement you asked about" : focus == .directionChange ? "Earlier requirement" : "Likely goal" }
    public var hasBothReporters: Bool {
        let statuses = Set((evidenceReports ?? []).map(\.status))
        return statuses.contains(.humanReported) && statuses.contains(.agentReported)
    }
    public var evidenceLabel: String {
        hasBothReporters ? "You and AI reported checks" : (evidenceStatus ?? .unknown).label
    }
    public var evidenceExplanation: String {
        hasBothReporters ? "These are separate saved reports from you and the agent. They may describe different cases; neither report independently verifies the other." : (evidenceStatus ?? .unknown).explanation
    }
    /// A cue is limited to brief, recognizable assent; longer explanations are never treated as surrender.
    public static func isBriefAssent(_ text: String) -> Bool {
        let words = text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        guard !words.isEmpty, words.count <= 12 else { return false }
        let normalized = words.joined(separator: " ")
        let pattern = #"^(?:(?:okay|ok|yes|sure|fine|right|agreed|great|sounds good|that works) ?)?(?:please ?)?(?:(?:go ahead|proceed|do it|do that|use it|use that)(?: with (?:that|this)(?: approach| plan| change)?)?)?$"#
        return normalized.range(of: pattern, options: .regularExpression) != nil
    }
    public static let intentionalResponse = "I intentionally accepted this direction change."
    public static let checkResponse = "I want to check this direction change before continuing."
    static func asksAboutEarlierStatement(_ context: DecisionContext) -> Bool {
        guard context.memoryRecall != nil, let anchor = context.anchor else { return false }
        return anchor.novelText.range(of: #"(?i)\b(?:earlier|original|agreed|previous|remember|remind)\b"#, options: .regularExpression) != nil
    }
    static func earlierStatementGoal(_ quote: String) -> String {
        "Earlier: “" + String(quote.prefix(140)) + (quote.count > 140 ? "…" : "") + "”"
    }
    /// Limited topic guard for a model's proposed direction comparison when
    /// recalled material is present. It is not a semantic equivalence test.
    public static func sharesDirectionTopic(_ boundary: String, _ proposal: String) -> Bool {
        let stop = Set("this that with from have make work does again still please should there their when then only same been what your agent keep before after just current change text request code leave example propose using will would could must without requirement earlier original".split(separator: " ").map(String.init))
        func terms(_ text: String) -> Set<String> {
            Set(text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count >= 4 && !stop.contains($0) }.map { $0.hasSuffix("ies") ? String($0.dropLast(3)) + "y" : $0.count > 4 && $0.hasSuffix("s") ? String($0.dropLast()) : $0 })
        }
        return !terms(boundary).isDisjoint(with: terms(proposal))
    }

    /// Admission guard, not proof that two reports concern the same fault.
    /// In particular, a requested behavior is not a prior observed failure.
    static func hasRecurrenceContext(_ references: [WorkReference], context: DecisionContext) -> Bool {
        guard let anchor = context.sources.firstIndex(where: { $0.id == context.anchorID }),
              references.contains(where: { $0.sourceID == context.anchorID }) else { return false }
        let reports = WorkEvidenceStatus.reports(references: references, context: context)
        let notObserved = #"(?i)\?|\b(?:if I|if we|will|would|might|have not|haven't|not yet|I plan|I intend)\b|\b(?:assistant|agent|you) (?:said|wrote|reported)\b"#
        guard reports.contains(where: { $0.sourceID == context.anchorID && $0.status == .humanReported }) ||
                context.sources[anchor].novelText.range(of: notObserved, options: .regularExpression) == nil else { return false }
        let requirement = #"(?i)\b(?:must|should|shall|need to|want to|please|ensure)\b|^\s*(?:keep|make|prevent|add|remove|import|export|open|use|do not|don't)\b"#
        return references.contains { ref in
            guard let earlier = context.sources.firstIndex(where: { $0.id == ref.sourceID }), earlier < anchor,
                  context.sources[earlier].role == "user", context.sources[earlier].sessionID == context.sessionID,
                  context.sources[earlier].origin != .reusedAgent,
                  reports.contains(where: { $0.sourceID == ref.sourceID && $0.status == .humanReported }) ||
                    (!ref.quote.contains("?") && ref.quote.range(of: requirement, options: .regularExpression) == nil) else { return false }
            return references.contains { agent in
                guard let index = context.sources.firstIndex(where: { $0.id == agent.sourceID }) else { return false }
                return earlier < index && index < anchor && context.sources[index].role == "assistant" && context.sources[index].sessionID == context.sessionID
            }
        }
    }

    /// This is a literal, source-backed question about a named boundary, not a model verdict about intent.
    private static func literalBoundaryRule(_ proposal: WorkProposal, context: DecisionContext) -> String? {
        guard proposal.focus == .directionChange, Self.isBriefAssent(context.anchor?.novelText ?? ""),
              let boundary = proposal.references.first(where: { $0.use == .boundary }),
              let change = proposal.references.first(where: { $0.use == .change }),
              let a = context.sources.firstIndex(where: { $0.id == boundary.sourceID }),
              let b = context.sources.firstIndex(where: { $0.id == change.sourceID }),
              let c = context.sources.firstIndex(where: { $0.id == context.anchorID }), a < b, b < c,
              context.memoryRecall == nil || sharesDirectionTopic(boundary.quote, change.quote),
              !context.recalledMessageIDs.contains(context.sources[a].messageID), !context.recalledMessageIDs.contains(context.sources[b].messageID),
              !context.hasMissingHumanContext(between: context.sources[a].messageID, and: context.sources[c].messageID),
              !context.sources[(a+1)..<c].contains(where: { $0.role == "user" && !Self.isBriefAssent($0.novelText) }) else { return nil }
        let compiled = WorkFrame(resultState: .proposed, focus: .directionChange, goal: boundary.quote, nextStep: "", references: proposal.references).proposal(in: context)
        guard compiled.goal == proposal.goal, compiled.headline == proposal.headline, compiled.account == proposal.account, compiled.nextStep == proposal.nextStep else { return nil }
        func matches(_ pattern: String, _ value: String) -> Bool { value.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil }
        let prior = boundary.quote, next = change.quote
        guard !matches(#"\b(?:not|no|won't|without)\b.{0,25}\b(?:hosted|cloud|paid|add|drop|delete)\b"#, next) else { return nil }
        if matches(#"\b(?:no|not|without)\b.{0,25}\bdependenc(?:y|ies)\b"#, prior), matches(#"\b(?:add|install|introduce|use)\b.{0,40}\b(?:package|dependency)\b"#, next) { return "no-dependency-versus-package" }
        if matches(#"\b(?:keep|preserve|retain)\b.{0,35}\b(?:edits|records|data)\b"#, prior), matches(#"\b(?:drop|dropping|delete|discard|wipe)\b.{0,30}\b(?:table|edits|data|records)\b"#, next) { return "preserve-data-versus-replace" }
        if matches(#"\b(?:without|no|not)\b.{0,25}\bpaid\b"#, prior), matches(#"\b(?:add|adding|use|using|introduce)\b.{0,35}\bpaid\b"#, next) { return "no-paid-service-versus-paid-api" }
        if matches(#"\b(?:do not|don't|never)\b.{0,15}\bupload\b|\b(?:must|should) stay on (?:this|the) (?:machine|device)\b"#, prior), matches(#"\b(?:send|sending|upload)\b.{0,60}\b(?:external|provider|remote|server)\b"#, next) { return "keep-on-device-versus-upload" }
        if matches(#"\b(?:offline|local.only|on.device)\b"#, prior), matches(#"\b(?:hosted|cloud|remote|server)\b"#, next) { return "offline-versus-hosted" }
        return nil
    }
    /// Five narrow literal conflicts can raise a question without asking an LLM to judge private intentions.
    public static func literalCandidate(in context: DecisionContext) -> WorkFrame? {
        guard let anchor = context.anchor, Self.isBriefAssent(anchor.novelText), anchor.origin != .reusedAgent,
              let end = context.sources.firstIndex(where: { $0.id == anchor.id }) else { return nil }
        let before = Array(context.sources.prefix(end))
        for agent in before.filter({ $0.role == "assistant" && $0.sessionID == context.sessionID && !context.recalledMessageIDs.contains($0.messageID) }).suffix(3).reversed() {
            guard let index = before.firstIndex(where: { $0.id == agent.id }),
                  let boundary = before.prefix(index).last(where: { $0.role == "user" && $0.sessionID == context.sessionID && $0.origin != .reusedAgent && !context.recalledMessageIDs.contains($0.messageID) }),
                  !context.hasMissingHumanContext(between: boundary.messageID, and: anchor.messageID) else { continue }
            let refs: [WorkReference] = [.init(sourceID: boundary.id, quote: String(boundary.quote.prefix(100)), use: .boundary), .init(sourceID: agent.id, quote: String(agent.quote.prefix(100)), use: .change), .init(sourceID: anchor.id, quote: String(anchor.quote.prefix(100)), use: .response)]
            let frame = WorkFrame(resultState: .proposed, focus: .directionChange, goal: refs[0].quote, nextStep: "", references: refs)
            if literalBoundaryRule(frame.proposal(in: context), context: context) != nil { return frame }
        }
        return nil
    }
    public static func validated(_ proposal: WorkProposal, challenge: WorkChallenge, context: DecisionContext) -> Self? {
        let literalRule = literalBoundaryRule(proposal, context: context)
        guard (literalRule != nil || (challenge.goalSupported && challenge.accountSupported && challenge.nextStepRelevant)),
              !proposal.goal.isEmpty, proposal.goal.count <= 160, !proposal.headline.isEmpty, proposal.headline.count <= 110,
              !proposal.account.isEmpty, proposal.account.count <= 620, !proposal.nextStep.isEmpty, proposal.nextStep.count <= 240,
              (2...7).contains(proposal.references.count) else { return nil }
        let known = Set(context.sources.map(\.id)), ids = Set(proposal.references.map(\.sourceID))
        guard ids.contains(context.anchorID), ids.isSubset(of: known),
              (literalRule != nil || (challenge.sourceIDs.contains(context.anchorID) && Set(challenge.sourceIDs).isSubset(of: known) && ids.isSubset(of: Set(challenge.sourceIDs)))),
              let anchor = context.anchor, anchor.role == "user", anchor.origin != .reusedAgent else { return nil }
        // A bare assent with no substantive surrounding record cannot support an invented goal.
        let bare = #"(?i)^\s*(?:do it|go ahead|proceed|continue|ok|okay|yes|sure)[.!\s]*$"#
        guard context.sources.contains(where: { $0.novelText.rangeOfCharacter(from: .alphanumerics) != nil && $0.novelText.range(of: bare, options: .regularExpression) == nil }) else { return nil }
        // Exact witness spans are checked against the actual model excerpt, never guessed or repaired.
        for reference in proposal.references {
            guard let source = context.sources.first(where: { $0.id == reference.sourceID }),
                  reference.quote.rangeOfCharacter(from: .alphanumerics) != nil, reference.quote.count <= 180,
                  String(source.text.prefix(source.role == "assistant" ? 650 : 1400)).contains(reference.quote),
                  (source.originalText ?? source.text).contains(reference.quote) else { return nil }
            if source.origin == .mixed && reference.sourceID == context.anchorID && !source.novelText.contains(reference.quote) { return nil }
        }
        if let id = proposal.recalledGoalSourceID {
            guard Self.asksAboutEarlierStatement(context), let ref = proposal.references.first(where: { $0.sourceID == id && [.intent, .boundary].contains($0.use) }),
                  context.sources.contains(where: { $0.id == id && $0.role == "user" && $0.origin != .reusedAgent && context.recalledMessageIDs.contains($0.messageID) && $0.novelText.contains(ref.quote) }),
                  proposal.goal == Self.earlierStatementGoal(ref.quote) else { return nil }
        }
        let generated = [proposal.goal, proposal.headline, proposal.account, proposal.nextStep].joined(separator: " ")
        let personal = #"(?i)\b(cognitive decline|brain atrophy|sanity score|IQ|mental health|cognitive dysfunction score|brain strain score)\b|\byou (?:are|were|seem|became|have become|have) (?:being steered|tired|disengaged|dependent|uncritical)|\byou (?:did not|didn't|never|failed to) (?:read|review|understand|think)|\byou (?:have|show|are showing|suffer from) (?:cognitive dysfunction|cognitive impairment|dementia|burnout)\b|\byou (?:fully|clearly|definitely) understand"#
        guard generated.range(of: personal, options: .regularExpression) == nil else { return nil }
        let privateUnderstanding = #"(?i)\b(?:verify|determine|assess|measure|test|prove|confirm|check)\b.{0,35}\b(?:you|your|(?:the\s+)?(?:user|human)(?:['’]s)?)\b.{0,30}\b(?:understand\w*|comprehen\w*)\b"#
        guard generated.range(of: privateUnderstanding, options: .regularExpression) == nil else { return nil }
        let evidenceStatus = WorkEvidenceStatus.classify(proposal, context: context)
        if proposal.resultState != nil && proposal.focus == .progress && ![.humanReported, .agentReported].contains(evidenceStatus) { return nil }
        var key: String?
        if proposal.focus == .directionChange {
            // An ambient cue needs an earlier human boundary, an intervening agent proposal and this human response.
            guard (literalRule != nil || challenge.directionMismatchSupported), Self.isBriefAssent(anchor.novelText),
                  let boundary = proposal.references.first(where: { reference in
                      [.boundary, .intent].contains(reference.use) && context.sources.first(where: { $0.id == reference.sourceID })?.role == "user" && reference.sourceID != context.anchorID
                  }),
                  let change = proposal.references.first(where: { $0.use == .change }),
                  proposal.references.contains(where: { $0.use == .response && $0.sourceID == context.anchorID }),
                  let a = context.sources.firstIndex(where: { $0.id == boundary.sourceID }),
                  let b = context.sources.firstIndex(where: { $0.id == change.sourceID }),
                  let c = context.sources.firstIndex(where: { $0.id == context.anchorID }), a < b, b < c,
                  context.memoryRecall == nil || Self.sharesDirectionTopic(boundary.quote, change.quote),
                  context.sources[a].role == "user", context.sources[a].origin != .reusedAgent,
                  context.sources[b].role == "assistant",
                  !context.recalledMessageIDs.contains(context.sources[a].messageID), !context.recalledMessageIDs.contains(context.sources[b].messageID),
                  !context.hasMissingHumanContext(between: context.sources[a].messageID, and: context.sources[c].messageID),
                  !context.sources[(a+1)..<c].contains(where: { $0.role == "user" && !Self.isBriefAssent($0.novelText) }), [a,b,c].allSatisfy({ context.sources[$0].sessionID == context.sessionID }),
                  (literalRule != nil || [boundary.sourceID, change.sourceID, context.anchorID].allSatisfy({ challenge.sourceIDs.contains($0) })) else { return nil }
            let value = [a,b].map { context.sources[$0].messageID + ":" + context.sources[$0].fingerprint }.joined(separator: "|")
            key = SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
        }
        if proposal.focus == .recurringIssue {
            let human = context.sources.filter { ids.contains($0.id) && $0.role == "user" && $0.origin != .reusedAgent && $0.sessionID == context.sessionID }
            guard Self.hasRecurrenceContext(proposal.references, context: context), Set(human.map(\.messageID)).count >= 2,
                  context.sources.contains(where: { ids.contains($0.id) && $0.role == "assistant" && $0.sessionID == context.sessionID }) else { return nil }
        }
        let canonical = proposal.references.map { reference in
            WorkReference(sourceID: context.sources.first { $0.id == reference.sourceID }!.messageID, quote: reference.quote, use: reference.use)
        }
        let reports = evidenceStatus == .unknown ? [] : WorkEvidenceStatus.reports(references: proposal.references, context: context).map { report in
            WorkEvidenceReport(sourceID: context.sources.first { $0.id == report.sourceID }!.messageID, quote: report.quote, status: report.status)
        }
        return Self(focus: proposal.focus, goal: proposal.goal, headline: proposal.headline, account: proposal.account, nextStep: proposal.nextStep, references: canonical, signalKey: key, boundaryRule: literalRule, evidenceStatus: evidenceStatus, evidenceReports: reports, recalledGoalSourceID: proposal.recalledGoalSourceID.flatMap { id in context.sources.first { $0.id == id }?.messageID })
    }
}

extension DecisionRevision {
    public static func contextual(context: DecisionContext, proposal: WorkProposal, challenge: WorkChallenge, engine: String, previousID: String? = nil, now: Date = Date()) -> Self {
        let reading = WorkReading.validated(proposal, challenge: challenge, context: context)
        let ids = Set(reading?.references.map(\.sourceID) ?? [context.anchor?.messageID ?? ""])
        let evidence = context.sources.filter { ids.contains($0.messageID) }.map { source in
            let witness = reading?.references.first { $0.sourceID == source.messageID }?.quote ?? source.quote
            return DecisionEvidence(messageID: source.messageID, sessionID: source.sessionID, role: source.role, origin: source.origin, quote: witness, fingerprint: source.fingerprint)
        }
        return Self(memoryRecall: context.memoryRecall, id: UUID().uuidString, sessionID: context.sessionID, anchorMessageID: context.anchor?.messageID ?? "", inputDigest: context.inputDigest, previousID: previousID, createdAt: now, engine: engine,
                    kind: reading?.focus == .recurringIssue ? .recurringIssue : .uncertain, status: reading == nil ? .unknown : .tentative, actions: nil,
                    goal: reading?.goal ?? "", summary: reading?.headline ?? "No specific check is ready yet.",
                    reason: reading?.account ?? "The local reading did not pass its source or meaning checks.",
                    alternative: "This is an interpretation of saved work; context outside this excerpt may change it.", unknown: "The saved conversation does not establish what you reviewed or understood elsewhere.",
                    check: reading?.boundaryRule.map { "The app’s literal boundary rule (" + $0 + ") matched these exact source spans. This asks which requirement to keep; it does not establish intent or surrender. The model challenge can disagree and is not independent proof." } ?? "A separate model pass checked the goal, account and proposed next step. Exact source spans and reference roles were checked by the app. This is still a tentative interpretation.", evidence: evidence,
                    loadedMessages: context.loadedMessages, storedMessages: context.storedMessages, relatedMessageCounts: context.relatedMessageCounts, reading: reading)
    }
    public func directionAcknowledged(by reports: [DecisionPerspective]) -> Bool {
        reports.contains { $0.sessionID == sessionID && ($0.anchorMessageID == anchorMessageID || (reading?.signalKey != nil && $0.signalKey == reading?.signalKey)) && [WorkReading.intentionalResponse, WorkReading.checkResponse].contains($0.text) }
    }
}


extension WorkProposal {
    /// Supply real neighboring context for the critic. Unknown references or quotations remain invalid.
    public func withWitnessContext(_ context: DecisionContext) -> Self {
        guard references.allSatisfy({ reference in context.sources.contains { $0.id == reference.sourceID } }) else { return self }
        var values = references
        if let anchor = context.anchor, !values.contains(where: { $0.sourceID == anchor.id }) {
            values.append(.init(sourceID: anchor.id, quote: String(anchor.quote.prefix(160)), use: .response))
        }
        if focus == .directionChange, let index = context.sources.firstIndex(where: { $0.id == context.anchorID }),
           let agent = context.sources.prefix(index).last(where: { $0.role == "assistant" && $0.sessionID == context.sessionID }),
           !values.contains(where: { $0.sourceID == agent.id && $0.use == .change }) {
            values.append(.init(sourceID: agent.id, quote: String(agent.quote.prefix(160)), use: .change))
        }
        if WorkReading.isBriefAssent(context.anchor?.novelText ?? ""), !values.contains(where: { ref in ref.sourceID != context.anchorID && context.sources.first(where: { $0.id == ref.sourceID })?.role == "user" }),
           let index = context.sources.firstIndex(where: { $0.id == context.anchorID }), let earlier = context.sources.prefix(index).last(where: { $0.role == "user" && $0.sessionID == context.sessionID && $0.origin != .reusedAgent }) {
            values.append(.init(sourceID: earlier.id, quote: String(earlier.quote.prefix(100)), use: .intent))
        }
        return .init(focus: focus, goal: goal, headline: headline, account: account, nextStep: nextStep, references: values, resultState: resultState, recalledGoalSourceID: recalledGoalSourceID)
    }
    public func respectingExplicitTopicChange(_ context: DecisionContext) -> Self {
        guard let anchor = context.anchor, references.allSatisfy({ ref in context.sources.contains { $0.id == ref.sourceID } }),
              anchor.novelText.range(of: #"(?i)\b(?:switch topics|separate issue|new topic)\b"#, options: .regularExpression) != nil else { return self }
        let refs: [WorkReference] = [.init(sourceID: anchor.id, quote: String(anchor.quote.prefix(160)), use: .intent), .init(sourceID: anchor.id, quote: String(anchor.quote.prefix(160)), use: .response)]
        return .init(focus: focus == .recurringIssue || focus == .progress ? .check : focus, goal: goal, headline: "A new question worth settling.", account: "This request asks about another topic. The cited words identify the current question; no outcome is established here.", nextStep: nextStep, references: refs, resultState: WorkResultState.none)
    }
}


extension WorkReading {
    public var displayTitle: String {
        if focus == .check || focus == .handoff { return nextStep }
        guard focus == .directionChange else { return headline }
        switch boundaryRule {
        case "offline-versus-hosted": return "Keep processing offline, or use a hosted service?"
        case "no-dependency-versus-package": return "Keep the existing tools, or add a dependency?"
        case "preserve-data-versus-replace": return "Preserve local data, or replace its table?"
        case "no-paid-service-versus-paid-api": return "Keep this free of paid services, or add a paid API?"
        case "keep-on-device-versus-upload": return "Keep this data on the device, or send it outside?"
        default: return "Is this new approach the direction you want?"
        }
    }
}
