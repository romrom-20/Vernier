import Foundation
import VernierCore

private struct DecisionProbeCase: Decodable {
    struct Message: Decodable { let role: String; let text: String }
    let id: String
    let split: String
    let messages: [Message]
    let expectedKinds: [DecisionKind]
    let critical: Bool
    let perspective: String?
}

extension AppCoordinator {
    /// Explicit synthetic evaluation uses the exact production proposer, critic and host checks.
    func runDecisionModelProbe() async throws {
        let args = CommandLine.arguments
        func value(_ flag: String) -> String? { guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }; return args[i + 1] }
        let engine = value("--model") ?? "apple"
        guard let fixtures = value("--cases"), let reportPath = value("--report") else { throw DecisionGenerationError.invalidResponse }
        let data = try Data(contentsOf: URL(fileURLWithPath: fixtures))
        let cases = try JSONDecoder().decode([DecisionProbeCase].self, from: data)
        var rows: [[String: Any]] = []
        for item in cases where value("--split") == nil || value("--split") == item.split {
            let sources = item.messages.enumerated().map { index, message in
                DecisionSource(id: "S\(index)", messageID: "synthetic-\(item.id)-\(index)", sessionID: "synthetic-\(item.id)", role: message.role, text: message.text)
            }
            guard let anchor = sources.last(where: { $0.role == "user" }) else { continue }
            let perspective = item.perspective.map { [DecisionPerspective(sessionID: anchor.sessionID, text: $0, anchorMessageID: anchor.messageID)] } ?? []
            let context = DecisionContext(sessionID: anchor.sessionID, anchorID: anchor.id, sources: sources, perspectives: perspective)
            do {
                let generated = try await DecisionGenerator.shared.generate(context: context, model: engine)
                let pass = item.expectedKinds.contains(generated.revision.kind)
                let row: [String: Any] = ["id": item.id, "split": item.split, "critical": item.critical, "pass": pass,
                    "expected": item.expectedKinds.map(\.rawValue), "proposed": generated.proposedKind.rawValue,
                    "actionFacts": try JSONSerialization.jsonObject(with: JSONEncoder().encode(generated.actions)), "initial": generated.initialKind.rawValue, "actual": generated.revision.kind.rawValue, "proposedSources": generated.draft.sourceIDs, "criticSources": generated.critique.sourceIDs, "criticSupported": generated.critique.supported, "seconds": generated.seconds, "tokens": generated.tokens,
                    "summary": generated.revision.summary, "reason": generated.revision.reason, "critique": generated.critique.reason,
                    "alternative": generated.revision.alternative, "unknown": generated.revision.unknown]
                rows.append(row)
                print("MODEL CASE \(item.id): \(pass ? "PASS" : "FAIL") \(generated.proposedKind.rawValue) -> \(generated.revision.kind.rawValue), \(String(format: "%.2f", generated.seconds))s")
            } catch {
                rows.append(["id": item.id, "split": item.split, "critical": item.critical, "pass": false, "error": String(describing: error)])
                print("MODEL CASE \(item.id): ERROR \(error)")
            }
            let report: [String: Any] = ["engine": engine, "promptVersion": (try? DecisionPromptResource.load().0.version) ?? "unavailable", "syntheticOnly": true, "cases": rows, "passed": rows.filter { $0["pass"] as? Bool == true }.count, "total": rows.count]
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: reportPath), options: .atomic)
        }
        print("MODEL EVALUATION COMPLETE: \(rows.filter { $0["pass"] as? Bool == true }.count)/\(rows.count)")
    }
}
