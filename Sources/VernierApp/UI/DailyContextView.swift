import SwiftUI
import VernierCore

struct DailyContextView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let first = model.dayInsights.first {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(first.historical ? "A SAVED READING FROM THAT DAY" : "YOUR WORK, IN CONTEXT").font(.caption2.weight(.medium)).tracking(1.3).foregroundStyle(.white.opacity(0.85))
                        Text(first.title).font(.system(size: 26, weight: .medium, design: .rounded)).foregroundStyle(.white)
                        Text(first.reading.goal).font(.callout).foregroundStyle(.white.opacity(0.9))
                    }.padding(24).frame(maxWidth: .infinity, alignment: .leading).background { VernierField() }
                    VStack(alignment: .leading, spacing: 15) {
                        Label(first.evidenceStatus.label, systemImage: "text.magnifyingglass").font(.callout.weight(.medium))
                        Text(first.detail).font(.callout).foregroundStyle(Palette.secondary).lineSpacing(3)
                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow(text: first.reading.focus == .progress ? "What to carry forward" : "One useful way back in")
                            Text(first.reading.nextStep).font(.title3.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Palette.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                        HStack {
                            Button("See why this reading was made →") { model.openDayInsight(first) }.buttonStyle(QuietButtonStyle())
                            Spacer()
                            Text(first.revision.createdAt.formatted(date: .omitted, time: .shortened)).font(.caption).foregroundStyle(Palette.secondary)
                        }
                        Text(first.historical ? "Saved interpretation from this date. Later work may have changed the result." : "A local interpretation with saved sources, not a grade of your understanding.").font(.caption2).foregroundStyle(Palette.secondary)
                    }.padding(24)
                }.background(Palette.surface.opacity(0.80)).clipShape(RoundedRectangle(cornerRadius: 22))
                if model.dayInsights.count > 1 {
                    DisclosureGroup("Other work worth returning to") {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(Array(model.dayInsights.dropFirst().prefix(3))) { insight in
                                Button { model.openDayInsight(insight) } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(insight.reading.goal).font(.callout.weight(.medium))
                                        Text(insight.title).font(.caption).foregroundStyle(Palette.secondary)
                                        Text(insight.reading.nextStep).font(.caption).lineLimit(2)
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                }.buttonStyle(.plain)
                                Divider()
                            }
                        }.padding(.top, 14)
                    }.font(.callout)
                }
                DisclosureGroup("What this reading covers") {
                    Text("Uses up to 200 saved readings created on the selected day and keeps the latest in each active conversation. This is not a complete task history. Current-day readings must still match their sources; historical readings describe what was saved then. A goal or relationship can be misread even when its quotations are valid.")
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
    let insight: WorkDayInsight
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: insight.historical ? "Saved reading · " + insight.revision.createdAt.formatted(date: .abbreviated, time: .omitted) : "One thing worth returning to")
            Text(insight.title).font(.system(size: 20, weight: .medium, design: .rounded)).tracking(-0.3).lineLimit(3)
            VStack(alignment: .leading, spacing: 9) {
                Text(insight.reading.goal).font(.callout.weight(.medium)).lineLimit(2)
                Text(insight.evidenceStatus.label).font(.caption).foregroundStyle(Palette.secondary)
                Divider()
                Text(insight.reading.nextStep).font(.callout).lineLimit(3)
                Button("See the reading and its sources →") { model.openDayInsight(insight) }.buttonStyle(.plain).font(.caption.weight(.medium))
            }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
            Text(insight.historical ? "A saved interpretation; later work may differ." : "Tentative local reading · you can correct it.").font(.caption2).foregroundStyle(Palette.secondary)
        }
    }
}
