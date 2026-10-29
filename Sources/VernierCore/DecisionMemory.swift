import Foundation
import CryptoKit

public enum DecisionKind: String, Codable, CaseIterable, Sendable {
    case uncertain, delegation, humanDirection = "human_direction", agentProposal = "agent_proposal"
    case evidenceRequest = "evidence_request", explanationRequest = "explanation_request"
    case recurringIssue = "recurring_issue", outcomeReport = "outcome_report"
    public var title: String {
        switch self {
        case .uncertain: "There’s a gap in the picture."
        case .delegation: "You left a next step to the agent."
        case .humanDirection: "Your input shaped the next step."
        case .agentProposal: "The agent introduced a direction."
        case .evidenceRequest: "You asked for evidence."
        case .explanationRequest: "You asked to make sense of the work."
        case .recurringIssue: "A requirement returned."
        case .outcomeReport: "You reported what happened."
        }
    }
}

/// Observable acts can coexist; a handoff does not cancel a constraint or a request for evidence.
public struct DecisionActions: Codable, Sendable {
    public let hasClearContribution: Bool
    public let requestsUnsupportedPersonalVerdict: Bool
    public let requestsConcreteCheck: Bool
    public let requestsExplanation: Bool
    public let choosesOrLimitsApproach: Bool
    public let reportsObservedResult: Bool
    public let reportsSameFailureAgain: Bool
    public let reportsContinuingFailure: Bool?
    public let acceptsNewAgentApproach: Bool
    public let delegatesNextStep: Bool
    public init(hasClearContribution: Bool = true, requestsUnsupportedPersonalVerdict: Bool = false, requestsConcreteCheck: Bool = false, requestsExplanation: Bool = false, choosesOrLimitsApproach: Bool = false, reportsObservedResult: Bool = false, reportsSameFailureAgain: Bool = false, reportsContinuingFailure: Bool = false, acceptsNewAgentApproach: Bool = false, delegatesNextStep: Bool = false) {
        self.hasClearContribution = hasClearContribution; self.requestsUnsupportedPersonalVerdict = requestsUnsupportedPersonalVerdict
        self.requestsConcreteCheck = requestsConcreteCheck; self.requestsExplanation = requestsExplanation; self.choosesOrLimitsApproach = choosesOrLimitsApproach
        self.reportsObservedResult = reportsObservedResult; self.reportsSameFailureAgain = reportsSameFailureAgain; self.reportsContinuingFailure = reportsContinuingFailure; self.acceptsNewAgentApproach = acceptsNewAgentApproach; self.delegatesNextStep = delegatesNextStep
    }
    public var kind: DecisionKind {
        if !hasClearContribution || requestsUnsupportedPersonalVerdict { return .uncertain }
        if reportsObservedResult && reportsContinuingFailure == true && reportsSameFailureAgain { return .recurringIssue }
        if reportsObservedResult { return .outcomeReport }
        if requestsConcreteCheck { return .evidenceRequest }
        if requestsExplanation { return .explanationRequest }
        if choosesOrLimitsApproach { return .humanDirection }
        if acceptsNewAgentApproach { return .agentProposal }
        if delegatesNextStep { return .delegation }
        return .uncertain
    }
}

public enum DecisionStatus: String, Codable, Sendable { case supported, tentative, unknown }
public enum TextOrigin: String, Codable, Sendable { case userSupplied = "user_supplied", agent, reusedAgent = "reused_agent", mixed }

public struct DecisionSource: Codable, Identifiable, Sendable {
    public let id: String
    public let messageID: String
    public let sessionID: String
    public let role: String
    public let text: String
    public let fingerprint: String
    public let originalText: String?
    public var origin: TextOrigin
    public var novelText: String
    public var reusedFrom: [String]
    public init(id: String, messageID: String, sessionID: String, role: String, text: String, fingerprint: String = "", originalText: String? = nil) {
        self.id = id; self.messageID = messageID; self.sessionID = sessionID; self.role = role; self.text = text
        self.fingerprint = fingerprint; self.originalText = originalText; origin = role == "assistant" ? .agent : .userSupplied
        novelText = ["user", "user_report"].contains(role) ? text : ""; reusedFrom = []
    }
    public var quote: String {
        let original = originalText ?? text
        let novelSegment = novelText.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.rangeOfCharacter(from: .alphanumerics) != nil && original.contains($0) }.max { $0.count < $1.count }
        let candidate = origin == .mixed ? (novelSegment ?? text) : text
        let prefix = String(candidate.trimmingCharacters(in: .whitespacesAndNewlines).prefix(240))
        if !prefix.isEmpty, original.contains(prefix) { return prefix }
        let segments = prefix.components(separatedBy: .newlines).filter { $0.count >= 8 && original.contains($0) }
        if let longest = segments.max(by: { $0.count < $1.count }) { return longest }
        return String(original.prefix(240))
    }
    public static func fingerprint(_ message: ConversationMessage) -> String {
        digest([message.id, message.speaker, message.phase, String(message.sourceAt?.timeIntervalSince1970 ?? 0), message.text].joined(separator: "|"))
    }
}

/// Detect known text reuse, not whether a human independently authored every remaining word.
public enum SourceAttribution {
    public static func annotate(_ input: [DecisionSource]) -> [DecisionSource] {
        struct Word { let value: String; let range: NSRange }
        func words(_ text: String) -> [Word] {
            let regex = try! NSRegularExpression(pattern: #"[\p{L}\p{N}']+"#)
            let ns = text as NSString
            return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { Word(value: ns.substring(with: $0.range).lowercased(), range: $0.range) }
        }
        var phrases: [String: String] = [:]
        var result: [DecisionSource] = []
        for var source in input {
            let tokens = words(source.text)
            if source.role == "assistant", tokens.count >= 8 {
                for index in 0...(tokens.count - 8) { phrases[tokens[index..<(index + 8)].map(\.value).joined(separator: " ")] = source.id }
            } else if source.role == "user" {
                var ranges: [NSRange] = []; var origins = Set<String>()
                if tokens.count >= 8 {
                    for index in 0...(tokens.count - 8) {
                        let key = tokens[index..<(index + 8)].map(\.value).joined(separator: " ")
                        if let origin = phrases[key] {
                            origins.insert(origin)
                            let first = tokens[index].range, last = tokens[index + 7].range
                            ranges.append(NSRange(location: first.location, length: NSMaxRange(last) - first.location))
                        }
                    }
                }
                var merged: [NSRange] = []
                for range in ranges.sorted(by: { $0.location < $1.location }) {
                    if let last = merged.last, range.location <= NSMaxRange(last) + 2 { merged[merged.count - 1] = NSUnionRange(last, range) }
                    else { merged.append(range) }
                }
                let novel = NSMutableString(string: source.text)
                for range in merged.reversed() { novel.replaceCharacters(in: range, with: "\n") }
                var remaining = String(novel)
                remaining = remaining.replacingOccurrences(of: #"(?s)```.*?```"#, with: " ", options: .regularExpression)
                remaining = remaining.replacingOccurrences(of: #"(?m)^\s*>.*$"#, with: " ", options: .regularExpression)
                source.novelText = remaining.trimmingCharacters(in: .whitespacesAndNewlines)
                source.reusedFrom = origins.sorted()
                if !origins.isEmpty { source.origin = words(source.novelText).isEmpty ? .reusedAgent : .mixed }
            }
            result.append(source)
        }
        return result
    }
}

public struct DecisionPerspective: Codable, Identifiable, Sendable {
    public let id: String
    public let sessionID: String
    public let text: String
    public let createdAt: Date
    public let revisionID: String?
    public let anchorMessageID: String?
    public let signalKey: String?
    public init(id: String = UUID().uuidString, sessionID: String, text: String, createdAt: Date = Date(), revisionID: String? = nil, anchorMessageID: String? = nil, signalKey: String? = nil) {
        self.id = id; self.sessionID = sessionID; self.text = String(text.prefix(1500)); self.createdAt = createdAt; self.revisionID = revisionID; self.anchorMessageID = anchorMessageID; self.signalKey = signalKey
    }
}

public struct DecisionFrontier: Codable, Sendable {
    public let messageID: String
    public let fingerprint: String
    public init(messageID: String, fingerprint: String) { self.messageID = messageID; self.fingerprint = fingerprint }
}

public struct DecisionContext: Codable, Sendable {
    public let sessionID: String
    public let anchorID: String
    public let sources: [DecisionSource]
    public let perspectives: [DecisionPerspective]
    public let earlierAccount: String?
    public let loadedMessages: Int
    public let storedMessages: Int
    public let relatedMessageCounts: [String: Int]
    public let frontier: DecisionFrontier?
    public var anchor: DecisionSource? { sources.first { $0.id == anchorID } }
    public var inputDigest: String {
        let counts = relatedMessageCounts.sorted { $0.key < $1.key }.map { $0.key + ":" + String($0.value) }.joined(separator: "|")
        let records = sources.map { $0.messageID + ":" + $0.fingerprint + ":" + $0.text }.joined(separator: "|")
        let reports = perspectives.map { $0.id + ":" + ($0.anchorMessageID ?? "unlinked") + ":" + $0.text }.joined(separator: "|")
        let parts: [String] = ["decision-v1", String(storedMessages), counts, sessionID, anchorID, frontier?.messageID ?? "", frontier?.fingerprint ?? "", records, reports]
        return digest(parts.joined(separator: "|"))
    }
    public init(sessionID: String, anchorID: String, sources: [DecisionSource], perspectives: [DecisionPerspective] = [], earlierAccount: String? = nil, storedMessages: Int? = nil, attributed: Bool = false, relatedMessageCounts: [String: Int] = [:], frontier: DecisionFrontier? = nil) {
        self.sessionID = sessionID; self.anchorID = anchorID
        self.frontier = frontier ?? sources.last(where: { $0.sessionID == sessionID && $0.role != "user_report" }).map { .init(messageID: $0.messageID, fingerprint: $0.fingerprint) }
        let reports = perspectives.enumerated().map { index, report in
            DecisionSource(id: "P\(index)", messageID: "feedback:" + report.id, sessionID: sessionID, role: "user_report", text: report.text, fingerprint: digest(report.text))
        }
        self.sources = (attributed ? sources : SourceAttribution.annotate(sources)) + reports
        self.perspectives = perspectives; self.earlierAccount = earlierAccount; self.relatedMessageCounts = relatedMessageCounts; loadedMessages = sources.count; self.storedMessages = storedMessages ?? sources.count
    }
    public static func make(sessionID: String, messages: [ConversationMessage], perspectives: [DecisionPerspective] = [], previous: DecisionRevision? = nil, storedMessages: Int, retrieved: [ConversationMessage] = [], relatedMessageCounts: [String: Int] = [:]) -> Self? {
        let ordered = messages.filter { $0.sessionID == sessionID }.sorted {
            let a = $0.sourceAt ?? $0.observedAt, b = $1.sourceAt ?? $1.observedAt
            return a == b ? $0.id < $1.id : a < b
        }
        guard let anchor = ordered.last(where: { $0.speaker == "user" && !SessionDisplay.visibleText($0.text).isEmpty }) else { return nil }
        var seenMessages = Set<String>()
        let all = (retrieved + ordered).filter { seenMessages.insert($0.id).inserted }.sorted {
            let a = $0.sourceAt ?? $0.observedAt, b = $1.sourceAt ?? $1.observedAt
            return a == b ? $0.id < $1.id : a < b
        }
        let raw = all.compactMap { message -> DecisionSource? in
            let text = String(SessionDisplay.visibleText(message.text).prefix(8192))
            guard !text.isEmpty else { return nil }
            return DecisionSource(id: message.id, messageID: message.id, sessionID: message.sessionID, role: message.speaker, text: text, fingerprint: DecisionSource.fingerprint(message), originalText: message.text)
        }
        let attributed = SourceAttribution.annotate(raw)
        let primary = attributed.filter { $0.sessionID == sessionID }
        var selected = Array(primary.suffix(12))
        let retained = Set(selected.map(\.messageID))
        let priorIDs = Set(previous?.evidence.map(\.messageID) ?? [])
        let earlierEvidence = primary.filter { priorIDs.contains($0.messageID) && !retained.contains($0.messageID) }
        selected.insert(contentsOf: earlierEvidence.suffix(3), at: 0)
        if !selected.contains(where: { $0.messageID == anchor.id }), let value = attributed.first(where: { $0.messageID == anchor.id }) { selected.insert(value, at: 0) }
        if let opening = primary.first(where: { $0.role == "user" }), !selected.contains(where: { $0.messageID == opening.messageID }) { selected.insert(opening, at: 0) }
        let latestHuman = Array(primary.filter { $0.role == "user" }.suffix(3))
        var protected = Set(latestHuman.map(\.messageID)); protected.insert(anchor.id)
        if let opening = primary.first(where: { $0.role == "user" }) { protected.insert(opening.messageID) }
        if let last = primary.last { protected.insert(last.messageID) }
        let perspectiveTargets = Set(perspectives.suffix(3).compactMap(\.anchorMessageID))
        protected.formUnion(perspectiveTargets)
        let intentIDs = Set(previous?.reading?.references.filter { $0.use == .intent }.map(\.sourceID) ?? [])
        protected.formUnion(intentIDs)
        var needed = latestHuman + primary.filter { perspectiveTargets.contains($0.messageID) || intentIDs.contains($0.messageID) }
        if let index = primary.firstIndex(where: { $0.messageID == anchor.id }), let proposal = primary.prefix(index).last(where: { $0.role == "assistant" }) {
            needed.append(proposal); protected.insert(proposal.messageID)
        }
        for source in needed where !selected.contains(where: { $0.messageID == source.messageID }) { selected.append(source) }
        let order = Dictionary(uniqueKeysWithValues: primary.enumerated().map { ($0.element.messageID, $0.offset) })
        selected.sort { order[$0.messageID, default: 0] < order[$1.messageID, default: 0] }
        while selected.count > 18, let index = selected.firstIndex(where: { !protected.contains($0.messageID) }) { selected.remove(at: index) }
        selected.insert(contentsOf: attributed.filter { $0.sessionID != sessionID }.suffix(4), at: 0)
        let labels = Dictionary(uniqueKeysWithValues: selected.enumerated().map { ($0.element.messageID, "S\($0.offset)") })
        let labeled = selected.enumerated().map { index, source -> DecisionSource in
            var value = DecisionSource(id: "S\(index)", messageID: source.messageID, sessionID: source.sessionID, role: source.role, text: source.text, fingerprint: source.fingerprint, originalText: source.originalText)
            value.origin = source.origin; value.novelText = source.novelText
            value.reusedFrom = source.reusedFrom.map { labels[$0] ?? "archived_agent_text" }
            return value
        }
        guard let anchorID = labeled.first(where: { $0.messageID == anchor.id })?.id else { return nil }
        return Self(sessionID: sessionID, anchorID: anchorID, sources: labeled, perspectives: Array(perspectives.suffix(3)), earlierAccount: previous.map { "Earlier HYPOTHESIS (not fact): Goal: \($0.goal). \($0.summary) \($0.reason) Next check: \($0.reading?.nextStep ?? $0.unknown)" }, storedMessages: storedMessages, attributed: true, relatedMessageCounts: relatedMessageCounts, frontier: ordered.last.map { .init(messageID: $0.id, fingerprint: DecisionSource.fingerprint($0)) })
    }

    public func contextualSourceIDs(for kind: DecisionKind, selected: [String]) -> [String] {
        guard selected.contains(anchorID), kind != .uncertain, let index = sources.firstIndex(where: { $0.id == anchorID }) else { return selected }
        var result = selected
        let before = sources.prefix(index).filter { $0.sessionID == sessionID }
        if let agent = before.last(where: { $0.role == "assistant" }), !result.contains(agent.id) { result.append(agent.id) }
        if kind == .recurringIssue, let human = before.last(where: { $0.role == "user" && $0.origin != .reusedAgent }), !result.contains(human.id) { result.append(human.id) }
        return result
    }

    public var promptData: String {
        func entry(_ source: DecisionSource) -> String {
            let role = source.role == "user" ? "SAVED HUMAN" : source.role == "assistant" ? "SAVED AGENT" : "HUMAN PERSPECTIVE (self-report)"
            let scope = source.sessionID == sessionID ? "current_conversation" : "retrieved_context_not_a_confirmed_task_link"
            let limit = source.role == "assistant" ? 650 : 1400
            var value = "[\(source.id)] \(role) | \(scope) | origin=\(source.origin.rawValue)\nQuoted text: \(String(source.text.prefix(limit)))"
            if source.role == "user_report" {
                let report = perspectives.first { "feedback:" + $0.id == source.messageID }
                let target = sources.first { $0.messageID == report?.anchorMessageID }?.id
                value += "\nThis perspective refers to: " + (target.map { "[" + $0 + "]" } ?? "an unlinked earlier request; relevance to this anchor is unknown")
            }
            if source.origin == .mixed { value += "\nKnown reused wording from: " + source.reusedFrom.joined(separator: ", ") + "\nAdded words to assess: " + String(source.novelText.prefix(1200)) }
            if source.origin == .reusedAgent { value += "\nThis repeats known agent wording. Independent human reasoning and intention are NOT established." }
            return value
        }
        var parts = ["SAVED TRANSCRIPT. You are an observer, not a participant. Latest human anchor: [" + anchorID + "]."]
        parts += sources.map(entry)
        if let earlierAccount { parts.append(earlierAccount) }
        if let anchor { parts.append("LATEST HUMAN CONTRIBUTION TO EXPLAIN, not the original task or agent reply:\n" + entry(anchor)) }
        return parts.joined(separator: "\n\n")
    }
}

public struct DecisionDraft: Codable, Sendable {
    public let kind: DecisionKind
    public let goal: String
    public let summary: String
    public let reason: String
    public let alternative: String
    public let unknown: String
    public let sourceIDs: [String]
    public init(kind: DecisionKind, goal: String, summary: String, reason: String, alternative: String, unknown: String, sourceIDs: [String]) {
        self.kind = kind; self.goal = goal; self.summary = summary; self.reason = reason; self.alternative = alternative; self.unknown = unknown; self.sourceIDs = sourceIDs
    }
}
public struct DecisionCritique: Codable, Sendable {
    public let supported: Bool
    public let reason: String
    public let sourceIDs: [String]
    public init(supported: Bool, reason: String, sourceIDs: [String]) { self.supported = supported; self.reason = reason; self.sourceIDs = sourceIDs }
}
public struct DecisionEvidence: Codable, Identifiable, Sendable {
    public let messageID: String
    public let sessionID: String
    public let role: String
    public let origin: TextOrigin
    public let quote: String
    public let fingerprint: String
    public var id: String { messageID }
}
public struct DecisionRevision: Codable, Identifiable, Sendable {
    public let id: String
    public let sessionID: String
    public let anchorMessageID: String
    public let inputDigest: String
    public let previousID: String?
    public let createdAt: Date
    public let engine: String
    public let kind: DecisionKind
    public let status: DecisionStatus
    public let actions: DecisionActions?
    public let goal: String
    public let summary: String
    public let reason: String
    public let alternative: String
    public let unknown: String
    public let check: String
    public let evidence: [DecisionEvidence]
    public let loadedMessages: Int
    public let storedMessages: Int
    public let relatedMessageCounts: [String: Int]
    public let reading: WorkReading?

    public static func validated(context: DecisionContext, draft: DecisionDraft, critique: DecisionCritique, engine: String, previousID: String? = nil, now: Date = Date(), actions: DecisionActions? = nil) -> Self {
        let known = Set(context.sources.map(\.id))
        let cited = Array(Set(draft.sourceIDs)).sorted()
        let sources = context.sources.filter { cited.contains($0.id) }
        var issues: [String] = []
        if cited.isEmpty || !Set(cited).isSubset(of: known) || !cited.contains(context.anchorID) { issues.append("The proposed account did not cite the current request and valid sources.") }
        if !critique.supported || !critique.sourceIDs.contains(context.anchorID) || !Set(critique.sourceIDs).isSubset(of: known) { issues.append("The second review did not support this interpretation.") }
        let currentReports = Set(context.perspectives.filter { $0.anchorMessageID == context.anchor?.messageID }.map { "feedback:" + $0.id })
        if let anchor = context.anchor, anchor.origin == .reusedAgent, !sources.contains(where: { currentReports.contains($0.messageID) }) { issues.append("The current user-supplied message repeats known agent text; its content is not evidence of independent human reasoning.") }
        let humanSources = sources.filter { ["user", "user_report"].contains($0.role) && $0.origin != .reusedAgent && $0.novelText.rangeOfCharacter(from: .alphanumerics) != nil }
        if draft.kind != .uncertain && draft.kind != .agentProposal && humanSources.isEmpty { issues.append("No distinct user contribution supports that conclusion.") }
        if draft.kind == .agentProposal && !sources.contains(where: { $0.role == "assistant" }) { issues.append("No cited agent proposal supports that account.") }
        if draft.kind == .recurringIssue && Set(humanSources.filter { $0.role == "user" }.map(\.messageID)).count < 2 { issues.append("A recurring problem needs two distinct user reports, not shared generic words.") }
        let generated = [draft.summary, draft.reason, draft.alternative, draft.unknown].joined(separator: " ")
        if generated.range(of: #"(?i)\byou (?:(?:are|were|seem|seemed|appear|appeared) )?(?:(?:clearly|fully|definitely|now|probably) )?(?:understand|understood|being steered|tired|disengaged)|\b(cognitive decline|brain atrophy|IQ|mental health|sanity score)\b"#, options: .regularExpression) != nil { issues.append("The account makes an unsupported claim about the person.") }
        let valid = issues.isEmpty
        let actualKind: DecisionKind = valid ? draft.kind : .uncertain
        let evidence = sources.map { DecisionEvidence(messageID: $0.messageID, sessionID: $0.sessionID, role: $0.role, origin: $0.origin, quote: $0.quote, fingerprint: $0.fingerprint) }
        let fallbackEvidence = context.anchor.map { [DecisionEvidence(messageID: $0.messageID, sessionID: $0.sessionID, role: $0.role, origin: $0.origin, quote: $0.quote, fingerprint: $0.fingerprint)] } ?? []
        return Self(id: UUID().uuidString, sessionID: context.sessionID, anchorMessageID: context.anchor?.messageID ?? "", inputDigest: context.inputDigest, previousID: previousID, createdAt: now, engine: engine,
            kind: actualKind, status: actualKind == .uncertain ? .unknown : .tentative, actions: valid && actualKind != .uncertain ? actions : nil,
            goal: String(draft.goal.prefix(180)),
            summary: valid ? String(draft.summary.prefix(300)) : "The saved exchange does not yet support a reliable account of your contribution.",
            reason: valid ? String(draft.reason.prefix(650)) : issues.joined(separator: " "),
            alternative: valid ? String(draft.alternative.prefix(350)) : "The proposal failed an evidence check. Read the original exchange before drawing a conclusion.",
            unknown: valid ? String(draft.unknown.prefix(350)) : "The available evidence does not establish a reliable interpretation of this exchange.",
            check: valid ? "The local challenge accepted the proposed action and references. Host checks also validated the current anchor, source identities and evidence structure. Agreement is not independent confirmation." : "The proposal was withheld after the challenge or a source check. No personal capability verdict is established.", evidence: valid && !evidence.isEmpty ? evidence : fallbackEvidence,
            loadedMessages: context.loadedMessages, storedMessages: context.storedMessages, relatedMessageCounts: context.relatedMessageCounts, reading: nil)
    }
}

private func digest(_ value: String) -> String { SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined() }
