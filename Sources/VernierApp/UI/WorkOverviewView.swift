import SwiftUI
import VernierCore

struct WorkOverviewView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 25) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 9) {
                    Eyebrow(text: "A little perspective on your work")
                    Text("Your part in the work.").font(.system(size: 33, weight: .medium, design: .rounded)).tracking(-0.8)
                    Text("What you handed over. What you questioned. Where you changed the direction.")
                        .font(.callout).foregroundStyle(Palette.secondary).lineSpacing(3)
                }
                Spacer()
                CaptureToggle(model: model, compact: true)
            }
            if let moment = model.selectedParticipation {
                ParticipationDetail(model: model, moment: moment).id("participation-focus")
                let alternatives = otherMoments(moment)
                if !alternatives.isEmpty {
                    VStack(alignment: .leading, spacing: 13) {
                        Eyebrow(text: "Other moments to understand")
                        ForEach(alternatives) { item in
                            Button { model.selectedParticipationID = item.id } label: {
                                HStack(alignment: .top, spacing: 14) {
                                    ParticipationGlyph(kind: item.kind, compact: true).frame(width: 37, height: 37)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(item.kind.title).font(.callout.weight(.medium))
                                        Text(item.userSource?.quote ?? "Open the exchange").font(.caption).foregroundStyle(Palette.secondary).lineLimit(2)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.left").font(.caption).foregroundStyle(Palette.secondary)
                                }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 15))
                            }.buttonStyle(.plain).accessibilityLabel("\(item.kind.title) Show this exchange")
                        }
                    }
                }
            } else { ParticipationEmptyView(model: model) }
            PresenceExplanation(model: model)
            DisclosureGroup("What this reading is based on") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("These readings match explicit wording in its saved exchange: a request to test or explain, a condition you added, a short instruction to continue, or a reported recurring issue with related earlier wording. They are starting points for reflection. No model generated these readings.")
                    Text("A request to explain does not show that you understood the answer. An agent’s later reply is its report; checks you made elsewhere and actual project outcomes may be missing. The rules can misread quotes, negation and app-added text.")
                    if let overview = model.workOverview {
                        Text("Recent context: \(overview.sessions.count) of \(overview.eligibleSessions) recently updated conversations; \(overview.loadedMessages) of \(overview.storedMessages) saved messages loaded. Provider history may still be filling. At most 24 conversations, giving each workspace a slot first, with the latest 100 messages and 4,096 characters per message. Readings use dated requests from the past 24 hours.")
                    }
                    Text("Readings are ordered by explicit evidence/check or recurring-issue wording, then constraints/explanations, then simple continuation or other requests, and by recency within each group. This is not an assessment of importance, cognitive effort or understanding.")
                }.font(.caption).foregroundStyle(Palette.secondary).padding(.top, 9)
            }.font(.caption)
            if let error = model.workOverviewError { Text(error).font(.caption).foregroundStyle(Palette.amber) }
        }.task(id: model.workOverviewKey) { await model.loadWorkOverview() }
    }
    private func otherMoments(_ selected: ParticipationMoment) -> [ParticipationMoment] {
        var kinds = Set<ParticipationKind>()
        return Array(model.participationMoments.filter { moment in
            guard moment.id != selected.id else { return false }
            return kinds.insert(moment.kind).inserted
        }.prefix(4))
    }
}

struct ParticipationDetail: View {
    @ObservedObject var model: AppModel
    let moment: ParticipationMoment
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .center, spacing: 17) {
                ParticipationGlyph(kind: moment.kind).frame(width: 66, height: 66)
                VStack(alignment: .leading, spacing: 8) {
                    Text(moment.kind.label.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(1.1).foregroundStyle(participationColor(moment.kind))
                    Text(moment.kind.title).font(.system(size: 27, weight: .medium, design: .rounded)).tracking(-0.5)
                }
                Spacer(minLength: 0)
            }
            Text(moment.kind.shortReading).font(.callout).foregroundStyle(Palette.secondary).lineSpacing(3)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(moment.sources.enumerated()), id: \.element.id) { index, source in
                    SourceStep(source: source, isLast: index == moment.sources.count - 1)
                }
            }
            VStack(alignment: .leading, spacing: 9) {
                Eyebrow(text: "Why this may matter")
                Text(moment.kind.significance).font(.callout).foregroundStyle(Palette.secondary).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                if moment.followingReply != nil {
                    Text("The later reply is an agent report. What you understood or verified afterward remains open.")
                        .font(.caption).foregroundStyle(Palette.secondary)
                }
            }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(Palette.inset.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
            HStack(spacing: 20) {
                Button { model.readParticipation(moment) } label: { Label("See the surrounding exchange", systemImage: "bubble.left.and.bubble.right") }
                    .buttonStyle(QuietButtonStyle())
                Button("Open original messages ↗") { model.showMemory(sessionID: moment.sessionID, query: moment.userSource?.quote ?? "") }
                    .buttonStyle(.plain).font(.caption).foregroundStyle(Palette.mint)
            }
        }.padding(25).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Palette.line.opacity(0.5), lineWidth: 0.5))
    }
}

private struct SourceStep: View {
    let source: ParticipationSource
    let isLast: Bool
    private var human: Bool { source.speaker == "user" }
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 5) {
                Image(systemName: human ? "person.fill" : "sparkle").font(.system(size: 10, weight: .medium))
                    .foregroundStyle(human ? Palette.mint : Palette.lavender).frame(width: 25, height: 25)
                    .background((human ? Palette.mint : Palette.lavender).opacity(0.08), in: Circle())
                if !isLast { Rectangle().fill(Palette.line.opacity(0.55)).frame(width: 1).frame(maxHeight: .infinity) }
            }.frame(width: 25)
            VStack(alignment: .leading, spacing: 7) {
                Text(source.label).font(.caption.weight(.medium)).foregroundStyle(human ? Palette.mint : Palette.lavender)
                Text("“\(source.quote)”").font(.system(size: 14)).lineSpacing(3).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, isLast ? 0 : 23)
        }.fixedSize(horizontal: false, vertical: true).accessibilityElement(children: .combine)
    }
}

struct ParticipationGlyph: View {
    let kind: ParticipationKind
    var compact = false
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: compact ? 12 : 20).fill(participationColor(kind).opacity(0.07))
            GeometryReader { geometry in
                let w = geometry.size.width, h = geometry.size.height
                Path { path in
                    path.move(to: CGPoint(x: w * 0.22, y: h * 0.66))
                    path.addCurve(to: CGPoint(x: w * 0.78, y: h * 0.28), control1: CGPoint(x: w * 0.57, y: h * 0.66), control2: CGPoint(x: w * 0.43, y: h * 0.28))
                }.stroke(participationColor(kind).opacity(0.55), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                Circle().fill(Palette.lavender).frame(width: compact ? 4 : 6, height: compact ? 4 : 6).position(x: w * 0.22, y: h * 0.66)
                Circle().fill(Palette.mint).frame(width: compact ? 5 : 8, height: compact ? 5 : 8).position(x: w * 0.78, y: h * 0.28)
                Circle().strokeBorder(Palette.mint.opacity(0.5), lineWidth: 1).frame(width: compact ? 12 : 19, height: compact ? 12 : 19).position(x: w * 0.78, y: h * 0.28)
            }
        }.accessibilityHidden(true)
    }
}

private func participationColor(_ kind: ParticipationKind) -> Color {
    switch kind {
    case .returnedIssue: Palette.amber
    case .continued: Palette.lavender
    default: Palette.mint
    }
}

struct PresenceExplanation: View {
    @ObservedObject var model: AppModel
    private var explanation: String {
        if model.isShowcase { return "These are invented exchanges. This preview reads no personal history. In the live app, the circle controls background memory from Codex in Conductor." }
        if model.paused { return "New collection is paused. You can still explore saved work. The circle lets you resume or open this context." }
        if !model.codexEnabled { return "Connect Codex in Conductor to build a local memory of your work. The circle gives you quick capture controls." }
        if !model.conversationMemoryEnabled { return "Only activity metadata is connected. Enable conversation memory to see your requests and the agent’s replies in context." }
        return "While Vernier is running, saved Codex work follows you across Conductor workspaces—even with this window and the circle hidden. The circle lets you pause collection or return to the context."
    }
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: "circle.dotted").font(.system(size: 27, weight: .light)).foregroundStyle(Palette.mint)
            VStack(alignment: .leading, spacing: 7) {
                Text(model.paused ? "Your saved work is still here." : "Here while you work.").font(.callout.weight(.medium))
                Text(explanation)
                    .font(.caption).foregroundStyle(Palette.secondary).lineSpacing(3)
                Button("See what Vernier remembers →") { model.openStudio(.connections) }.buttonStyle(.plain).font(.caption).foregroundStyle(Palette.mint)
            }
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.inset.opacity(0.45), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct ParticipationEmptyView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        InstrumentCard {
            VStack(alignment: .leading, spacing: 14) {
                ParticipationGlyph(kind: .instruction).frame(width: 56, height: 56)
                Text(model.workOverviewLoading ? "Gathering the context…" : "A little context comes first.").font(.title2)
                Text("Vernier needs a saved request and its surrounding replies to show your part in the work. Conversation memory may be off, still filling, or missing source times.")
                    .font(.callout).foregroundStyle(Palette.secondary).lineSpacing(3)
                Button("See connected memory →") { model.openStudio(.connections) }.buttonStyle(QuietButtonStyle())
            }
        }
    }
}

struct QuickWorkOverviewView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "Your part in the work")
            if let moment = model.participationMoments.first {
                HStack(alignment: .center, spacing: 11) {
                    ParticipationGlyph(kind: moment.kind, compact: true).frame(width: 34, height: 34)
                    Text(moment.kind.title).font(.system(size: 20, weight: .medium, design: .rounded)).tracking(-0.4).fixedSize(horizontal: false, vertical: true)
                }
                Text(moment.kind.shortReading).font(.caption).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
                if let source = moment.userSource {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("YOUR WORDS").font(.system(size: 9, weight: .medium)).tracking(1).foregroundStyle(Palette.mint)
                        Text("“\(source.quote)”").font(.callout).lineLimit(3)
                    }.padding(11).frame(maxWidth: .infinity, alignment: .leading).background(Palette.inset.opacity(0.75), in: RoundedRectangle(cornerRadius: 12))
                }
                Button("Why this matters →") { model.openParticipation(moment) }.font(.caption.weight(.medium)).buttonStyle(.plain).foregroundStyle(Palette.mint)
            } else {
                Text(model.workOverviewLoading ? "Gathering the context…" : "Waiting for your next exchange.").font(.system(size: 20, weight: .medium, design: .rounded))
                Text("Your saved Codex requests and replies help Vernier explain where you shaped the work. Open the dashboard to check connected memory.").font(.caption).foregroundStyle(Palette.secondary)
            }
            if let error = model.workOverviewError { Text(error).font(.caption2).foregroundStyle(Palette.amber) }
        }.task(id: model.workOverviewKey) { await model.loadWorkOverview() }
    }
}
