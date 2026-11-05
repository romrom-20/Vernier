import Foundation
import CryptoKit

/// A local index of original statements, never a model-written account of what
/// someone believes. Relevance and continued validity remain unconfirmed.
public struct ConversationRecall: Codable, Sendable, Equatable {
    public static let version = "recall-1"
    public static let candidateLimit = 240
    public static let textLimit = 8192
    public static let entryLimit = 4
    public enum Reason: String, Codable, Sendable {
        case sharedWords = "shared_words", requestedReminder = "requested_reminder"
        case possibleUpdate = "possible_later_update", exchangeReply = "earlier_exchange_reply"
        public var label: String {
            switch self {
            case .sharedWords: "Earlier statement with related wording"
            case .requestedReminder: "Earlier statement found for your reminder"
            case .possibleUpdate: "A later statement that may change the context"
            case .exchangeReply: "AI reply from that earlier exchange"
            }
        }
    }
    public struct Entry: Codable, Identifiable, Sendable, Equatable {
        public let messageID: String
        public let sessionID: String
        public let fingerprint: String
        public let speaker: String
        public let quote: String
        public let sourceAt: Date?
        public let reason: Reason
        public let parentMessageID: String?
        public var id: String { messageID }
    }
    public let entries: [Entry]
    public let policyVersion: String
    public let textLimitUsed: Int
    public let scannedMessageIDs: [String]
    public let orderedHumanMessageIDs: [String]
    public let totalHumanMessages: Int
    public let scanDigest: String
    public var windowLimited: Bool { totalHumanMessages > scannedMessageIDs.count }
    public var coverage: String {
        "Searched up to \(scannedMessageIDs.count) of \(totalHumanMessages) saved human-role messages, using up to \(textLimitUsed) characters each. Earlier statements may have been updated or concern another task."
    }

    /// Hash all considered originals, including statements not finally selected.
    /// This protects an in-flight review from an edited, omitted correction.
    public static func signature(_ candidates: [ConversationMessage]) -> String {
        let values = ordered(candidates).map { $0.id + ":" + DecisionSource.fingerprint($0) }.joined(separator: "|")
        return SHA256.hash(data: Data((version + "|" + values).utf8)).map { String(format: "%02x", $0) }.joined()
    }
    public static func select(candidates: [ConversationMessage], context: DecisionContext, totalHumanMessages: Int, previousGoal: String? = nil) -> Self? {
        let scanned = Array(ordered(candidates.filter { $0.sessionID == context.sessionID && $0.speaker == "user" }).suffix(candidateLimit))
        guard let anchor = context.anchor, let anchorIndex = scanned.firstIndex(where: { $0.id == anchor.messageID }) else { return nil }
        let visibleIDs = scanned.filter { !SessionDisplay.visibleText($0.text).isEmpty }.map(\.id)
        let present = Set(context.sources.map(\.messageID))
        let earlier = Array(scanned.prefix(anchorIndex)).filter { !present.contains($0.id) }
        let reset = anchor.novelText.range(of: #"(?i)\b(?:new topic|separate issue|switch topics)\b"#, options: .regularExpression) != nil
        let reminder = anchor.novelText.range(of: #"(?i)\b(?:remind|remember|earlier|original goal|left off)\b|what (?:did|have) (?:I|we) (?:choose|decide|ask)"#, options: .regularExpression) != nil
        let preceding = context.sources.prefix { $0.id != anchor.id }.last { $0.role == "assistant" && $0.sessionID == context.sessionID }
        let query = anchor.novelText + (anchor.novelText.count < 120 && !reset ? " " + (preceding?.text ?? "") + " " + (previousGoal ?? "") : "")
        let wanted = terms(query)
        struct Candidate { let message: ConversationMessage; let quote: String; let score: Int; let order: Int }
        let ranked: [Candidate] = reset ? [] : earlier.enumerated().compactMap { position, message in
            let text = String(SessionDisplay.visibleText(message.text).prefix(textLimit))
            let excerpts = chunks(text)
            let scored = excerpts.map { quote -> (String, Int) in
                let shared = wanted.intersection(terms(quote))
                let substantive = shared.count >= 2 || shared.contains(where: { $0.count >= 6 })
                let score = substantive ? shared.count * 10 + (isUpdate(quote) ? 2 : 0) : 0
                return (quote, score)
            }
            guard let best = scored.max(by: { $0.1 < $1.1 }), best.1 > 0 || reminder else { return nil }
            return Candidate(message: message, quote: best.0, score: best.1, order: position)
        }.sorted { $0.score == $1.score ? $0.order > $1.order : $0.score > $1.score }
        var selected = Array(ranked.prefix(2)).map { item in
            entry(item.message, quote: item.quote, reason: item.score > 0 ? .sharedWords : .requestedReminder)
        }
        // Include a later possible revision even when "I withdraw that limit"
        // shares no nouns with the earlier requirement. It is still raw text.
        if let first = selected.compactMap({ selected in scanned.firstIndex { $0.id == selected.messageID } }).min(), !reset {
            let updates = scanned[(first + 1)..<anchorIndex].reversed().filter { message in
                !present.contains(message.id) && !selected.contains(where: { $0.messageID == message.id }) && isUpdate(String(SessionDisplay.visibleText(message.text).prefix(textLimit)))
            }
            for message in updates.prefix(3 - selected.count) {
                if let quote = chunks(String(SessionDisplay.visibleText(message.text).prefix(textLimit))).last(where: isUpdate) {
                    selected.append(entry(message, quote: quote, reason: .possibleUpdate))
                }
            }
        }
        guard !selected.isEmpty || !Set(visibleIDs).isSubset(of: present) || totalHumanMessages > scanned.count else { return nil }
        return Self(entries: selected, policyVersion: version, textLimitUsed: textLimit, scannedMessageIDs: scanned.map(\.id), orderedHumanMessageIDs: visibleIDs, totalHumanMessages: totalHumanMessages, scanDigest: signature(scanned))
    }
    /// Storage supplies only a reply from the same original turn. The reply is
    /// historical context, never evidence that the latest version was checked.
    public func addingReply(_ message: ConversationMessage, to parent: Entry) -> Self {
        guard entries.count < Self.entryLimit, message.sessionID == parent.sessionID, message.speaker == "assistant", !entries.contains(where: { $0.messageID == message.id }),
              let quote = Self.chunks(String(SessionDisplay.visibleText(message.text).prefix(Self.textLimit))).first else { return self }
        let next = entries + [Self.entry(message, quote: quote, reason: .exchangeReply, parent: parent.messageID)]
        return Self(entries: next, policyVersion: policyVersion, textLimitUsed: textLimitUsed, scannedMessageIDs: scannedMessageIDs, orderedHumanMessageIDs: orderedHumanMessageIDs, totalHumanMessages: totalHumanMessages, scanDigest: scanDigest)
    }
    func retainingEntries(_ ids: Set<String>) -> Self {
        Self(entries: entries.filter { ids.contains($0.messageID) }, policyVersion: policyVersion, textLimitUsed: textLimitUsed, scannedMessageIDs: scannedMessageIDs, orderedHumanMessageIDs: orderedHumanMessageIDs, totalHumanMessages: totalHumanMessages, scanDigest: scanDigest)
    }
    private static func entry(_ message: ConversationMessage, quote: String, reason: Reason, parent: String? = nil) -> Entry {
        Entry(messageID: message.id, sessionID: message.sessionID, fingerprint: DecisionSource.fingerprint(message), speaker: message.speaker, quote: quote, sourceAt: message.sourceAt, reason: reason, parentMessageID: parent)
    }
    private static func ordered(_ values: [ConversationMessage]) -> [ConversationMessage] {
        values.sorted {
            let a = $0.sourceAt ?? $0.observedAt, b = $1.sourceAt ?? $1.observedAt
            return a == b ? $0.id < $1.id : a < b
        }
    }
    private static func terms(_ text: String) -> Set<String> {
        let stop = Set("this that with from have want make work does again still please should there their when then only same been what your agent keep trying question answer explain user model before after just current change text request code earlier original requirement requirements result check checked ready proceed continue thanks okay using about into they them were which would could will implementation".split(separator: " ").map(String.init))
        return Set(text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count >= 4 && !stop.contains($0) })
    }
    private static func isUpdate(_ text: String) -> Bool {
        text.range(of: #"(?i)\b(?:withdraw|revoke|replace|revised?|instead|no longer|new topic|separate issue|switch topics)\b|\bchange\b.{0,20}\b(?:requirement|boundary|limit)\b"#, options: .regularExpression) != nil
    }
    private static func chunks(_ text: String) -> [String] {
        var result: [String] = []
        for line in text.components(separatedBy: .newlines) {
            var start = line.startIndex
            while start < line.endIndex {
                var end = line.index(start, offsetBy: 360, limitedBy: line.endIndex) ?? line.endIndex
                if end != line.endIndex, let space = line[start..<end].lastIndex(where: { $0.isWhitespace }) { end = space }
                guard end > start else { break }
                let quote = String(line[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
                if quote.count >= 8 && quote.rangeOfCharacter(from: .alphanumerics) != nil { result.append(quote) }
                start = end
                while start < line.endIndex && line[start].isWhitespace { start = line.index(after: start) }
            }
        }
        return result
    }
}
