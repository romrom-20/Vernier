import Foundation

/// Public presentation data. Never derived from a user's local provider or archive.
public enum ShowcaseFixtures {
    public static func library(now: Date = Date()) -> SessionLibrary {
        let prompts = [
            "Make capture rest when my Mac sleeps, and resume only when I choose.",
            "Keep the floating pill stable while I hover. Pause should work in place.",
            "Help me revisit the design decisions, not just count the messages."
        ]
        let replies = [
            "The example implementation preserves Pause across wake. Inspect the lifecycle checks before relying on it.",
            "This example separates the capture button from the open-dashboard action and keeps one hover target.",
            "A useful review links the intended result, the change, and the evidence. Message counts alone do not establish understanding."
        ]
        var sessions: [SessionMetadata] = []
        var turns: [TurnMetadata] = []
        var messages: [ConversationMessage] = []
        var signals: [AgentToolSignal] = []
        var digests: [SessionDigest] = []
        for index in prompts.indices {
            let id = "showcase-session-\(index)"
            let turnID = "showcase-turn-\(index)"
            let created = now.addingTimeInterval(-Double(index + 1) * 2400)
            sessions.append(SessionMetadata(id: id, workspaceID: "showcase-workspace", createdAt: created,
                updatedAt: created.addingTimeInterval(600), observedAt: now, sourceKind: "appServer", turnsComplete: true))
            turns.append(TurnMetadata(id: turnID, sessionID: id, outcome: .completed, startedAt: created,
                completedAt: created.addingTimeInterval(600), observedAt: now))
            for (speaker, text) in [("user", prompts[index]), ("assistant", replies[index])] {
                messages.append(ConversationMessage(id: "showcase-\(index)-\(speaker)", sessionID: id, turnID: turnID,
                    speaker: speaker, phase: speaker == "user" ? "unspecified" : "final_answer", text: text,
                    sourceAt: created.addingTimeInterval(speaker == "user" ? 0 : 600), observedAt: now,
                    redactions: 0, textTruncated: false, attachmentsOmitted: false))
            }
            signals.append(AgentToolSignal(id: "showcase-signal-\(index)", sessionID: id, kind: "command_execution",
                outcome: "completed", count: 1, sourceAt: created.addingTimeInterval(500), observedAt: now))
            digests.append(SessionDigest(sessionID: id, promptExcerpt: SessionDisplay.excerpt(prompts[index]), messageCount: 2, signalCount: 1))
        }
        let window = BriefWindow.make(session: sessions[0], messages: messages.filter { $0.sessionID == sessions[0].id }, storedMessages: 2)
        let brief = window.validate(goal: "Keep capture quiet and predictable across sleep and wake.",
            goalCitation: BriefEvidence(messageID: "M0", quote: prompts[0]),
            moments: [BriefMomentDraft(kind: .steering, title: "You set a concrete lifecycle requirement",
                detail: "The example request names sleep and explicit resume behavior, giving the implementation a testable boundary.",
                evidence: [BriefEvidence(messageID: "M0", quote: prompts[0])])],
            nextStep: "Check that Pause survives sleep, then explicitly resume and inspect the result.", generatedAt: now,
            engine: "Synthetic showcase · no model ran")
        return SessionLibrary(sessions: sessions, turns: turns, notes: [:], messages: messages, signals: signals,
            memoryCoverage: sessions.map { MemoryCoverage(sessionID: $0.id, complete: true, issue: false) },
            totalMessageCount: messages.count, totalSignalCount: signals.count, digests: digests, workBriefs: [brief])
    }
}

extension ShowcaseFixtures {
    /// A richer invented coding session for the interactive map. No real transcript is used.
    public static func visualLibrary(now: Date = Date()) -> SessionLibrary {
        let base = library(now: now)
        let source = base.sessions[0]
        let start = now.addingTimeInterval(-2700)
        let texts: [(String, String)] = [
            ("user", "Build a CSV importer. Re-importing the same file must not create duplicate contacts."),
            ("assistant", "The importer is implemented. I used email as the contact identity."),
            ("assistant", "I added normalization and a preview screen."),
            ("user", "The same CSV creates duplicates again. Keep existing contacts; show duplicates in the preview."),
            ("assistant", "I updated the duplicate check."),
            ("assistant", "The build completed."),
            ("user", "A successful build does not test re-importing. Run the same file twice and show the before-and-after counts."),
            ("assistant", "The second run still creates two duplicates. I will trace the identity key."),
            ("assistant", "I adjusted whitespace normalization."),
            ("user", "Keep the scope to deduplication. Do not redesign the import screen."),
            ("assistant", "I report zero new contacts on the second import. The blank-email case has not been checked."),
            ("user", "Before shipping, check a file with blank emails too.")
        ]
        var messages: [ConversationMessage] = []; var turns: [TurnMetadata] = []
        var turnID = ""
        for (index, value) in texts.enumerated() {
            let at = start.addingTimeInterval(Double(index) * 150)
            if value.0 == "user" {
                turnID = "showcase-story-turn-\(index)"
                turns.append(TurnMetadata(id: turnID, sessionID: source.id, outcome: .completed, startedAt: at, completedAt: at.addingTimeInterval(60), observedAt: now))
            }
            messages.append(ConversationMessage(id: "showcase-story-message-\(index)", sessionID: source.id, turnID: turnID,
                speaker: value.0, phase: value.0 == "user" ? "unspecified" : (index % 3 == 2 ? "commentary" : "final_answer"),
                text: value.1, sourceAt: at, observedAt: now, redactions: 0, textTruncated: false, attachmentsOmitted: false))
        }
        let session = SessionMetadata(id: source.id, workspaceID: source.workspaceID, createdAt: start,
                                      updatedAt: messages.last!.sourceAt!, observedAt: now, sourceKind: source.sourceKind, turnsComplete: true)
        let window = BriefWindow.make(session: session, messages: messages, storedMessages: messages.count)
        let brief = window.validate(goal: "Import contacts without creating duplicates on a second run.",
            goalCitation: .init(messageID: "M0", quote: texts[0].1), moments: [
                .init(kind: .repair, title: "The duplicate problem came back.", detail: "The same re-import requirement returned after the agent said the importer was implemented. That suggests a repair loop worth checking, rather than evidence that you asked too many questions.", evidence: [.init(messageID: "M0", quote: texts[0].1), .init(messageID: "M3", quote: texts[3].1)]),
                .init(kind: .steering, title: "You changed what counted as evidence.", detail: "You distinguished a successful build from a successful re-import, then kept the work focused on deduplication. Those are concrete acceptance and scope constraints.", evidence: [.init(messageID: "M6", quote: texts[6].1), .init(messageID: "M9", quote: texts[9].1)])
            ], nextStep: "Run the same blank-email CSV twice and compare contact counts. Keep the result separate from the agent’s completion claim.", generatedAt: now, engine: "Synthetic showcase · no model ran")
        let allMessages = messages + base.messages.filter { $0.sessionID != source.id }
        let allTurns = turns + base.turns.filter { $0.sessionID != source.id }
        let digests = [SessionDigest(sessionID: source.id, promptExcerpt: SessionDisplay.excerpt(texts[0].1), messageCount: messages.count, signalCount: 1)] + base.digests.filter { $0.sessionID != source.id }
        return SessionLibrary(sessions: [session] + Array(base.sessions.dropFirst()), turns: allTurns, notes: [:],
                              messages: allMessages, signals: base.signals, memoryCoverage: base.memoryCoverage,
                              totalMessageCount: allMessages.count, totalSignalCount: base.totalSignalCount,
                              digests: digests, workBriefs: [brief])
    }
}
