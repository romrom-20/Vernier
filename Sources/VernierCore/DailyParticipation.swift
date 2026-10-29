import Foundation

/// Calendar days use the chosen local time zone, including 23/25-hour days. Observation time never substitutes for source time.
public struct WorkDay: Equatable, Sendable {
    public let start: Date
    public let end: Date
    public let timeZoneID: String
    public let key: String
    public init(containing date: Date, calendar: Calendar = .current) {
        start = calendar.startOfDay(for: date)
        end = calendar.date(byAdding: .day, value: 1, to: start)!
        timeZoneID = calendar.timeZone.identifier
        let c = calendar.dateComponents([.year, .month, .day], from: start)
        key = String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!) + "@" + timeZoneID
    }
    public func contains(_ date: Date) -> Bool { date >= start && date < end }
}
public enum DailyAction: String, CaseIterable, Sendable {
    case continued, directed, checked, reported, other
    public var label: String {
        switch self {
        case .continued: "Handed back"
        case .directed: "Added direction"
        case .checked: "Asked to check"
        case .reported: "Reported a result"
        case .other: "Other / unclear"
        }
    }
    public var definition: String {
        switch self {
        case .continued: "Brief assent or a plain continuation, with no added requirement in the saved words."
        case .directed: "Wording adds a requirement, constraint, correction or choice."
        case .checked: "Wording asks for a test, explanation, comparison or evidence. A request does not prove a check was completed."
        case .reported: "Wording reports a first-person attempt or observed result; the result is self-reported."
        case .other: "Other wording, a brief repair request, known copied text or a meaning these rules cannot resolve."
        }
    }
}
public struct DailyMoment: Identifiable, Sendable {
    public let id: String
    public let sessionID: String
    public let workspaceID: String
    public let at: Date
    public let action: DailyAction
    public let excerpt: String
    public let agentID: String?
    public let repairOnly: Bool
    public let knownCopiedText: Bool
}
public struct DailyProject: Identifiable, Sendable {
    public let id: String
    public let sessionIDs: [String]
    public let moments: [DailyMoment]
    public var continued: Int { moments.filter { $0.action == .continued }.count }
    public var checked: Int { moments.filter { $0.action == .checked }.count }
}
public struct DailyHour: Identifiable, Sendable {
    public let at: Date
    public let moments: [DailyMoment]
    public var id: Date { at }
}
public struct DailyThread: Identifiable, Sendable {
    public let id: String
    public let anchorID: String
    public let excerpt: String
}
public struct DailyInput: Sendable {
    public let messages: [ConversationMessage]
    public let datedTotal: Int
    public let undatedTotal: Int
    public let precedingContext: [ConversationMessage]
    public init(messages: [ConversationMessage], datedTotal: Int, undatedTotal: Int, precedingContext: [ConversationMessage] = []) {
        self.messages = messages; self.datedTotal = datedTotal; self.undatedTotal = undatedTotal; self.precedingContext = precedingContext
    }
}
/// A descriptive breakdown of recorded follow-ups, never a percentage of tasks, brain use or time spent thinking.
public struct DailyParticipation: Sendable {
    public let day: WorkDay
    public let moments: [DailyMoment]
    public let hours: [DailyHour]
    public let agentOnlyThreads: [DailyThread]
    public let projects: [DailyProject]
    public let loadedMessages: Int
    public let datedTotal: Int
    public let undatedTotal: Int
    public let partialHistory: Bool
    public let clippedMessages: Int
    public var followUps: Int { moments.count }
    public var limited: Bool { loadedMessages < datedTotal || partialHistory || clippedMessages > 0 }
    public func count(_ action: DailyAction) -> Int { moments.filter { $0.action == action }.count }
    public func percent(_ action: DailyAction) -> Int? {
        followUps == 0 ? nil : Int((100.0 * Double(count(action)) / Double(followUps)).rounded())
    }
    public var longestContinuation: [DailyMoment] {
        var best: [DailyMoment] = []
        for group in Dictionary(grouping: moments, by: \.sessionID).values {
            var streak: [DailyMoment] = []
            for m in group.sorted(by: { $0.at == $1.at ? $0.id < $1.id : $0.at < $1.at }) {
                if m.action == .continued { streak.append(m) } else { streak = [] }
                if streak.count > best.count || (streak.count == best.count && (streak.last?.at ?? .distantPast) > (best.last?.at ?? .distantPast)) { best = streak }
            }
        }
        return best
    }
    public var repairRequests: [DailyMoment] { moments.filter(\.repairOnly) }
    public var takeaway: String {
        guard followUps > 0 else { return "Your day takes shape as saved conversations arrive." }
        if longestContinuation.count >= 3 { return "You handed the next step back \(longestContinuation.count) times in a row in one conversation." }
        if repairRequests.count >= 2 { return "\(repairRequests.count) brief repair requests are worth a closer look." }
        if count(.checked) > 0 { return "You asked for checks or explanations in \(count(.checked)) of \(followUps) follow-ups." }
        if count(.continued) > 0 { return "\(count(.continued)) of \(followUps) replies asked AI to carry on." }
        if count(.directed) > 0 { return "\(count(.directed)) replies added a condition, choice or correction." }
        if count(.reported) > 0 { return "\(count(.reported)) replies reported a result from a personal check." }
        return followUps == 1 ? "One saved reply is too little to describe a daily pattern." : "These replies don’t fit the simple wording categories yet."
    }
    public static func make(day: WorkDay, input: DailyInput, sessions: [SessionMetadata], coverage: [MemoryCoverage] = []) -> Self {
        let relevant = input.messages.filter { $0.sourceAt.map(day.contains) == true && ["user", "assistant"].contains($0.speaker) }
        var moments: [DailyMoment] = []
        var agentOnly: [DailyThread] = []
        let workspace = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0.workspaceID) })
        for (sessionID, messages) in Dictionary(grouping: relevant, by: \.sessionID) {
            let preceding = input.precedingContext.filter { $0.sessionID == sessionID && ($0.sourceAt ?? .distantFuture) < day.start }.max { ($0.sourceAt ?? .distantPast) < ($1.sourceAt ?? .distantPast) }
            let contextualMessages = messages + (preceding.map { [$0] } ?? [])
            let story = SessionStory.make(sessionID: sessionID, messages: contextualMessages, storedMessages: contextualMessages.count)
            if story.followUps == 0, story.agentMessages > 0, let first = story.runs.first(where: { $0.isUser && $0.messages.contains { $0.sourceAt.map(day.contains) == true } }), let anchor = first.messages.first(where: { $0.sourceAt.map(day.contains) == true }) {
                agentOnly.append(.init(id: sessionID, anchorID: anchor.id, excerpt: String(SessionDisplay.visibleText(anchor.text).prefix(180))))
            }
            let sources = story.runs.flatMap(\.messages).map { m in DecisionSource(id: m.id, messageID: m.id, sessionID: m.sessionID, role: m.speaker, text: SessionDisplay.visibleText(m.text)) }
            let annotated = Dictionary(uniqueKeysWithValues: SourceAttribution.annotate(sources).map { ($0.id, $0) })
            var previousAgent: ConversationMessage?
            for message in story.runs.flatMap(\.messages) {
                if message.speaker == "assistant" { previousAgent = message; continue }
                guard message.speaker == "user", let agent = previousAgent, let time = message.sourceAt, day.contains(time), let source = annotated[message.id] else { continue }
                let text = humanText(source.novelText)
                let copied = source.origin == .reusedAgent
                var action = copied || message.textTruncated ? DailyAction.other : classify(text)
                if action == .continued, SessionDisplay.visibleText(agent.text).trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("?"),
                   !PromptSignals.isContinuationCue(text), !matches(#"\b(?:go ahead|proceed|continue|do it|finish|keep going)\b"#, text) { action = .other }
                moments.append(.init(id: message.id, sessionID: sessionID, workspaceID: workspace[sessionID] ?? sessionID, at: time,
                    action: action, excerpt: String(humanText(message.text).prefix(220)), agentID: agent.id,
                    repairOnly: !copied && !message.textTruncated && isBriefRepair(text), knownCopiedText: copied))
            }
        }
        moments.sort { $0.at == $1.at ? $0.id < $1.id : $0.at < $1.at }
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: day.timeZoneID) ?? .current
        let groupedHours = Dictionary(grouping: moments) { cal.dateInterval(of: .hour, for: $0.at)!.start }
        let hours = groupedHours.map { DailyHour(at: $0.key, moments: $0.value) }.sorted { $0.at < $1.at }
        let groupedProjects = Dictionary(grouping: moments, by: \.workspaceID)
        var projects: [DailyProject] = []
        for (id, values) in groupedProjects {
            let ids = Array(Set(values.map(\.sessionID))).sorted()
            projects.append(DailyProject(id: id, sessionIDs: ids, moments: values))
        }
        projects.sort { left, right in
            if left.moments.count == right.moments.count { return left.id < right.id }
            return left.moments.count > right.moments.count
        }
        let used = Set(relevant.map(\.sessionID))
        let partial = used.contains { id in coverage.first { $0.sessionID == id }?.complete != true }
        return Self(day: day, moments: moments, hours: hours, agentOnlyThreads: agentOnly.sorted { $0.id < $1.id }, projects: projects, loadedMessages: relevant.count, datedTotal: input.datedTotal,
                    undatedTotal: input.undatedTotal, partialHistory: partial, clippedMessages: relevant.filter(\.textTruncated).count)
    }
    /// Display/input cleanup only. Original records remain unchanged and open through the source link.
    public static func humanText(_ raw: String) -> String {
        SessionDisplay.visibleText(raw).replacingOccurrences(of: #"\.context/attachments/[^\n]+?\.(?:png|jpe?g|webp|gif|heic|txt|md|pdf)(?=\s|$)"#, with: "", options: [.regularExpression, .caseInsensitive]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private static func matches(_ pattern: String, _ text: String) -> Bool { text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil }
    public static func isBriefRepair(_ text: String) -> Bool {
        matches(#"^\s*(?:(?:please|again|it['’]s|that['’]s)\s+)*(?:fix (?:it|this|that)|still (?:broken|not working)|same (?:bug|error|problem)|try again)[.!\s]*$"#, text)
    }
    public static func classify(_ text: String) -> DailyAction {
        guard !text.isEmpty, !isBriefRepair(text) else { return .other }
        // Negated assertions and questions are not a report of a completed check.
        if matches(#"\bI (?:tried|tested|replayed|reproduced|checked|ran)\b"#, text), !matches(#"\b(?:haven['’]t|have not|didn['’]t|did not|couldn['’]t|could not|if I|when I|should I|can I|before I)\b"#, text) { return .reported }
        let noCheck = matches(#"\b(?:do not|don't|no need to|skip|avoid)\s+(?:test|verify|explain|check|compare|reproduce)\b"#, text)
        if matches(#"\b(?:why|how|understand)\b"#, text) || text.contains("?") || (!noCheck && matches(#"\b(?:test|verify|explain|compare|reproduce|prove|check)\b"#, text)) { return .checked }
        if noCheck { return .directed }
        if matches(#"\b(?:must|only|instead|keep|don['’]t|do not|without|rather than|I (?:want|choose|prefer)|use .+ because|expected|should)\b"#, text) { return .directed }
        if WorkReading.isBriefAssent(text) || PromptSignals.isContinuationCue(text) || matches(#"^\s*(?:please\s+)?(?:continue|proceed|keep going|carry on|finish (?:it|this|that|what you were doing))[.!\s]*$"#, text) { return .continued }
        return .other
    }
}

public struct DailyReflection: Codable, Sendable {
    public enum Clarity: String, Codable, CaseIterable, Sendable { case clear = "Clear", mixed = "Mixed", revisit = "Need to revisit" }
    public enum Energy: String, Codable, CaseIterable, Sendable { case steady = "Steady", tired = "Tired", unsure = "Not sure" }
    public let dayKey: String
    public let dayStart: Date
    public let clarity: Clarity?
    public let energy: Energy?
    public let note: String
    public let updatedAt: Date
    public init(day: WorkDay, clarity: Clarity?, energy: Energy?, note: String, updatedAt: Date = Date()) {
        dayKey = day.key; dayStart = day.start; self.clarity = clarity; self.energy = energy; self.note = note; self.updatedAt = updatedAt
    }
}
