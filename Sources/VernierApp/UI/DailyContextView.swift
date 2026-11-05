import SwiftUI
import VernierCore

struct DailyContextView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !model.dayInsights.isEmpty {
                HStack {
                    Eyebrow(text: "Recent checkpoints")
                    Spacer()
                    Text("\(model.dayInsights.count) \(model.dayInsights.count == 1 ? "conversation" : "conversations")").font(.caption).foregroundStyle(Palette.secondary)
                }
                Text("Local interpretations with saved sources; you can correct them.").font(.caption).foregroundStyle(Palette.secondary)
                ForEach(model.dayInsights) { insight in
                    InstrumentCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(insight.historical ? "Saved checkpoint" : "Conversation checkpoint").font(.caption.weight(.medium))
                                Spacer()
                                Text(insight.revision.createdAt.formatted(date: .omitted, time: .shortened)).font(.caption.monospacedDigit())
                            }.foregroundStyle(Palette.secondary)
                            Text(insight.reading.goal).font(.title3.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                            Label(insight.reading.evidenceLabel, systemImage: "text.magnifyingglass").font(.callout)
                            VStack(alignment: .leading, spacing: 6) {
                                Eyebrow(text: insight.reading.focus == .progress ? "Carry forward" : "Next checkpoint")
                                Text(insight.reading.nextStep).font(.callout).fixedSize(horizontal: false, vertical: true)
                            }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                                .background(Palette.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                            Button("See this reading and its sources →") { model.openDayInsight(insight) }.buttonStyle(QuietButtonStyle())
                            if insight.historical {
                                Text("Saved interpretation from this date; later work may differ.").font(.caption2).foregroundStyle(Palette.secondary)
                            }
                        }
                    }
                }
                DisclosureGroup("What these checkpoints cover") {
                    Text("Uses up to 200 saved readings created on the selected day and keeps the latest in each active conversation. These are conversation checkpoints, not a complete list of open tasks. Current-day readings must still match their sources; historical readings describe what was saved then. A goal or relationship can be misread even when its quotations are valid.")
                        .font(.caption).foregroundStyle(Palette.secondary).padding(.top, 10)
                }.font(.caption)
            } else {
                InstrumentCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(text: "A useful way back into the work")
                        Text(model.dailyDayOffset == 0 ? "A contextual reading isn’t ready yet." : "No outcome-based reading is available for that day.").font(.title2.weight(.medium))
                        Text(model.dailyDayOffset == 0 ? "The saved exchanges are available below. A local review can connect a practical goal to what was reported and one useful next step. It can be wrong; it does not measure how much you thought." : "The recorded replies remain available below. A review made now would describe the latest saved state, rather than reconstructing what a past reading would have said.").font(.callout).foregroundStyle(Palette.secondary)
                        if let moment = model.dailyRevisit {
                            HStack(spacing: 18) {
                                Button("Read this exchange") { model.openDailyMoment(moment) }.buttonStyle(QuietButtonStyle())
                            }
                        }
                        if model.dailyDayOffset == 0, let sessionID = model.dailyReviewSessionID {
                            Button(model.reviewingDecision ? "Reading locally…" : "Review this saved work") { model.reviewDecision(sessionID: sessionID) }
                                .buttonStyle(QuietButtonStyle()).disabled(model.reviewingDecision || model.paused || model.systemSuspended || !model.conversationMemoryEnabled || !model.codexEnabled || model.isShowcase)
                        }
                        if let error = model.decisionError { Text(error).font(.caption).foregroundStyle(Palette.amber) }
                    }
                }
            }
        }
    }
}

struct QuickContextView: View {
    @ObservedObject var model: AppModel
    let insights: [WorkDayInsight]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Eyebrow(text: insights.first?.historical == true ? "Saved checkpoints" : "Recent checkpoints")
                Spacer(minLength: 4)
                Text("\(min(insights.count, 3)) of \(insights.count)").font(.caption2.monospacedDigit()).foregroundStyle(Palette.secondary)
            }
            ForEach(Array(insights.prefix(3))) { insight in
                Button { model.openDayInsight(insight) } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(insight.reading.goal).font(.callout.weight(.medium)).lineLimit(2)
                        Text(insight.reading.evidenceLabel).font(.caption2).foregroundStyle(Palette.secondary)
                        Text(insight.reading.nextStep).font(.caption).lineLimit(2)
                        Text("Reading and sources →").font(.caption2.weight(.medium)).foregroundStyle(Palette.accent)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
                        .background(Palette.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
                        .contentShape(RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
                    .accessibilityHint("Opens this checkpoint and its saved sources")
            }
            Text(insights.count > 3 ? "Latest reading per conversation. Open the recap for all \(insights.count)." : "Latest saved reading in each conversation.")
                .font(.caption2).foregroundStyle(Palette.secondary)
        }
    }
}
