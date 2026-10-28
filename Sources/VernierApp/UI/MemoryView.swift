import SwiftUI
import VernierCore

struct MemoryView: View {
    @ObservedObject var model: AppModel
    @State private var query = ""
    @State private var sessionID: String?
    @State private var messages: [ConversationMessage] = []
    private var focusedSource: Bool { model.memorySourceID != nil && query.isEmpty }
    private var searchKey: String {
        let parts: [String] = [model.memorySourceID ?? "", String(model.memoryEraseRevision), query, sessionID ?? "all", String(model.library.totalMessageCount), model.lastSync?.description ?? ""]
        return parts.joined(separator: "|")
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(focusedSource ? "The original saved message." : "A memory of the work.").font(.system(size: 32, weight: .light))
            Text(focusedSource ? "The exact source behind the reading, kept in its original form." : "Your prompts. The agent’s replies. Evidence you can return to.").foregroundStyle(Palette.secondary)
            if !focusedSource {
            ConversationConsentView(model: model)
            InstrumentCard {
                VStack(alignment: .leading, spacing: 17) {
                    HStack {
                        memoryNumber(model.library.totalMessageCount, "messages stored")
                        memoryNumber(model.library.memoryCoverage.filter(\.complete).count, "histories captured")
                        Spacer()
                        Button("Refresh memory") { Task { await model.syncSessions() } }.disabled(!model.codexEnabled || model.paused || model.syncing)
                    }
                    Text("\(model.library.memoryCoverage.filter { !$0.complete }.count) histories still partial or backfilling. New text and older history fill independently; unavailable provider history stays unknown.")
                        .font(.caption).foregroundStyle(Palette.secondary)
                }
            }
            InstrumentCard {
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(text: "Reflection / evidence before a score")
                    Text("Patterns are a starting point.").font(.title3.weight(.medium))
                    Text("Short continuation wording appears in \(model.library.messages.filter(\.isContinuationCue).count) of the latest \(model.library.messages.filter { $0.speaker == "user" }.count) loaded user messages. This literal wording flag doesn’t establish fatigue or disengagement.")
                        .font(.callout).foregroundStyle(Palette.secondary)
                    Text("Reading, comprehension, tab changes and cognitive performance are not measured. No cognitive score is calculated. Record what you verified and understood in a session takeaway.")
                        .font(.caption).foregroundStyle(Palette.amber)
                }
            }
            HStack {
                TextField("Search all locally stored conversation text", text: $query).textFieldStyle(.roundedBorder)
                Picker("Session", selection: Binding(get: { sessionID }, set: { model.memorySourceID = nil; sessionID = $0 })) {
                    Text("All sessions").tag(String?.none)
                    ForEach(model.library.sessions) { Text(model.library.title(for: $0)).tag(Optional($0.id)) }
                }.frame(width: 180)
            }
            }
            if model.memorySourceID != nil && query.isEmpty {
                HStack {
                    Text("Showing the exact original record.").font(.caption).foregroundStyle(Palette.secondary)
                    Spacer()
                    Button("Show this conversation") { model.memorySourceID = nil }.buttonStyle(.plain).font(.caption).foregroundStyle(Palette.mint)
                }
            }
            Text("Showing up to 100 matches by available timestamps. Older formats can supply turn-boundary times; order is approximate when timestamps are missing. Search runs on this Mac.").font(.caption).foregroundStyle(Palette.secondary)
            if messages.isEmpty {
                InstrumentCard { EmptyState(title: "No matching conversation text yet.", detail: model.conversationMemoryEnabled ? "Memory is backfilling available Codex history. Some older provider histories may not expose text." : "Conversation capture is off. Enable it above only if you want this content stored locally.") }
            }
            ForEach(messages) { message in
                MemoryMessageCard(message: message) {
                    if let session = model.library.sessions.first(where: { $0.id == message.sessionID }) { model.inspectSession(session) }
                }
            }
        }.onAppear { sessionID = model.memorySessionID; query = model.memoryQuery }
            .onChange(of: model.memoryRouteRevision) { _, _ in sessionID = model.memorySessionID; query = model.memoryQuery }
            .onChange(of: model.memoryEraseRevision) { _, _ in messages = [] }
            .onChange(of: model.memoryQuery) { _, value in query = value }
            .onChange(of: model.memorySessionID) { _, value in sessionID = value }
            .task(id: searchKey) {
            do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
            let result = await model.searchMemory(query, sessionID: sessionID, sourceID: query.isEmpty ? model.memorySourceID : nil)
            if !Task.isCancelled { messages = result }
        }
    }
    private func memoryNumber(_ value: Int, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(String(value)).font(.system(size: 27, weight: .light, design: .monospaced))
            Text(label).font(.caption).foregroundStyle(Palette.secondary)
        }
    }
}

struct ConversationConsentView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        InstrumentCard {
            VStack(alignment: .leading, spacing: 13) {
                Eyebrow(text: "Codex in Conductor / content permission")
                Toggle("Save conversation memory on this Mac", isOn: $model.conversationMemoryEnabled)
                    .toggleStyle(.switch).disabled(!model.codexEnabled && !model.conversationMemoryEnabled)
                Text("Reads available prompts and visible agent replies from connected Conductor workspaces. Also saves file-change and command-outcome metadata, excluding tool bodies. Existing history within your retention window is included. Provider user-side messages can include app-added context; this is not a keystroke log.")
                    .font(.callout).foregroundStyle(Palette.secondary)
                Text("Conversation text is sensitive. Credential redaction is best-effort; private details can remain. Stored locally as readable text and included in exports. Optional local reasoning uses this text with a separate setting; no conversation is sent to a cloud model. Images, attachments, private reasoning and raw command/file output are excluded.")
                    .font(.caption).foregroundStyle(Palette.secondary)
                Text(model.retentionDays == 0 ? "Retention: until you delete it." : "Retention: sessions updated within \(model.retentionDays) days. Change this in Privacy.")
                    .font(.caption).foregroundStyle(Palette.secondary)
                Text("Turning off stops capture; use Privacy → Erase conversation memory to remove saved text. Pause blocks in-flight storage. Tab or screen observation is a separate future permission.")
                    .font(.caption).foregroundStyle(Palette.secondary)
            }
        }
    }
}

struct MemoryMessageCard: View {
    let message: ConversationMessage
    var inspect: () -> Void
    @State private var expanded = false
    var body: some View {
        InstrumentCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Label(message.speaker == "user" ? "User-side message" : message.phase == "final_answer" ? "Agent’s report" : "Agent’s reply", systemImage: message.speaker == "user" ? "person" : "sparkle")
                        .font(.caption.weight(.medium)).foregroundStyle(message.speaker == "user" ? Palette.lavender : Palette.mint)
                    Spacer()
                    Text(message.sourceAt.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "Source time unknown")
                        .font(.caption2).foregroundStyle(Palette.secondary)
                }
                Text(message.text).font(.callout).lineSpacing(4).textSelection(.enabled).lineLimit(expanded ? nil : 9)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button(expanded ? "Show less" : "Read message") { expanded.toggle() }.buttonStyle(.plain).font(.caption).foregroundStyle(Palette.secondary)
                    Spacer()
                    Button("Inspect session →", action: inspect).buttonStyle(.plain).font(.caption).foregroundStyle(Palette.mint)
                }
                if message.redactions > 0 || message.textTruncated || message.attachmentsOmitted {
                    Text("\(message.redactions) credential-like matches redacted\(message.textTruncated ? " · text length capped" : "")\(message.attachmentsOmitted ? " · attachments omitted" : "")")
                        .font(.caption2).foregroundStyle(Palette.amber)
                }
                Text(message.speaker == "assistant" ? "Provider conversation text · claims in this reply are not independently verified." : "Provider conversation text · can include app-added context; a prompt does not establish reading or comprehension.")
                    .font(.caption2).foregroundStyle(Palette.secondary)
            }
        }
    }
}
