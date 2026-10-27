import Foundation
import VernierCore

extension AppCoordinator {
    /// Explicit development probe: calls only Apple's on-device model with invented data.
    func runLocalModelProbe() async throws {
        let root = URL(fileURLWithPath: "/synthetic/conductor/workspaces")
        let now = Date()
        let raw: [String: Any] = ["id": "brief-probe", "cwd": root.appendingPathComponent("app/demo").path,
                                 "createdAt": now.timeIntervalSince1970, "updatedAt": now.timeIntervalSince1970, "source": "cli"]
        guard let session = MetadataBoundary.session(raw, root: root, salt: "synthetic", now: now, turnsComplete: true) else { throw BriefGenerationError.insufficient }
        let texts = [
            ("user", "Make the floating control pause capture without opening the dashboard."),
            ("assistant", "I changed the control and it works."),
            ("user", "Clicking Pause still opens the dashboard. Reproduce that click."),
            ("assistant", "It is fixed now."),
            ("user", "Pause opens the dashboard again. Separate the click targets and test both states."),
            ("assistant", "I will separate the buttons and add a test."),
            ("user", "Show the test result before declaring it fixed.")
        ]
        let messages = texts.enumerated().compactMap { index, value -> ConversationMessage? in
            let item: [String: Any] = value.0 == "user"
                ? ["id": "m\(index)", "type": "userMessage", "content": [["type": "text", "text": value.1]]]
                : ["id": "m\(index)", "type": "agentMessage", "phase": "final_answer", "text": value.1]
            return ConversationBoundary.message(["turnId": "t\(index)", "startedAtMs": now.addingTimeInterval(Double(index)).timeIntervalSince1970 * 1000, "item": item], sessionID: session.id, salt: "synthetic", now: now)
        }
        let window = BriefWindow.make(session: session, messages: messages, storedMessages: messages.count)
        let brief = try await LocalBriefGenerator.shared.generate(window)
        print("SYNTHETIC LOCAL MODEL PROBE: \(brief.moments.count) source-validated observations; \(brief.omittedSuggestions) rejected citations")
        print("Synthetic goal: \(brief.goal)")
        for moment in brief.moments { print("Synthetic observation [\(moment.kind.rawValue)]: \(moment.title) — \(moment.detail)") }
        print("Synthetic next step: \(brief.nextStep)")
        guard !brief.moments.isEmpty else { throw BriefGenerationError.insufficient }
    }
}
