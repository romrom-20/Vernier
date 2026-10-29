import SwiftUI
import VernierCore

private func dayColor(_ action: DailyAction) -> Color {
    switch action {
    case .continued: Palette.lavender
    case .directed: Palette.mint
    case .checked: Color(red: 0.22, green: 0.47, blue: 0.64)
    case .reported: Palette.amber
    case .other: Palette.secondary.opacity(0.38)
    }
}
struct DailyOverviewView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            if let cue = model.directionToCheck, let reading = cue.reading {
                Button { model.openDirectionCheck() } label: {
                    HStack(spacing: 10) { Image(systemName: "arrow.triangle.branch"); Text(reading.displayTitle).font(.callout.weight(.medium)); Spacer(); Text("Check this choice →").font(.caption) }
                        .foregroundStyle(Palette.amber).padding(16).background(Palette.amber.opacity(0.07), in: RoundedRectangle(cornerRadius: 13))
                }.buttonStyle(.plain)
            }
            if !model.localInsightsEnabled && !model.isShowcase {
                InstrumentCard {
                    Text("A daily picture, from your saved work.").font(.title2)
                    Text("Enable local review to see your recorded follow-ups, the checks you asked for and a place worth revisiting. Nothing is sent to a cloud model.").font(.callout).foregroundStyle(Palette.secondary)
                    Button("Open local review settings") { model.dailyConversationExpanded = true }.buttonStyle(QuietButtonStyle())
                }
            } else if let day = model.dailyReport {
                if day.followUps > 0 {
                    DailySummaryCard(model: model, report: day)
                    HStack(alignment: .top, spacing: 18) {
                        DailyRhythmView(report: day).frame(maxWidth: .infinity)
                        DailyPatternCard(model: model, report: day).frame(maxWidth: .infinity)
                    }
                    DailyProjectsView(model: model, report: day)
                    DailyEvidenceView(model: model, report: day).id("daily-breakdown")
                } else {
                    InstrumentCard {
                        Text("No dated follow-ups to describe yet.").font(.title2)
                        Text("This view starts when a saved human reply follows an agent reply. Initial requests and messages without source dates don’t enter that percentage. It will update as history arrives.").font(.callout).foregroundStyle(Palette.secondary)
                        if model.dailyDayOffset == 0 { Button("Look at yesterday") { model.chooseDay(-1) }.buttonStyle(QuietButtonStyle()) }
                    }
                }
                if !day.agentOnlyThreads.isEmpty {
                    DisclosureGroup("\(day.agentOnlyThreads.count) conversations have agent replies with no saved follow-up") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("These are outside the follow-up percentage. They may be fully delegated work, ongoing work or review that happened elsewhere.").font(.caption).foregroundStyle(Palette.secondary)
                            ForEach(day.agentOnlyThreads.prefix(6)) { thread in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(thread.excerpt).font(.callout).lineLimit(2)
                                    Button("Read this exchange →") { model.showMemorySource(sessionID: thread.id, messageID: thread.anchorID) }.buttonStyle(.plain).font(.caption).foregroundStyle(Palette.mint)
                                }
                            }
                        }.padding(.top, 12)
                    }.font(.callout).padding(20).background(Palette.surface, in: RoundedRectangle(cornerRadius: 18))
                }
                DailyCheckInView(model: model).id(day.day.key)
                DisclosureGroup("What these numbers can tell you") {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Each item is one saved human message with an earlier agent reply in the same conversation. Multiple human messages in one provider turn count separately. Initial requests aren’t in the denominator. This is wording in the record, not a percentage of tasks or minutes spent thinking.")
                        Text("The rules match recognizable English wording, hide app-added instructions and guard known copied agent text. Short replies can be deliberate delegation; an explanation request can be useful oversight. Typing style, language, missing history and context can change the reading.")
                        Text("\(day.loadedMessages) of \(day.datedTotal) dated messages loaded for this day. \(day.undatedTotal) undated messages in the archive cannot be assigned to a day. \(day.clippedMessages) loaded messages are clipped. \(day.partialHistory ? "Some conversation history is incomplete." : "Available conversation history is marked complete.")")
                        Text("Days use \(day.day.timeZoneID). While your Mac sleeps, Vernier rests too; saved provider history can fill in after wake. Yesterday remains available as a morning recap. The app does not observe sleep or infer how rested you feel.")
                    }.font(.caption).foregroundStyle(Palette.secondary).lineSpacing(4).padding(.top, 10)
                }.font(.caption)
            } else {
                InstrumentCard {
                    HStack { if model.dailyLoading { ProgressView().controlSize(.small) }; Text(model.dailyLoading ? "Bringing your day into view…" : "Your saved work will build the picture here.").font(.title3) }
                    Text("Codex in Conductor · local saved conversations").font(.caption).foregroundStyle(Palette.secondary)
                }
            }
            if let error = model.dailyError { Text(error).font(.caption).foregroundStyle(Palette.amber) }
        }.task(id: model.dailyLoadKey) { await model.loadDailyParticipation() }
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Eyebrow(text: "The human side of the work")
                Spacer()
                HStack(spacing: 12) {
                    Button { model.chooseDay(model.dailyDayOffset - 1) } label: { Image(systemName: "chevron.left") }.disabled(model.dailyDayOffset <= model.dailyOldestOffset).accessibilityLabel("Previous day")
                    Text(model.dailyDayOffset == 0 ? "Today" : model.dailyDayOffset == -1 ? "Yesterday" : model.selectedWorkDay.start.formatted(date: .abbreviated, time: .omitted)).font(.callout.weight(.medium))
                    Button { model.chooseDay(model.dailyDayOffset + 1) } label: { Image(systemName: "chevron.right") }.disabled(model.dailyDayOffset == 0).accessibilityLabel("Next day")
                    if model.dailyDayOffset != 0 { Button("Today") { model.chooseDay(0) }.font(.caption) }
                }.buttonStyle(.plain)
                CaptureToggle(model: model, compact: true)
            }
            Text(model.dailyDayOffset == 0 ? "How you worked with AI today." : "A little perspective on that day.")
                .font(.system(size: 32, weight: .medium, design: .rounded)).tracking(-0.6)
            Text("Saved Codex work in Conductor. What you handed over, where you stepped in, and what to carry forward.").font(.callout).foregroundStyle(Palette.secondary)
            if model.dailyReport?.limited == true { Label("A partial picture of saved work", systemImage: "circle.lefthalf.filled").font(.caption).foregroundStyle(Palette.amber) }
            if model.paused { Text("Capture is paused. This is your saved day so far.").font(.caption).foregroundStyle(Palette.amber) }
        }
    }
}

private struct DailySummaryCard: View {
    @ObservedObject var model: AppModel
    let report: DailyParticipation
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(report.percent(.continued) ?? 0)%").font(.system(size: 64, weight: .light, design: .rounded)).tracking(-2).foregroundStyle(Palette.lavender)
                    Text("handed the next step back").font(.headline)
                    Text("\(report.count(.continued)) of \(report.followUps) recorded follow-ups").font(.caption).foregroundStyle(Palette.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 18) {
                    metric(.directed, subtitle: "constraints, choices or corrections")
                    metric(.checked, subtitle: "tests, explanations or evidence")
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            DailyShareBar(report: report, height: 9)
            Text("A short approval can be a good choice. The useful question is whether you could return to the work and explain the changes that matter.").font(.callout).foregroundStyle(Palette.secondary).lineSpacing(4)
        }.padding(26).background(Palette.surface, in: RoundedRectangle(cornerRadius: 22))
    }
    private func metric(_ action: DailyAction, subtitle: String) -> some View {
        Button { model.dailyFilter = action } label: {
            HStack(alignment: .top, spacing: 12) {
                Text("\(report.count(action))").font(.system(size: 27, weight: .medium, design: .rounded)).foregroundStyle(dayColor(action)).frame(width: 34, alignment: .leading)
                VStack(alignment: .leading, spacing: 3) { Text(action.label).font(.callout.weight(.medium)); Text(subtitle).font(.caption).foregroundStyle(Palette.secondary) }
            }
        }.buttonStyle(.plain).accessibilityLabel("\(action.label), \(report.count(action)). Show matching follow-ups")
    }
}
struct DailyShareBar: View {
    let report: DailyParticipation
    var height: CGFloat = 7
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(DailyAction.allCases, id: \.self) { action in
                    if report.count(action) > 0 {
                        RoundedRectangle(cornerRadius: 3).fill(dayColor(action))
                            .frame(width: max(0, (geometry.size.width - CGFloat(max(0, DailyAction.allCases.filter { report.count($0) > 0 }.count - 1)) * 2) * CGFloat(report.count(action)) / CGFloat(max(1, report.followUps))))
                    }
                }
            }
        }.frame(height: height).accessibilityElement(children: .ignore).accessibilityLabel(DailyAction.allCases.map { "\($0.label): \(report.count($0))" }.joined(separator: ", "))
    }
}
private struct DailyRhythmView: View {
    let report: DailyParticipation
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Eyebrow(text: "Your rhythm")
            Text("Where you stepped in.").font(.title3.weight(.medium))
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(report.hours) { hour in
                    VStack(spacing: 5) {
                        VStack(spacing: 2) {
                            ForEach(DailyAction.allCases.reversed(), id: \.self) { action in
                                let n = hour.moments.filter { $0.action == action }.count
                                if n > 0 { RoundedRectangle(cornerRadius: 2).fill(dayColor(action)).frame(height: CGFloat(n) / CGFloat(max(1, report.hours.map { $0.moments.count }.max() ?? 1)) * 60) }
                            }
                        }.frame(height: 70, alignment: .bottom)
                        Text(hour.at.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))).font(.system(size: 9)).foregroundStyle(Palette.secondary).lineLimit(1).minimumScaleFactor(0.7)
                    }.frame(maxWidth: .infinity).help("\(hour.at.formatted(date: .omitted, time: .shortened)): \(hour.moments.count) saved follow-ups")
                }
            }.frame(height: 92)
            Text("Counts by active hour · gaps between shown hours are omitted. Colors match the breakdown below.").font(.caption2).foregroundStyle(Palette.secondary)
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Palette.surface, in: RoundedRectangle(cornerRadius: 18))
    }
}
private struct DailyPatternCard: View {
    @ObservedObject var model: AppModel
    let report: DailyParticipation
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Eyebrow(text: "One pattern to reflect on")
            Text(report.takeaway).font(.title3.weight(.medium)).fixedSize(horizontal: false, vertical: true)
            Text(report.longestContinuation.count >= 3 ? "That may be efficient delegation. Pick one change from that stretch: what was the reason for it, and what evidence would convince you it works?" : report.repairRequests.count >= 2 ? "A concrete expected behavior can help break a repair loop. What happened, what should have happened, and how would you check the difference?" : report.count(.checked) > 0 ? "A check request shows where you asked for evidence. The saved result, when there is one, helps you see what was actually settled." : "Open the exchange to see what changed and decide what you’d like to understand better.")
                .font(.caption).foregroundStyle(Palette.secondary).lineSpacing(4)
            if let moment = model.dailyRevisit {
                Text("One place to return: “" + moment.excerpt + "”").font(.caption).foregroundStyle(Palette.text).lineLimit(2)
                Button("Review this stretch →") { model.openDailyMoment(moment) }.buttonStyle(.plain).font(.caption.weight(.medium)).foregroundStyle(Palette.mint)
            }
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Palette.inset.opacity(0.65), in: RoundedRectangle(cornerRadius: 18))
    }
}
private struct DailyProjectsView: View {
    @ObservedObject var model: AppModel
    let report: DailyParticipation
    var body: some View {
        DisclosureGroup("Across your work") {
            VStack(alignment: .leading, spacing: 16) {
                Text("Grouped by workspace. Each title names one conversation’s current goal; a workspace can contain several tasks.").font(.caption2).foregroundStyle(Palette.secondary)
                ForEach(report.projects.prefix(8)) { project in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.dailyProjectTitle(project)).font(.callout.weight(.medium)).lineLimit(2)
                        Text("\(project.continued) handed back · \(project.checked) asked for a check · \(project.moments.count) follow-ups").font(.caption).foregroundStyle(Palette.secondary)
                        if let last = project.moments.last { Button("Explore this work →") { model.openDailyMoment(last) }.buttonStyle(.plain).font(.caption).foregroundStyle(Palette.mint) }
                    }
                    if project.id != report.projects.prefix(8).last?.id { Divider() }
                }
                if report.projects.count > 8 { Text("Showing the eight workspace groups with the most recorded follow-ups.").font(.caption2).foregroundStyle(Palette.secondary) }
            }.padding(.top, 15)
        }.font(.callout.weight(.medium)).padding(20).background(Palette.surface, in: RoundedRectangle(cornerRadius: 18))
    }
}
private struct DailyEvidenceView: View {
    @ObservedObject var model: AppModel
    let report: DailyParticipation
    @State private var expanded = false
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Eyebrow(text: "The breakdown")
                Spacer()
                if model.dailyFilter != nil { Button("Show all") { model.dailyFilter = nil }.font(.caption).buttonStyle(.plain).foregroundStyle(Palette.mint) }
            }
            HStack(spacing: 14) {
                ForEach(DailyAction.allCases, id: \.self) { action in
                    Button { model.dailyFilter = model.dailyFilter == action ? nil : action; expanded = true } label: {
                        HStack(spacing: 5) { Circle().fill(dayColor(action)).frame(width: 6, height: 6); Text("\(action.label) \(report.count(action))").font(.caption2).foregroundStyle(model.dailyFilter == action ? Palette.text : Palette.secondary) }
                    }.buttonStyle(.plain)
                }
            }
            DisclosureGroup(model.dailyFilter?.label ?? "See the follow-ups behind these numbers", isExpanded: $expanded) {
                VStack(alignment: .leading, spacing: 12) {
                    if let action = model.dailyFilter { Text(action.definition).font(.caption).foregroundStyle(Palette.secondary) }
                    let values = report.moments.filter { model.dailyFilter == nil || $0.action == model.dailyFilter }.reversed()
                    ForEach(Array(values.prefix(12))) { moment in
                        HStack(alignment: .top, spacing: 12) {
                            Circle().fill(dayColor(moment.action)).frame(width: 7, height: 7).padding(.top, 5)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(moment.excerpt).font(.callout).lineLimit(3)
                                Text(moment.at.formatted(date: .omitted, time: .shortened) + " · " + moment.action.label + (moment.knownCopiedText ? " · known copied agent text" : "")).font(.caption2).foregroundStyle(Palette.secondary)
                                Button("Read original ↗") { model.showMemorySource(sessionID: moment.sessionID, messageID: moment.id) }.buttonStyle(.plain).font(.caption).foregroundStyle(Palette.mint)
                            }
                            Spacer()
                        }
                    }
                    if values.count > 12 { Text("Showing the latest twelve matching follow-ups. All loaded matches count in the breakdown.").font(.caption2).foregroundStyle(Palette.secondary) }
                }.padding(.top, 12)
            }.font(.caption)
        }.padding(20).background(Palette.surface, in: RoundedRectangle(cornerRadius: 18))
        .onChange(of: model.dailyFilter) { expanded = model.dailyFilter != nil }
    }
}
private struct DailyCheckInView: View {
    @ObservedObject var model: AppModel
    @State private var clarity: DailyReflection.Clarity?
    @State private var energy: DailyReflection.Energy?
    @State private var note = ""
    @State private var edited = false
    @State private var saved = false
    @State private var saving = false
    var body: some View {
        DisclosureGroup(model.dailyReflection.map { "My check-in · " + [$0.clarity?.rawValue, $0.energy?.rawValue].compactMap { $0 }.joined(separator: " · ") } ?? "How did the work feel? · optional check-in") {
            VStack(alignment: .leading, spacing: 14) {
                Text("The conversation can show what you wrote. Your own check-in adds how it felt.").font(.caption).foregroundStyle(Palette.secondary)
                HStack { Text("My understanding").font(.caption).frame(width: 125, alignment: .leading); ForEach(DailyReflection.Clarity.allCases, id: \.self) { value in choice(value.rawValue, selected: clarity == value) { clarity = clarity == value ? nil : value } } }
                HStack { Text("My energy").font(.caption).frame(width: 125, alignment: .leading); ForEach(DailyReflection.Energy.allCases, id: \.self) { value in choice(value.rawValue, selected: energy == value) { energy = energy == value ? nil : value } } }
                TextField("One thing I want to remember…", text: $note, axis: .vertical).lineLimit(2...4).textFieldStyle(.roundedBorder).onChange(of: note) { edited = true; saved = false }
                HStack {
                    Text(saved ? "Saved on this Mac." : "Your report · kept with this date · \(note.count)/500").font(.caption2).foregroundStyle(Palette.secondary)
                    Spacer()
                    Button(saving ? "Saving…" : "Save check-in") {
                        saving = true
                        let day = model.selectedWorkDay, savedClarity = clarity, savedEnergy = energy, savedNote = note
                        Task { saved = await model.saveDailyCheckIn(day: day, clarity: savedClarity, energy: savedEnergy, note: savedNote); saving = false; if saved { edited = false } }
                    }.buttonStyle(QuietButtonStyle()).disabled(saving || note.count > 500 || model.isShowcase)
                }
                if model.isShowcase { Text("Read-only invented example; this check-in does not save.").font(.caption2).foregroundStyle(Palette.secondary) }
            }.padding(.top, 14)
        }.font(.callout.weight(.medium)).padding(20).background(Palette.surface, in: RoundedRectangle(cornerRadius: 18))
        .onAppear { restore() }.onChange(of: model.dailyReflection?.updatedAt) { if !edited { restore() } }
    }
    private func restore() { clarity = model.dailyReflection?.clarity; energy = model.dailyReflection?.energy; note = model.dailyReflection?.note ?? "" }
    private func choice(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button { action(); edited = true; saved = false } label: { Text(title).font(.caption).padding(.horizontal, 10).padding(.vertical, 7).background(selected ? Palette.mint.opacity(0.14) : Palette.inset, in: Capsule()) }.buttonStyle(.plain)
    }
}
struct QuickDailyView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            if let cue = model.directionToCheck, let reading = cue.reading {
                Eyebrow(text: "A choice to revisit")
                Text(reading.displayTitle).font(.system(size: 20, weight: .medium, design: .rounded)).fixedSize(horizontal: false, vertical: true)
                Text("A proposed approach differs from an earlier requirement. The recap shows both so you can choose.").font(.callout).foregroundStyle(Palette.secondary)
            } else if let day = model.quickDailyReport {
                let recap = QuickRecap(report: day)
                HStack {
                    Eyebrow(text: model.quickRecapIsPreviousDay || model.dailyDayOffset == -1 ? "Yesterday’s recap" : model.dailyDayOffset == 0 ? "Today so far" : day.day.start.formatted(date: .abbreviated, time: .omitted))
                    Spacer()
                    if day.limited { Text("Partial history").font(.caption2).foregroundStyle(Palette.amber) }
                }
                Text(recap.headline).font(.system(size: 21, weight: .medium, design: .rounded)).tracking(-0.3).fixedSize(horizontal: false, vertical: true)
                Text(recap.detail).font(.callout).foregroundStyle(Palette.secondary)
                if !recap.secondary.isEmpty { Text(recap.secondary).font(.caption).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true) }
                VStack(alignment: .leading, spacing: 5) {
                    Text("One thing to reflect on").font(.caption2).foregroundStyle(Palette.secondary)
                    Text(recap.question).font(.callout.weight(.medium))
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Palette.inset.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
                if model.quickRecapIsPreviousDay { Text("Today: \(model.dailyReport?.followUps ?? 0) saved replies so far. Showing yesterday’s fuller recap.").font(.caption2).foregroundStyle(Palette.secondary) }
            } else {
                Eyebrow(text: "Your saved work")
                Text(emptyTitle).font(.system(size: 21, weight: .medium, design: .rounded)).fixedSize(horizontal: false, vertical: true)
                Text(emptyDetail).font(.callout).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }.task(id: model.dailyLoadKey) { await model.loadDailyParticipation() }
    }
    private var emptyTitle: String {
        if !model.codexEnabled && model.library.totalMessageCount == 0 { return "Connect your saved Codex conversations." }
        if !model.conversationMemoryEnabled && model.library.totalMessageCount == 0 { return "Saved conversation capture is off." }
        if !model.localInsightsEnabled { return "Daily reviews are off." }
        if model.dailyError != nil { return "The recap couldn’t load." }
        if model.dailyLoading { return "Reading your recent conversations…" }
        return model.dailyDayOffset == 0 ? "No saved replies today yet." : "No saved replies for this day."
    }
    private var emptyDetail: String {
        if !model.codexEnabled && model.library.totalMessageCount == 0 { return "Vernier needs saved conversations before it can describe how you worked." }
        if !model.conversationMemoryEnabled && model.library.totalMessageCount == 0 { return "Connect saved chat text to build a recap. Metadata alone doesn’t include your replies." }
        if !model.localInsightsEnabled { return "Turn on local review in the dashboard to build a recap from your saved messages." }
        if let error = model.dailyError { return error + " Open the recap to try again." }
        if model.dailyLoading { return "Checking today and yesterday. Everything stays on this Mac." }
        if model.paused { return "Capture is paused. Your existing conversations are still saved; resume to collect new work." }
        return "A recap needs saved replies from you after an agent message. Earlier conversations remain in the dashboard."
    }
}
