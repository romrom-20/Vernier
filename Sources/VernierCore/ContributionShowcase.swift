import Foundation

extension ShowcaseFixtures {
    /// Hand-authored presentation labels for invented records. No inference or personal archive.
    public static func contributionReadings(library: SessionLibrary) -> [ContributionReading] {
        let labels: [String: [DailyAction]] = [
            "showcase-story-message-3": [.reported, .directed],
            "showcase-story-message-6": [.checked],
            "showcase-story-message-9": [.directed],
            "showcase-story-message-11": [.checked],
            "showcase-work-0": [.continued],
            "invented-checkpoint-0-2": [.checked],
            "invented-checkpoint-1-2": [.reported],
            "invented-checkpoint-2-2": [.continued],
            "quick-review-2": [.checked], "quick-review-4": [.checked], "quick-review-6": [.checked]
        ]
        return library.sessions.flatMap { session -> [ContributionReading] in
            let messages = library.messages.filter { $0.sessionID == session.id }
            guard session.id.hasPrefix("showcase-"), let context = DecisionContext.make(sessionID: session.id, messages: messages, storedMessages: messages.count) else { return [] }
            let drafts = ContributionReading.batchTargets(in: context).compactMap { source -> ContributionDraft? in
                guard let acts = labels[source.messageID], let primary = acts.first else { return nil }
                return .init(sourceID: source.id, primary: primary, claims: acts.map { .init(action: $0, quote: String(source.quote.prefix(140))) })
            }
            return ContributionReading.validate(drafts, supportedIDs: Set(drafts.map(\.sourceID)), context: context, engine: "Invented presentation · no model ran")
        }
    }
}
