import Foundation
import VernierCore

extension AppModel {
    func focusStory(_ messageID: String) { storyFocusID = messageID; storyFocusRevision += 1 }
    var storyKey: String {
        guard let session = briefSession else { return "none" }
        return session.id + ":" + String(library.digest(for: session)?.messageCount ?? 0) + ":" + String(session.updatedAt.timeIntervalSince1970)
    }
    var currentStory: SessionStory? { sessionStory?.sessionID == briefSession?.id ? sessionStory : nil }
    func loadSessionStory() async {
        guard let session = briefSession else { sessionStory = nil; storyLoading = false; return }
        let key = storyKey
        if storyLoadedKey == key, currentStory != nil { return }
        storyGeneration += 1
        let generation = storyGeneration
        storyLoading = true; storyError = nil
        defer { if storyKey == key && storyGeneration == generation { storyLoading = false } }
        do {
            let messages: [ConversationMessage]
            if isShowcase { messages = library.messages.filter { $0.sessionID == session.id } }
            else if isolatedEnvironment { messages = library.messages.filter { $0.sessionID == session.id } }
            else { messages = try await store?.memoryMessages(sessionID: session.id, limit: 500) ?? [] }
            guard !Task.isCancelled, storyKey == key, storyGeneration == generation else { return }
            sessionStory = SessionStory.make(sessionID: session.id, messages: messages,
                                             storedMessages: library.digest(for: session)?.messageCount ?? messages.count)
            storyLoadedKey = key
        } catch {
            guard storyKey == key, storyGeneration == generation, !Task.isCancelled else { return }
            storyError = "The saved conversation couldn’t be loaded. Your records have not changed."
        }
    }
}
