import Foundation
import VernierCore

public enum WorkEvidenceChecks {
    private static func check(_ condition: Bool, _ message: String) throws { if !condition { throw CoreCheckFailure(description: message) } }
    private static func context(agent: String, human: String, perspectives: [DecisionPerspective] = []) -> DecisionContext {
        DecisionContext(sessionID: "evidence", anchorID: "S2", sources: [
            .init(id: "S0", messageID: "intent", sessionID: "evidence", role: "user", text: "Keep the import from creating duplicate contacts."),
            .init(id: "S1", messageID: "agent", sessionID: "evidence", role: "assistant", text: agent),
            .init(id: "S2", messageID: "human", sessionID: "evidence", role: "user", text: human)], perspectives: perspectives)
    }
    private static func revision(_ context: DecisionContext, state: WorkResultState = .proposed, focus: WorkFocus = .check, now: Date = Date()) -> DecisionRevision {
        let refs = context.sources.map { WorkReference(sourceID: $0.id, quote: String($0.quote.prefix(170)), use: $0.id == "S0" ? .intent : $0.role == "assistant" ? .change : .response) }
        let proposal = WorkProposal(focus: focus, goal: "Prevent duplicate contacts", headline: "Reconnect the check with the original case.", account: "The saved report is attributed to its speaker.", nextStep: "Import the same file twice and compare the contact counts.", references: refs, resultState: state)
        return DecisionRevision.contextual(context: context, proposal: proposal, challenge: .init(goalSupported: true, accountSupported: true, nextStepRelevant: true, directionMismatchSupported: false, sourceIDs: context.sources.map(\.id)), engine: "invented · work-12", now: now)
    }
    public static func provenance() async throws {
        let build = revision(context(agent: "The code builds. I have not replayed the import.", human: "Show the result for importing twice."), state: .behaviorReported)
        try check(build.reading?.evidenceStatus == .buildOnly, "A model's behavioral-result tag must not turn a build-only citation into a behavioral result")
        let actual = "I tested the contact importer with the same file twice and it created one contact."
        let human = revision(context(agent: "I added the import guard.", human: actual))
        try check(human.reading?.evidenceStatus == .humanReported, "A human's actual attempt/result must remain distinct from an agent claim even when the model misses its result tag")
        let exported = revision(context(agent: "I fixed UTF-8 handling.", human: "I exported the same accented names twice and compared the saved files. Both were correct."), state: .behaviorReported)
        try check(exported.reading?.evidenceStatus == .humanReported, "A concrete export and comparison must retain the human's result provenance")
        let copied = revision(context(agent: actual, human: "You said: " + actual + " Show that output."))
        try check(copied.reading?.evidenceStatus == .agentReported, "Copied agent success must not become a human-reported check")
        let hypothetical = revision(context(agent: "The build succeeds.", human: "If I tested the contact import twice, would I get one contact?"), state: .behaviorReported)
        try check(hypothetical.reading?.evidenceStatus == .buildOnly, "A hypothetical human test must not become a performed result")
        let unrun = revision(context(agent: "I have not tested the contact importer; no result is ready.", human: "Proceed with the implementation; I will check it later."))
        try check(unrun.reading?.evidenceStatus == .noResult, "An explicitly unrun check must remain open in the cited record")
        for text in ["The build has not passed.", "If the build passes, I will test the import."] {
            try check(revision(context(agent: text, human: "Show the actual result.")).reading?.evidenceStatus == .noResult,
                      "A negated or conditional build is not a reported passing build")
        }
        let report = DecisionPerspective(sessionID: "evidence", text: actual, anchorMessageID: "human")
        let reported = revision(context(agent: "I added the import guard.", human: "Proceed.", perspectives: [report]))
        try check(reported.reading?.evidenceStatus == .humanReported, "A perspective about this exact request must retain its human-report provenance")
        let wrong = DecisionPerspective(sessionID: "evidence", text: actual, anchorMessageID: "another-request")
        let unrelated = revision(context(agent: "I added the import guard.", human: "Proceed.", perspectives: [wrong]))
        try check(unrelated.reading?.evidenceStatus == .noResult, "A report about another request must not settle the current request")
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(human)) as! [String: Any]
        var oldReading = object["reading"] as! [String: Any]; oldReading.removeValue(forKey: "evidenceStatus"); object["reading"] = oldReading
        let old = try JSONDecoder().decode(DecisionRevision.self, from: JSONSerialization.data(withJSONObject: object))
        try check(old.reading?.evidenceStatus == nil && old.reading?.goal == human.reading?.goal, "Older saved readings must decode without inventing an outcome status")
        let context = context(agent: "The build succeeds.", human: "Show the original case.")
        let bad = WorkProposal(focus: .check, goal: "Prevent duplicate contacts", headline: "Your cognitive dysfunction score is 90", account: "A claim without evidence", nextStep: "Try the import.", references: context.sources.map { .init(sourceID: $0.id, quote: $0.quote, use: .response) }, resultState: .buildOnly)
        let challenge = WorkChallenge(goalSupported: true, accountSupported: true, nextStepRelevant: true, directionMismatchSupported: false, sourceIDs: context.sources.map(\.id))
        try check(WorkReading.validated(bad, challenge: challenge, context: context) == nil, "Source-valid text must not license an invented cognitive-health score")
        let bare = DecisionContext(sessionID: "evidence", anchorID: "S0", sources: [.init(id: "S0", messageID: "bare", sessionID: "evidence", role: "user", text: "Do it.")])
        let invented = WorkProposal(focus: .handoff, goal: "Retrieve a saved work item", headline: "A checkpoint", account: "A proposed goal", nextStep: "Identify the work.", references: [.init(sourceID: "S0", quote: "Do it.", use: .intent), .init(sourceID: "S0", quote: "Do it.", use: .response)], resultState: WorkResultState.none)
        try check(WorkReading.validated(invented, challenge: .init(goalSupported: true, accountSupported: true, nextStepRelevant: true, directionMismatchSupported: false, sourceIDs: ["S0"]), context: bare) == nil,
                  "Agreement and exact quotes cannot turn a lone assent into an invented practical goal")
    }
    public static func daySelection() async throws {
        let day = WorkDay(containing: Date()), base = day.start.addingTimeInterval(3600)
        let ctx = context(agent: "The build succeeds.", human: "Check importing twice.")
        let first = revision(ctx, now: base)
        let second = revision(ctx, now: base.addingTimeInterval(20))
        let current = WorkDayInsight.make(day: day, activeSessionIDs: ["evidence"], revisions: [first, second], currentIDs: [second.id])
        try check(current.count == 1 && current.first?.id == second.id && current.first?.historical == false, "A daily insight must deduplicate by conversation and use the current source-backed reading")
        try check(WorkDayInsight.make(day: day, activeSessionIDs: ["evidence"], revisions: [first], currentIDs: []).isEmpty, "A stale reading must not become a current recap")
        let future = revision(ctx, now: day.end.addingTimeInterval(60))
        let historical = WorkDayInsight.make(day: day, activeSessionIDs: ["evidence"], revisions: [first, future])
        try check(historical.count == 1 && historical.first?.id == first.id && historical.first?.historical == true, "Tomorrow's interpretation must not be presented as yesterday's account")
        let rejected = DecisionRevision.contextual(context: ctx, proposal: .init(focus: .check, goal: "Prevent duplicates", headline: "A check", account: "Unconfirmed", nextStep: "Import twice.", references: []), challenge: .init(goalSupported: false, accountSupported: false, nextStepRelevant: false, directionMismatchSupported: false, sourceIDs: []), engine: "invented · work-12", now: base.addingTimeInterval(40))
        try check(WorkDayInsight.make(day: day, activeSessionIDs: ["evidence"], revisions: [first, rejected]).isEmpty, "A newer withheld reading must supersede an older accepted one instead of reviving it")
        try check(WorkDayInsight.make(day: day, activeSessionIDs: ["other-project"], revisions: [first]).isEmpty, "A reading from an inactive project must not enter another day's recap")
    }
}
