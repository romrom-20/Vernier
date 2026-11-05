import Foundation
import AppKit
import VernierCore

private struct ContributionCase: Decodable {
    struct Message: Decodable { let role: String; let text: String }
    struct Target: Decodable { let messageIndex: Int; let primary: DailyAction; let additional: [DailyAction] }
    let id: String
    let messages: [Message]
    let primary: DailyAction
    let additional: [DailyAction]
    let targets: [Target]?
}
extension AppCoordinator {
    /// Explicit invented packets only; no archive, connector or capture settings.
    func runContributionProbe() async throws {
        guard model.isolatedEnvironment, !model.isShowcase, NSApp.activationPolicy() == .prohibited else { throw DecisionGenerationError.unavailable }
        let args = CommandLine.arguments
        func value(_ key: String) -> String? { guard let i = args.firstIndex(of: key), i + 1 < args.count else { return nil }; return args[i + 1] }
        guard let file = value("--cases"), let report = value("--report") else { throw DecisionGenerationError.invalidResponse }
        let cases = try JSONDecoder().decode([ContributionCase].self, from: Data(contentsOf: URL(fileURLWithPath: file)))
        guard !cases.isEmpty, Set(cases.map(\.id)).count == cases.count else { throw DecisionGenerationError.invalidResponse }
        let engine = value("--model") ?? "gemma4:e2b-it-qat"
        var rows: [[String: Any]] = []
        var exported: [[String: Any]] = []
        let exportOnly = args.contains("--export-packets-only")
        for item in cases {
            let start = Calendar.current.startOfDay(for: Date()).addingTimeInterval(3600)
            let messages = item.messages.enumerated().map { i, m in
                ConversationMessage(id: "invented-\(item.id)-\(i)", sessionID: "invented", turnID: "turn-\(i)", speaker: m.role, phase: m.role == "user" ? "user" : "final_answer", text: m.text, sourceAt: start.addingTimeInterval(Double(i)), observedAt: start, redactions: 0, textTruncated: false, attachmentsOmitted: false)
            }
            guard let context = DecisionContext.make(sessionID: "invented", messages: messages, storedMessages: messages.count) else { throw DecisionGenerationError.invalidResponse }
            let expectations = item.targets ?? [.init(messageIndex: messages.count - 1, primary: item.primary, additional: item.additional)]
            // A multi-target packet must declare every expected target: checking only the anchor hides earlier failures.
            guard expectations.allSatisfy({ messages.indices.contains($0.messageIndex) && Set($0.additional).count == $0.additional.count && !$0.additional.contains($0.primary) && !$0.additional.contains(.other) && ($0.primary != .other || $0.additional.isEmpty) }),
                  Set(expectations.map(\.messageIndex)).count == expectations.count,
                  Set(expectations.map { messages[$0.messageIndex].id }) == Set(ContributionReading.batchTargets(in: context).map(\.messageID)),
                  let anchorExpectation = expectations.first(where: { messages[$0.messageIndex].id == context.anchor?.messageID }),
                  anchorExpectation.primary == item.primary, Set(anchorExpectation.additional) == Set(item.additional) else { throw DecisionGenerationError.invalidResponse }
            let wording = DailyParticipation.make(day: WorkDay(containing: start), input: .init(messages: messages, datedTotal: messages.count, undatedTotal: 0), sessions: []).moments
            func scores(_ readings: [ContributionReading]) -> [[String: Any]] {
                expectations.map { target in
                    let messageID = messages[target.messageIndex].id
                    let label = readings.first { $0.messageID == messageID }
                    let expected = target.primary == .other ? Set<DailyAction>() : Set([target.primary] + target.additional)
                    let tags = Set(label?.claims.map(\.action) ?? [])
                    let matched = (label?.accepted == true || target.primary == .other) && label?.primary == target.primary && tags == expected
                    return ["messageID": messageID, "expectedPrimary": target.primary.rawValue, "expectedActs": expected.map(\.rawValue).sorted(), "actualPrimary": label?.primary.rawValue ?? "missing", "actualActs": tags.map(\.rawValue).sorted(), "accepted": label?.accepted == true, "primaryMatch": label?.primary == target.primary, "tagsMatch": tags == expected, "wordingPrimaryMatch": wording.first { $0.id == messageID }?.action == target.primary, "pass": matched]
                }
            }
            let wordingMatch = expectations.allSatisfy { target in wording.first { $0.id == messages[target.messageIndex].id }?.action == target.primary }
            if exportOnly {
                let packet = WorkWitnessPacket(context: context)
                let ids = ContributionReading.batchTargets(in: context).map(\.id)
                let selected = Set(ids)
                let witnesses = Dictionary(grouping: packet.witnesses.filter { selected.contains($0.sourceID) }, by: \.sourceID).mapValues { $0.map(\.id) }
                let expected = expectations.map { target -> [String: Any] in
                    let source = context.sources.first { $0.messageID == messages[target.messageIndex].id }!
                    return ["sourceID": source.id, "messageID": source.messageID, "primary": target.primary.rawValue,
                            "acts": target.primary == .other ? [] : ([target.primary] + target.additional).map(\.rawValue),
                            "origin": source.origin.rawValue,
                            "wordingPrimary": wording.first { $0.id == source.messageID }?.action.rawValue ?? "missing"]
                }
                exported.append(["id": item.id, "packet": packet.promptData, "targetIDs": ids, "expected": expected,
                                 "instructions": DecisionGenerator.contributionInstructions,
                                 "schema": DecisionGenerator.contributionSchema(ids: ids, witnesses: witnesses, challenge: false)])
                continue
            }
            let began = Date()
            do {
                let result = try await DecisionGenerator.shared.generateContributions(context: context, model: engine)
                let readings = result.readings
                let targetResults = scores(readings)
                let pass = targetResults.allSatisfy { $0["pass"] as? Bool == true }
                rows.append(["id": item.id, "pass": pass, "wordingPrimaryMatch": wordingMatch, "primaryMatch": targetResults.allSatisfy { $0["primaryMatch"] as? Bool == true }, "tagsMatch": targetResults.allSatisfy { $0["tagsMatch"] as? Bool == true }, "targets": targetResults, "proposalJSON": try JSONSerialization.jsonObject(with: result.proposalJSON), "challengeJSON": try JSONSerialization.jsonObject(with: result.challengeJSON), "packet": WorkWitnessPacket(context: context).promptData, "seconds": Date().timeIntervalSince(began), "readings": try JSONSerialization.jsonObject(with: JSONEncoder().encode(readings)), "drafts": try JSONSerialization.jsonObject(with: JSONEncoder().encode(result.drafts)), "supportedIDs": result.supportedIDs])
                print("CONTRIBUTION \(item.id): \(pass ? "PASS" : "FAIL")")
            } catch { rows.append(["id": item.id, "pass": false, "wordingPrimaryMatch": wordingMatch, "targets": scores([]), "seconds": Date().timeIntervalSince(began), "error": error.localizedDescription]) }
            let output: [String: Any] = ["syntheticOnly": true, "engine": engine, "version": ContributionReading.version, "reportVersion": 2, "evaluatedTargets": rows.reduce(0) { $0 + (($1["targets"] as? [[String: Any]])?.count ?? 0) }, "matchedTargets": rows.reduce(0) { $0 + (($1["targets"] as? [[String: Any]])?.filter { $0["pass"] as? Bool == true }.count ?? 0) }, "passed": rows.filter { $0["pass"] as? Bool == true }.count, "wordingPrimaryMatched": rows.filter { $0["wordingPrimaryMatch"] as? Bool == true }.count, "total": rows.count, "cases": rows]
            try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: report), options: .atomic)
        }
        if exportOnly {
            let output: [String: Any] = ["syntheticOnly": true, "packetExportOnly": true, "version": ContributionReading.version,
                                         "total": exported.count, "cases": exported]
            try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: report), options: .atomic)
        }
    }
}
