import Foundation

/// A reading of a recorded exchange. The rules identify explicit wording in context;
/// they do not measure understanding, attention, review, or task success.
public enum ParticipationKind: String, Sendable {
    case returnedIssue, requestedEvidence, setBoundary, soughtExplanation, continued, instruction
    public var title: String {
        switch self {
        case .returnedIssue: "You came back to a problem."
        case .requestedEvidence: "You asked for a concrete check."
        case .setBoundary: "You made your requirement explicit."
        case .soughtExplanation: "You asked for an explanation."
        case .continued: "You let the agent continue."
        case .instruction: "Start with what you asked for."
        }
    }
    public var label: String {
        switch self {
        case .returnedIssue: "Returning to a problem"
        case .requestedEvidence: "Asking for evidence"
        case .setBoundary: "Setting direction"
        case .soughtExplanation: "Seeking an explanation"
        case .continued: "Letting the agent continue"
        case .instruction: "Your instruction"
        }
    }
    public var significance: String {
        switch self {
        case .returnedIssue: "You reported a problem after an agent reply, with related wording in an earlier request. This is a place to see whether the explanation or the check became more specific."
        case .requestedEvidence: "Your follow-up asked for a test or observable result. That gives you something to judge beyond the agent’s description of its work."
        case .setBoundary: "You added an explicit condition after the agent replied. That is a visible contribution from you to the direction of the work."
        case .soughtExplanation: "You returned to the explanation. The request shows an attempt to make sense of the work; whether the explanation helped remains yours to judge."
        case .continued: "You asked the agent to continue without adding a new condition in that message. The preceding reply shows what you were letting it carry forward."
        case .instruction: "This is a saved request from you. There is not enough explicit evidence here to describe a change in your participation."
        }
    }
    public var shortReading: String {
        switch self {
        case .returnedIssue: "A related issue appeared again after the agent replied. See what you said changed—or stayed unresolved."
        case .requestedEvidence: "You followed the agent’s reply with a request for a test or observable result."
        case .setBoundary: "After the agent replied, you spelled out a condition for what should happen next."
        case .soughtExplanation: "You followed the agent’s reply with a request for an explanation."
        case .continued: "After the agent replied, you gave it a short instruction to carry on."
        case .instruction: "Open the surrounding exchange to see what you were asking the agent to do."
        }
    }
    var priority: Int {
        switch self {
        case .returnedIssue, .requestedEvidence: 4
        case .setBoundary, .soughtExplanation: 3
        case .continued: 1
        case .instruction: 0
        }
    }
}

public struct ParticipationSource: Identifiable, Sendable {
    public let messageID: String
    public let speaker: String
    public let label: String
    public let quote: String
    public var id: String { label + ":" + messageID }
}

public struct ParticipationMoment: Identifiable, Sendable {
    public let sessionID: String
    public let anchorID: String
    public let kind: ParticipationKind
    public let sourceAt: Date
    public let sources: [ParticipationSource]
    public var id: String { sessionID + ":" + anchorID + ":" + kind.rawValue }
    public var userSource: ParticipationSource? { sources.first { $0.messageID == anchorID } }
    public var followingReply: ParticipationSource? { sources.first { $0.label == "The agent replied afterward" } }
    public var precedingReply: ParticipationSource? { sources.first { $0.label == "The agent had replied" } }
}

public enum ParticipationReview {
    public static func make(story: SessionStory, since: Date, until: Date) -> [ParticipationMoment] {
        var moments: [ParticipationMoment] = []
        for (index, run) in story.runs.enumerated() where run.isUser {
            guard let message = run.representative, let time = message.sourceAt, time >= since, time <= until else { continue }
            let text = SessionDisplay.visibleText(message.text)
            guard !text.isEmpty else { continue }
            let agent = index > 0 && !story.runs[index - 1].isUser ? story.runs[index - 1] : nil
            let earlier = story.runs.prefix(index).last(where: \.isUser)
            let kind = classify(text, hasPrecedingAgent: agent != nil, earlier: earlier?.excerpt)
            var sources: [ParticipationSource] = []
            if (kind == .returnedIssue || kind == .continued), let earlier, let value = source(earlier, label: "Earlier, you asked") { sources.append(value) }
            if let agent, let value = source(agent, label: "The agent had replied") {
                sources.append(value)
                if let last = agent.messages.last, last.id != agent.representative?.id,
                   SessionDisplay.visibleText(last.text).range(of: #"(?i)\b(build|test|fail|result|error)\w*\b"#, options: .regularExpression) != nil {
                    let report = StoryRun(id: last.id, speaker: last.speaker, messages: [last], priorAgentMessages: 0)
                    if let progress = source(report, label: "The agent also reported") { sources.append(progress) }
                }
            }
            if let value = source(run, label: agent == nil ? "You asked" : "Then you said", focus: kind) { sources.append(value) }
            if index + 1 < story.runs.count, !story.runs[index + 1].isUser,
               let value = source(story.runs[index + 1], label: "The agent replied afterward") { sources.append(value) }
            guard sources.contains(where: { $0.messageID == message.id }) else { continue }
            moments.append(ParticipationMoment(sessionID: story.sessionID, anchorID: message.id, kind: kind, sourceAt: time, sources: sources))
        }
        return ordered(moments)
    }

    public static func ordered(_ moments: [ParticipationMoment]) -> [ParticipationMoment] {
        moments.sorted { left, right in
            if left.kind.priority != right.kind.priority { return left.kind.priority > right.kind.priority }
            if left.sourceAt != right.sourceAt { return left.sourceAt > right.sourceAt }
            return left.id < right.id
        }
    }

    private static func source(_ run: StoryRun, label: String, focus: ParticipationKind? = nil) -> ParticipationSource? {
        guard let message = run.representative else { return nil }
        var quote = run.sourceQuote
        if let focus {
            let pattern: String
            switch focus {
            case .returnedIssue: pattern = #"(?i)\b(again|still|same|keeps?|not fixed)\b"#
            case .requestedEvidence: pattern = #"(?i)\b(test|verify|run|reproduce|check|compare|show)\b"#
            case .setBoundary: pattern = #"(?i)\b(instead|do not|don't|must|keep|i want|rather than)\b"#
            case .soughtExplanation: pattern = #"(?i)\b(explain|understand|why|how)\b"#
            default: pattern = "^"
            }
            let visible = run.excerpt
            if let match = visible.range(of: pattern, options: .regularExpression) {
                let start = visible.index(match.lowerBound, offsetBy: -45, limitedBy: visible.startIndex) ?? visible.startIndex
                let end = visible.index(start, offsetBy: 210, limitedBy: visible.endIndex) ?? visible.endIndex
                let focused = String(visible[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
                if message.text.contains(focused) { quote = focused }
            }
        }
        guard quote.count >= 5, message.text.contains(quote) else { return nil }
        return ParticipationSource(messageID: message.id, speaker: message.speaker, label: label, quote: quote)
    }

    private static func classify(_ text: String, hasPrecedingAgent: Bool, earlier: String?) -> ParticipationKind {
        guard hasPrecedingAgent else { return .instruction }
        func matches(_ pattern: String) -> Bool { text.range(of: pattern, options: .regularExpression) != nil }
        let recurrence = matches(#"(?i)\b(?:still.{0,40}(?:fail|broken|not work|doesn't|does not)|(?:same|again).{0,50}(?:bug|issue|problem|error|duplicate)|(?:bug|issue|problem|error|duplicate)\w*.{0,25}again|keeps? .{0,25}(?:fail|glitch|closing|opening)|not fixed|doesn't work|does not work)\b"#)
        if recurrence, !matches(#"(?i)\b(?:what if|suppose|imagine|hypothetical)\b"#), let earlier, sharedTerms(text, earlier) >= 2 { return .returnedIssue }
        if matches(#"(?i)(?:^|[.!?]\s*|\b(?:please|you|then|and)\s+)(?:test|verify|reproduce)\b|\b(?:run.{0,60}(?:twice|same)|(?:show|compare).{0,50}(?:before.and.after|expected|actual|results?|counts?)|before shipping.{0,50}check)\b"#) { return .requestedEvidence }
        if !matches(#"(?i)\b(?:do not|don't|stop|no need to)\s+explain\b"#),
           matches(#"(?i)\b(?:explain|help me understand|i (?:don't|do not) (?:understand|know)|why (?:did|does|is|are|would|was|were)|how (?:does|did|would).{0,40}work)\b"#) { return .soughtExplanation }
        if matches(#"(?i)\b(?:instead|(?:do not|don't)\s+(?:change|add|remove|redesign|open|close|use|show|build|make|collect|capture|start|ship|deploy|explain|count|focus)|must|should only|keep.{0,50}(?:scope|only|without)|i (?:don't|do not) want|i want|that's not|that isn't|rather than)\b"#) { return .setBoundary }
        if PromptSignals.isContinuationCue(text) { return .continued }
        return .instruction
    }

    private static func sharedTerms(_ first: String, _ second: String) -> Int {
        let stop = Set(["this", "that", "with", "from", "have", "want", "make", "work", "does", "again", "still", "please", "should", "there", "their", "when", "then", "only", "same", "been", "what", "your", "agent"])
        func terms(_ value: String) -> Set<String> {
            let words = value.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
            return Set(words.filter { $0.count >= 4 && !stop.contains($0) }.map { word in
                word.count > 4 && word.hasSuffix("s") ? String(word.dropLast()) : word
            })
        }
        return terms(first).intersection(terms(second)).count
    }
}
