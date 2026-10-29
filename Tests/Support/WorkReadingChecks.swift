import Foundation
import VernierCore

public enum WorkReadingChecks {
    private static func check(_ value: @autoclosure () throws -> Bool, _ detail: String) throws {
        if try !value() { throw CoreCheckFailure(description: detail) }
    }
    public static func grounding() async throws {
        let sources: [DecisionSource] = [
            .init(id: "S0", messageID: "boundary", sessionID: "synthetic", role: "user", text: "Search must stay offline. No query may leave this device.", fingerprint: "boundary-v1"),
            .init(id: "S1", messageID: "proposal", sessionID: "synthetic", role: "assistant", text: "I recommend sending the query to a hosted matching API.", fingerprint: "proposal-v1"),
            .init(id: "S2", messageID: "response", sessionID: "synthetic", role: "user", text: "Okay, go ahead.", fingerprint: "response-v1")]
        let context = DecisionContext(sessionID: "synthetic", anchorID: "S2", sources: sources)
        let packet = WorkWitnessPacket(context: context)
        try check(Set(packet.witnesses.map(\.id)).count == packet.witnesses.count && packet.witnesses.allSatisfy { span in context.sources.first { $0.id == span.sourceID }!.text.contains(span.quote) }, "Selectable witnesses manufactured or duplicated source spans")
        let short = DecisionContext(sessionID: "synthetic", anchorID: "S2", sources: [sources[0], sources[1], .init(id: "S2", messageID: "short", sessionID: "synthetic", role: "user", text: "No.")])
        try check(WorkWitnessPacket(context: short).witnesses.contains { $0.quote == "No." }, "The witness packet discarded a short but meaningful human response")
        let refs = [WorkReference(sourceID: "S0", quote: "Search must stay offline.", use: .boundary), .init(sourceID: "S1", quote: "sending the query to a hosted matching API", use: .change), .init(sourceID: "S2", quote: "Okay, go ahead.", use: .response)]
        func proposal(_ focus: WorkFocus = .directionChange, references: [WorkReference]? = nil, headline: String = "The proposed plan sends queries off the device.") -> WorkProposal {
            .init(focus: focus, goal: "Keep search working offline", headline: headline, account: "An offline boundary was followed by a hosted API proposal and a brief approval.", nextStep: "Should queries leave the device, or should the original offline requirement stay?", references: references ?? refs)
        }
        let yes = WorkChallenge(goalSupported: true, accountSupported: true, nextStepRelevant: true, directionMismatchSupported: true, sourceIDs: ["S0", "S1", "S2"])
        let accepted = WorkReading.validated(proposal(), challenge: yes, context: context)
        try check(accepted?.signalKey != nil && accepted?.references.map(\.sourceID) == ["boundary", "proposal", "response"], "A supported cue lost canonical source references")
        let rejected = WorkChallenge(goalSupported: true, accountSupported: true, nextStepRelevant: true, directionMismatchSupported: false, sourceIDs: ["S0", "S1", "S2"])
        try check(WorkReading.validated(proposal(), challenge: rejected, context: context) == nil, "An unconfirmed mismatch became a direction cue")
        let compiled = WorkFrame(resultState: .proposed, focus: .directionChange, goal: "Keep search offline", nextStep: "", references: refs).proposal(in: context)
        let literal = WorkReading.validated(compiled, challenge: rejected, context: context)
        try check(literal?.boundaryRule == "offline-versus-hosted", "A literal source-backed boundary question depended on a model verdict about intent")
        let noModel = WorkChallenge(goalSupported: false, accountSupported: false, nextStepRelevant: false, directionMismatchSupported: false, sourceIDs: [])
        let local = WorkReading.literalCandidate(in: context)!
        try check(WorkReading.validated(local.proposal(in: context), challenge: noModel, context: context)?.signalKey != nil, "A literal-only question incorrectly required a model call or model citations")
        let ungrounded = [refs[0], WorkReference(sourceID: "S1", quote: "The user did not review the design.", use: .change), refs[2]]
        try check(WorkReading.validated(proposal(references: ungrounded), challenge: yes, context: context) == nil, "A fabricated witness span was accepted")
        let fake = proposal(references: [.init(sourceID: "made-up", quote: "Search must stay offline.", use: .boundary), refs[2]]).withWitnessContext(context)
        try check(WorkReading.validated(fake, challenge: yes, context: context) == nil, "Context expansion repaired a fabricated source")
        let supplemented = proposal(references: [refs[0], refs[1]]).withWitnessContext(context)
        try check(WorkReading.validated(supplemented, challenge: yes, context: context)?.signalKey == accepted?.signalKey, "Supplying the actual anchor changed or lost a valid cue")
        try check(WorkReading.validated(proposal(headline: "You are being steered and you never understand the work."), challenge: yes, context: context) == nil, "A personal capability verdict escaped the work reader")
        try check(!WorkReading.isBriefAssent("I am deliberately changing the requirement because cross-device sync is now required."), "A deliberate explanation was treated as bare assent")
        try check(!WorkReading.isBriefAssent("Do not go ahead; keep the offline behavior.") && WorkReading.isBriefAssent("Sounds good, proceed."), "The conservative assent gate confused rejection and approval")
        let wrongOrder = DecisionContext(sessionID: "synthetic", anchorID: "S2", sources: [sources[1],sources[0],sources[2]])
        try check(WorkReading.validated(proposal(), challenge: yes, context: wrongOrder) == nil, "A proposal preceding the boundary became a subsequent direction change")
        let foreign = DecisionSource(id: "S1", messageID: "proposal", sessionID: "other-project", role: "assistant", text: sources[1].text)
        let acrossProjects = DecisionContext(sessionID: "synthetic", anchorID: "S2", sources: [sources[0], foreign, sources[2]])
        try check(WorkReading.validated(proposal(), challenge: yes, context: acrossProjects) == nil, "Retrieved context became a confirmed cross-project direction warning")
        let revision = DecisionRevision.contextual(context: context, proposal: proposal(), challenge: yes, engine: "synthetic")
        try check(revision.evidence.count == 3 && revision.evidence.allSatisfy { ["boundary", "proposal", "response"].contains($0.messageID) }, "Contextual reading lost its actual evidence")
        let wrongReport = DecisionPerspective(sessionID: "synthetic", text: WorkReading.intentionalResponse, anchorMessageID: "another-request")
        let report = DecisionPerspective(sessionID: "synthetic", text: WorkReading.intentionalResponse, anchorMessageID: "response")
        try check(!revision.directionAcknowledged(by: [wrongReport]) && revision.directionAcknowledged(by: [report]), "Direction acknowledgment leaked between requests")
        let earlierChoice = DecisionPerspective(sessionID: "synthetic", text: WorkReading.intentionalResponse, anchorMessageID: "older-approval", signalKey: revision.reading?.signalKey)
        try check(revision.directionAcknowledged(by: [earlierChoice]), "A continuing approval re-raised a resolved question about the same boundary and proposal")
        let changed = DecisionContext(sessionID: "synthetic", anchorID: "S4", sources: [sources[0], sources[1], .init(id: "S3", messageID: "changed-boundary", sessionID: "synthetic", role: "user", text: "I deliberately changed the requirement: remote processing is allowed now."), .init(id: "S4", messageID: "new-approval", sessionID: "synthetic", role: "user", text: "Yes, proceed.")])
        try check(WorkReading.literalCandidate(in: changed) == nil, "An older proposal ignored an intervening human change of requirement")
        let data = try JSONEncoder().encode(revision)
        try check(try JSONDecoder().decode(DecisionRevision.self, from: data).reading?.signalKey == accepted?.signalKey, "Contextual reading failed a storage round trip")
        var old = try JSONSerialization.jsonObject(with: data) as! [String: Any]; old.removeValue(forKey: "reading")
        try check(try JSONDecoder().decode(DecisionRevision.self, from: JSONSerialization.data(withJSONObject: old)).reading == nil, "Old revision payloads could no longer be read")
    }
    public static func storage() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("vernier-work-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let gate = ObservationGate(); let token = gate.configure(enabled: true, contentEnabled: true, analysisEnabled: true)
        let store = try SessionStore(directory: dir, gate: gate)
        let library = ShowcaseFixtures.workLibrary(), sessionID = library.sessions[0].id
        _ = try await store.apply(.init(sessions: library.sessions, turns: library.turns, truncated: false, observedAt: Date(), messages: library.messages), token: token)
        let context = try await store.decisionContext(sessionID: sessionID)!
        let agent = context.sources.last { $0.role == "assistant" }!, anchor = context.anchor!
        let refs = [WorkReference(sourceID: agent.id, quote: String(agent.quote.prefix(160)), use: .change), .init(sourceID: anchor.id, quote: String(anchor.quote.prefix(160)), use: .response)]
        let proposed = WorkProposal(focus: .check, goal: "Prevent duplicate contacts", headline: "The blank-email case still needs a result.", account: "The agent reports zero new contacts on a repeated import; blank emails remain unchecked in that report.", nextStep: "Import the blank-email file twice and compare the contact counts.", references: refs)
        let challenge = WorkChallenge(goalSupported: true, accountSupported: true, nextStepRelevant: true, directionMismatchSupported: false, sourceIDs: refs.map(\.sourceID))
        let revision = DecisionRevision.contextual(context: context, proposal: proposed, challenge: challenge, engine: "synthetic · work-2")
        let saved = try await store.saveDecisionRevision(revision, context: context, token: token)
        let loaded = try await store.loadDecisionRevisions(sessionID: sessionID)
        try check(saved && loaded.first?.reading?.goal == proposed.goal && loaded.first?.evidence.count == 2, "The contextual reading was not persisted with canonical evidence")
        let exported = String(decoding: try await store.exportJSON(), as: UTF8.self)
        try check(exported.contains("blank-email") && exported.contains("nextStep"), "Export omitted the contextual memory")
        try await store.eraseConversationMemory()
        let remaining = try await store.loadDecisionRevisions()
        try check(remaining.isEmpty, "Memory erasure retained contextual interpretations")
    }
}
