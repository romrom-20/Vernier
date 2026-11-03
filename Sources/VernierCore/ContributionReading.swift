import Foundation

public struct ContributionClaim: Codable, Sendable {
    public let action: DailyAction
    public let quote: String
    public init(action: DailyAction, quote: String) { self.action = action; self.quote = quote }
}

public struct ContributionDraft: Codable, Sendable {
    public let sourceID: String
    public let primary: DailyAction
    public let claims: [ContributionClaim]
    public init(sourceID: String, primary: DailyAction, claims: [ContributionClaim]) {
        self.sourceID = sourceID; self.primary = primary; self.claims = claims
    }
}

/// A revisable model interpretation, tied to an unchanged canonical human message.
public struct ContributionReading: Codable, Sendable {
    public static let version = "contribution-1"
    public let messageID: String
    public let sessionID: String
    public let fingerprint: String
    public let primary: DailyAction
    public let claims: [ContributionClaim]
    public let accepted: Bool
    public let engine: String
    public let reviewedAt: Date
    public var explanation: String {
        guard accepted else { return "The contextual classification was withheld. This does not establish what your reply meant." }
        if primary == .other { return "The local model did not establish a clear main role from the available context." }
        let extras = claims.filter { $0.action != primary }.map { $0.action.label }
        return "The local model read this reply with its surrounding conversation as “\(primary.label)”." + (extras.isEmpty ? "" : " It also identified: " + extras.joined(separator: ", ") + ".") + " These are source-linked interpretations, not a measure of thought or understanding."
    }
    public static func targets(in context: DecisionContext) -> [DecisionSource] {
        let own = context.sources.filter { $0.sessionID == context.sessionID && ["user", "assistant"].contains($0.role) }
        return own.enumerated().filter { index, source in
            source.role == "user" && own.prefix(index).contains { $0.role == "assistant" }
        }.map(\.element)
    }
    public static func batchTargets(in context: DecisionContext, excluding: Set<String> = []) -> [DecisionSource] {
        Array(targets(in: context).filter { !excluding.contains($0.messageID) }.suffix(4))
    }
    /// The critic is fallible too. This checks actor, exact span and schema, not semantic truth.
    public static func validate(_ drafts: [ContributionDraft], supportedIDs: Set<String>, context: DecisionContext, engine: String, now: Date = Date(), excluding: Set<String> = []) -> [Self] {
        batchTargets(in: context, excluding: excluding).map { source in
            let matches = drafts.filter { $0.sourceID == source.id }
            let draft = matches.count == 1 ? matches.first : nil
            let claims = draft?.claims ?? []
            let actions = claims.map(\.action)
            let valid = supportedIDs.contains(source.id) && source.origin != .reusedAgent && source.text.count <= 1400 &&
                draft != nil && claims.count <= 4 && Set(actions).count == actions.count && !actions.contains(.other) &&
                (draft!.primary == .other ? claims.isEmpty : actions.contains(draft!.primary)) &&
                claims.allSatisfy { !$0.quote.isEmpty && $0.quote.count <= 180 && source.novelText.contains($0.quote) && (source.originalText ?? source.text).contains($0.quote) }
            return Self(messageID: source.messageID, sessionID: source.sessionID, fingerprint: source.fingerprint,
                        primary: valid ? draft!.primary : .other, claims: valid ? claims : [], accepted: valid,
                        engine: engine + " · " + version, reviewedAt: now)
        }
    }
    public static func latest(_ readings: [Self], for message: ConversationMessage) -> Self? {
        readings.filter { $0.messageID == message.id && $0.sessionID == message.sessionID && $0.fingerprint == DecisionSource.fingerprint(message) && $0.engine.hasSuffix(" · " + version) }
            .max { $0.reviewedAt < $1.reviewedAt }
    }
}
