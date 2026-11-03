import Foundation
import AppKit
import VernierCore

private struct ContributionCase: Decodable {
    struct Message: Decodable { let role: String; let text: String }
    let id: String
    let messages: [Message]
    let primary: DailyAction
    let additional: [DailyAction]
}
extension AppCoordinator {
    /// Explicit invented packets only; no archive, connector or capture settings.
    func runContributionProbe() async throws {
        guard model.isolatedEnvironment, !model.isShowcase, NSApp.activationPolicy() == .prohibited else { throw DecisionGenerationError.unavailable }
        let args = CommandLine.arguments
        func value(_ key: String) -> String? { guard let i = args.firstIndex(of: key), i + 1 < args.count else { return nil }; return args[i + 1] }
        guard let file = value("--cases"), let report = value("--report") else { throw DecisionGenerationError.invalidResponse }
        let cases = try JSONDecoder().decode([ContributionCase].self, from: Data(contentsOf: URL(fileURLWithPath: file)))
        let engine = value("--model") ?? "gemma4:e2b-it-qat"
        var rows: [[String: Any]] = []
        for item in cases {
            let start = Calendar.current.startOfDay(for: Date()).addingTimeInterval(3600)
            let messages = item.messages.enumerated().map { i, m in
                ConversationMessage(id: "invented-\(item.id)-\(i)", sessionID: "invented", turnID: "turn-\(i)", speaker: m.role, phase: m.role == "user" ? "user" : "final_answer", text: m.text, sourceAt: start.addingTimeInterval(Double(i)), observedAt: start, redactions: 0, textTruncated: false, attachmentsOmitted: false)
            }
            guard let context = DecisionContext.make(sessionID: "invented", messages: messages, storedMessages: messages.count) else { continue }
            let wording = DailyParticipation.make(day: WorkDay(containing: start), input: .init(messages: messages, datedTotal: messages.count, undatedTotal: 0), sessions: []).moments.last?.action
            let began = Date()
            do {
                let result = try await DecisionGenerator.shared.generateContributions(context: context, model: engine)
                let readings = result.readings
                let reading = readings.first { $0.messageID == context.anchor?.messageID }
                let expected = item.primary == .other ? Set<DailyAction>() : Set([item.primary] + item.additional)
                let tags = Set(reading?.claims.map(\.action) ?? [])
                let pass = (reading?.accepted == true || item.primary == .other) && reading?.primary == item.primary && tags == expected
                rows.append(["id": item.id, "pass": pass, "wordingPrimaryMatch": wording == item.primary, "primaryMatch": reading?.primary == item.primary, "tagsMatch": tags == expected, "seconds": Date().timeIntervalSince(began), "readings": try JSONSerialization.jsonObject(with: JSONEncoder().encode(readings)), "drafts": try JSONSerialization.jsonObject(with: JSONEncoder().encode(result.drafts)), "supportedIDs": result.supportedIDs])
                print("CONTRIBUTION \(item.id): \(pass ? "PASS" : "FAIL")")
            } catch { rows.append(["id": item.id, "pass": false, "wordingPrimaryMatch": wording == item.primary, "seconds": Date().timeIntervalSince(began), "error": error.localizedDescription]) }
            let output: [String: Any] = ["syntheticOnly": true, "engine": engine, "version": ContributionReading.version, "passed": rows.filter { $0["pass"] as? Bool == true }.count, "wordingPrimaryMatched": rows.filter { $0["wordingPrimaryMatch"] as? Bool == true }.count, "total": rows.count, "cases": rows]
            try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: report), options: .atomic)
        }
    }
}
