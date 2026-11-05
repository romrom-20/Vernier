import Foundation

/// A read-only casebook of possible links. These snapshots never merge tasks
/// or promote an earlier interpretation into current authority.
public struct RelatedConversationMemory: Sendable, Equatable {
    public struct Statement: Identifiable, Sendable, Equatable {
        public let id: String
        public let messageID: String
        public let speaker: String
        public let quote: String
        public let date: Date?
        public let isPerspective: Bool
    }
    public struct Candidate: Identifiable, Sendable, Equatable {
        public let sessionID: String
        public let earlierGoal: String
        public let readingCreatedAt: Date
        public let matchedWords: [String]
        public let statements: [Statement]
        public let hasNewerPerspective: Bool
        public var id: String { sessionID }
    }
    public let sessionID: String
    public let anchorMessageID: String
    public let candidates: [Candidate]
    public let consideredConversations: Int
    public static func keywords(_ text: String) -> Set<String> {
        let stop = Set("this that with from have want make work does again still please should there their when then only same been what your agent keep trying question answer explain user model before after just current change text request code earlier original remind other another conversation thread chose choose choice agreed".split(separator: " ").map(String.init))
        return Set(text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count >= 4 && !stop.contains($0) })
    }
}
