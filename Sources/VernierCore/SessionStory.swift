import Foundation

/// A projection of recorded messages, separate from model interpretations and mental-state claims.
public struct StoryRun: Identifiable, Sendable {
    public let id: String
    public let speaker: String
    public let messages: [ConversationMessage]
    public let priorAgentMessages: Int
    public var isUser: Bool { speaker == "user" }
    public var sourceAt: Date? { messages.first?.sourceAt }
    public var representative: ConversationMessage? { isUser ? messages.last : (messages.last { $0.phase == "final_answer" } ?? messages.last) }
    public var excerpt: String { SessionDisplay.visibleText(representative?.text ?? "") }
    public var progressExcerpt: String? {
        guard !isUser, let last = messages.last, last.id != representative?.id else { return nil }
        return String(SessionDisplay.visibleText(last.text).prefix(180))
    }
    public var sourceQuote: String {
        let original = representative?.text ?? ""
        let cleaned = String(SessionDisplay.visibleText(original).prefix(160))
        if original.contains(cleaned) { return cleaned }
        return original.components(separatedBy: .newlines).first { line in
            line.count >= 5 && !line.hasPrefix("<") && cleaned.contains(line)
        } ?? ""
    }
}

public struct SessionStory: Sendable {
    public let sessionID: String
    public let runs: [StoryRun]
    public let loadedMessages: Int
    public let storedMessages: Int
    public let missingSourceTimes: Int
    public let userMessages: Int
    public let agentMessages: Int
    public var followUps: Int { runs.filter { $0.isUser && $0.priorAgentMessages > 0 }.count }
    public var longestAgentRun: Int { runs.filter { !$0.isUser }.map { $0.messages.count }.max() ?? 0 }
    public var signature: String { runs.map { $0.id + ":" + String($0.messages.count) }.joined(separator: "|") }
    public var latestFollowUp: StoryRun? { runs.last { $0.isUser && $0.priorAgentMessages > 0 } }
    public func run(containing messageID: String) -> StoryRun? { runs.first { $0.messages.contains { $0.id == messageID } } }

    public static func make(sessionID: String, messages: [ConversationMessage], storedMessages: Int) -> Self {
        let scoped = messages.filter { $0.sessionID == sessionID }
        let sorted = scoped.sorted {
            let left = $0.sourceAt ?? $0.observedAt, right = $1.sourceAt ?? $1.observedAt
            return left == right ? $0.id < $1.id : left < right
        }
        var groups: [[ConversationMessage]] = []
        for message in sorted where ["user", "assistant"].contains(message.speaker) && !SessionDisplay.visibleText(message.text).isEmpty {
            if let last = groups.last?.last, last.speaker == message.speaker,
               message.speaker == "assistant" || last.turnID == message.turnID { groups[groups.count - 1].append(message) }
            else { groups.append([message]) }
        }
        let runs = groups.enumerated().map { index, group in
            StoryRun(id: group[0].id, speaker: group[0].speaker, messages: group,
                     priorAgentMessages: index > 0 && group[0].speaker == "user" && groups[index - 1][0].speaker == "assistant" ? groups[index - 1].count : 0)
        }
        return Self(sessionID: sessionID, runs: runs, loadedMessages: scoped.count, storedMessages: storedMessages,
                    missingSourceTimes: scoped.filter { $0.sourceAt == nil }.count,
                    userMessages: groups.flatMap { $0 }.filter { $0.speaker == "user" }.count,
                    agentMessages: groups.flatMap { $0 }.filter { $0.speaker == "assistant" }.count)
    }
}
