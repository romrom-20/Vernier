import Foundation
import VernierCore

private struct WorkProbeCase: Decodable {
    struct Message: Decodable { let role: String; let text: String }
    let id: String
    let messages: [Message]
    let expectedFocuses: [WorkFocus]
    let expectedCue: Bool
    let goalTerms: [String]
}
extension AppCoordinator {
    /// Only explicit invented fixtures. Never opens the personal archive or connector.
    func runWorkModelProbe() async throws {
        let args = CommandLine.arguments
        func value(_ flag: String) -> String? { guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }; return args[i + 1] }
        guard let file = value("--cases"), let report = value("--report") else { throw DecisionGenerationError.invalidResponse }
        let cases = try JSONDecoder().decode([WorkProbeCase].self, from: Data(contentsOf: URL(fileURLWithPath: file)))
        let model = value("--model") ?? "gemma4:e2b-it-qat"
        var rows: [[String: Any]] = []
        for item in cases {
            let sources = item.messages.enumerated().map { i, m in DecisionSource(id: "S\(i)", messageID: "synthetic-\(item.id)-\(i)", sessionID: "synthetic", role: m.role, text: m.text) }
            guard let anchor = sources.last(where: { $0.role == "user" }) else { continue }
            let context = DecisionContext(sessionID: "synthetic", anchorID: anchor.id, sources: sources)
            do {
                let result = try await DecisionGenerator.shared.review(context: context, model: model)
                let reading = result.revision.reading
                let cue = reading?.signalKey != nil
                let focusOK = reading.map { item.expectedFocuses.contains($0.focus) } ?? item.expectedFocuses.contains(.none)
                let goalOK = item.goalTerms.isEmpty || reading.map { r in item.goalTerms.contains { r.goal.localizedCaseInsensitiveContains($0) } } == true
                let pass = focusOK && goalOK && cue == item.expectedCue
                let row: [String: Any] = ["id": item.id, "pass": pass, "accepted": reading != nil, "cue": cue, "expectedCue": item.expectedCue, "seconds": result.seconds, "reviewEngine": result.revision.engine, "basis": reading?.boundaryRule ?? "model_challenge",
                    "frame": try JSONSerialization.jsonObject(with: JSONEncoder().encode(result.frame)), "proposal": try JSONSerialization.jsonObject(with: JSONEncoder().encode(result.proposal)), "challenge": try JSONSerialization.jsonObject(with: JSONEncoder().encode(result.challenge))]
                rows.append(row)
                print("WORK CASE \(item.id): \(pass ? "PASS" : "FAIL"), \(reading?.focus.rawValue ?? "withheld"), \(String(format: "%.2f", result.seconds))s")
            } catch { rows.append(["id": item.id, "pass": false, "expectedCue": item.expectedCue, "error": String(describing: error)]) }
            let output: [String: Any] = ["syntheticOnly": true, "engine": model, "promptVersion": DecisionGenerator.promptVersion, "passed": rows.filter { $0["pass"] as? Bool == true }.count, "total": rows.count, "cases": rows]
            try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: report), options: .atomic)
        }
    }
}
