import SwiftUI
import VernierCore

struct StudioView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 30) {
                HStack(spacing: 12) { InstrumentMark(size: 32); Text(Brand.name).font(.title2.weight(.medium)) }.padding(.top, 12)
                VStack(spacing: 5) {
                    ForEach(StudioPage.allCases) { page in
                        Button { if page == .memory { model.memorySessionID = nil }; model.page = page } label: {
                            HStack(spacing: 11) { Image(systemName: page.symbol).frame(width: 20); Text(page.rawValue); Spacer() }
                                .font(.callout.weight(model.page == page ? .medium : .regular))
                                .padding(12).foregroundStyle(model.page == page ? Palette.text : Palette.secondary)
                                .background(model.page == page ? Palette.inset : .clear, in: RoundedRectangle(cornerRadius: 9))
                        }.buttonStyle(.plain).accessibilityAddTraits(model.page == page ? .isSelected : [])
                    }
                }
                Spacer()
                VStack(alignment: .leading, spacing: 12) {
                    StatusLine(model: model)
                    Text("Resident on your Mac.\nYour records stay here.").font(.caption).foregroundStyle(Palette.secondary).lineSpacing(4)
                    Text(model.loginStatus.label).font(.caption2).foregroundStyle(Palette.secondary)
                    Button("Welcome guide") { model.showWelcome() }.buttonStyle(.plain).font(.caption).foregroundStyle(Palette.secondary)
                }
            }.padding(20).frame(width: 200).background(Palette.surface)
            Rectangle().fill(Palette.line.opacity(0.5)).frame(width: 0.5)
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack {
                        Eyebrow(text: "Your perspective / \(model.page.rawValue)")
                        Spacer()
                        if model.isShowcase { Text("SHOWCASE · SYNTHETIC DATA").font(.caption.weight(.semibold)).foregroundStyle(Palette.amber) }
                        if model.demoEnabled { DemoBadge() }
                        if model.page != .overview { CaptureToggle(model: model, compact: true) }
                    }
                    Group {
                        switch model.page {
                        case .overview:
                            if model.demoEnabled { OverviewView(model: model) } else { LiveOverviewView(model: model) }
                        case .sessions: SessionsView(model: model)
                        case .memory: MemoryView(model: model)
                        case .decisions: DecisionsView(model: model)
                        case .connections: ConnectionsView(model: model)
                        case .privacy: PrivacyView(model: model)
                        }
                    }
                }.padding(30).frame(maxWidth: 1080, alignment: .leading).frame(maxWidth: .infinity)
            }.id(model.page).background(Palette.canvas)
        }.foregroundStyle(Palette.text).frame(minWidth: 860, minHeight: 580)
    }
}

struct OverviewView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 25) {
            VStack(alignment: .leading, spacing: 9) {
                Text("Keep the work in view.").font(.system(size: 32, weight: .light))
                Text("Signals from observed activity—not cognitive diagnosis.").font(.callout).foregroundStyle(Palette.secondary)
            }
            InstrumentCard {
                HStack(alignment: .top, spacing: 24) {
                    metric(model.projection.taskCount, "Sample tasks", "Three fictional task boundaries")
                    Rectangle().fill(Palette.line).frame(width: 0.5, height: 65)
                    metric(model.projection.eventCount, "Sample events", "Fixed sequence · 10:20–10:42")
                    Rectangle().fill(Palette.line).frame(width: 0.5, height: 65)
                    metric(nil, "Live coverage", "No sources connected")
                }
            }
            if model.demoEnabled {
                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Eyebrow(text: "Sample activity")
                            Spacer()
                            Picker("Source", selection: $model.providerFilter) {
                                Text("All sources").tag(Provider?.none)
                                ForEach(Provider.allCases) { Text($0.name).tag(Optional($0)) }
                            }.labelsHidden().frame(width: 135)
                        }
                        VStack(spacing: 0) {
                            ForEach(model.visibleEvents) { event in
                                Button { model.inspect(event) } label: { TimelineRow(event: event) }.buttonStyle(.plain)
                                if event.id != model.visibleEvents.last?.id { Divider().overlay(Palette.line.opacity(0.4)).padding(.leading, 45) }
                            }
                        }
                    }.frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 16) {
                        InstrumentCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Image(systemName: "viewfinder").font(.title2).foregroundStyle(Palette.amber)
                                Eyebrow(text: "Evidence before scores")
                                Text("A little context.\nA better question.").font(.title3.weight(.medium))
                                Text("A completed task doesn’t tell us what you understood. Start with what the source can actually show.")
                                    .font(.callout).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
                                Button("Explore sample evidence →") { model.inspect(DemoFixtures.events[0]) }
                                    .buttonStyle(.plain).font(.caption.weight(.medium)).foregroundStyle(Palette.amber)
                            }
                        }
                        Text("All events here are bundled examples. No tools, prompts, or files are being monitored.")
                            .font(.caption).foregroundStyle(Palette.secondary).lineSpacing(4)
                    }.frame(width: 220)
                }
            } else {
                InstrumentCard { EmptyState() }
                Button("Explore demo data") { model.demoEnabled = true }.buttonStyle(QuietButtonStyle())
            }
        }
    }
    private func metric(_ value: Int?, _ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value.map(String.init) ?? "—").font(.system(size: 33, weight: .light, design: .monospaced))
            Text(model.demoEnabled ? title : title.replacingOccurrences(of: "Sample", with: "Observed")).font(.callout)
            Text(model.demoEnabled ? detail : "No sources connected").font(.caption2).foregroundStyle(Palette.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TimelineRow: View {
    let event: DemoEvent
    var body: some View {
        HStack(spacing: 12) {
            ProviderMark(provider: event.provider)
            VStack(alignment: .leading, spacing: 4) {
                Text(event.kind.label).font(.callout)
                Text("\(event.provider.name) · sample").font(.caption).foregroundStyle(Palette.secondary)
            }
            Spacer(minLength: 10)
            Text(event.timeLabel).font(.system(.caption, design: .monospaced)).foregroundStyle(Palette.secondary)
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(Palette.secondary)
        }.padding(.vertical, 13).contentShape(Rectangle())
            .accessibilityElement(children: .combine).accessibilityHint("Inspect fictional event and coverage limits")
    }
}

struct DecisionsView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Follow the evidence.").font(.system(size: 32, weight: .light))
            Text("An event is an observation. Understanding remains yours.").foregroundStyle(Palette.secondary)
            if model.demoEnabled {
                let event = model.selectedEvent ?? DemoFixtures.events[0]
                InstrumentCard {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack { ProviderMark(provider: event.provider); Text(event.kind.label).font(.title2); Spacer(); Text(event.timeLabel).monospacedDigit().foregroundStyle(Palette.secondary) }
                        evidence("Sample source event", "\(event.provider.name) · \(event.id)\n\(event.provenance)", color: Palette.mint)
                        evidence("What this fixture says", event.detail, color: Palette.mint)
                        evidence("Related sample evidence", relatedEvidence(event), color: Palette.lavender)
                        evidence("What remains unknown", "Whether you reviewed this work, verified it elsewhere, or understand its assumptions. No connected source is observing those actions.", color: Palette.amber)
                        Divider()
                        Text("This is an inspector preview. Review rules, user attestations, and reminders are planned for M5; no opportunity has been detected.")
                            .font(.caption).foregroundStyle(Palette.secondary)
                    }
                }
                Eyebrow(text: "Same sample task")
                ForEach(DemoFixtures.events.filter { $0.taskID == event.taskID }) { related in
                    Button { model.selectedEvent = related } label: { TimelineRow(event: related) }.buttonStyle(.plain)
                }
            } else if let session = model.selectedSession {
                SessionDetailView(model: model, session: session).id(session.id)
            } else {
                InstrumentCard { EmptyState(title: "Choose a session.", detail: "Open Sessions to inspect recorded turn outcomes and write a takeaway. No review opportunity detector is running.") }
                Button("Open Sessions") { model.page = .sessions }.buttonStyle(QuietButtonStyle())
            }
        }
    }
    private func evidence(_ title: String, _ detail: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Rectangle().fill(color.opacity(0.65)).frame(width: 2)
            VStack(alignment: .leading, spacing: 6) { Eyebrow(text: title); Text(detail).font(.callout).lineSpacing(4).textSelection(.enabled) }
        }.fixedSize(horizontal: false, vertical: true)
    }
    private func relatedEvidence(_ event: DemoEvent) -> String {
        let tests = DemoFixtures.events.filter { $0.taskID == event.taskID && $0.kind == .testCompleted }
        return tests.isEmpty ? "No test event exists in this fictional task sequence. This says nothing about your real work." : "Fictional test event: \(tests.map(\.id).joined(separator: ", ")). This does not establish test quality."
    }
}
