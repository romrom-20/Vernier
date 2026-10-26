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
        return SessionLibrary(sessions: sessions, turns: turns, notes: [:], messages: messages, signals: signals,
            memoryCoverage: sessions.map { MemoryCoverage(sessionID: $0.id, complete: true, issue: false) },
            totalMessageCount: messages.count, totalSignalCount: signals.count, digests: digests)
    }
}
