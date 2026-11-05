import SwiftUI
import VernierCore

/// Original earlier excerpts, displayed separately from the current interpretation.
struct ConversationRecallView: View {
    @ObservedObject var model: AppModel
    let memory: ConversationRecall
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("These are earlier saved statements, not a list of current requirements or verified results. Later messages may change their meaning.")
                .font(.caption).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
            ForEach(memory.entries) { entry in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(entry.speaker == "assistant" ? "AI reply from then" : "Earlier human statement").font(.caption.weight(.medium))
                        Spacer()
                        if let date = entry.sourceAt { Text(date.formatted(date: .abbreviated, time: .shortened)).font(.caption2) }
                    }.foregroundStyle(entry.speaker == "assistant" ? Palette.lavender : Palette.mint)
                    Text("“\(entry.quote)”").font(.callout).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                    Text(entry.reason.label).font(.caption2).foregroundStyle(Palette.secondary)
                    Button("Read original ↗") { model.showMemorySource(sessionID: entry.sessionID, messageID: entry.messageID) }
                        .buttonStyle(.plain).font(.caption).foregroundStyle(Palette.mint)
                }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Palette.inset.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
            }
            Text(memory.coverage).font(.caption2).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
