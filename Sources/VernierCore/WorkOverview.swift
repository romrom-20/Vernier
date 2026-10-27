import Foundation

/// Transparent wording cues, never a measurement of delegation, attention or understanding.
public enum RequestCue: String, CaseIterable, Sendable {
    case goAhead, handoff, question, direction, other
    public var title: String {
        switch self {
        case .goAhead: "Go-ahead only"
        case .handoff: "Task-first wording"
        case .question: "Questions & checks"
        case .direction: "Constraints & corrections"
        case .other: "Other wording"
        }
    }
    public static func classify(_ raw: String) -> Self {
        let text = SessionDisplay.visibleText(raw)
        if PromptSignals.isContinuationCue(text) { return .goAhead }
        func matches(_ pattern: String) -> Bool { text.range(of: pattern, options: .regularExpression) != nil }
        if matches(#"(?i)\b(test|verify|check|explain|why|how|understand|compare|reproduce|prove)\b"#) || text.contains("?") { return .question }
        if matches(#"(?i)\b(instead|only|must|should|don't|do not|keep|stop|wrong|still|again|rather)\b"#) { return .direction }
        if matches(#"(?i)^\s*(?:(?:please|can you|could you|let['’]s)\s+)?(?:build|make|implement|add|fix|create|update|change|remove|refactor|ship|deploy|write)\b"#) { return .handoff }
        return .other
    }
}

public struct WorkRequest: Identifiable, Sendable {
    public let message: ConversationMessage
    public let cue: RequestCue
    public var id: String { message.id }
    public var excerpt: String { String(SessionDisplay.visibleText(message.text).prefix(180)) }
}

public struct WorkSession: Identifiable, Sendable {
    public let session: SessionMetadata
    public let requests: [WorkRequest]
    public let loadedMessages: Int
    public let storedMessages: Int
    public let memoryComplete: Bool
    public let latestSpeaker: String?
    public let agentLast: ConversationMessage?
    public let lastOutcome: SessionOutcome?
    public var id: String { session.id }
    public var hasRecordedFailure: Bool { lastOutcome == .failed }
    public var hasPartialMemory: Bool { !memoryComplete || loadedMessages < storedMessages }
}

public struct WorkOverview: Sendable {
    public let sessions: [WorkSession]
    public let eligibleSessions: Int
    public let since: Date
    public let until: Date
    public var requests: [WorkRequest] { sessions.flatMap(\.requests).sorted {
        let a = $0.message.sourceAt!, b = $1.message.sourceAt!
        return a == b ? $0.id < $1.id : a > b
    } }
    public var workspaces: Int { Set(sessions.map { $0.session.workspaceID }).count }
    public var agentLastCount: Int { sessions.filter { $0.agentLast != nil }.count }
    public var failureCount: Int { sessions.filter(\.hasRecordedFailure).count }
    public var loadedMessages: Int { sessions.reduce(0) { $0 + $1.loadedMessages } }
    public var storedMessages: Int { sessions.reduce(0) { $0 + $1.storedMessages } }
    public func count(_ cue: RequestCue) -> Int { requests.filter { $0.cue == cue }.count }

    public static func make(library: SessionLibrary, messages: [ConversationMessage], now: Date, limit: Int = 24) -> Self {
        let since = now.addingTimeInterval(-86400)
        let eligible = library.sessions.filter { $0.updatedAt >= since && $0.createdAt <= now }.sorted {
            $0.updatedAt == $1.updatedAt ? $0.id < $1.id : $0.updatedAt > $1.updatedAt
        }
        let grouped = Dictionary(grouping: messages, by: \.sessionID)
        let turns = Dictionary(grouping: library.turns, by: \.sessionID)
        // Give quieter workspaces a slot before filling remaining slots by recency.
        var seen = Set<String>()
        let representatives = eligible.filter { seen.insert($0.workspaceID).inserted }
        let representativeIDs = Set(representatives.map(\.id))
        let remaining: [SessionMetadata] = eligible.filter { !representativeIDs.contains($0.id) }
        let prioritized: [SessionMetadata] = representatives + remaining
        var selected: [SessionMetadata] = Array(prioritized.prefix(max(0, limit)))
        selected.sort { left, right in
            if left.updatedAt == right.updatedAt { return left.id < right.id }
            return left.updatedAt > right.updatedAt
        }
        let sessions = selected.map { session in
            let values = grouped[session.id] ?? []
            let story = SessionStory.make(sessionID: session.id, messages: values, storedMessages: library.digest(for: session)?.messageCount ?? values.count)
            let requests = story.runs.filter(\.isUser).flatMap(\.messages).filter {
                guard let time = $0.sourceAt else { return false }
                return time >= since && time <= now
            }.map { WorkRequest(message: $0, cue: RequestCue.classify($0.text)) }
            let last = story.runs.last?.messages.last
            let agentLast = last.flatMap { message -> ConversationMessage? in
                guard message.speaker == "assistant", let time = message.sourceAt, time >= since, time <= now else { return nil }
                return story.runs.last?.representative
            }
            let latestTurn = (turns[session.id] ?? []).max {
                let a = $0.startedAt ?? $0.observedAt, b = $1.startedAt ?? $1.observedAt
                return a == b ? $0.id < $1.id : a < b
            }
            let lastOutcome = latestTurn.flatMap { turn -> SessionOutcome? in
                guard let time = turn.startedAt, time >= since, time <= now else { return nil }
                return turn.outcome
            }
            return WorkSession(session: session, requests: requests, loadedMessages: story.loadedMessages, storedMessages: story.storedMessages,
                memoryComplete: library.memoryCoverage.first { $0.sessionID == session.id }?.complete == true,
                latestSpeaker: last?.speaker, agentLast: agentLast, lastOutcome: lastOutcome)
        }
        return Self(sessions: sessions, eligibleSessions: eligible.count, since: since, until: now)
    }
}
