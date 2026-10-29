import Foundation

/// Model-selectable spans are made by the app. The model never has to reproduce a quotation.
public struct WorkWitness: Sendable {
    public let id: String
    public let sourceID: String
    public let quote: String
}
public struct WorkWitnessPacket: Sendable {
    public let witnesses: [WorkWitness]
    public let promptData: String
    public init(context: DecisionContext) {
        var spans: [WorkWitness] = [], records: [[String: Any]] = []
        for source in context.sources {
            let limit = source.role == "assistant" ? 650 : 1400
            let visible = source.origin == .mixed ? source.novelText : source.text
            let text = String(visible.prefix(limit))
            var entries: [[String: String]] = []
            for text in text.components(separatedBy: .newlines) {
            var start = text.startIndex
            while start < text.endIndex && entries.count < 12 {
                var end = text.index(start, offsetBy: 140, limitedBy: text.endIndex) ?? text.endIndex
                if end != text.endIndex {
                    let tail = text.index(end, offsetBy: -30, limitedBy: start) ?? start
                    if let space = text[tail..<end].lastIndex(where: { $0.isWhitespace }) { end = space }
                }
                guard end > start else { break }
                let quote = String(text[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
                if quote.rangeOfCharacter(from: .alphanumerics) != nil && (source.originalText ?? source.text).contains(quote) && source.text.contains(quote) {
                    let id = "W\(spans.count)"
                    spans.append(.init(id: id, sourceID: source.id, quote: quote))
                    entries.append(["witnessID": id, "quotedText": quote])
                }
                start = end
                while start < text.endIndex && text[start].isWhitespace { start = text.index(after: start) }
            }
            }
            var record: [String: Any] = ["sourceID": source.id, "speaker": source.role, "origin": source.origin.rawValue,
                "scope": source.sessionID == context.sessionID ? "current conversation" : "retrieved candidate, task link unconfirmed", "spans": entries]
            if source.role == "user_report" {
                let report = context.perspectives.first { "feedback:" + $0.id == source.messageID }
                record["perspectiveAboutSource"] = context.sources.first { $0.messageID == report?.anchorMessageID }?.id ?? "unlinked earlier request"
            }
            records.append(record)
        }
        witnesses = spans
        let packet: [String: Any] = ["currentHumanAnchor": context.anchorID, "sources": records,
            "previousHypothesisNotFact": context.earlierAccount ?? "none", "coverage": "A bounded, possibly incomplete excerpt. Saved statements are not proof of private intentions or understanding."]
        promptData = String(decoding: (try? JSONSerialization.data(withJSONObject: packet, options: [.sortedKeys])) ?? Data(), as: UTF8.self)
    }
    public func witness(_ id: String) -> WorkWitness? { witnesses.first { $0.id == id } }
}
