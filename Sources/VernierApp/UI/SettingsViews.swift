import SwiftUI
import VernierCore

struct ConnectionsView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Connect with intention.").font(.system(size: 32, weight: .light))
            Text("Choose what becomes visible. Know what stays unknown.").foregroundStyle(Palette.secondary)
            ForEach(Provider.allCases) { provider in
                InstrumentCard {
                    HStack(alignment: .top, spacing: 16) {
                        ProviderMark(provider: provider)
                        VStack(alignment: .leading, spacing: 9) {
                            Text(provider.name).font(.title3.weight(.medium))
                            if provider == .codex {
                                Text(model.codexEnabled ? (model.lastSync == nil ? "Enabled · awaiting verification" : (model.conversationMemoryEnabled ? "Conversation memory + activity · connected" : "Activity metadata · connected")) : "Not connected")
                                    .font(.caption).foregroundStyle(Palette.amber)
                                Text("Read session IDs, timestamps and recorded turn outcomes through Conductor’s installed Codex. Only sessions under your local conductor/workspaces folder are kept. IDs and workspace paths are hashed locally.")
                                    .font(.callout).foregroundStyle(Palette.secondary)
                                Toggle("Connect Codex session metadata", isOn: $model.codexEnabled).toggleStyle(.switch)
                                Text("No hooks or Conductor settings are changed. The provider may return titles/previews; they are discarded in memory. Conversation text is stored only with the separate permission shown below. This version-sensitive app-server adapter uses read-only requests and does not control agents.")
                                    .font(.caption).foregroundStyle(Palette.secondary)
                                if model.codexEnabled {
                                    Text(model.conversationMemoryEnabled ? "Conversation text capture enabled separately" : "Metadata only · conversation capture off").font(.caption).foregroundStyle(Palette.lavender)
                                    Button("Conversation permission…") { model.page = .memory }.buttonStyle(.plain).foregroundStyle(Palette.lavender)
                                }
                                if model.codexEnabled { Button("Verify / refresh metadata") { Task { await model.syncSessions() } }.disabled(model.syncing || model.paused) }
                                if let error = model.connectionError { Text(error).font(.caption).foregroundStyle(Palette.rose) }
                            } else {
                                Text("Not connected · adapter planned for \(milestone(provider))").font(.caption).foregroundStyle(Palette.amber)
                                Text("No settings inspected or changed. No verified events or declared capabilities yet.")
                                    .font(.callout).foregroundStyle(Palette.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "plug").foregroundStyle(Palette.secondary)
                    }
                }
            }
            Label("ChatGPT conversations, other agents, and nonlocal sessions are not covered. Demo data stays separate.", systemImage: "info.circle").font(.callout).foregroundStyle(Palette.secondary)
        }
    }
    private func milestone(_ provider: Provider) -> String {
        switch provider { case .claudeCode: "M2"; case .codex: "M3"; case .cursor: "M4" }
    }
}

struct PrivacyView: View {
    @ObservedObject var model: AppModel
    @State private var confirmDelete = false
    @State private var confirmEraseMemory = false
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Your work stays yours.").font(.system(size: 32, weight: .light))
            Text("Local records and optional on-device interpretation. No Vernier account or cloud model calls.").foregroundStyle(Palette.secondary)
            InstrumentCard {
                VStack(alignment: .leading, spacing: 19) {
                    Eyebrow(text: "Presence")
                    Toggle("Pause observation", isOn: $model.paused)
                    Text("Pause is saved across relaunch and blocks in-flight storage too. Resume reads the current historical metadata; there is no event buffer or stream replay.").font(.caption).foregroundStyle(Palette.secondary)
                    Divider()
                    Toggle("Show floating pill", isOn: $model.pillEnabled)
                    Toggle("Keep pill expanded", isOn: $model.pillAlwaysExpanded).disabled(!model.pillEnabled)
                    Text("The circle rests quietly. Hover for controls; click its body to keep them open. Play/pause changes capture in place. Only the dashboard arrow opens the full window. Control-click for more actions, or drag to reposition.").font(.caption).foregroundStyle(Palette.secondary)
                    Button("Reset pill position") { model.resetPill() }.buttonStyle(.borderless)
                    Divider()
                    ResidencySettings(model: model)
                }.toggleStyle(.switch)
            }
            InstrumentCard {
                VStack(alignment: .leading, spacing: 18) {
                    Eyebrow(text: "Preview")
                    Toggle("Show demo data", isOn: $model.demoEnabled).toggleStyle(.switch)
                    Text("Fixed fictional events, bundled with the app. Turn off to see real session records, or an empty state before connection.").font(.caption).foregroundStyle(Palette.secondary)
                    if model.demoEnabled {
                        Picker("Sample status", selection: $model.previewState) {
                            ForEach(InstrumentState.allCases.filter { $0 != .paused }, id: \.self) { Text($0.label).tag($0) }
                        }
                        Text("Changes only the labeled demo status. Pause overrides every preview state.").font(.caption).foregroundStyle(Palette.secondary)
                    }
                }
            }
            ConversationConsentView(model: model)
            InstrumentCard {
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(text: "Local interpretation")
                    Toggle("Generate on-device work briefs", isOn: $model.localInsightsEnabled).toggleStyle(.switch)
                    Text("Apple’s on-device model reviews bounded excerpts of saved Codex conversations. It suggests a working goal, source-linked observations and a next step. No conversation is sent to a cloud model. Automatic reviews are limited to one every five minutes for the selected session; manual refresh is available. Pause and content revocation stop in-flight results from being saved.")
                        .font(.caption).foregroundStyle(Palette.secondary)
                    Text("Turning this off keeps existing briefs. Erase conversation memory clears them with the saved messages; retention removes them with their session. Briefs are included in your private export.")
                        .font(.caption).foregroundStyle(Palette.secondary)
                    if let reason = model.briefUnavailable { Text(reason).font(.caption).foregroundStyle(Palette.secondary) }
                }
            }
            Button("Erase conversation memory…", role: .destructive) { confirmEraseMemory = true }
                .buttonStyle(QuietButtonStyle())
            InstrumentCard {
                VStack(alignment: .leading, spacing: 14) {
                    Eyebrow(text: "Data & permissions")
                    Text("Session metadata and your notes stay on this Mac.").font(.headline)
                    Text("SQLite records use a private Application Support directory. Session/workspace identifiers are salted hashes. Metadata-only mode excludes prompts and replies. With conversation permission enabled, redacted text is stored locally too. Notes and captured conversation text are personal content included in exports. Raw tool output and file diffs remain excluded.")
                        .font(.callout).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
                    Picker("Keep sessions updated within", selection: $model.retentionDays) {
                        Text("30 days").tag(30)
                        Text("90 days").tag(90)
                        Text("1 year").tag(365)
                        Text("Until I delete").tag(0)
                    }.onChange(of: model.retentionDays) { _, _ in Task { await model.applyRetention() } }
                    Text("Older sessions and their notes are deleted locally. This does not remove anything from Codex or Conductor.").font(.caption).foregroundStyle(Palette.secondary)
                    HStack {
                        Button("Export local records…") { Task { await model.exportRecords() } }
                        Button("Disconnect and delete…", role: .destructive) { confirmDelete = true }
                    }.buttonStyle(QuietButtonStyle())
                    if let error = model.storageError { Text(error).font(.caption).foregroundStyle(Palette.rose) }
                    Text("No screen reading, microphone, Accessibility access or Vernier telemetry. The connector launches a local Codex metadata process with analytics disabled; Codex otherwise retains its own configuration. Review rules and reminders remain unavailable.").font(.caption).foregroundStyle(Palette.secondary)
                }
            }
        }.confirmationDialog("Erase all saved conversation text and agent signals?", isPresented: $confirmEraseMemory) {
            Button("Stop capture and erase conversation memory", role: .destructive) { Task { await model.eraseConversationMemory() } }
        } message: {
            Text("Session metadata and your notes remain. Codex history is untouched. This cannot be undone locally.")
        }.confirmationDialog("Delete all local session records and your notes?", isPresented: $confirmDelete) {
            Button("Disconnect and delete local data", role: .destructive) { Task { await model.deleteLocalRecords() } }
        } message: {
            Text("This cannot be undone. Codex and Conductor history is not deleted. Reconnecting later imports available metadata again.")
        }
    }
}

struct WelcomeView: View {
    @ObservedObject var model: AppModel
    var complete: () -> Void
    @State private var step = 0
    private let titles = ["Keep your agency in view.", "Private by construction.", "Connect on your terms.", "Every permission, explained.", "A quiet place to begin."]
    private let details = [
        "A small instrument for the work you do with AI. See the evidence, keep the context, and stay ready to take over.",
        "Your work belongs to you. Session records and your notes stay local. The read-only Codex connection saves conversation text only with separate permission. No screen or microphone access is requested.",
        "Start with zero connectors, or connect Codex session metadata for local Conductor workspaces from Connections. Claude Code and Cursor are not connected yet.",
        "The Codex metadata connector changes no provider settings and controls no agent. It reads session history through a version-sensitive local API. You choose whether to enable it in Connections.",
        "Your menu-bar instrument is ready. Explore clearly labeled demo data, or turn it off for an empty workspace. Open Studio whenever you want more context."
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack { InstrumentMark(size: 44); Spacer(); Text("\(step + 1) / 5").font(.system(.caption, design: .monospaced)).foregroundStyle(Palette.secondary) }
            Spacer(minLength: 0)
            Eyebrow(text: "\(Brand.name) / Welcome")
            Text(titles[step]).font(.system(size: 34, weight: .light)).fixedSize(horizontal: false, vertical: true)
            Text(details[step]).font(.body).foregroundStyle(Palette.secondary).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
            if step == 2 {
                HStack(spacing: 15) { ForEach(Provider.allCases) { provider in VStack(spacing: 8) { ProviderMark(provider: provider); Text(provider.name).font(.caption) } } }
            }
            if step == 4 {
                Toggle("Explore demo data", isOn: $model.demoEnabled)
                Toggle("Enable the optional floating pill", isOn: $model.pillEnabled)
            }
            Spacer(minLength: 0)
            HStack {
                if step > 0 { Button("Back") { step -= 1 }.buttonStyle(.plain) }
                Spacer()
                Button(step == 4 ? "Open Studio" : "Continue") {
                    if step == 4 { model.finishOnboarding(); complete() } else { step += 1 }
                }.buttonStyle(QuietButtonStyle()).keyboardShortcut(.defaultAction)
            }
            Text("Local development build · connections are separately enabled").font(.caption2).foregroundStyle(Palette.secondary)
        }.padding(38).frame(width: 540, height: 510).background(Palette.canvas).foregroundStyle(Palette.text)
    }
}
