import Foundation

extension DecisionDraft {
    /// Model-selected actions and references; visible language is compiled from their limited meaning.
    public static func grounded(context: DecisionContext, kind: DecisionKind, sourceIDs: [String], actions: DecisionActions? = nil) -> Self {
        let anchorIndex = context.sources.firstIndex { $0.id == context.anchorID } ?? context.sources.count
        let laterReply = context.sources.enumerated().contains { index, source in
            index > anchorIndex && source.sessionID == context.sessionID && source.role == "assistant" && sourceIDs.contains(source.id)
        }
        let goal = String((context.anchor?.quote ?? "Saved request").prefix(180))
        let summary: String
        let reason: String
        let alternative: String
        let unknown: String
        switch kind {
        case .evidenceRequest:
            summary = actions?.delegatesNextStep == true ? "You left the test to the agent and specified the check." : (laterReply ? "You asked for evidence; an agent reply is now in view." : "Your request set a concrete check.")
            reason = "This request sets an observable check and can leave execution to the agent. It does not record a passing result."
            alternative = "This could be routine checking or a response to an unresolved case. The wording alone does not establish why you asked."
            unknown = "The cited request does not verify an outcome. Read any agent report separately and add what you checked yourself."
        case .humanDirection:
            summary = actions?.delegatesNextStep == true ? "You left execution to the agent and set a direction." : (laterReply ? "Your message set a direction; the agent replied." : "Your message set or restated a direction.")
            reason = "Your saved words set or restate a boundary or choice. The original wording is below."
            alternative = "This may restate an existing boundary rather than introduce a new decision."
            unknown = "The wording does not establish whether the change was carried out, reviewed or understood."
        case .agentProposal:
            summary = "An agent proposal was followed by your assent."
            reason = "An agent message introduced an approach, followed by an assenting response. Your earlier intentions are not visible here."
            alternative = "The proposal may match a decision you had already made outside this conversation."
            unknown = "Your prior decision process and any review outside the saved exchange are not observed."
        case .delegation:
            summary = laterReply ? "You handed off a next step; the agent replied." : "Your message left a next step to the agent."
            reason = "The response leaves a next step to the agent. The record does not show what you reviewed before handing it off."
            alternative = "The same short approval could follow deliberate review or defer a check until later."
            unknown = "What you reviewed before or after the handoff is not established by the response."
        case .explanationRequest:
            summary = laterReply ? "You asked for an explanation; the agent replied." : "Your message requested an explanation."
            reason = "The saved wording asks to explain or clarify part of the work. The quote shows which part; whether it resolved the question needs a later report."
            alternative = "This could be learning, checking an existing understanding, or asking for clearer documentation."
            unknown = "Whether an explanation resolved the question requires later evidence or your own report."
        case .recurringIssue:
            summary = "A reported problem returned after an agent reply."
            reason = "Two reports appear to concern the same concrete problem after an agent reply. Check that the inputs and requirements match."
            alternative = "A similar symptom can come from a different input or requirement rather than the same unresolved fault."
            unknown = "The causal connection and whether the latest issue was resolved are not verified by these reports."
        case .outcomeReport:
            summary = "Your message reported what happened."
            reason = "Your message reports a result. It is shown as your report, with the available exchange."
            alternative = "The report may describe one tested case rather than the full behavior of the feature."
            unknown = "Independent verification and coverage beyond the reported case remain outside this reading."
        case .uncertain:
            summary = "The exchange needs your context before a firmer reading."
            reason = "This account needs more context. The source excerpts remain available for your own reading."
            alternative = "The same wording can serve different intentions or refer to context outside this saved exchange."
            unknown = "The missing intention, referent or outcome is not established by the available sources."
        }
        return .init(kind: kind, goal: goal, summary: summary, reason: reason, alternative: alternative, unknown: unknown, sourceIDs: sourceIDs)
    }
}
