import Foundation
import AppKit
import VernierCore
import CryptoKit

private struct WorkProbeCase: Decodable {
    struct Message: Decodable { let role: String; let text: String }
    let id: String
    let messages: [Message]
    let expectedFocuses: [WorkFocus]
    let expectedCue: Bool
    let goalTerms: [String]
    let expectedEvidenceStatus: WorkEvidenceStatus?
    let expectedResultState: WorkResultState?
    let trainingFrame: WorkFrame?
    let usesArchive: Bool?
}
extension AppCoordinator {
    /// Only explicit invented fixtures. Never opens the personal archive or connector.
    func runWorkModelProbe() async throws {
        guard model.isolatedEnvironment, !model.isShowcase, NSApp.activationPolicy() == .prohibited else { throw DecisionGenerationError.unavailable }
        let args = CommandLine.arguments
        func value(_ flag: String) -> String? { guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }; return args[i + 1] }
        guard let file = value("--cases"), let report = value("--report") else { throw DecisionGenerationError.invalidResponse }
        let cases = try JSONDecoder().decode([WorkProbeCase].self, from: Data(contentsOf: URL(fileURLWithPath: file)))
        guard !cases.isEmpty, Set(cases.map(\.id)).count == cases.count else { throw DecisionGenerationError.invalidResponse }
        let model = value("--model") ?? "gemma4:e2b-it-qat"
        var rows: [[String: Any]] = []
        var exports: [[String: Any]] = []
        let exportOnly = args.contains("--export-work-packets-only")
        for item in cases {
            guard let context = try await workProbeContext(item, recall: !args.contains("--without-earlier-recall")) else { throw DecisionGenerationError.invalidResponse }
            if exportOnly {
                var packet = try DecisionGenerator.workProbePacket(context: context)
                packet["id"] = item.id
                if let frame = item.trainingFrame {
                    let proposal = frame.proposal(in: context).withWitnessContext(context).respectingExplicitTopicChange(context)
                    let ids = Set(proposal.references.map(\.sourceID)).sorted()
                    let challenge = WorkChallenge(goalSupported: true, accountSupported: true, nextStepRelevant: true, directionMismatchSupported: false, sourceIDs: ids)
                    let revision = DecisionRevision.contextual(context: context, proposal: proposal, challenge: challenge, engine: "Invented training fixture")
                    guard revision.reading != nil,
                          item.expectedEvidenceStatus.map({ revision.reading?.evidenceStatus == $0 }) != false,
                          item.expectedFocuses.contains(revision.reading!.focus) else { throw DecisionGenerationError.invalidResponse }
                    let witnesses = WorkWitnessPacket(context: context)
                    let refs = try frame.references.map { ref -> [String: String] in
                        guard let witness = witnesses.witnesses.first(where: { $0.sourceID == ref.sourceID && $0.quote == ref.quote }) else { throw DecisionGenerationError.invalidResponse }
                        return ["witnessID": witness.id, "use": ref.use.rawValue]
                    }
                    packet["goldRead"] = ["focus": frame.focus.rawValue, "resultState": frame.resultState.rawValue, "goal": frame.goal, "nextStep": frame.nextStep, "references": refs]
                    packet["proposal"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(proposal))
                    packet["goldChallenge"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(challenge))
                }
                exports.append(packet)
                continue
            }
            do {
                let result = try await DecisionGenerator.shared.review(context: context, model: model)
                let reading = result.revision.reading
                let cue = reading?.signalKey != nil
                let focusOK = reading.map { item.expectedFocuses.contains($0.focus) } ?? item.expectedFocuses.contains(.none)
                let goalOK = (reading == nil && item.expectedFocuses.contains(.none)) || item.goalTerms.isEmpty || reading.map { r in item.goalTerms.contains { r.goal.localizedCaseInsensitiveContains($0) } } == true
                let evidenceOK = item.expectedEvidenceStatus.map { expected in
                    reading?.evidenceStatus == expected || (reading == nil && item.expectedFocuses.contains(.none) && expected == .noResult)
                }
                let resultOK = item.expectedResultState.map { result.frame.resultState == $0 }
                let pass = focusOK && goalOK && cue == item.expectedCue && evidenceOK != false && resultOK != false
                let row: [String: Any] = ["id": item.id, "pass": pass, "accepted": reading != nil, "cue": cue, "expectedCue": item.expectedCue, "seconds": result.seconds, "reviewEngine": result.revision.engine, "basis": reading?.boundaryRule ?? "model_challenge",
                    "focusMatch": focusOK, "goalTermMatch": goalOK, "evidenceMatch": evidenceOK as Any? ?? NSNull(), "resultStateMatch": resultOK as Any? ?? NSNull(), "evidenceStatus": reading?.evidenceStatus?.rawValue ?? "withheld", "resultState": result.frame.resultState.rawValue,
                    "frame": try JSONSerialization.jsonObject(with: JSONEncoder().encode(result.frame)), "proposal": try JSONSerialization.jsonObject(with: JSONEncoder().encode(result.proposal)), "challenge": try JSONSerialization.jsonObject(with: JSONEncoder().encode(result.challenge))]
                var audited = row
                audited["evidenceReports"] = try reading?.evidenceReports.map { try JSONSerialization.jsonObject(with: JSONEncoder().encode($0)) } ?? NSNull()
                audited["memoryRecall"] = try context.memoryRecall.map { try JSONSerialization.jsonObject(with: JSONEncoder().encode($0)) } ?? NSNull()
                audited["selectedMessageIDs"] = context.sources.map(\.messageID)
                audited["packetSHA256"] = SHA256.hash(data: Data(WorkWitnessPacket(context: context).promptData.utf8)).map { String(format: "%02x", $0) }.joined()
                audited["contextSources"] = context.sources.count
                audited["rejectedDirection"] = try result.rejectedDirection.map { try JSONSerialization.jsonObject(with: JSONEncoder().encode($0)) } ?? NSNull()
                audited["rejectedDirectionChallenge"] = try result.rejectedDirectionChallenge.map { try JSONSerialization.jsonObject(with: JSONEncoder().encode($0)) } ?? NSNull()
                rows.append(audited)
                print("WORK CASE \(item.id): \(pass ? "PASS" : "FAIL"), \(reading?.focus.rawValue ?? "withheld"), \(String(format: "%.2f", result.seconds))s")
            } catch { rows.append(["id": item.id, "pass": false, "expectedCue": item.expectedCue, "error": String(describing: error)]) }
            let output: [String: Any] = ["syntheticOnly": true, "evaluationVersion": "work-probe-2", "engine": model, "promptVersion": DecisionGenerator.promptVersion, "passed": rows.filter { $0["pass"] as? Bool == true }.count, "evidencePassed": rows.filter { $0["evidenceMatch"] as? Bool == true }.count, "total": rows.count, "cases": rows]
            try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: report), options: .atomic)
        }
        if exportOnly {
            try JSONSerialization.data(withJSONObject: ["syntheticOnly": true, "packetExportOnly": true, "promptVersion": DecisionGenerator.promptVersion, "cases": exports], options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: report), options: .atomic)
        }
    }
    private func workProbeContext(_ item: WorkProbeCase, recall: Bool) async throws -> DecisionContext? {
        guard item.usesArchive == true else {
            let sources = item.messages.enumerated().map { i, m in DecisionSource(id: "S\(i)", messageID: "synthetic-\(item.id)-\(i)", sessionID: "synthetic", role: m.role, text: m.text) }
            guard let anchor = sources.last(where: { $0.role == "user" }) else { return nil }
            return DecisionContext(sessionID: "synthetic", anchorID: anchor.id, sources: sources)
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("vernier-invented-recall-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let gate = ObservationGate(), token = gate.configure(enabled: true, contentEnabled: true, analysisEnabled: true)
        let store = try SessionStore(directory: directory, gate: gate)
        let now = Date(), session = ShowcaseFixtures.library(now: now).sessions[0]
        var turn = 0
        let messages = item.messages.enumerated().map { i, message -> ConversationMessage in
            if message.role == "user" { turn += 1 }
            return ConversationMessage(id: "synthetic-\(item.id)-\(i)", sessionID: session.id, turnID: "synthetic-turn-\(turn)", speaker: message.role, phase: message.role == "assistant" ? "final_answer" : "user", text: message.text, sourceAt: now.addingTimeInterval(Double(i - item.messages.count)), observedAt: now, redactions: 0, textTruncated: false, attachmentsOmitted: false)
        }
        guard try await store.apply(.init(sessions: [session], turns: [], truncated: false, observedAt: now, messages: messages), token: token) else { throw DecisionGenerationError.invalidResponse }
        return try await store.decisionContext(sessionID: session.id, includeEarlierRecall: recall)
    }
}
