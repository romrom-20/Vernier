import SwiftUI
import VernierCore

struct RelatedConversationMemoryView: View {
    @ObservedObject var model: AppModel
    let memory: RelatedConversationMemory
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("These earlier conversations share wording with this question. They may be different tasks. Their decisions do not become instructions for the current work.")
                .font(.caption).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
            ForEach(memory.candidates) { candidate in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Possible related conversation").font(.caption.weight(.medium))
                        Spacer()
                        Text(candidate.readingCreatedAt.formatted(date: .abbreviated, time: .omitted)).font(.caption2)
                    }.foregroundStyle(Palette.secondary)
                    if !candidate.earlierGoal.isEmpty {
                        Text("Earlier reading: " + candidate.earlierGoal).font(.callout.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                    }
                    if candidate.hasNewerPerspective {
                        Label("Your newer perspective appears below; the earlier reading may be outdated.", systemImage: "text.bubble")
                            .font(.caption).foregroundStyle(Palette.amber).fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(candidate.statements) { statement in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(statement.isPerspective ? "Your saved perspective" : statement.speaker == "assistant" ? "The AI's saved statement" : "Your saved statement")
                                .font(.caption2.weight(.medium)).foregroundStyle(statement.speaker == "assistant" ? Palette.lavender : Palette.mint)
                            Text("“\(statement.quote)”").font(.callout).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                            Button(statement.isPerspective ? "Read the associated exchange ↗" : "Read original ↗") {
                                model.showMemorySource(sessionID: candidate.sessionID, messageID: statement.messageID)
                            }.buttonStyle(.plain).font(.caption).foregroundStyle(Palette.mint)
                        }
                    }
                    Text("Shared words: " + candidate.matchedWords.joined(separator: ", ")).font(.caption2).foregroundStyle(Palette.secondary)
                }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Palette.inset.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
            }
            Text("Uses up to 60 earlier reviewed conversations in this workspace and shows at most two possible links. This casebook is rebuilt from saved records; it does not merge conversations or run another model.")
                .font(.caption2).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
