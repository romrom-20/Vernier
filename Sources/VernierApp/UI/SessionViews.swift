import SwiftUI
import VernierCore

struct LiveOverviewView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            DailyOverviewView(model: model)
            DisclosureGroup("Look closer at one conversation", isExpanded: $model.dailyConversationExpanded) {
                DecisionOverviewView(model: model).padding(.top, 18)
            }.font(.headline).id("participation-focus")
            DisclosureGroup("Inspect a conversation", isExpanded: $model.workDetailExpanded) {
                SessionStoryView(model: model).padding(.top, 18)
            }.font(.headline).id("session-inspector")
            InstrumentCard {
                DisclosureGroup("Saved memory and capture details") {
                    CaptureInventory(model: model).padding(.top, 14)
                }.font(.callout.weight(.medium))
            }
            if model.library.sessions.isEmpty {
                InstrumentCard {
                    EmptyState(title: model.codexEnabled ? "Ready for session metadata." : "Connect your Codex sessions.", detail: model.codexEnabled ? "Refresh reads available session history for local Conductor workspaces. No conversation is resumed." : "Open Connections to enable read-only metadata from Conductor’s installed Codex.")
                }
                Button("Connections") { model.openStudio(.connections) }.buttonStyle(QuietButtonStyle())
            } else {
                Button("Browse all saved sessions →") { model.page = .sessions }.buttonStyle(.plain).foregroundStyle(Palette.mint)
            }
        }
    }
}

struct SessionCoverageView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        InstrumentCard {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Label("Codex · Conductor workspaces", systemImage: "rectangle.stack").font(.headline)
                    Spacer()
                    Text(model.codexEnabled ? (model.lastSync == nil ? "Awaiting verification" : "Read-only") : "Disconnected")
                        .font(.caption).foregroundStyle(Palette.mint)
                }
                HStack(spacing: 28) {
                    number(model.library.sessions.count, "Stored sessions")
                    number(model.knownTurnCount, "Recorded turns")
                    Spacer()
                    Button { Task { await model.syncSessions() } } label: {
                        Label(model.syncing ? "Refreshing…" : "Refresh", systemImage: "arrow.clockwise")
                    }.disabled(model.syncing || model.paused || !model.codexEnabled).buttonStyle(QuietButtonStyle())
                }
                Text(model.captureModeDescription)
                    .font(.caption).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
                DisclosureGroup("Connection and coverage details") {
                if let date = model.lastSync ?? model.storedAt {
                    Text("Last checked: \(date.formatted(date: .abbreviated, time: .standard))").font(.caption2).foregroundStyle(Palette.secondary)
                }
                if model.lastSync != nil {
                    Text("Last check: \(model.lastWriteSummary.changes) changed records · \(model.lastDiagnostics.historyReads) metadata history reads · \(model.lastDiagnostics.memoryReads) content pages").font(.caption2).foregroundStyle(Palette.secondary)
                }
                if model.paused { Label("Paused. New refreshes stop; in-flight results are not stored.", systemImage: "pause.circle").font(.caption).foregroundStyle(Palette.amber) }
                if model.coverageLimited || model.library.sessions.contains(where: { !$0.turnsComplete }) {
                    Text("Partial history: checks up to 300 recent Codex sessions and 20 changed session histories per refresh, with up to 100 turns each. Some histories may be unavailable.").font(.caption).foregroundStyle(Palette.amber)
                }
                }.font(.caption).foregroundStyle(Palette.secondary)
                if let error = model.connectionError ?? model.storageError { Text(error).font(.callout).foregroundStyle(Palette.rose) }
            }
        }
    }
    private func number(_ value: Int?, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(model.lastSync == nil && model.storedAt == nil ? "—" : (value.map(String.init) ?? "—")).font(.system(size: 28, weight: .light, design: .monospaced))
            Text(label).font(.caption).foregroundStyle(Palette.secondary)
        }
    }
}

struct SessionsView: View {
    @ObservedObject var model: AppModel
    @State private var workspace: String?
    private var workspaceIDs: [String] { Array(Set(model.library.sessions.map(\.workspaceID))).sorted() }
    private var sessions: [SessionMetadata] { model.library.sessions.filter { workspace == nil || $0.workspaceID == workspace } }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("How did you steer the work?").font(.system(size: 32, weight: .light))
            Text("Revisit your intent, the direction you gave, and what you now understand.").foregroundStyle(Palette.secondary)
            SessionCoverageView(model: model)
            HStack {
                Eyebrow(text: model.conversationMemoryEnabled ? "Saved conversations" : "Recorded activity")
                Spacer()
                Picker("Workspace", selection: $workspace) {
                    Text("All workspaces").tag(String?.none)
                    ForEach(workspaceIDs, id: \.self) { Text(model.library.workspaceName($0)).tag(Optional($0)) }
                }.frame(maxWidth: 220)
            }
            if sessions.isEmpty {
                InstrumentCard { EmptyState(title: "No stored sessions in this view.", detail: "Enable the Codex metadata connection or choose another workspace. Demo rows never appear in session history.") }
            }
            ForEach(sessions) { session in
                Button { model.inspectSession(session) } label: { SessionRow(session: session, library: model.library) }.buttonStyle(.plain)
            }
        }
    }
}

struct SessionRow: View {
    let session: SessionMetadata
    let library: SessionLibrary
    var body: some View {
        HStack(spacing: 14) {
            ProviderMark(provider: .codex)
            VStack(alignment: .leading, spacing: 6) {
                Text(library.title(for: session)).font(.callout.weight(.semibold)).lineLimit(2).multilineTextAlignment(.leading)
                Text("\(library.notes[session.id]?.isEmpty == false ? "Your note" : library.digest(for: session)?.promptExcerpt != nil ? "Prompt excerpt" : "Session history") · \(library.workspaceName(session.workspaceID)) · \(session.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundStyle(Palette.secondary)
                if let note = library.notes[session.id], !note.isEmpty {
                    Text("Your note: \(note)").font(.caption).lineLimit(2).foregroundStyle(Palette.lavender)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                Text((library.digest(for: session)?.messageCount ?? 0) > 0 ? "\(library.digest(for: session)!.messageCount.formatted()) messages" : "Activity metadata")
                    .font(.caption).foregroundStyle(Palette.secondary)
                Text((library.digest(for: session)?.messageCount ?? 0) > 0 ? (library.memoryCoverage.first { $0.sessionID == session.id }?.complete == true ? "Memory caught up" : library.memoryCoverage.first { $0.sessionID == session.id }?.issue == true ? "Memory needs attention" : "Memory filling") : (session.turnsComplete ? "Activity recorded" : "Partial activity"))
                    .font(.caption2).foregroundStyle(Palette.secondary)
            }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Palette.secondary)
        }.padding(16).background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle()).accessibilityElement(children: .combine)
    }
}

struct SessionDetailView: View {
    @ObservedObject var model: AppModel
    let session: SessionMetadata
    @State private var note = ""
    @State private var saved = false
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text(model.library.title(for: session)).font(.system(size: 28, weight: .medium)).fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button("All sessions") { model.page = .sessions }.buttonStyle(.plain).foregroundStyle(Palette.mint)
            }
            Text("Codex in Conductor · \(model.library.workspaceName(session.workspaceID))").font(.callout).foregroundStyle(Palette.secondary)
            HStack {
                Button("Read this conversation →") { model.showMemory(sessionID: session.id) }.buttonStyle(QuietButtonStyle())
                Button("Review this work") {
                    model.selectDecisionSession(session.id)
                    if !model.localInsightsEnabled { model.localInsightsEnabled = true }
                    model.reviewDecision(sessionID: session.id)
                    model.openStudio(.overview)
                }.buttonStyle(.plain).font(.caption).foregroundStyle(Palette.mint)
                    .disabled(model.isShowcase || model.paused || !model.conversationMemoryEnabled)
                Spacer()
                Text("\(model.library.digest(for: session)?.messageCount ?? 0) saved messages").font(.caption).foregroundStyle(Palette.secondary)
            }
            PromptTrailView(model: model, session: session)
            InstrumentCard {
                DisclosureGroup("Recorded session activity") {
                VStack(alignment: .leading, spacing: 16) {
                    Eyebrow(text: "Observed metadata")
                    Text("Created \(session.createdAt.formatted())\nLast updated by Codex \(session.updatedAt.formatted())\nLast observed by this app \(session.observedAt.formatted())")
                        .font(.callout).lineSpacing(5)
                    Text("Provider source label: \(session.sourceKind). Grouped by Conductor workspace location; client identity is not independently verified.")
                        .font(.caption).foregroundStyle(Palette.secondary)
                    Divider()
                    Eyebrow(text: "Recorded turn outcomes")
                    ForEach(model.library.turns(for: session)) { turn in
                        HStack(alignment: .top) {
                            Text(turn.outcome.label).font(.callout)
                            Spacer()
                            Text((turn.completedAt ?? turn.startedAt)?.formatted(date: .abbreviated, time: .shortened) ?? "Time unknown")
                                .font(.caption).foregroundStyle(Palette.secondary)
                        }
                    }
                    if model.library.turns(for: session).isEmpty {
                        Text(session.turnsComplete ? "No turns were present in the available provider history." : "Turn history is unavailable. The count is unknown.").foregroundStyle(Palette.secondary)
                    }
                    Text("A completed turn means Codex finished responding. It does not prove tests passed, changes shipped, or that work was reviewed.")
                        .font(.caption).foregroundStyle(Palette.amber)
                }.padding(.top, 15)
                }.font(.callout)
            }
            InstrumentCard {
                VStack(alignment: .leading, spacing: 13) {
                    Eyebrow(text: "Your own view · user reported")
                    Text("Your intent. Your steering. Your understanding.").font(.title3.weight(.medium))
                    Text("What did you want at the start? Where did you challenge or redirect the agent? What can you explain now, and what still needs checking? Record what happened in your own words; a repeated “fix it” alone does not tell us whether you steered well.")
                        .font(.callout).foregroundStyle(Palette.secondary)
                    TextEditor(text: $note).font(.body).frame(minHeight: 110).scrollContentBackground(.hidden)
                        .padding(10).background(Palette.inset, in: RoundedRectangle(cornerRadius: 9))
                        .accessibilityLabel("Your outcome and takeaway for this session")
                    HStack {
                        Button(saved ? "Saved locally" : "Save takeaway") {
                            Task { await model.saveNote(note, session: session); saved = model.storageError == nil }
                        }.buttonStyle(QuietButtonStyle()).disabled(note.utf8.count > 16_000)
                        Text("Local only · included in exports").font(.caption).foregroundStyle(Palette.secondary)
                    }
                    if let error = model.storageError { Text(error).font(.caption).foregroundStyle(Palette.rose) }
                }
            }
            if model.library.totalMessageCount > 0 {
                Text("\((model.library.digest(for: session)?.signalCount ?? 0).formatted()) saved agent activity records. These describe the agent’s activity, not proof of your review.")
                    .font(.caption).foregroundStyle(Palette.secondary)
            }
            Text("Reading, comprehension, browser/tab interactions and cognitive performance are not observed. Conversation capture is separately controlled in Memory.")
                .font(.caption).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
        }.onAppear { note = model.library.notes[session.id] ?? "" }.onChange(of: note) { _, _ in saved = false }
    }
}


struct InteractionFocusView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        InstrumentCard {
            VStack(alignment: .leading, spacing: 14) {
                Eyebrow(text: "Your side of the interaction")
                Text("How did you steer the work?").font(.title3.weight(.medium))
                Text("Follow the intent you set, the course you changed, and what you understood along the way.")
                    .font(.callout).foregroundStyle(Palette.secondary)
                HStack(alignment: .top, spacing: 18) {
                    focus("Intent", "What were you trying to achieve?")
                    focus("Steering", "Where did you question or redirect?")
                    focus("Understanding", "What can you explain or verify?")
                }
                Button("Review a session →") { model.openStudio(.sessions) }
                    .buttonStyle(.plain).font(.callout.weight(.medium)).foregroundStyle(Palette.mint)
                Text("Session reviews are yours to assess. Prompt counts and repeated requests do not establish how well you thought.")
                    .font(.caption).foregroundStyle(Palette.secondary)
            }
        }
    }
    private func focus(_ title: String, _ question: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption.weight(.semibold))
            Text(question).font(.caption).foregroundStyle(Palette.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PromptTrailView: View {
    @ObservedObject var model: AppModel
    let session: SessionMetadata
    @State private var prompts: [ConversationMessage] = []
    var body: some View {
        InstrumentCard {
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: "Your interaction trail")
                Text("Revisit the direction you gave.").font(.title3.weight(.medium))
                Text("Read your prompts alongside the agent’s replies, then decide where you set the course or followed it.")
                    .font(.callout).foregroundStyle(Palette.secondary)
                if !prompts.isEmpty {
                    DisclosureGroup("Recent saved prompts · \(prompts.count) shown") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(prompts) { message in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(message.sourceAt?.formatted(date: .abbreviated, time: .shortened) ?? "Source time unknown")
                                        .font(.caption2).foregroundStyle(Palette.secondary)
                                    Text(SessionDisplay.excerpt(message.text) ?? "App-added context · open the conversation for detail")
                                        .font(.callout).textSelection(.enabled)
                                }
                            }
                        }.padding(.top, 10)
                    }.font(.caption)
                }
                Text("A bounded glimpse of the latest 100 saved messages, showing up to 6 user-side prompts in approximate time order. Provider text can include app-added context; this is not a quality assessment.")
                    .font(.caption).foregroundStyle(Palette.secondary)
                Button("Read prompts with replies →") { model.showMemory(sessionID: session.id) }
                    .buttonStyle(.plain).font(.caption.weight(.medium)).foregroundStyle(Palette.mint)
            }
        }.task(id: session.id + String(model.library.totalMessageCount)) {
            let messages = await model.searchMemory("", sessionID: session.id)
            if !Task.isCancelled { prompts = Array(messages.filter { $0.speaker == "user" }.prefix(6).reversed()) }
        }
    }
}
