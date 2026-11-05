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
                }
                DailyContextView(model: model)
                if day.followUps > 0 {
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
                                    Button("Read this exchange →") { model.showMemorySource(sessionID: thread.id, messageID: thread.anchorID) }.buttonStyle(.plain).font(.caption).foregroundStyle(Palette.accent)
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
                        Text(day.contextual ? "The local model interprets replies in a bounded excerpt. A second pass challenges its labels, and the app checks exact sources and attribution. Unread or unsupported replies stay unclear. Additional signals stay with each reply. Interpretations can be wrong." : "The default categories use recognizable English wording and can miss intent, typos or mixed requests. The experimental model-category mode is separate and off by default because it has not passed its quality gate.")
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
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("A CLOSER LOOK AT YOUR DAY").font(.system(size: 10, weight: .medium)).tracking(1.5).foregroundStyle(.white.opacity(0.85))
                    Text("Your replies, at a glance.").font(.system(size: 25, weight: .medium, design: .rounded)).tracking(-0.4).foregroundStyle(.white)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(report.followUps)").font(.system(size: 31, weight: .light, design: .rounded)).monospacedDigit()
                    Text("saved follow-ups").font(.caption2)
                }.foregroundStyle(.white).padding(12).background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
            }.padding(22).background { VernierField() }
            VStack(alignment: .leading, spacing: 18) {
                Text(report.contextual ? "Experimental model categories · inspect each interpretation’s sources." : "Wording categories · choose a category to see the reply and the rule used.")
                    .font(.callout).foregroundStyle(Palette.secondary)
                if report.contextual {
                    Text("\(report.acceptedFollowUps) of \(report.followUps) replies have supported interpretations · \(report.pendingFollowUps) awaiting review. Cards count the main role; additional signals remain visible in each reply.")
                        .font(.caption).foregroundStyle(Palette.secondary)
                }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                ForEach(DailyAction.allCases, id: \.self) { action in
                    Button { model.selectDailyEvidence(action: action) } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: action.symbol).font(.callout).foregroundStyle(dayColor(action))
                                Spacer()
                                Text("\(report.count(action))").font(.system(size: 30, weight: .medium, design: .rounded)).monospacedDigit()
                            }
                            Text(action == .other && report.contextual ? "Unclear / unread" : action.label).font(.callout.weight(.medium)).frame(height: 36, alignment: .top)
                            Text(action == .other && !report.contextual ? "Wording the rules cannot settle" : action.shortExplanation).font(.caption2).foregroundStyle(Palette.secondary).frame(height: 30, alignment: .top)
                        }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                            .background(dayColor(action).opacity(0.055), in: RoundedRectangle(cornerRadius: 13))
                            .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(model.dailyFilter == action ? dayColor(action) : Palette.line.opacity(0.5), lineWidth: model.dailyFilter == action ? 1.5 : 0.5))
                    }.buttonStyle(.plain).help(action.definition)
                        .accessibilityLabel("\(action.label), \(report.count(action)). Show matching replies and their times")
                }
            }
            DailyShareBar(report: report, height: 7)
            Text("An interpretation of saved words, not a grade. A brief approval can be deliberate; asking for a check does not mean it happened.")
                .font(.caption).foregroundStyle(Palette.secondary).lineSpacing(3)
            }.padding(22)
        }.background(Palette.surface.opacity(0.78)).clipShape(RoundedRectangle(cornerRadius: 22))
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
        case .other: "Awaiting review or meaning unclear"
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
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Palette.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
    }
}
struct DailyProjectsView: View {
    @ObservedObject var model: AppModel
    let report: DailyParticipation
    var body: some View {
        DisclosureGroup("Across your work", isExpanded: $model.dailyProjectsExpanded) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Grouped by workspace. Each title names one conversation’s current goal; a workspace can contain several tasks.").font(.caption2).foregroundStyle(Palette.secondary)
                ForEach(report.projects.prefix(8)) { project in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.dailyProjectTitle(project)).font(.callout.weight(.medium)).lineLimit(2)
                        Text("\(project.continued) handed back · \(project.checked) asked for a check · \(project.moments.count) follow-ups").font(.caption).foregroundStyle(Palette.secondary)
                        if let last = project.moments.last { Button("Explore this work →") { model.openDailyMoment(last) }.buttonStyle(.plain).font(.caption).foregroundStyle(Palette.accent) }
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
                            VStack(alignment: .leading, spacing: 10) {
                                Text(moment.reason)
                                if let reading = moment.interpretation {
                                    ForEach(reading.claims, id: \.action) { claim in
                                        Text(claim.action.label + ": “" + claim.quote + "”")
                                    }
                                    Text("Read by " + reading.engine + " · " + reading.reviewedAt.formatted(date: .abbreviated, time: .shortened))
                                }
                                Text("Wording-only comparison: " + moment.wordingAction.label + ". " + moment.wordingReason)
                            }.font(.caption).foregroundStyle(Palette.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6)
                        }.font(.caption)
                        if let reading = moment.interpretation, reading.claims.count > 1 {
                            Text("Also: " + reading.claims.filter { $0.action != reading.primary }.map { $0.action.label }.joined(separator: " · "))
                                .font(.caption).foregroundStyle(Palette.mint)
                        }
                        HStack(spacing: 18) {
                            Button("Read this exchange →") { model.openDailyMoment(moment) }
                            Button("Original reply ↗") { model.showMemorySource(sessionID: moment.sessionID, messageID: moment.id) }
                        }.buttonStyle(.plain).font(.caption).foregroundStyle(Palette.accent)
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
                Label(model.contributionLabelsEnabled || model.isShowcase ? "Daily counts · experimental contextual interpretations" : "Daily counts · wording rules", systemImage: "list.bullet")
                    .font(.callout.weight(.medium))
                Text(model.contributionLabelsEnabled || model.isShowcase ? "The local model proposes observable acts and a second pass challenges them. The app checks exact sources and attribution, organizes one main role and retains additional signals. Unread replies stay unclear. Open ‘Why this was counted’ for quotes, engine, time and the wording-only comparison." : "The boxes currently use wording rules, not the model. The contextual goal reading below them is separate. Experimental model categories can be tried in local review settings, but have not passed their quality gate; the default remains unchanged.")
                Label(model.reviewingDecision ? "Conversation review · reading locally now" : !model.localInsightsEnabled ? "Conversation review · off" : model.paused || model.systemSuspended ? "Conversation review · paused" : !model.codexEnabled || !model.conversationMemoryEnabled ? "Conversation review · needs saved chats" : model.automaticDecisionReviews ? "Conversation review · automatic" : "Conversation review · manual", systemImage: "sparkle.magnifyingglass")
                    .font(.callout.weight(.medium))
                Text("The same review cycle also suggests a goal and useful next check. Named boundary rules can ask about a changed requirement without a model call. Neither a category nor model agreement certifies that you understood or were steered.")
                if let latest = model.decisionRevisions.max(by: { $0.createdAt < $1.createdAt }) {
                    Text("Latest saved conversation review: " + latest.createdAt.formatted(date: .abbreviated, time: .shortened) + ". This may concern a different day or conversation.")
                } else { Text("No saved conversation review is available yet.") }
                if let error = model.decisionError { Text(error).foregroundStyle(Palette.amber) }
                Text("Automatic reviews wait for 15 seconds of quiet and start at most once every 2 minutes, one conversation at a time. They rest in Low Power Mode; a busy backlog takes longer.")
                if model.contributionLabelsEnabled || model.isShowcase {
                    Text("Each cycle attempts up to four unread replies in the bounded packet, not the entire archive. Daily labels use up to 200 related revisions; older replies may remain unclassified. There is no background weight training.")
                }
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
private struct QuickWorkOverview: View {
    @ObservedObject var model: AppModel
    let report: DailyParticipation
    private let actions: [DailyAction] = [.directed, .checked, .continued, .reported]
    private var dayLabel: String {
        if report.day == WorkDay(containing: Date()) { return "Today so far" }
        return report.day.start.formatted(date: .abbreviated, time: .omitted)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: dayLabel + " · across your work")
            Text("\(report.followUps) \(report.followUps == 1 ? "follow-up" : "follow-ups") · \(report.activeSessionIDs.count) \(report.activeSessionIDs.count == 1 ? "conversation" : "conversations")")
                .font(.callout.weight(.medium))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(actions, id: \.self) { action in
                    Button { model.openQuickEvidence(action) } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            Text("\(report.count(action))").font(.system(size: 21, weight: .medium, design: .rounded)).monospacedDigit().foregroundStyle(dayColor(action))
                            Text(label(action)).font(.caption).foregroundStyle(Palette.text)
                            Spacer(minLength: 0)
                        }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Palette.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
                            .contentShape(RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(.plain).disabled(report.count(action) == 0)
                        .accessibilityLabel("\(report.count(action)) \(action.label). Open matching saved replies.")
                        .help(action.definition)
                }
            }
            Text("\(report.count(.other)) other / unclear · \(report.contextual ? "local interpretations" : "wording cues")")
                .font(.caption2).foregroundStyle(Palette.secondary)
            if report.limited {
                Label("Some saved history is missing or clipped", systemImage: "circle.lefthalf.filled").font(.caption2).foregroundStyle(Palette.amber)
            }
        }
    }
    private func label(_ action: DailyAction) -> String {
        switch action {
        case .directed: "Added direction"
        case .checked: "Asked for checks"
        case .continued: "Asked to continue"
        case .reported: "Reported results"
        case .other: "Other / unclear"
        }
    }
}

struct QuickDailyView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let day = model.quickDailyReport {
                QuickWorkOverview(model: model, report: day)
            }
            if let cue = model.directionToCheck, let reading = cue.reading {
                Button { model.openDirectionCheck() } label: {
                    Label(reading.displayTitle, systemImage: "arrow.triangle.branch").font(.caption.weight(.medium)).foregroundStyle(Palette.amber)
                }.buttonStyle(.plain)
            }
            if !model.quickInsights.isEmpty {
                DisclosureGroup("Conversation checkpoints (\(model.quickInsights.count))") {
                    QuickContextView(model: model, insights: model.quickInsights).padding(.top, 10)
                }.disclosureGroupStyle(RecapDisclosureStyle()).font(.caption)
            } else if model.quickDailyReport != nil {
                Text(model.reviewingDecision ? "Reading conversations locally…" : "Conversation readings are not ready yet.")
                    .font(.caption2).foregroundStyle(Palette.secondary)
            } else if model.directionToCheck == nil {
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
