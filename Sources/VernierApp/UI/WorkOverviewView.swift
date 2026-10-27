import SwiftUI
import VernierCore

struct WorkOverviewView: View {
    @ObservedObject var model: AppModel
    @State private var selectedCue: RequestCue? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 9) {
                    Eyebrow(text: "Across your work / past 24 hours")
                    Text("How are you steering your agents?").font(.system(size: 31, weight: .medium, design: .rounded)).tracking(-0.8)
                    Text("See what you asked agents to do, where you added direction, and which threads to revisit.")
                        .font(.callout).foregroundStyle(Palette.secondary).lineSpacing(3)
                }
                Spacer()
                CaptureToggle(model: model, compact: true)
            }
            if let overview = model.workOverview, !overview.sessions.isEmpty {
                Text("Sample · \(overview.loadedMessages) of \(overview.storedMessages) saved messages in \(overview.sessions.count) of \(overview.eligibleSessions) recently updated sessions")
                    .font(.caption).foregroundStyle(Palette.secondary)
                HStack(spacing: 14) {
                    overviewNumber(overview.workspaces, "Workspaces", "\(overview.sessions.count) recent sessions", Palette.mint)
                    overviewNumber(overview.requests.isEmpty ? nil : overview.count(.goAhead), "Go-ahead only", "Short continuation wording in sample", Palette.lavender)
                    overviewNumber(overview.requests.isEmpty ? nil : overview.count(.question) + overview.count(.direction), "Questions & direction", "Specific checks, constraints & corrections", Palette.mint)
                }
                if overview.requests.isEmpty {
                    InstrumentCard {
                        Text("No dated requests are available in this sample. Conversation memory may be off, filling, or missing source times. This does not mean you delegated nothing.")
                            .font(.callout).foregroundStyle(Palette.secondary)
                    }
                } else {
                InstrumentCard {
                    VStack(alignment: .leading, spacing: 17) {
                        HStack { Eyebrow(text: "How you prompted"); Spacer(); Text("\(overview.requests.count) dated requests sampled").font(.caption).foregroundStyle(Palette.secondary) }
                        Text("Delegating and steering can happen in the same request.").font(.headline)
                        cueBar(overview)
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(RequestCue.allCases, id: \.self) { cue in
                                Button { selectedCue = selectedCue == cue ? nil : cue } label: {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(overview.count(cue).formatted()).font(.title2.monospacedDigit())
                                        Text(cue.title).font(.caption).fixedSize(horizontal: false, vertical: true)
                                    }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
                                        .background(selectedCue == cue ? cueColor(cue).opacity(0.12) : Palette.inset, in: RoundedRectangle(cornerRadius: 10))
                                }.buttonStyle(.plain).foregroundStyle(cueColor(cue)).accessibilityLabel("\(cue.title), \(overview.count(cue)) requests. Show source examples")
                            }
                        }
                        Text("Wording cues, not an engagement score. A task request can be well considered; a question can be routine. Select a category to read the actual requests.")
                            .font(.caption).foregroundStyle(Palette.secondary)
                        if let cue = selectedCue { requestExamples(overview, cue: cue) }
                    }
                }
                }
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Eyebrow(text: "Threads to revisit")
                        Spacer()
                        Text("\(overview.agentLastCount) agent-last · \(overview.failureCount) last turn failed").font(.caption).foregroundStyle(Palette.secondary)
                    }
                    Text("An agent’s reply leaves a question for you: what evidence would make this safe to rely on?")
                        .font(.callout).foregroundStyle(Palette.secondary)
                    ForEach(prioritized(overview)) { work in workRow(work) }
                    Text("Agent-last means no later message from you in this loaded history. You may have reviewed or tested elsewhere. A failed turn is a provider status, not proof that the project is broken.")
                        .font(.caption).foregroundStyle(Palette.secondary)
                }
                DisclosureGroup("Coverage and how these cues work") {
                    VStack(alignment: .leading, spacing: 9) {
                        Text(coverage(overview))
                        Text("Dated requests only, within the past 24 hours. Messages without source times are excluded from request counts. Counts classify wording in this sample, not all your AI use. Known injected instruction blocks are removed; quoted or remaining app-added text can still affect categories.")
                        Text("Go-ahead matches short ‘continue / proceed’ wording. Questions and check words take priority, then constraints and corrections, then an opening task verb such as ‘build / fix / add’. Everything else stays Other. Mixed requests get one category; misclassification is possible. No model runs for this overview.")
                        Text("Workspaces use existing private identifiers. Repository names and paths are not collected; multiple workspaces may belong to one repo. No observation of reading, understanding, clicks, or review outside saved conversations.")
                    }.font(.caption).foregroundStyle(Palette.secondary).padding(.top, 8)
                }.font(.caption)
            } else {
                InstrumentCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(model.workOverviewLoading ? "Gathering your recent threads…" : "Your recent work will gather here.").font(.title3)
                        Text("This view compares saved Codex sessions in Conductor from the past 24 hours. Conversation memory is needed for wording examples; metadata alone cannot show how you prompted.")
                            .font(.callout).foregroundStyle(Palette.secondary)
                        Button("Open connections →") { model.openStudio(.connections) }.buttonStyle(QuietButtonStyle())
                    }
                }
            }
            if let error = model.workOverviewError { Text(error).font(.caption).foregroundStyle(Palette.amber) }
        }.task(id: model.workOverviewKey) { await model.loadWorkOverview() }
    }
    private func overviewNumber(_ count: Int?, _ title: String, _ detail: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(count?.formatted() ?? "—").font(.system(size: 30, weight: .light, design: .rounded)).foregroundStyle(color)
            Text(title).font(.callout.weight(.medium))
            Text(detail).font(.caption2).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
    }
    private func cueBar(_ overview: WorkOverview) -> some View {
        GeometryReader { geometry in
            HStack(spacing: 3) {
                ForEach(RequestCue.allCases.filter { overview.count($0) > 0 }, id: \.self) { cue in
                    RoundedRectangle(cornerRadius: 4).fill(cueColor(cue).opacity(0.8))
                        .frame(width: max(0, (geometry.size.width - 12) * CGFloat(overview.count(cue)) / CGFloat(max(1, overview.requests.count))))
                }
            }
        }.frame(height: 13).accessibilityHidden(true)
    }
    private func requestExamples(_ overview: WorkOverview, cue: RequestCue) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if overview.count(cue) == 0 { Text("No matching request in this sample.").font(.caption).foregroundStyle(Palette.secondary) }
            ForEach(Array(overview.requests.filter { $0.cue == cue }.prefix(5))) { request in
                if let work = overview.sessions.first(where: { $0.id == request.message.sessionID }) {
                    Button { model.inspectWork(work, messageID: request.id) } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(model.library.workspaceName(work.session.workspaceID) + " · " + model.library.title(for: work.session)).font(.caption2).foregroundStyle(Palette.secondary).lineLimit(1)
                            Text("“\(request.excerpt)”").font(.callout).lineLimit(3)
                            Text("Compare with agent replies →").font(.caption).foregroundStyle(Palette.mint)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.buttonStyle(.plain)
                }
            }
            if overview.count(cue) > 5 { Text("Showing the latest 5 matching requests. Open Memory for the archive.").font(.caption2).foregroundStyle(Palette.secondary) }
        }.padding(.top, 8)
    }
    private func prioritized(_ overview: WorkOverview) -> [WorkSession] {
        overview.sessions.sorted {
            let a = $0.hasRecordedFailure ? 2 : $0.agentLast != nil ? 1 : 0
            let b = $1.hasRecordedFailure ? 2 : $1.agentLast != nil ? 1 : 0
            return a == b ? ($0.session.updatedAt == $1.session.updatedAt ? $0.id < $1.id : $0.session.updatedAt > $1.session.updatedAt) : a > b
        }
    }
    private func workRow(_ work: WorkSession) -> some View {
        Button { model.inspectWork(work, messageID: work.agentLast?.id) } label: {
            HStack(alignment: .top, spacing: 15) {
                Image(systemName: work.hasRecordedFailure ? "exclamationmark.circle" : work.agentLast != nil ? "bubble.right" : "arrow.turn.up.right")
                    .font(.title3).foregroundStyle(work.hasRecordedFailure ? Palette.amber : Palette.lavender).frame(width: 24).padding(.top, 4)
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(model.library.workspaceName(work.session.workspaceID)).font(.caption.weight(.medium)).foregroundStyle(Palette.mint)
                        Text(work.hasRecordedFailure ? "LAST TURN FAILED" : work.agentLast != nil ? "AGENT REPLIED LAST" : work.loadedMessages == 0 ? "NO TEXT LOADED" : work.latestSpeaker == "user" ? "YOU MESSAGED LAST" : "NO DATED REPLY CUE")
                            .font(.system(size: 9, weight: .semibold)).foregroundStyle(work.hasRecordedFailure ? Palette.amber : Palette.secondary)
                        Spacer()
                        if work.hasPartialMemory { Text("Partial history").font(.caption2).foregroundStyle(Palette.secondary) }
                    }
                    Text(model.library.title(for: work.session)).font(.headline).lineLimit(2)
                    if let agent = work.agentLast {
                        Text("Agent: “\(String(SessionDisplay.visibleText(agent.text).prefix(160)))”").font(.caption).foregroundStyle(Palette.secondary).lineLimit(2)
                    }
                    Text("\(work.requests.filter { $0.cue == .goAhead }.count) go-aheads · \(work.requests.filter { $0.cue == .question || $0.cue == .direction }.count) questions / direction · inspect exchange →")
                        .font(.caption).foregroundStyle(Palette.secondary)
                }
            }.padding(17).background(Palette.surface, in: RoundedRectangle(cornerRadius: 15))
        }.buttonStyle(.plain).accessibilityHint("Open this session's conversation map. Review and understanding remain unknown.")
    }
    private func coverage(_ overview: WorkOverview) -> String {
        "Updated \(overview.until.formatted(date: .omitted, time: .shortened)). \(overview.sessions.count) of \(overview.eligibleSessions) recently updated sessions, giving each workspace a slot before filling by recency; up to 24 sessions × 100 latest saved messages each, at most 4,096 characters per message. \(overview.loadedMessages) of \(overview.storedMessages) saved messages loaded for those sessions. Provider memory may still be filling. All counts describe this sample."
    }
}

private func cueColor(_ cue: RequestCue) -> Color {
    switch cue {
    case .goAhead: Palette.lavender
    case .handoff: Palette.lavender.opacity(0.7)
    case .question: Palette.mint
    case .direction: Palette.amber
    case .other: Palette.secondary.opacity(0.65)
    }
}

struct QuickWorkOverviewView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "Across your work / past 24h")
            if let overview = model.workOverview, !overview.sessions.isEmpty {
                Text("\(overview.workspaces) \(overview.workspaces == 1 ? "workspace" : "workspaces"). \(overview.sessions.count) threads.")
                    .font(.system(size: 21, weight: .medium, design: .rounded)).tracking(-0.5)
                HStack(spacing: 8) {
                    quickCount(overview.requests.isEmpty ? nil : overview.count(.goAhead), "Go-ahead only", Palette.lavender)
                    quickCount(overview.requests.isEmpty ? nil : overview.count(.question) + overview.count(.direction), "Questions / direction", Palette.mint)
                }
                Text(overview.requests.isEmpty ? "No dated requests sampled · memory may be off or filling" : "\(overview.count(.goAhead)) go-ahead only · wording sample, not a review score").font(.caption2).foregroundStyle(Palette.secondary)
                if let work = overview.sessions.first(where: \.hasRecordedFailure) ?? overview.sessions.first(where: { $0.agentLast != nil }) {
                    Button { model.inspectWork(work, messageID: work.agentLast?.id) } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(work.hasRecordedFailure ? "A THREAD TO CHECK · LAST TURN FAILED" : "A THREAD TO CHECK · AGENT REPLIED LAST")
                                .font(.system(size: 9, weight: .semibold)).tracking(0.5).foregroundStyle(Palette.amber)
                            Text(model.library.workspaceName(work.session.workspaceID) + " · " + model.library.title(for: work.session)).font(.callout).lineLimit(2)
                            Text("Inspect what happened →").font(.caption).foregroundStyle(Palette.mint)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.buttonStyle(.plain)
                }
                Text("\(overview.loadedMessages) / \(overview.storedMessages) saved messages sampled · review outside conversations is unknown")
                    .font(.caption2).foregroundStyle(Palette.secondary)
            } else {
                Text(model.workOverviewLoading ? "Gathering recent work…" : "No recent threads in view.").font(.headline)
                Text("Saved Codex sessions across Conductor workspaces will appear here. Open the dashboard for coverage and connections.").font(.caption).foregroundStyle(Palette.secondary)
            }
            if let error = model.workOverviewError { Text(error).font(.caption2).foregroundStyle(Palette.amber) }
        }.task(id: model.workOverviewKey) { await model.loadWorkOverview() }
    }
    private func quickCount(_ value: Int?, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value?.formatted() ?? "—").font(.system(size: 24, weight: .light, design: .rounded)).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(Palette.secondary)
        }.padding(11).frame(maxWidth: .infinity, alignment: .leading).background(Palette.inset, in: RoundedRectangle(cornerRadius: 11))
    }
}
