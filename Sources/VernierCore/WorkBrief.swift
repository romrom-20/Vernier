import Foundation
import CryptoKit

public enum BriefMomentKind: String, Codable, CaseIterable, Sendable {
    case handoff, repair, steering, choice
    public var label: String {
        switch self {
        case .handoff: "Possible handoff stretch"
        case .repair: "Repeated checking or repair"
        case .steering: "Clear direction from you"
        case .choice: "Choice to revisit"
        }
    }
    public var symbol: String {
        switch self { case .handoff: "arrow.right"; case .repair: "arrow.triangle.2.circlepath"; case .steering: "arrow.turn.up.right"; case .choice: "arrow.triangle.branch" }
    }
}

public struct BriefEvidence: Codable, Sendable, Equatable {
    public let messageID: String
    public let quote: String
    public let speaker: String
    public let sourceAt: Date?
    public init(messageID: String, quote: String, speaker: String = "", sourceAt: Date? = nil) {
        self.messageID = messageID; self.quote = quote; self.speaker = speaker; self.sourceAt = sourceAt
    }
}

public struct BriefMomentDraft: Sendable {
    public let kind: BriefMomentKind
    public let title: String
    public let detail: String
    public let evidence: [BriefEvidence]
    public init(kind: BriefMomentKind, title: String, detail: String, evidence: [BriefEvidence]) {
        self.kind = kind; self.title = title; self.detail = detail; self.evidence = evidence
    }
}

public struct BriefMoment: Codable, Identifiable, Sendable {
    public let id: String
    public let kind: BriefMomentKind
    public let title: String
    public let detail: String
    public let evidence: [BriefEvidence]
    public var dismissed = false
}

public struct WorkBrief: Codable, Sendable {
    public let sessionID: String
    public let inputDigest: String
    public let sourceUpdatedAt: Date
    public let generatedAt: Date
    public let goal: String
    public let goalEvidence: BriefEvidence?
    public var moments: [BriefMoment]
    public let nextStep: String
    public let reviewedMessages: Int
    public let storedMessages: Int
    public let clippedMessages: Int
    public let missingSourceTimes: Int
    public let omittedSuggestions: Int
    public let engine: String
    public var visibleMoments: [BriefMoment] { moments.filter { !$0.dismissed } }
}

public struct BriefWindow: Sendable {
    public struct Entry: Codable, Sendable {
        public let label: String
        public let messageID: String
        public let speaker: String
        public let text: String
        public let sourceAt: Date?
        public let clipped: Bool
        let originalText: String
        public var sourceQuote: String {
            let prefix = String(text.prefix(200))
            if originalText.contains(prefix) { return prefix }
            // Removing injected blocks can join noncontiguous source text. Quote an actual segment instead.
            for line in text.components(separatedBy: .newlines) {
                let quote = String(line.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
                if quote.count >= 5, originalText.contains(quote) { return quote }
            }
            return ""
        }
    }
    public let sessionID: String
    public let sourceUpdatedAt: Date
    public let storedMessages: Int
    public let entries: [Entry]
    public var inputDigest: String {
        let value = "brief-v1|" + sessionID + "|" + entries.map { $0.messageID + "|" + $0.speaker + "|" + $0.text }.joined(separator: "\n")
        return SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    public var promptData: String {
        struct Input: Encodable { let id: String; let role: String; let text: String }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let values = entries.map { Input(id: $0.label, role: $0.speaker, text: $0.text) }
        return (try? String(decoding: encoder.encode(values), as: UTF8.self)) ?? "[]"
    }
    public var hasEnoughContext: Bool { entries.filter { $0.speaker == "user" }.count >= 2 && entries.contains { $0.speaker == "assistant" } }

    public static func make(session: SessionMetadata, messages: [ConversationMessage], opening: ConversationMessage? = nil,
                            storedMessages: Int, maxEntries: Int = 18, perMessage: Int = 1200) -> Self {
        let sorted = messages.sorted {
            let a = $0.sourceAt ?? $0.observedAt, b = $1.sourceAt ?? $1.observedAt
            return a == b ? $0.id < $1.id : a < b
        }
        let requiredUsers = Array(sorted.filter { $0.speaker == "user" }.suffix(2))
        let requiredIDs = Set(requiredUsers.map(\.id))
        var selected = Array(sorted.suffix(max(3, maxEntries)))
        // Progress replies must not crowd both sides of the user's latest exchange out of the excerpt.
        for message in requiredUsers where !selected.contains(where: { $0.id == message.id }) {
            if let replace = selected.firstIndex(where: { !requiredIDs.contains($0.id) }) { selected.remove(at: replace) }
            selected.append(message)
        }
        selected.sort { ($0.sourceAt ?? $0.observedAt, $0.id) < ($1.sourceAt ?? $1.observedAt, $1.id) }
        if let opening, !selected.contains(where: { $0.id == opening.id }) { selected.insert(opening, at: 0) }
        let entries = selected.enumerated().compactMap { index, message -> Entry? in
            let cleaned = SessionDisplay.visibleText(message.text)
            guard !cleaned.isEmpty else { return nil }
            let limit = message.speaker == "user" ? perMessage : min(350, perMessage)
            let text = String(cleaned.prefix(limit))
            return Entry(label: "M\(index)", messageID: message.id, speaker: message.speaker, text: text,
                         sourceAt: message.sourceAt, clipped: cleaned.count > limit || message.textTruncated, originalText: message.text)
        }
        return Self(sessionID: session.id, sourceUpdatedAt: session.updatedAt, storedMessages: storedMessages, entries: entries)
    }
    public func narrowed() -> Self {
        guard entries.count > 4 else { return self }
        // Retain the opening context and the most recent exchange. Labels never change.
        var selected = [entries[0]] + Array(entries.suffix(max(3, entries.count / 2)))
        let required = Array(entries.filter { $0.speaker == "user" }.suffix(2)) + Array(entries.filter { $0.speaker == "assistant" }.suffix(1))
        for entry in required where !selected.contains(where: { $0.messageID == entry.messageID }) { selected.append(entry) }
        let ids = Set(selected.map(\.messageID))
        return Self(sessionID: sessionID, sourceUpdatedAt: sourceUpdatedAt, storedMessages: storedMessages,
                    entries: entries.filter { ids.contains($0.messageID) })
    }
    public func clipped(to limit: Int) -> Self {
        Self(sessionID: sessionID, sourceUpdatedAt: sourceUpdatedAt, storedMessages: storedMessages,
             entries: entries.map { Entry(label: $0.label, messageID: $0.messageID, speaker: $0.speaker,
                                           text: String($0.text.prefix(max(40, limit))), sourceAt: $0.sourceAt,
                                           clipped: $0.clipped || $0.text.count > limit, originalText: $0.originalText) })
    }
    public func evidence(_ draft: BriefEvidence) -> BriefEvidence? {
        guard let entry = entries.first(where: { $0.label == draft.messageID }),
              draft.quote.count >= 5, draft.quote.count <= 300, entry.text.contains(draft.quote), entry.originalText.contains(draft.quote) else { return nil }
        return BriefEvidence(messageID: entry.messageID, quote: draft.quote, speaker: entry.speaker, sourceAt: entry.sourceAt)
    }
    public func validate(goal: String, goalCitation: BriefEvidence, moments drafts: [BriefMomentDraft], nextStep: String,
                         generatedAt: Date = Date(), engine: String = "Apple on-device · v1") -> WorkBrief {
        let goalEvidence = evidence(goalCitation).flatMap { $0.speaker == "user" ? $0 : nil }
        let fallback = entries.first { $0.speaker == "user" }.flatMap { SessionDisplay.excerpt($0.text) } ?? "Revisit your latest instructions."
        var accepted: [BriefMoment] = [], seen: Set<String> = [], omitted = 0
        for draft in drafts.prefix(4) {
            guard !Self.unsupportedJudgment(draft.title + " " + draft.detail) else { omitted += 1; continue }
            let receipts = draft.evidence.compactMap(evidence)
            let userIDs = Set(receipts.filter { $0.speaker == "user" }.map(\.messageID))
            guard !receipts.isEmpty, receipts.count == draft.evidence.count,
                  (draft.kind == .choice || !userIDs.isEmpty),
                  (![BriefMomentKind.handoff, .repair].contains(draft.kind) || userIDs.count >= 2) else { omitted += 1; continue }
            if draft.kind == .choice {
                let source = receipts.map(\.quote).joined(separator: " ")
                guard source.range(of: #"(?i)\b(or|option|alternative|either|versus|vs)\b"#, options: .regularExpression) != nil else { omitted += 1; continue }
            }
            let key = draft.kind.rawValue + "|" + receipts.map(\.messageID).sorted().joined(separator: "|")
            guard seen.insert(key).inserted else { omitted += 1; continue }
            let id = MetadataBoundary.hash(key, salt: sessionID)
            accepted.append(BriefMoment(id: id, kind: draft.kind, title: Self.safe(draft.title, limit: 90),
                                        detail: Self.safe(draft.detail, limit: 440), evidence: receipts))
        }
        return WorkBrief(sessionID: sessionID, inputDigest: inputDigest, sourceUpdatedAt: sourceUpdatedAt, generatedAt: generatedAt,
                         goal: goalEvidence == nil ? fallback : Self.safe(goal, limit: 220), goalEvidence: goalEvidence,
                         moments: accepted, nextStep: Self.unsupportedJudgment(nextStep) || nextStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || nextStep.range(of: #"(?i)review (the |your )?(generated |session |local )?brief"#, options: .regularExpression) != nil ? "Choose one concrete acceptance check for this goal, then compare the observed behavior with it before asking for another change." : Self.safe(nextStep, limit: 450), reviewedMessages: entries.count,
                         storedMessages: storedMessages, clippedMessages: entries.filter(\.clipped).count,
                         missingSourceTimes: entries.filter { $0.sourceAt == nil }.count, omittedSuggestions: omitted, engine: engine)
    }
    private static func unsupportedJudgment(_ text: String) -> Bool {
        text.range(of: #"(?i)\b(fatigue|strain|IQ|dementia|cognitive decline|brain atrophy|disengaged|overthinking|lazy|exhausted|tired|intelligence|overquestioning)\b|\byou (never|didn't|did not) (read|review|understand|verify|check)|\b(reduc\w*|fewer|less)\s+(AI\s+)?(question\w*|check\w*)"#, options: .regularExpression) != nil
    }
    private static func safe(_ text: String, limit: Int) -> String {
        String(ConversationBoundary.redact(text).text.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
