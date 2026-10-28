import Foundation
import CSQLite
import VernierCore

public enum DecisionChecks {
    public static func provenance() async throws {
        func expect(_ value: @autoclosure () -> Bool, _ detail: String) throws { if !value() { throw CoreCheckFailure(description: detail) } }
        func actions(_ enabled: Set<String>) throws -> DecisionKind {
            let names = ["hasClearContribution", "requestsUnsupportedPersonalVerdict", "requestsConcreteCheck", "requestsExplanation", "choosesOrLimitsApproach", "reportsObservedResult", "reportsSameFailureAgain", "acceptsNewAgentApproach", "delegatesNextStep"]
            let fields = Dictionary(uniqueKeysWithValues: names.map { ($0, enabled.contains($0)) })
            return try JSONDecoder().decode(DecisionActions.self, from: JSONSerialization.data(withJSONObject: fields)).kind
        }
        try check(try actions(["hasClearContribution", "requestsConcreteCheck", "delegatesNextStep"]) == .evidenceRequest, "Delegating a test erased the person's evidence request")
        try check(try actions(["hasClearContribution", "choosesOrLimitsApproach", "delegatesNextStep"]) == .humanDirection, "Delegating execution erased the person's choice")
        try check(try actions(["hasClearContribution", "reportsSameFailureAgain"]) == .uncertain, "A hypothetical or shared symptom became an observed recurring result")
        try check(try actions(["hasClearContribution", "requestsUnsupportedPersonalVerdict", "delegatesNextStep"]) == .uncertain, "A requested personal verdict became a supported work account")
        let original = "Before<environment_context>App-added material</environment_context>after"
        let cleaned = DecisionSource(id: "raw", messageID: "raw", sessionID: "synthetic", role: "user", text: "Beforeafter", originalText: original)
        try expect(original.contains(cleaned.quote) && cleaned.quote != "Beforeafter", "Cleaning manufactured a noncontiguous source quotation")
        let finalPayload = try ModelJSONPayload.finalObject("<think>discard this private computation</think>\n{\"answer\":true}", allowsThinkingEnvelope: true)
        try expect(String(decoding: finalPayload, as: UTF8.self) == "{\"answer\":true}", "A model's internal computation leaked into the final payload")
        for malformed in ["<think>unfinished", "prefix {\"answer\":true}", "{\"answer\":true} trailing", "{\"answer\":true} {\"answer\":false}"] {
            do { _ = try ModelJSONPayload.finalObject(malformed, allowsThinkingEnvelope: true); throw CoreCheckFailure(description: "Malformed model output was guessed into an account") }
            catch ModelJSONPayload.Failure.malformed { }
        }
        let plan = "I will keep the sample input fixed and compare the parsers. The frozen numerical tests still fail, so I will try another normalization pass."
        let raw = [DecisionSource(id: "S0", messageID: "m0", sessionID: "synthetic", role: "user", text: "Keep trying to answer the question."),
                   DecisionSource(id: "S1", messageID: "m1", sessionID: "synthetic", role: "assistant", text: plan),
                   DecisionSource(id: "S2", messageID: "m2", sessionID: "synthetic", role: "user", text: plan)]
        let context = DecisionContext(sessionID: "synthetic", anchorID: "S2", sources: raw)
        try expect(context.anchor?.origin == .reusedAgent && context.anchor?.reusedFrom == ["S1"], "Known copied agent text was treated as a new human contribution")
        let fixture = ShowcaseFixtures.visualLibrary()
        let current = fixture.sessions[0].id
        let duplicateContext = DecisionContext.make(sessionID: current, messages: fixture.messages, storedMessages: 12, retrieved: fixture.messages)
        try expect(Set(duplicateContext?.sources.map(\.messageID) ?? []).count == duplicateContext?.sources.count, "Duplicate retrieval could crash or repeat evidence labels")
        let wrong = draft(.recurringIssue, ids: ["S0", "S2"])
        let rejected = DecisionRevision.validated(context: context, draft: wrong, critique: .init(supported: true, reason: "Shared wording", sourceIDs: ["S2"]), engine: "synthetic")
        try expect(rejected.kind == .uncertain && rejected.status == .unknown, "Generic keep/trying overlap and reused text produced a confident recurring-problem account")
        let mixed = raw.dropLast() + [DecisionSource(id: "S2", messageID: "m2", sessionID: "synthetic", role: "user", text: plan + "\nI reject this plan. Keep the old contacts and compare before-and-after counts.")]
        let mixedContext = DecisionContext(sessionID: "synthetic", anchorID: "S2", sources: Array(mixed))
        try expect(mixedContext.anchor?.origin == .mixed && mixedContext.anchor?.novelText.contains("I reject") == true, "A critique surrounding a copied plan was lost")
        try expect(mixedContext.anchor?.quote.contains("I reject") == true && mixedContext.anchor?.quote.contains("I will keep") == false, "The source quote hid the actual added words behind the reused plan")
        let valid = DecisionRevision.validated(context: mixedContext, draft: draft(.humanDirection, ids: ["S1", "S2"]), critique: .init(supported: true, reason: "The added constraint rejects the proposal.", sourceIDs: ["S2"]), engine: "synthetic")
        try expect(valid.kind == .humanDirection && valid.status == .tentative, "An evidence-backed description became a claim of verified understanding")
        let shortReply = DecisionContext(sessionID: "synthetic", anchorID: "S2", sources: [raw[0], raw[1], .init(id: "S2", messageID: "m2", sessionID: "synthetic", role: "user", text: plan + "\nNo.")])
        try expect(shortReply.anchor?.origin == .mixed && shortReply.anchor?.quote == "No.", "A short, distinct rejection was erased by a minimum word threshold")
        let expanded = shortReply.contextualSourceIDs(for: .humanDirection, selected: ["S2"])
        try expect(expanded.contains("S1") && expanded.contains("S2"), "Source context expansion lost the recorded prior proposal or actual anchor")
        let noRescue = shortReply.contextualSourceIDs(for: .humanDirection, selected: ["fake"])
        try expect(noRescue == ["fake"], "Context expansion silently repaired fabricated model references")
        let successful = DecisionActions(reportsObservedResult: true, reportsSameFailureAgain: true, reportsContinuingFailure: false)
        try expect(successful.kind == .outcomeReport, "A passing report about the same topic became a recurring failure")
        let invented = DecisionRevision.validated(context: mixedContext, draft: draft(.humanDirection, ids: ["fake"]), critique: .init(supported: true, reason: "Looks right", sourceIDs: ["fake"]), engine: "synthetic")
        try expect(invented.kind == .uncertain, "Fabricated citations were accepted")
        let unsupported = DecisionRevision.validated(context: mixedContext, draft: draft(.humanDirection, ids: ["S2"]), critique: .init(supported: false, reason: "This may only be a quotation", sourceIDs: ["S2"]), engine: "synthetic")
        try expect(unsupported.kind == .uncertain, "A rejected challenge did not withhold the proposed interpretation")
        let overlap = DecisionActions(choosesOrLimitsApproach: true, delegatesNextStep: true)
        let safeDraft = DecisionDraft.grounded(context: mixedContext, kind: .humanDirection, sourceIDs: ["S2"], actions: overlap)
        let safeReading = DecisionRevision.validated(context: mixedContext, draft: safeDraft, critique: .init(supported: true, reason: "Cited scope condition", sourceIDs: ["S2"]), engine: "synthetic", actions: overlap)
        try expect(safeReading.actions?.delegatesNextStep == true && safeReading.kind == .humanDirection && !safeReading.summary.contains("implemented"), "The reading lost overlapping delegation or invented a human implementation outcome")
        let cognitive = DecisionDraft(kind: .humanDirection, goal: "Import safely", summary: "You clearly understand every change.", reason: "You understood the code.", alternative: "Unknown", unknown: "Unknown", sourceIDs: ["S2"])
        try expect(DecisionRevision.validated(context: mixedContext, draft: cognitive, critique: .init(supported: true, reason: "Claims understanding", sourceIDs: ["S2"]), engine: "synthetic").kind == .uncertain, "Unsupported comprehension claims passed host validation")
        let unsupportedAlternative = DecisionDraft(kind: .humanDirection, goal: "Import safely", summary: "You added a scope condition.", reason: "The request excludes a redesign.", alternative: "You were clearly tired.", unknown: "The test result is missing.", sourceIDs: ["S2"])
        try expect(DecisionRevision.validated(context: mixedContext, draft: unsupportedAlternative, critique: .init(supported: true, reason: "A condition was added.", sourceIDs: ["S2"]), engine: "synthetic").status == .unknown, "Unsupported personal claims escaped through the alternative field")
        let report = DecisionPerspective(sessionID: "synthetic", text: "I intentionally pasted the plan to approve it after checking the prototype.", anchorMessageID: "m2")
        let clarified = DecisionContext(sessionID: "synthetic", anchorID: "S2", sources: raw, perspectives: [report])
        let account = DecisionRevision.validated(context: clarified, draft: draft(.delegation, ids: ["S2", "P0"]), critique: .init(supported: true, reason: "The person reports deliberate approval.", sourceIDs: ["S2", "P0"]), engine: "synthetic", previousID: rejected.id)
        try expect(account.kind == .delegation && account.previousID == rejected.id && account.evidence.contains { $0.role == "user_report" }, "An explicit human clarification could not revise the earlier uncertain account")
        let unrelatedReport = DecisionPerspective(sessionID: "synthetic", text: "I approved an earlier plan.", anchorMessageID: "m0")
        let wrongContext = DecisionContext(sessionID: "synthetic", anchorID: "S2", sources: raw, perspectives: [unrelatedReport])
        let wrongReport = DecisionRevision.validated(context: wrongContext, draft: draft(.delegation, ids: ["S2", "P0"]), critique: .init(supported: true, reason: "Earlier approval", sourceIDs: ["S2"]), engine: "synthetic")
        try expect(wrongReport.kind == .uncertain, "A perspective about an older request authorized interpreting a different copied anchor")
        try expect(context.inputDigest != clarified.inputDigest && clarified.promptData.contains(report.text), "New human evidence did not invalidate the inference input")
    }
    public static func storage() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("vernier-decision-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let gate = ObservationGate()
        var token = gate.configure(enabled: true, contentEnabled: true, analysisEnabled: true)
        let store = try SessionStore(directory: directory, gate: gate)
        let now = Date(), fixture = ShowcaseFixtures.workLibrary(now: Date())
        _ = try await store.apply(.init(sessions: fixture.sessions, turns: fixture.turns, truncated: false, observedAt: now, messages: fixture.messages), token: token)
        let session = fixture.sessions[0]
        try await store.saveNote(sessionID: session.id, text: "Keep my original note.")
        guard let firstContext = try await store.decisionContext(sessionID: session.id) else { throw CoreCheckFailure(description: "No decision context") }
        let first = revision(firstContext)
        let exactSource = try await store.memoryMessage(id: first.anchorMessageID)
        try check(exactSource?.id == first.anchorMessageID && exactSource?.sessionID == session.id, "Exact source lookup returned the wrong canonical record")
        try await expect(try await store.saveDecisionRevision(first, context: firstContext, token: token), "Initial decision was not persisted")
        let extra = ConversationBoundary.message(["turnId": "new-turn", "startedAtMs": now.timeIntervalSince1970 * 1000,
            "item": ["id": "new-user", "type": "userMessage", "content": [["type": "text", "text": "Keep the scope to duplicate contacts; do not redesign the preview."]]]], sessionID: session.id, salt: "synthetic", now: now)!
        _ = try await store.apply(.init(sessions: fixture.sessions, turns: [], truncated: false, observedAt: now, messages: [extra]), token: token)
        try await expect(try await !store.saveDecisionRevision(first, context: firstContext, token: token), "A late inference saved after newer evidence arrived")
        let nextContext = try await store.decisionContext(sessionID: session.id)!
        let next = revision(nextContext, previousID: first.id)
        try await expect(try await store.saveDecisionRevision(next, context: nextContext, token: token), "Revised decision did not save")
        let report = DecisionPerspective(sessionID: session.id, text: "I deliberately set this boundary after testing the old preview.")
        try await store.saveDecisionPerspective(report, revisionID: next.id)
        let reportContext = try await store.decisionContext(sessionID: session.id)!
        try check(reportContext.perspectives.count == 1 && reportContext.perspectives.first?.anchorMessageID == next.anchorMessageID && reportContext.sources.contains { $0.role == "user_report" }, "User perspective did not enter the next review as a separate source")
        let informed = revision(reportContext, previousID: next.id)
        let stale = token; token = gate.configure(enabled: false, contentEnabled: true, analysisEnabled: true)
        try await expect(try await !store.saveDecisionRevision(informed, context: reportContext, token: stale), "Pause did not block an in-flight decision write")
        token = gate.configure(enabled: true, contentEnabled: true, analysisEnabled: false)
        try await expect(try await !store.saveDecisionRevision(informed, context: reportContext, token: token), "Analysis opt-out incorrectly allowed a new inference write")
        token = gate.configure(enabled: true, contentEnabled: true, analysisEnabled: true)
        try await expect(try await store.saveDecisionRevision(informed, context: reportContext, token: token), "A revised account could not cite a saved perspective")
        let latestOnly = try await store.loadLatestDecisionRevisions()
        try check(latestOnly.count == 1 && latestOnly.first?.id == informed.id, "A busy conversation could crowd other conversations out of the latest-reading index")
        let exportData = try await store.exportJSON()
        let exported = try JSONSerialization.jsonObject(with: exportData) as! [String: Any]
        try check((exported["decisionRevisions"] as? [Any])?.count == 3 && (exported["decisionPerspectives"] as? [Any])?.count == 1, "Export omitted decision memory or the user's perspective")
        // Editing a cited canonical message must invalidate its dependent derived readings.
        let original = fixture.messages.first { $0.id == "showcase-story-message-11" }!
        var fields = try JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as! [String: Any]
        fields["text"] = "Before shipping, check blank emails and empty rows."
        let edited = try JSONDecoder().decode(ConversationMessage.self, from: JSONSerialization.data(withJSONObject: fields))
        _ = try await store.apply(.init(sessions: fixture.sessions, turns: [], truncated: false, observedAt: now, messages: [edited]), token: token)
        try await expect(try await store.loadDecisionRevisions().isEmpty, "An edited cited source retained stale interpretations")
        try await expect(try await store.loadDecisionPerspectives().isEmpty, "A source-invalidated review retained its dependent report")
        try await store.eraseConversationMemory()
        let remaining = try await store.load()
        try check(remaining.sessions.count == 3 && remaining.notes[session.id] == "Keep my original note.", "Reasoning erasure removed metadata or personal notes")
        let erasedRevisions = try await store.loadDecisionRevisions()
        let erasedPerspectives = try await store.loadDecisionPerspectives()
        try check(erasedRevisions.isEmpty && erasedPerspectives.isEmpty, "Memory erasure left derived decision content")
    }
    public static func longEpisode() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("vernier-long-episode-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let gate = ObservationGate(); let token = gate.configure(enabled: true, contentEnabled: true, analysisEnabled: true)
        let store = try SessionStore(directory: directory, gate: gate)
        let now = Date(), fixture = ShowcaseFixtures.visualLibrary()
        var progress: [ConversationMessage] = []
        for index in 0..<80 {
            var fields = try JSONSerialization.jsonObject(with: JSONEncoder().encode(fixture.messages[0])) as! [String: Any]
            fields["id"] = "long-progress-\(index)"; fields["speaker"] = "assistant"; fields["phase"] = "commentary"; fields["text"] = "Recorded progress update \(index)."
            fields["sourceAt"] = now.addingTimeInterval(Double(index)).timeIntervalSinceReferenceDate
            progress.append(try JSONDecoder().decode(ConversationMessage.self, from: JSONSerialization.data(withJSONObject: fields)))
        }
        _ = try await store.apply(.init(sessions: fixture.sessions, turns: fixture.turns, truncated: false, observedAt: now, messages: fixture.messages + progress), token: token)
        let context = try await store.decisionContext(sessionID: fixture.sessions[0].id)!
        try check(context.anchor?.messageID == "showcase-story-message-11", "A long agent run replaced the actual latest human request with an opening request")
        try check(context.sources.contains { $0.messageID == "showcase-story-message-10" }, "Long-run context lost the agent proposal preceding the actual anchor")
        try check(context.sources.filter { $0.role == "user" }.count >= 3 && context.sources.count <= 18, "Long-run context lost recent human contributions or exceeded its bound")
        try await expect(try await store.saveDecisionRevision(revision(context), context: context, token: token), "The long-run packet lost its canonical source frontier")
        var injected = try JSONSerialization.jsonObject(with: JSONEncoder().encode(progress.last!)) as! [String: Any]
        injected["id"] = "app-context-only"; injected["speaker"] = "user"; injected["phase"] = "unspecified"
        injected["text"] = "<environment_context>Injected app context, not a new request.</environment_context>"
        injected["sourceAt"] = now.addingTimeInterval(90).timeIntervalSinceReferenceDate
        let contextOnly = try JSONDecoder().decode(ConversationMessage.self, from: JSONSerialization.data(withJSONObject: injected))
        _ = try await store.apply(.init(sessions: fixture.sessions, turns: [], truncated: false, observedAt: now, messages: [contextOnly]), token: token)
        let afterContext = try await store.decisionContext(sessionID: fixture.sessions[0].id)!
        try check(afterContext.anchor?.messageID == "showcase-story-message-11" && afterContext.frontier?.messageID == contextOnly.id, "App-only context replaced the human anchor or broke the canonical frontier")
        let afterReading = revision(afterContext)
        try await expect(try await store.saveDecisionRevision(afterReading, context: afterContext, token: token), "A filtered app-context record prevented all future readings from saving")
        injected["text"] = "<environment_context>Changed app context</environment_context>"
        let changed = try JSONDecoder().decode(ConversationMessage.self, from: JSONSerialization.data(withJSONObject: injected))
        _ = try await store.apply(.init(sessions: fixture.sessions, turns: [], truncated: false, observedAt: now, messages: [changed]), token: token)
        let remaining = try await store.loadDecisionRevisions()
        try check(!remaining.contains { $0.id == afterReading.id }, "Changing a hidden frontier record retained its dependent reading")

    }
    public static func relatedStorage() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("vernier-related-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let gate = ObservationGate(); let token = gate.configure(enabled: true, contentEnabled: true, analysisEnabled: true)
        let store = try SessionStore(directory: directory, gate: gate)
        let now = Date(), fixture = ShowcaseFixtures.library()
        _ = try await store.apply(.init(sessions: fixture.sessions, turns: fixture.turns, truncated: false, observedAt: now, messages: fixture.messages), token: token)
        let firstID = fixture.sessions[0].id, secondID = fixture.sessions[1].id
        let firstContext = try await store.decisionContext(sessionID: firstID)!
        let original = revision(firstContext)
        try await expect(try await store.saveDecisionRevision(original, context: firstContext, token: token), "Cannot seed a related reading")
        func message(_ id: String, _ session: String, _ body: String, _ offset: Double) throws -> ConversationMessage {
            var fields = try JSONSerialization.jsonObject(with: JSONEncoder().encode(fixture.messages[0])) as! [String: Any]
            fields["id"] = id; fields["sessionID"] = session; fields["text"] = body; fields["speaker"] = "user"
            fields["sourceAt"] = now.addingTimeInterval(offset).timeIntervalSinceReferenceDate
            return try JSONDecoder().decode(ConversationMessage.self, from: JSONSerialization.data(withJSONObject: fields))
        }
        let followup = try message("related-followup", secondID, "Import contacts safely: check the blank-email preview before release.", 1)
        _ = try await store.apply(.init(sessions: fixture.sessions, turns: [], truncated: false, observedAt: now, messages: [followup]), token: token)
        let related = try await store.decisionContext(sessionID: secondID)!
        try check(related.relatedMessageCounts[firstID] == 2 && related.anchor?.sessionID == secondID, "Related retrieval lost the current anchor or stored frontier")
        try check(related.sources.contains { $0.sessionID == firstID } && related.promptData.contains("retrieved_context_not_a_confirmed_task_link"), "Retrieved evidence was mislabeled as the current task")
        let reading = revision(related)
        try await expect(try await store.saveDecisionRevision(reading, context: related, token: token), "Related reading could not persist valid source references")
        let changed = try message("related-newer", firstID, "The import result has changed.", 2)
        _ = try await store.apply(.init(sessions: fixture.sessions, turns: [], truncated: false, observedAt: now, messages: [changed]), token: token)
        let late = revision(related)
        try await expect(try await !store.saveDecisionRevision(late, context: related, token: token), "New evidence in another conversation allowed a stale reading")
        let source = fixture.messages.first { $0.sessionID == firstID }!
        let edited = try message(source.id, source.sessionID, "An edited canonical source", -600)
        _ = try await store.apply(.init(sessions: fixture.sessions, turns: [], truncated: false, observedAt: now, messages: [edited]), token: token)
        try await expect(try await store.loadDecisionRevisions().isEmpty, "A foreign source edit failed to invalidate a dependent reading")
    }
    public static func migration() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("vernier-decision-upgrade-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let gate = ObservationGate(); let token = gate.configure(enabled: true, contentEnabled: true, analysisEnabled: true)
        let fixture = ShowcaseFixtures.library()
        var old: SessionStore? = try SessionStore(directory: directory, gate: gate)
        _ = try await old?.apply(.init(sessions: fixture.sessions, turns: fixture.turns, truncated: false, observedAt: Date(), messages: fixture.messages), token: token)
        try await old?.saveNote(sessionID: fixture.sessions[0].id, text: "Existing v4 note")
        old = nil
        var db: OpaquePointer?
        try check(sqlite3_open(directory.appendingPathComponent("sessions.sqlite").path, &db) == SQLITE_OK, "Cannot open temporary migration fixture")
        let sql = "DROP TRIGGER decision_message_delete; DROP TRIGGER decision_message_edit; DROP TRIGGER decision_perspective_delete; DROP TABLE decision_sources; DROP TABLE decision_perspectives; DROP TABLE decision_revisions; DELETE FROM schema_migrations WHERE version=5; PRAGMA user_version=4;"
        try check(sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK, "Cannot prepare a genuine v4 schema")
        sqlite3_close(db)
        let upgraded = try SessionStore(directory: directory, gate: gate)
        let library = try await upgraded.load()
        try check(library.totalMessageCount == 6 && library.notes[fixture.sessions[0].id] == "Existing v4 note", "v4 upgrade lost canonical memory or the user's note")
        let records = try await upgraded.loadDecisionRevisions()
        try check(records.isEmpty, "Upgrade invented inference records")
    }
    private static func draft(_ kind: DecisionKind, ids: [String]) -> DecisionDraft {
        .init(kind: kind, goal: "Import contacts safely", summary: "The saved request limits the work to duplicate handling.", reason: "The person adds a condition after the proposal.", alternative: "This may be a restatement of an existing constraint.", unknown: "Independent understanding is not established.", sourceIDs: ids)
    }
    private static func revision(_ context: DecisionContext, previousID: String? = nil) -> DecisionRevision {
        DecisionRevision.validated(context: context, draft: draft(.humanDirection, ids: [context.anchorID]), critique: .init(supported: true, reason: "The source contains an explicit requirement.", sourceIDs: [context.anchorID]), engine: "synthetic · test", previousID: previousID)
    }
    private static func check(_ value: Bool, _ detail: String) throws { if !value { throw CoreCheckFailure(description: detail) } }
    private static func expect(_ value: @autoclosure () async throws -> Bool, _ detail: String) async throws { try check(await value(), detail) }
}
