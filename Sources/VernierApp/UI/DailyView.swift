import SwiftUI
import VernierCore

private func dayColor(_ action: DailyAction) -> Color {
    switch action {
    case .continued: Palette.lavender
    case .directed: Palette.mint
    case .checked: Palette.adaptive(0x86BADB, 0x3877A3)
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
                        DailyRhythmView(model: model, report: day).frame(maxWidth: .infinity)
                        DailyPatternCard(model: model, report: day).frame(maxWidth: .infinity)
                    }
                    DailyEvidenceView(model: model, report: day).id("daily-breakdown")
                    DailyProjectsView(model: model, report: day)
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
                DailyReadingExplanation(model: model)
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
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your replies, at a glance.").font(.title2.weight(.medium))
                Spacer()
                Text("\(report.followUps) saved follow-ups").font(.callout).foregroundStyle(Palette.secondary)
            }
            Text("Choose a category to see what you said, when, and why it was counted.")
                .font(.callout).foregroundStyle(Palette.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                ForEach(DailyAction.allCases, id: \.self) { action in
                    Button { model.selectDailyEvidence(action: action) } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: action.symbol).font(.callout).foregroundStyle(dayColor(action))
                                Spacer()
                                Text("\(report.count(action))").font(.system(size: 30, weight: .medium, design: .rounded)).monospacedDigit()
                            }
                            Text(action.label).font(.callout.weight(.medium)).frame(height: 36, alignment: .top)
                            Text(action.shortExplanation).font(.caption2).foregroundStyle(Palette.secondary).frame(height: 30, alignment: .top)
                        }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                            .background(dayColor(action).opacity(0.055), in: RoundedRectangle(cornerRadius: 13))
                            .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(model.dailyFilter == action ? dayColor(action) : Palette.line.opacity(0.5), lineWidth: model.dailyFilter == action ? 1.5 : 0.5))
                    }.buttonStyle(.plain).help(action.definition)
                        .accessibilityLabel("\(action.label), \(report.count(action)). Show matching replies and their times")
                }
            }
            DailyShareBar(report: report, height: 7)
            Text("From saved words, not a grade. A brief approval can be deliberate; asking for a check does not mean it happened.")
                .font(.caption).foregroundStyle(Palette.secondary).lineSpacing(3)
        }.padding(24).background(Palette.surface, in: RoundedRectangle(cornerRadius: 22))
    }
}
private extension DailyAction {
    var symbol: String {
        switch self {
        case .continued: "arrow.right"
        case .directed: "arrow.triangle.branch"
        case .checked: "magnifyingglass"
        case .reported: "text.bubble"
        case .other: "ellipsis"
        }
    }
    var shortExplanation: String {
        switch self {
        case .continued: "Brief approval or continuation"
        case .directed: "Conditions, choices or corrections"
        case .checked: "Tests, questions or explanations"
        case .reported: "Your own attempt or observation"
        case .other: "Wording the rules cannot settle"
        }
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
    @ObservedObject var model: AppModel
    let report: DailyParticipation
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Eyebrow(text: "When you replied")
            Text("Pick an hour. See the moments.").font(.title3.weight(.medium))
            ScrollView(.horizontal) {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(report.hours) { hour in hourButton(hour) }
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { legend }
                VStack(alignment: .leading, spacing: 6) { legend }
            }
            Text("Reply counts, not time spent. Only hours with saved replies are shown.").font(.caption2).foregroundStyle(Palette.secondary)
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Palette.surface, in: RoundedRectangle(cornerRadius: 18))
    }
    private var largestHour: Int { max(1, report.hours.map { $0.moments.count }.max() ?? 1) }
    private func hourButton(_ hour: DailyHour) -> some View {
        Button { model.selectDailyEvidence(hour: hour.at) } label: {
            VStack(spacing: 5) {
                Text("\(hour.moments.count)").font(.caption2.monospacedDigit()).foregroundStyle(Palette.text)
                VStack(spacing: 2) {
                    ForEach(Array(DailyAction.allCases.reversed()), id: \.self) { action in
                        hourSegment(hour, action: action)
                    }
                }.frame(height: 68, alignment: .bottom)
                Text(hour.at.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))).font(.system(size: 10)).foregroundStyle(Palette.secondary).lineLimit(1)
            }.padding(5).frame(width: 54)
                .background(model.dailyHour == hour.at ? Palette.inset : .clear, in: RoundedRectangle(cornerRadius: 7))
        }.buttonStyle(.plain).accessibilityLabel(hourLabel(hour))
    }
    @ViewBuilder private func hourSegment(_ hour: DailyHour, action: DailyAction) -> some View {
        let count = hour.moments.filter { $0.action == action }.count
        if count > 0 {
            RoundedRectangle(cornerRadius: 2).fill(dayColor(action)).frame(height: CGFloat(count) / CGFloat(largestHour) * 58)
        }
    }
    private func hourLabel(_ hour: DailyHour) -> String {
        let counts = DailyAction.allCases.compactMap { action -> String? in
            let count = hour.moments.filter { $0.action == action }.count
            return count > 0 ? "\(action.label): \(count)" : nil
        }.joined(separator: ", ")
        return hour.at.formatted(date: .omitted, time: .shortened) + ": " + counts + ". Show these replies"
    }
    @ViewBuilder private var legend: some View {
        ForEach(DailyAction.allCases.filter { report.count($0) > 0 }, id: \.self) { action in
            HStack(spacing: 4) {
                Image(systemName: action.symbol).foregroundStyle(dayColor(action))
                Text(action.label).foregroundStyle(Palette.secondary)
            }.font(.caption2).fixedSize()
        }
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
    @State private var visibleCount = 3
    private var values: [DailyMoment] { Array(model.dailyMatchingMoments.reversed()) }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(text: "What happened when")
                    Text(model.dailyFilter?.label ?? "Your saved replies").font(.title3.weight(.medium))
                    Text(selectionCaption).font(.caption).foregroundStyle(Palette.secondary)
                }
                Spacer()
                if model.dailyFilter != nil || model.dailyHour != nil {
                    Button("All replies") { model.selectDailyEvidence() }.font(.caption).buttonStyle(QuietButtonStyle())
                }
            }
            if let action = model.dailyFilter {
                Label(action.definition, systemImage: action.symbol).font(.caption).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if values.isEmpty {
                Text("No saved follow-ups matched this selection. That does not establish that the activity never happened.").font(.callout).foregroundStyle(Palette.secondary)
            }
            ForEach(values.prefix(visibleCount)) { moment in
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 8) {
                        Text(moment.at.formatted(date: .omitted, time: .shortened)).font(.caption.monospacedDigit()).foregroundStyle(Palette.secondary)
                        Image(systemName: moment.action.symbol).foregroundStyle(dayColor(moment.action))
                    }.frame(width: 66)
                    VStack(alignment: .leading, spacing: 9) {
                        Text(moment.action.label).font(.caption.weight(.medium)).foregroundStyle(dayColor(moment.action))
                        Text("“" + (moment.excerpt.isEmpty ? "No visible reply text" : moment.excerpt) + "”").font(.callout).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                        Text(model.dailyMomentTitle(moment)).font(.caption2).foregroundStyle(Palette.secondary).lineLimit(1)
                        DisclosureGroup("Why this was counted") {
                            Text(moment.reason).font(.caption).foregroundStyle(Palette.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6)
                        }.font(.caption)
                        HStack(spacing: 18) {
                            Button("Read this exchange →") { model.openDailyMoment(moment) }
                            Button("Original reply ↗") { model.showMemorySource(sessionID: moment.sessionID, messageID: moment.id) }
                        }.buttonStyle(.plain).font(.caption).foregroundStyle(Palette.mint)
                    }
                    Spacer(minLength: 0)
                }.padding(.vertical, 5)
                if moment.id != values.prefix(visibleCount).last?.id { Divider() }
            }
            if values.count > visibleCount {
                Button("Show more replies · \(values.count - visibleCount) remaining") { visibleCount += 12 }
                    .buttonStyle(QuietButtonStyle()).font(.caption)
            }
        }.padding(22).background(Palette.surface, in: RoundedRectangle(cornerRadius: 18))
            .onChange(of: model.dailyEvidenceRevision) { visibleCount = 12 }
    }
    private var selectionCaption: String {
        let hour = model.dailyHour.map { " · hour starting " + $0.formatted(date: .omitted, time: .shortened) } ?? ""
        return "\(values.count) of \(report.followUps) saved follow-ups" + hour + " · latest first"
    }
}
private struct DailyReadingExplanation: View {
    @ObservedObject var model: AppModel
    var body: some View {
        DisclosureGroup("How Vernier reads your work") {
            VStack(alignment: .leading, spacing: 12) {
                Label("Daily counts · wording rules", systemImage: "list.bullet")
                    .font(.callout.weight(.medium))
                Text("These categories look for recognizable phrases in saved replies. They do not use a model and can miss intent, typos or mixed requests. Open ‘Why this was counted’ to see the rule used.")
                Label(model.reviewingDecision ? "Conversation review · reading locally now" : !model.localInsightsEnabled ? "Conversation review · off" : model.paused || model.systemSuspended ? "Conversation review · paused" : !model.codexEnabled || !model.conversationMemoryEnabled ? "Conversation review · needs saved chats" : model.automaticDecisionReviews ? "Conversation review · automatic" : "Conversation review · manual", systemImage: "sparkle.magnifyingglass")
                    .font(.callout.weight(.medium))
                Text("Separately, the local reader uses surrounding messages to suggest a goal and useful next check, then challenges that reading against the sources. Named boundary rules can ask about a changed requirement without a model call. A reading can be wrong; it does not certify that you understood or were steered.")
                if let latest = model.decisionRevisions.max(by: { $0.createdAt < $1.createdAt }) {
                    Text("Latest saved conversation review: " + latest.createdAt.formatted(date: .abbreviated, time: .shortened) + ". This may concern a different day or conversation.")
                } else { Text("No saved conversation review is available yet.") }
                if let error = model.decisionError { Text(error).foregroundStyle(Palette.amber) }
                Text("Automatic reviews wait for 15 seconds of quiet and start at most once every 2 minutes, one conversation at a time. They rest in Low Power Mode; a busy backlog takes longer.")
                Text("Floorplan explains the app’s code and recent changes. It does not supply these metrics or read your personal sessions.")
            }.font(.caption).foregroundStyle(Palette.secondary).lineSpacing(3).padding(.top, 12)
        }.font(.callout).padding(20).background(Palette.surface, in: RoundedRectangle(cornerRadius: 18))
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
