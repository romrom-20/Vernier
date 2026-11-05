import Foundation
import VernierCore

public enum ConversationRecallChecks {
    private static func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw CoreCheckFailure(description: message) }
    }
    private static let goal = "For the phoneme export, keep every recording local. Do not upload audio."
    private struct Fixture {
        let session: SessionMetadata
        let messages: [ConversationMessage]
    }
    private static func fixture(now: Date, update: Bool = true) -> Fixture {
        let session = ShowcaseFixtures.library(now: now).sessions[0]
        var messages: [ConversationMessage] = [], turn = 0
        func add(_ id: String, _ role: String, _ text: String) {
            if role == "user" { turn += 1 }
            messages.append(.init(id: id, sessionID: session.id, turnID: "invented-turn-\(turn)", speaker: role, phase: role == "assistant" ? "final_answer" : "user", text: text, sourceAt: now.addingTimeInterval(Double(messages.count - 300)), observedAt: now, redactions: 0, textTruncated: false, attachmentsOmitted: false))
        }
        add("recall-opening", "user", "Help me work through several project questions.")
        add("recall-intro", "assistant", "Which requirement should we inspect?")
        for i in 0..<10 {
            add("recall-admin-\(i)", "user", "Use readable indentation for unrelated example number \(i).")
            add("recall-admin-answer-\(i)", "assistant", "The example formatting is ready.")
        }
        // Relevant wording is beyond the normal visible prefix of a message.
        add("recall-goal", "user", String(repeating: "Background description. ", count: 100) + "\n" + goal + "\nAdditional background without a new requirement.")
        add("recall-old-result", "assistant", "I tested the phoneme export and it returned one local file.")
        if update {
            add("recall-update", "user", "I withdraw that restriction. A hosted service is now allowed.")
            add("recall-update-reply", "assistant", "That explicit change is recorded.")
        }
        add("recall-work", "user", "Continue organizing the example code.")
        for i in 0..<90 { add("recall-progress-\(i)", "assistant", "Invented formatting progress \(i).") }
        add("recall-late-admin", "user", "Keep the status brief.")
        add("recall-late-answer", "assistant", "The status is brief.")
        add("recall-second-admin", "user", "Leave that example formatting alone.")
        add("recall-current-agent", "assistant", "The phoneme export change is ready. I have not replayed it.")
        add("recall-anchor", "user", "For the phoneme export, which concrete behavior should be checked next? I have not run this version.")
        return Fixture(session: session, messages: messages)
    }
    private static func store(_ fixture: Fixture, directory: URL, gate: ObservationGate, token: Int) async throws -> SessionStore {
        let store = try SessionStore(directory: directory, gate: gate)
        _ = try await store.apply(.init(sessions: [fixture.session], turns: [], truncated: false, observedAt: Date(), messages: fixture.messages), token: token)
        return store
    }
    private static func revision(_ context: DecisionContext) -> DecisionRevision {
        DecisionRevision.validated(context: context, draft: .init(kind: .humanDirection, goal: "Inspect the phoneme export", summary: "An invented source reading", reason: "Source links remain inspectable.", alternative: "Other context may change this reading.", unknown: "No private understanding is established.", sourceIDs: [context.anchorID]), critique: .init(supported: true, reason: "An invented test challenge", sourceIDs: [context.anchorID]), engine: "invented · recall-1")
    }
    public static func retrieval() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("vernier-recall-selection-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let gate = ObservationGate(), token = gate.configure(enabled: true, contentEnabled: true, analysisEnabled: true)
        let input = fixture(now: Date()), store = try await store(input, directory: directory, gate: gate, token: token)
        let baseline = try await store.decisionContext(sessionID: input.session.id, includeEarlierRecall: false)!
        let context = try await store.decisionContext(sessionID: input.session.id)!
        try check(!baseline.sources.contains { $0.messageID == "recall-goal" }, "The long-memory fixture did not reproduce loss of its middle requirement")
        try check(context.anchor?.messageID == "recall-anchor" && context.sources.count <= 18, "Recall replaced the current anchor or expanded its primary source budget")
        let memory = context.memoryRecall!
        try check(memory.entries.count <= 4 && memory.entries.contains { $0.messageID == "recall-goal" && $0.quote == goal }, "Recall did not recover the exact middle-of-message requirement")
        try check(memory.entries.contains { $0.messageID == "recall-update" && $0.reason == .possibleUpdate }, "A later revision sharing no topic words was omitted")
        try check(memory.entries.contains { $0.messageID == "recall-old-result" && $0.speaker == "assistant" }, "The original exchange reply lost its speaker")
        for entry in memory.entries {
            let original = input.messages.first { $0.id == entry.messageID }!
            try check(original.text.contains(entry.quote) && entry.fingerprint == DecisionSource.fingerprint(original), "Recall invented a quote or fingerprint")
            try check(context.sources.contains { $0.messageID == entry.messageID && $0.text == entry.quote }, "Recall did not make the chosen excerpt available to the reader")
        }
        let packet = WorkWitnessPacket(context: context)
        try check(packet.promptData.contains("current task and validity unconfirmed") && packet.promptData.contains("earlierRecall"), "A recalled statement was presented as an active instruction")
        try check(!packet.promptData.contains("recall-admin-0"), "The entire search index entered the model packet")
        try check(memory.policyVersion == "recall-1" && memory.textLimitUsed == 8192, "Recall did not preserve the policy used for its coverage claim")
        try check(memory.scannedMessageIDs.count <= ConversationRecall.candidateLimit, "Recall scan is unbounded")
        let original = input.messages.first { $0.id == "recall-goal" }!
        let changed = ConversationMessage(id: original.id, sessionID: original.sessionID, turnID: original.turnID, speaker: original.speaker, phase: original.phase, text: original.text + " Edited.", sourceAt: original.sourceAt, observedAt: original.observedAt, redactions: 0, textTruncated: false, attachmentsOmitted: false)
        try check(ConversationRecall.signature([original]) != ConversationRecall.signature([changed]), "A change outside the selected quotation did not change recall provenance")
    }
    public static func temporalBoundaries() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("vernier-recall-scope-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let gate = ObservationGate(), token = gate.configure(enabled: true, contentEnabled: true, analysisEnabled: true)
        let input = fixture(now: Date()), store = try await store(input, directory: directory, gate: gate, token: token)
        let context = try await store.decisionContext(sessionID: input.session.id)!
        let old = context.sources.first { $0.messageID == "recall-old-result" }!
        let goalSource = context.sources.first { $0.messageID == "recall-goal" }!
        let refs = [WorkReference(sourceID: old.id, quote: old.text, use: .result), .init(sourceID: context.anchorID, quote: context.anchor!.quote, use: .response)]
        let frame = WorkFrame(resultState: .behaviorReported, focus: .progress, goal: "Inspect the latest phoneme export", nextStep: "Keep the exact case.", references: refs)
        let yes = WorkChallenge(goalSupported: true, accountSupported: true, nextStepRelevant: true, directionMismatchSupported: true, sourceIDs: refs.map(\.sourceID))
        try check(WorkReading.validated(frame.proposal(in: context), challenge: yes, context: context) == nil, "A remembered passing test became evidence of a new completed result")
        let meta = WorkFrame(resultState: .proposed, focus: .check, goal: "The user is reporting a phoneme export question.", nextStep: "Inspect the case.", references: [.init(sourceID: goalSource.id, quote: goal, use: .intent), refs[1]]).proposal(in: context)
        try check(meta.goal != goal, "An unconfirmed remembered requirement was automatically made the active goal")
        try check(context.hasMissingHumanContext(between: "recall-opening", and: "recall-anchor"), "An omitted intervening statement was treated as absence of a human update")
        var sourceFields = try JSONSerialization.jsonObject(with: JSONEncoder().encode(context)) as! [String: Any]
        sourceFields.removeValue(forKey: "memoryRecall")
        let oldContext = try JSONDecoder().decode(DecisionContext.self, from: JSONSerialization.data(withJSONObject: sourceFields))
        try check(oldContext.memoryRecall == nil, "Old contexts cannot decode without the new optional memory field")
        // Same selector, explicit personal context: this is retrieval only, not
        // evidence that the coding result classifier understands personal actions.
        let now = Date(), sid = "invented-personal"
        let personal = (0..<12).map { i in ConversationMessage(id: "personal-\(i)", sessionID: sid, turnID: "p\(i)", speaker: "user", phase: "user", text: i == 4 ? "I choose a birthday gift under forty, without delivery to the office." : i == 11 ? "Remind me of the birthday gift delivery requirement." : "Unrelated invented statement \(i).", sourceAt: now.addingTimeInterval(Double(i)), observedAt: now, redactions: 0, textTruncated: false, attachmentsOmitted: false) }
        let anchor = DecisionSource(id: "S0", messageID: "personal-11", sessionID: sid, role: "user", text: personal[11].text)
        let other = ConversationMessage(id: "foreign-personal", sessionID: "another-area", turnID: "foreign", speaker: "user", phase: "user", text: personal[4].text, sourceAt: now, observedAt: now, redactions: 0, textTruncated: false, attachmentsOmitted: false)
        let recalled = ConversationRecall.select(candidates: personal + [other], context: .init(sessionID: sid, anchorID: "S0", sources: [anchor]), totalHumanMessages: 12)!
        try check(recalled.entries.contains { $0.messageID == "personal-4" } && recalled.entries.allSatisfy { $0.sessionID == sid }, "Recall mixed personal statements from another conversation")
        let remembered = DecisionSource(id: "S1", messageID: "personal-4", sessionID: sid, role: "user", text: personal[4].text)
        let currentAgent = DecisionSource(id: "S2", messageID: "personal-current-ai", sessionID: sid, role: "assistant", text: "No external action has been performed.")
        let reminder = DecisionContext(sessionID: sid, anchorID: "S0", sources: [remembered, currentAgent, anchor], memoryRecall: recalled)
        let reminderRefs = [WorkReference(sourceID: "S0", quote: anchor.quote, use: .response), .init(sourceID: "S2", quote: currentAgent.quote, use: .change)]
        let reminderProposal = WorkFrame(resultState: .proposed, focus: .check, goal: "Recall an earlier choice", nextStep: "Compare the saved statement with the current request.", references: reminderRefs).proposal(in: reminder)
        let reminderYes = WorkChallenge(goalSupported: true, accountSupported: true, nextStepRelevant: true, directionMismatchSupported: false, sourceIDs: ["S0", "S1", "S2"])
        let reminderReading = WorkReading.validated(reminderProposal, challenge: reminderYes, context: reminder)
        try check(reminderReading?.goal.hasPrefix("Earlier: “I choose") == true && reminderReading?.recalledGoalSourceID == "personal-4" && reminderReading?.goalLabel == "Earlier statement you asked about", "A requested literal past choice was not quoted with an explicit historical label")
        let start = ConversationMessage(id: "gap-start", sessionID: sid, turnID: "g0", speaker: "user", phase: "user", text: "Keep all transcription offline. No recording may leave this device.", sourceAt: now, observedAt: now, redactions: 0, textTruncated: false, attachmentsOmitted: false)
        let hidden = ConversationMessage(id: "gap-update", sessionID: sid, turnID: "g1", speaker: "user", phase: "user", text: "I withdraw that restriction.", sourceAt: now.addingTimeInterval(1), observedAt: now, redactions: 0, textTruncated: false, attachmentsOmitted: false)
        let end = ConversationMessage(id: "gap-end", sessionID: sid, turnID: "g2", speaker: "user", phase: "user", text: "Okay.", sourceAt: now.addingTimeInterval(3), observedAt: now, redactions: 0, textTruncated: false, attachmentsOmitted: false)
        let sparseSources = [DecisionSource(id: "S0", messageID: start.id, sessionID: sid, role: "user", text: start.text), DecisionSource(id: "S1", messageID: "gap-agent", sessionID: sid, role: "assistant", text: "I propose sending queries to a hosted transcription provider."), DecisionSource(id: "S2", messageID: end.id, sessionID: sid, role: "user", text: end.text)]
        let sparse = DecisionContext(sessionID: sid, anchorID: "S2", sources: sparseSources)
        let gap = ConversationRecall.select(candidates: [start, hidden, end], context: sparse, totalHumanMessages: 3)!
        let guarded = DecisionContext(sessionID: sid, anchorID: "S2", sources: sparseSources, memoryRecall: gap)
        let references = sparseSources.enumerated().map { i, source in WorkReference(sourceID: source.id, quote: source.quote, use: i == 0 ? .boundary : i == 1 ? .change : .response) }
        let direction = WorkFrame(resultState: .proposed, focus: .directionChange, goal: start.text, nextStep: "Choose the boundary.", references: references).proposal(in: guarded)
        let acceptedByModel = WorkChallenge(goalSupported: true, accountSupported: true, nextStepRelevant: true, directionMismatchSupported: true, sourceIDs: sparseSources.map(\.id))
        try check(WorkReading.literalCandidate(in: guarded) == nil && WorkReading.validated(direction, challenge: acceptedByModel, context: guarded) == nil, "A missing human revision let an old boundary produce an automatic direction cue")
        var edited = input.messages.last!
        edited = ConversationMessage(id: edited.id, sessionID: edited.sessionID, turnID: edited.turnID, speaker: edited.speaker, phase: edited.phase, text: "I tested the phoneme export myself and it returned two files.", sourceAt: edited.sourceAt, observedAt: edited.observedAt, redactions: 0, textTruncated: false, attachmentsOmitted: false)
        _ = try await store.apply(.init(sessions: [], turns: [], truncated: false, observedAt: now, messages: [edited]), token: token)
        let updated = try await store.decisionContext(sessionID: input.session.id)!
        let currentRefs = [WorkReference(sourceID: updated.sources.first { $0.messageID == old.messageID }!.id, quote: old.text, use: .result), .init(sourceID: updated.anchorID, quote: updated.anchor!.quote, use: .result)]
        let current = WorkFrame(resultState: .behaviorReported, focus: .progress, goal: "Inspect the latest phoneme export", nextStep: "Keep the case.", references: currentRefs).proposal(in: updated)
        let all = WorkChallenge(goalSupported: true, accountSupported: true, nextStepRelevant: true, directionMismatchSupported: false, sourceIDs: currentRefs.map(\.sourceID))
        let reading = WorkReading.validated(current, challenge: all, context: updated)
        try check(reading?.evidenceStatus == .humanReported && reading?.hasBothReporters == false, "The historical-result guard erased a real current human report or mixed it with the old AI result")
        let hosted = input.messages.first { $0.id == "recall-current-agent" }!
        let hostedChange = ConversationMessage(id: hosted.id, sessionID: hosted.sessionID, turnID: hosted.turnID, speaker: hosted.speaker, phase: hosted.phase, text: "I propose using a hosted phoneme export service.", sourceAt: hosted.sourceAt, observedAt: hosted.observedAt, redactions: 0, textTruncated: false, attachmentsOmitted: false)
        let assent = ConversationMessage(id: edited.id, sessionID: edited.sessionID, turnID: edited.turnID, speaker: edited.speaker, phase: edited.phase, text: "Okay.", sourceAt: edited.sourceAt, observedAt: edited.observedAt, redactions: 0, textTruncated: false, attachmentsOmitted: false)
        _ = try await store.apply(.init(sessions: [], turns: [], truncated: false, observedAt: now, messages: [hostedChange, assent]), token: token)
        let unrelated = try await store.decisionContext(sessionID: input.session.id)!
        let format = unrelated.sources.first { $0.messageID == "recall-second-admin" }!, service = unrelated.sources.first { $0.messageID == "recall-current-agent" }!
        try check(!unrelated.hasMissingHumanContext(between: format.messageID, and: unrelated.anchor!.messageID), "The unrelated-topic fixture accidentally depended only on a history gap")
        let unrelatedRefs = [WorkReference(sourceID: format.id, quote: format.quote, use: .boundary), .init(sourceID: service.id, quote: service.quote, use: .change), .init(sourceID: unrelated.anchorID, quote: unrelated.anchor!.quote, use: .response)]
        let guessed = WorkFrame(resultState: .proposed, focus: .directionChange, goal: format.quote, nextStep: "Choose the requirement.", references: unrelatedRefs).proposal(in: unrelated)
        let wrongYes = WorkChallenge(goalSupported: true, accountSupported: true, nextStepRelevant: true, directionMismatchSupported: true, sourceIDs: unrelatedRefs.map(\.sourceID))
        try check(WorkReading.validated(guessed, challenge: wrongYes, context: unrelated) == nil, "Same-model agreement made formatting and a network service an asserted direction conflict")
    }
    public static func storage() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("vernier-recall-store-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let gate = ObservationGate(), token = gate.configure(enabled: true, contentEnabled: true, analysisEnabled: true)
        let input = fixture(now: Date()), store = try await store(input, directory: directory, gate: gate, token: token)
        let first = try await store.decisionContext(sessionID: input.session.id)!
        let selected = Set(first.sources.map(\.messageID))
        let omitted = first.memoryRecall!.scannedMessageIDs.first { !selected.contains($0) }!
        let original = input.messages.first { $0.id == omitted }!
        func edit(_ message: ConversationMessage, suffix: String) -> ConversationMessage {
            .init(id: message.id, sessionID: message.sessionID, turnID: message.turnID, speaker: message.speaker, phase: message.phase, text: message.text + suffix, sourceAt: message.sourceAt, observedAt: message.observedAt, redactions: message.redactions, textTruncated: message.textTruncated, attachmentsOmitted: message.attachmentsOmitted)
        }
        _ = try await store.apply(.init(sessions: [], turns: [], truncated: false, observedAt: Date(), messages: [edit(original, suffix: " I withdraw that constraint.")]), token: token)
        let stale = try await store.saveDecisionRevision(revision(first), context: first, token: token)
        try check(!stale, "An edited omitted correction did not block an in-flight memory review")
        let fresh = try await store.decisionContext(sessionID: input.session.id)!
        let reading = revision(fresh)
        let freshSaved = try await store.saveDecisionRevision(reading, context: fresh, token: token)
        try check(freshSaved, "A fresh source-linked memory could not be saved")
        let values = try await store.loadDecisionRevisions()
        try check(values.first?.memoryRecall == fresh.memoryRecall, "Remembered statements did not round-trip with their provenance")
        let exported = String(decoding: try await store.exportJSON(), as: UTF8.self)
        try check(exported.contains("memoryRecall") && exported.contains(goal), "Export omitted the derived memory or its source wording")
        let linked = Set(fresh.sources.map(\.messageID))
        let nextOmitted = fresh.memoryRecall!.scannedMessageIDs.first { !linked.contains($0) }!
        let nextOriginal = input.messages.first { $0.id == nextOmitted }!
        _ = try await store.apply(.init(sessions: [], turns: [], truncated: false, observedAt: Date(), messages: [edit(nextOriginal, suffix: " A later correction.")]), token: token)
        let invalidated = try await store.loadDecisionRevisions()
        try check(invalidated.isEmpty, "An indexed but uncited edit retained a memory-dependent reading")
        let latest = try await store.decisionContext(sessionID: input.session.id)!
        let saved = try await store.saveDecisionRevision(revision(latest), context: latest, token: token)
        try check(saved, "Cannot seed memory before erasure")
        try await store.eraseConversationMemory()
        let erased = try await store.loadDecisionRevisions()
        let archive = String(decoding: try await store.exportJSON(), as: UTF8.self)
        try check(erased.isEmpty && !archive.contains(goal), "Erasure retained remembered quotations or derived records")
        let late = try await store.saveDecisionRevision(revision(latest), context: latest, token: token)
        try check(!late, "An in-flight result recreated erased memory")
    }
}
