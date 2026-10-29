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
        if focus == .directionChange && !WorkReading.isBriefAssent(context.anchor?.novelText ?? "") { focus = .handoff }
        if focus == .progress && resultState != .behaviorReported { focus = resultState == .buildOnly ? .check : .handoff }
        let lastReported = references.last { $0.use == .result }?.quote ?? ""
        let notRun = #"(?i)\b(?:have not|haven't|not yet|has not|hasn't)\b.{0,35}\b(?:run|ran|rerun|re-run|tested|replayed|checked|verified)\b"#
        if focus == .progress && lastReported.range(of: notRun, options: .regularExpression) != nil { focus = .check }
        let human = references.filter { ref in context.sources.first { $0.id == ref.sourceID }?.role == "user" }
        let boundary = human.first { $0.sourceID != context.anchorID }
        let agents = references.filter { ref in context.sources.first { $0.id == ref.sourceID }?.role == "assistant" }
        let agent = agents.last
        let headline: String, account: String, step: String, practicalGoal: String
        practicalGoal = focus == .directionChange ? (boundary?.quote ?? goal) : goal
        switch focus {
        case .directionChange:
            headline = "Does this proposal fit your requirement?"
            account = "The agent proposed: “" + (agent?.quote ?? "a different approach") + "”. Compare that approach with the saved requirement above."
            step = "Keep the original requirement, or change it deliberately?"
        case .check:
            headline = "A useful checkpoint before moving on."
            account = agent.map { "The agent reports: “" + $0.quote + "”. The proposed check below connects that report back to the current goal." } ?? "The request leaves a concrete question worth settling."
            step = nextStep
        case .handoff:
            headline = "The handoff has a checkpoint you can come back to."
            account = "The request leaves investigation or execution with the agent. This checkpoint gives you a concrete way back into that work."
            step = nextStep
        case .progress:
            headline = "There’s a reported result to build on."
            let result = references.last { $0.use == .result } ?? references.last
            let speaker = context.sources.first { $0.id == result?.sourceID }?.role == "user" ? "You report" : "The agent reports"
            account = speaker + ": “" + (result?.quote ?? "a result") + "”. This is a saved report, with its source available below."
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
        return .init(focus: focus, goal: practicalGoal, headline: headline, account: account, nextStep: step, references: references)
    }
}
public struct WorkProposal: Codable, Sendable {
    public let focus: WorkFocus
    public let goal: String
    public let headline: String
    public let account: String
    public let nextStep: String
    public let references: [WorkReference]
    public init(focus: WorkFocus, goal: String, headline: String, account: String, nextStep: String, references: [WorkReference]) {
        self.focus = focus; self.goal = goal; self.headline = headline; self.account = account; self.nextStep = nextStep; self.references = references
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

    /// This is a literal, source-backed question about a named boundary, not a model verdict about intent.
    private static func literalBoundaryRule(_ proposal: WorkProposal, context: DecisionContext) -> String? {
        guard proposal.focus == .directionChange, Self.isBriefAssent(context.anchor?.novelText ?? ""),
              let boundary = proposal.references.first(where: { $0.use == .boundary }),
              let change = proposal.references.first(where: { $0.use == .change }),
              let a = context.sources.firstIndex(where: { $0.id == boundary.sourceID }),
              let b = context.sources.firstIndex(where: { $0.id == change.sourceID }),
              let c = context.sources.firstIndex(where: { $0.id == context.anchorID }), a < b, b < c,
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
        for agent in before.filter({ $0.role == "assistant" && $0.sessionID == context.sessionID }).suffix(3).reversed() {
            guard let index = before.firstIndex(where: { $0.id == agent.id }),
                  let boundary = before.prefix(index).last(where: { $0.role == "user" && $0.sessionID == context.sessionID && $0.origin != .reusedAgent }) else { continue }
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
        // Exact witness spans are checked against the actual model excerpt, never guessed or repaired.
        for reference in proposal.references {
            guard let source = context.sources.first(where: { $0.id == reference.sourceID }),
                  reference.quote.rangeOfCharacter(from: .alphanumerics) != nil, reference.quote.count <= 180,
                  String(source.text.prefix(source.role == "assistant" ? 650 : 1400)).contains(reference.quote),
                  (source.originalText ?? source.text).contains(reference.quote) else { return nil }
            if source.origin == .mixed && reference.sourceID == context.anchorID && !source.novelText.contains(reference.quote) { return nil }
        }
        let generated = [proposal.goal, proposal.headline, proposal.account, proposal.nextStep].joined(separator: " ")
        let personal = #"(?i)\b(cognitive decline|brain atrophy|sanity score|IQ|mental health)\b|\byou (?:are|were|seem|became|have become) (?:being steered|tired|disengaged|dependent|uncritical)|\byou (?:did not|didn't|never|failed to) (?:read|review|understand|think)|\byou (?:fully|clearly|definitely) understand"#
        guard generated.range(of: personal, options: .regularExpression) == nil else { return nil }
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
                  context.sources[a].role == "user", context.sources[a].origin != .reusedAgent,
                  context.sources[b].role == "assistant",
                  !context.sources[(a+1)..<c].contains(where: { $0.role == "user" && !Self.isBriefAssent($0.novelText) }), [a,b,c].allSatisfy({ context.sources[$0].sessionID == context.sessionID }),
                  (literalRule != nil || [boundary.sourceID, change.sourceID, context.anchorID].allSatisfy({ challenge.sourceIDs.contains($0) })) else { return nil }
            let value = [a,b].map { context.sources[$0].messageID + ":" + context.sources[$0].fingerprint }.joined(separator: "|")
            key = SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
        }
        if proposal.focus == .recurringIssue {
            let human = context.sources.filter { ids.contains($0.id) && $0.role == "user" && $0.origin != .reusedAgent && $0.sessionID == context.sessionID }
            guard Set(human.map(\.messageID)).count >= 2,
                  context.sources.contains(where: { ids.contains($0.id) && $0.role == "assistant" && $0.sessionID == context.sessionID }) else { return nil }
        }
        let canonical = proposal.references.map { reference in
            WorkReference(sourceID: context.sources.first { $0.id == reference.sourceID }!.messageID, quote: reference.quote, use: reference.use)
        }
        return Self(focus: proposal.focus, goal: proposal.goal, headline: proposal.headline, account: proposal.account, nextStep: proposal.nextStep, references: canonical, signalKey: key, boundaryRule: literalRule)
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
        return Self(id: UUID().uuidString, sessionID: context.sessionID, anchorMessageID: context.anchor?.messageID ?? "", inputDigest: context.inputDigest, previousID: previousID, createdAt: now, engine: engine,
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
        return .init(focus: focus, goal: goal, headline: headline, account: account, nextStep: nextStep, references: values)
    }
    public func respectingExplicitTopicChange(_ context: DecisionContext) -> Self {
        guard let anchor = context.anchor, references.allSatisfy({ ref in context.sources.contains { $0.id == ref.sourceID } }),
              anchor.novelText.range(of: #"(?i)\b(?:switch topics|separate issue|new topic)\b"#, options: .regularExpression) != nil else { return self }
        let refs: [WorkReference] = [.init(sourceID: anchor.id, quote: String(anchor.quote.prefix(160)), use: .intent), .init(sourceID: anchor.id, quote: String(anchor.quote.prefix(160)), use: .response)]
        return .init(focus: focus == .recurringIssue ? .check : focus, goal: goal, headline: "A new question worth settling.", account: "This request opens another topic. The earlier agent report does not settle this new question.", nextStep: nextStep, references: refs)
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
