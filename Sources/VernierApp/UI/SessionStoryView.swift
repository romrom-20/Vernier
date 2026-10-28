import SwiftUI
import VernierCore

struct SessionStoryView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(text: "Codex in Conductor / source exchange")
                    Text("How the work moved.").font(.system(size: 32, weight: .medium, design: .rounded)).tracking(-0.9)
                    Text("Compare the agent’s replies with your next request. The map shows recorded messages, not a measure of attention or understanding.")
                        .font(.callout).foregroundStyle(Palette.secondary).lineSpacing(3)
                }
                Spacer()
                CaptureToggle(model: model, compact: true)
            }
            if !model.library.sessions.isEmpty {
                HStack {
                    Picker("Conversation", selection: Binding(get: { model.briefSession?.id ?? "" }, set: { id in
                        model.cancelWorkBrief(); model.briefSessionID = id; model.storyFocusID = nil; model.briefError = nil
                    })) {
                        ForEach(model.library.sessions) { session in Text(model.library.title(for: session)).tag(session.id) }
                    }.labelsHidden().frame(maxWidth: 520)
                    Spacer()
                    Label("On this Mac", systemImage: "lock").font(.caption).foregroundStyle(Palette.secondary)
                }
            }
            if let story = model.currentStory, !story.runs.isEmpty {
                if story.loadedMessages < story.storedMessages {
                    Text("Recent window · \(story.loadedMessages) of \(story.storedMessages) saved messages. Counts below apply to this window.")
                        .font(.caption).foregroundStyle(Palette.secondary)
                }
                DisclosureGroup("Message coverage") { StoryNumbers(story: story).padding(.top, 8) }.font(.caption)
                ConversationMap(model: model, story: story).id("conversation-map")
            } else if model.storyLoading {
                InstrumentCard { HStack(spacing: 12) { ProgressView().controlSize(.small); Text("Opening the saved conversation…").font(.callout) } }
            } else {
                InstrumentCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Image(systemName: "point.3.connected.trianglepath.dotted").font(.system(size: 36, weight: .ultraLight)).foregroundStyle(Palette.mint)
                        Text("A map begins with a conversation.").font(.title2.weight(.medium))
                        Text("Saved Codex messages become a visual sequence of your directions and the agent’s replies. Connect conversation memory to begin, or choose a session with saved text.")
                            .font(.callout).foregroundStyle(Palette.secondary)
                        Button("Open conversation memory →") { model.showMemory() }.buttonStyle(QuietButtonStyle())
                    }.padding(.vertical, 18)
                }
            }
            if let error = model.storyError { Text(error).font(.caption).foregroundStyle(Palette.amber) }
        }.task(id: model.storyKey) { await model.loadSessionStory() }
    }
}

struct StoryNumbers: View {
    let story: SessionStory
    var body: some View {
        HStack(spacing: 14) {
            StoryNumber(value: story.userMessages, title: "Messages from you", detail: "Recorded requests & follow-ups", symbol: "person.crop.circle", tint: Palette.mint)
            StoryNumber(value: story.agentMessages, title: "Agent messages", detail: "Replies & progress updates", symbol: "sparkle", tint: Palette.lavender)
            StoryNumber(value: story.followUps, title: "Times you came back", detail: "Your message after agent replies", symbol: "arrow.turn.up.left", tint: Palette.amber)
        }
    }
}
private struct StoryNumber: View {
    let value: Int
    let title: String
    let detail: String
    let symbol: String
    let tint: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 9) {
                Text(value.formatted()).font(.system(size: 27, weight: .light, design: .rounded)).monospacedDigit().contentTransition(.numericText())
                Text(title).font(.caption.weight(.medium))
                Spacer(minLength: 0)
                Image(systemName: symbol).font(.caption).foregroundStyle(tint)
            }
            Text(detail).font(.caption2).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.line.opacity(0.45), lineWidth: 0.5))
            .accessibilityElement(children: .combine)
    }
}

struct ConversationMap: View {
    @ObservedObject var model: AppModel
    let story: SessionStory
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedID: String?
    @State private var start: Int?
    @State private var revealed = false
    private let pageSize = 10
    private var first: Int { min(max(0, start ?? (story.runs.count - pageSize)), max(0, story.runs.count - pageSize)) }
    private var shown: [StoryRun] { Array(story.runs.dropFirst(first).prefix(pageSize)) }
    private var reading: DecisionRevision? { model.decisionRevisions.first { $0.sessionID == story.sessionID } }
    private var defaultRun: StoryRun? { story.latestFollowUp ?? story.runs.last }
    private var selected: StoryRun? { story.runs.first { $0.id == selectedID } ?? defaultRun }
    private func possibleLoop(_ run: StoryRun) -> Bool {
        reading?.kind == .recurringIssue && reading?.evidence.contains { source in run.messages.contains { $0.id == source.messageID } } == true
    }
    private var previous: StoryRun? {
        guard let selected, let index = story.runs.firstIndex(where: { $0.id == selected.id }), index > 0 else { return nil }
        return story.runs[index - 1]
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Eyebrow(text: "The conversation map")
                    Text(headline).font(.title2.weight(.medium))
                }
                Spacer()
                HStack(spacing: 8) {
                    Button { movePage(-1) } label: { Image(systemName: "chevron.left").frame(width: 23, height: 26) }
                        .disabled(first == 0).accessibilityLabel("Earlier exchanges")
                    Button { movePage(1) } label: { Image(systemName: "chevron.right").frame(width: 23, height: 26) }
                        .disabled(first + pageSize >= story.runs.count).accessibilityLabel("Later exchanges")
                }.buttonStyle(.plain).foregroundStyle(Palette.secondary)
            }
            Text("Follow a point to compare what the agent said with what you asked next.")
                .font(.callout).foregroundStyle(Palette.secondary)
            GeometryReader { geometry in
                let width = max(1, geometry.size.width - 84)
                let runs = shown
                let points = runs.enumerated().map { index, run in
                    CGPoint(x: 52 + width * CGFloat(index) / CGFloat(max(1, runs.count - 1)), y: run.isUser ? 43 : 119)
                }
                ZStack(alignment: .topLeading) {
                    Path { path in
                        path.move(to: CGPoint(x: 44, y: 43)); path.addLine(to: CGPoint(x: geometry.size.width - 15, y: 43))
                        path.move(to: CGPoint(x: 44, y: 119)); path.addLine(to: CGPoint(x: geometry.size.width - 15, y: 119))
                    }.stroke(Palette.line.opacity(0.3), style: StrokeStyle(lineWidth: 0.5, dash: [3, 6]))
                    Text("You").font(.caption2.weight(.medium)).foregroundStyle(Palette.mint).position(x: 14, y: 43)
                    Text("Agent").font(.caption2.weight(.medium)).foregroundStyle(Palette.lavender).position(x: 17, y: 119)
                    FlowPath(points: points).trim(from: 0, to: revealed ? 1 : 0)
                        .stroke(LinearGradient(colors: [Palette.mint.opacity(0.7), Palette.lavender.opacity(0.6), Palette.mint], startPoint: .leading, endPoint: .trailing), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .accessibilityHidden(true)
                    ForEach(Array(runs.enumerated()), id: \.element.id) { index, run in
                        Button { select(run.id) } label: {
                            ZStack {
                                Circle().fill(run.isUser ? Palette.mint.opacity(0.1) : Palette.lavender.opacity(0.09)).frame(width: 40, height: 40)
                                Circle().strokeBorder(run.id == selected?.id ? (run.isUser ? Palette.mint : Palette.lavender) : .clear, lineWidth: 1.5).frame(width: 40, height: 40)
                                Circle().fill(run.isUser ? Palette.mint : Palette.lavender).frame(width: 12, height: 12)
                                if possibleLoop(run) {
                                    Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(Palette.amber).frame(width: 21, height: 21).background(Palette.surface, in: Circle()).offset(x: 13, y: -13)
                                }
                                if !run.isUser, run.messages.count > 1 {
                                    Text("\(run.messages.count)").font(.system(size: 9, weight: .bold, design: .rounded))
                                        .foregroundStyle(Palette.surface).frame(width: 19, height: 19).background(Palette.lavender, in: Circle()).offset(x: 13, y: -13)
                                }
                            }.scaleEffect(run.id == selected?.id ? 1.08 : 1)
                        }.buttonStyle(.plain).position(points[index])
                            .help(run.isUser ? "Your message: \(String(run.excerpt.prefix(130)))" : "\(run.messages.count) recorded agent messages")
                            .accessibilityLabel("\(run.isUser ? "Your message" : "Agent replies"), group \(first + index + 1), \(run.messages.count) messages")
                            .accessibilityAddTraits(run.id == selected?.id ? .isSelected : [])
                    }
                }
            }.frame(height: 158)
            HStack {
                Label("Your messages", systemImage: "circle.fill").foregroundStyle(Palette.mint)
                Label("Agent reply stretches", systemImage: "circle.fill").foregroundStyle(Palette.lavender)
                Spacer()
                Text("\(first + 1)–\(first + shown.count) of \(story.runs.count) groups")
            }.font(.caption2)
            if reading?.kind == .recurringIssue {
                Label("Markers locate sources behind a tentative recurring-issue reading; they do not measure your understanding.", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption2).foregroundStyle(Palette.amber)
            }
            if let selected {
                Divider().overlay(Palette.line.opacity(0.5))
                HStack(spacing: 8) {
                    Image(systemName: selected.isUser ? "arrow.turn.up.left" : "sparkle").foregroundStyle(selected.isUser ? Palette.mint : Palette.lavender)
                    Text(selected.isUser && selected.priorAgentMessages > 0 ? "You came back after \(selected.priorAgentMessages) agent \(selected.priorAgentMessages == 1 ? "message" : "messages")" : selected.isUser ? "You sent a message" : "The agent replied \(selected.messages.count) \(selected.messages.count == 1 ? "time" : "times")")
                        .font(.callout.weight(.semibold))
                    Spacer()
                    if let time = selected.sourceAt { Text(time.formatted(date: .omitted, time: .shortened)).font(.caption).foregroundStyle(Palette.secondary) }
                }
                HStack(alignment: .top, spacing: 14) {
                    if let previous { StoryQuote(run: previous, sessionID: story.sessionID, heading: previous.isUser ? "Your request before it" : "The preceding agent replies", model: model) }
                    StoryQuote(run: selected, sessionID: story.sessionID, heading: selected.isUser ? "What you asked next" : "The selected reply stretch", model: model, emphasized: true)
                }.id(selected.id).transition(.opacity)
            }
            Text("\(story.loadedMessages) of \(story.storedMessages) saved messages loaded. Reading order, not a focus or time score.\(story.missingSourceTimes > 0 ? " Some source times are missing; order is approximate." : "")")
                .font(.caption2).foregroundStyle(Palette.secondary)
        }.padding(24).background(Palette.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Palette.line.opacity(0.5), lineWidth: 0.5))
            .onAppear { reveal(); focus(model.storyFocusID ?? defaultRun?.messages.last?.id); model.storyMapReadyRevision += 1 }
            .onChange(of: model.storyFocusRevision) { _, _ in focus(model.storyFocusID) }
            .onChange(of: story.sessionID) { _, _ in selectedID = nil; start = nil; reveal() }
    }
    private var headline: String {
        if story.followUps == 0 { return "The first part of the exchange." }
        return "You followed up \(story.followUps) \(story.followUps == 1 ? "time" : "times")."
    }
    private func select(_ id: String) {
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.22)) { selectedID = id }
    }
    private func movePage(_ direction: Int) {
        let index = max(0, min(max(0, story.runs.count - pageSize), first + direction * pageSize))
        start = index
        let page = story.runs.dropFirst(index).prefix(pageSize)
        if let run = page.last(where: \.isUser) ?? page.last { select(run.id) }
    }
    private func focus(_ id: String?) {
        guard let id, let run = story.run(containing: id), let index = story.runs.firstIndex(where: { $0.id == run.id }) else { return }
        if index < first || index >= first + pageSize { start = max(0, min(index - pageSize / 2, story.runs.count - pageSize)) }
        select(run.id)
    }
    private func reveal() {
        guard !reduceMotion, !ProcessInfo.processInfo.isLowPowerModeEnabled else { revealed = true; return }
        withAnimation(.easeOut(duration: 0.65)) { revealed = true }
    }
}
private struct FlowPath: Shape {
    let points: [CGPoint]
    func path(in rect: CGRect) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for index in 1..<points.count {
                let a = points[index - 1], b = points[index]
                let midpoint = (a.x + b.x) / 2
                path.addCurve(to: b, control1: CGPoint(x: midpoint, y: a.y), control2: CGPoint(x: midpoint, y: b.y))
            }
        }
    }
}
private struct StoryQuote: View {
    let run: StoryRun
    let sessionID: String
    let heading: String
    @ObservedObject var model: AppModel
    var emphasized = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(heading.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(0.8).foregroundStyle(Palette.secondary)
            Text(String(run.excerpt.prefix(380))).font(.callout).lineSpacing(3).lineLimit(5).textSelection(.enabled)
            if let progress = run.progressExcerpt {
                Text("Latest update: \(progress)").font(.caption).foregroundStyle(Palette.secondary).lineLimit(2)
            }
            Button("Read source ↗") { if let source = run.representative { model.showMemorySource(sessionID: sessionID, messageID: source.id) } }
                .buttonStyle(.plain).font(.caption.weight(.medium)).foregroundStyle(Palette.mint)
        }.padding(15).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(emphasized ? Palette.mint.opacity(0.06) : Palette.inset.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct StoryInterpretations: View {
    @ObservedObject var model: AppModel
    let story: SessionStory
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(text: "Make sense of the pattern")
                    Text("What might be happening.").font(.title2.weight(.medium))
                }
                Spacer()
                Text(model.isShowcase ? "Synthetic interpretations" : "AI interpretation").font(.caption).foregroundStyle(Palette.secondary)
            }
            if let brief = model.currentBrief, !brief.visibleMoments.isEmpty {
                ForEach(brief.visibleMoments) { moment in
                    StoryPatternCard(model: model, moment: moment, story: story)
                }
            } else {
                InstrumentCard {
                    HStack(alignment: .top, spacing: 16) {
                        Image(systemName: "arrow.triangle.branch").font(.title).foregroundStyle(Palette.mint)
                        VStack(alignment: .leading, spacing: 7) {
                            Text("A return can mean progress, or an unresolved problem.").font(.headline)
                            Text("Compare the two messages above. Did the reply meet the request, or did you need to repeat the same requirement? The recorded sequence alone cannot settle that.")
                                .font(.callout).foregroundStyle(Palette.secondary)
                        }
                    }
                }
            }
            InstrumentCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "scope").foregroundStyle(Palette.mint)
                        Eyebrow(text: "One way to move forward")
                    }
                    Text(checkTitle).font(.title3.weight(.medium))
                    Text(checkDetail).font(.callout).foregroundStyle(Palette.secondary).lineSpacing(3)
                    if let last = story.latestFollowUp {
                        Button("Locate the latest follow-up in the map ↑") { model.focusStory(last.messages.last?.id ?? last.id) }
                            .buttonStyle(.plain).font(.caption.weight(.medium)).foregroundStyle(Palette.mint)
                    }
                    Text("A suggested review step, not a detected mistake.").font(.caption2).foregroundStyle(Palette.secondary)
                }
            }
            DisclosureGroup("AI brief, sources & coverage") { WorkBriefView(model: model).padding(.top, 14) }
                .font(.callout).foregroundStyle(Palette.secondary)
        }
    }
    private var checkTitle: String {
        if model.currentBrief?.visibleMoments.contains(where: { $0.kind == .repair }) == true { return "Settle one requirement before another fix." }
        if model.currentBrief?.visibleMoments.contains(where: { $0.kind == .handoff }) == true { return "Make the expected result explicit." }
        return "Turn the latest request into one observable check."
    }
    private var checkDetail: String {
        if model.currentBrief?.visibleMoments.contains(where: { $0.kind == .repair }) == true {
            return "Pick a requirement that returned. Write the expected behavior, reproduce the current behavior, and compare them before commissioning another change. A completion claim leaves that check open."
        }
        return "Use your latest direction as the starting point. Name one result you could inspect or reproduce. Then compare the agent’s evidence with that result; record what remains uncertain."
    }
}
private struct StoryPatternCard: View {
    @ObservedObject var model: AppModel
    let moment: BriefMoment
    let story: SessionStory
    private var tint: Color { moment.kind == .repair ? Palette.amber : moment.kind == .handoff ? Palette.lavender : Palette.mint }
    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            PatternGlyph(kind: moment.kind, tint: tint).frame(width: 68, height: 68).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 9) {
                Text(moment.kind == .repair ? "A POSSIBLE LOOP" : moment.kind == .steering ? "DIRECTION FROM YOU" : moment.kind == .handoff ? "A POSSIBLE HANDOFF" : "AN OPEN ALTERNATIVE")
                    .font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(tint)
                Text(moment.title).font(.headline)
                Text(moment.detail).font(.callout).foregroundStyle(Palette.secondary).lineSpacing(3)
                HStack(spacing: 16) {
                    if let evidence = moment.evidence.first(where: { $0.speaker == "user" }), story.run(containing: evidence.messageID) != nil {
                        Button("Locate in map ↑") { model.focusStory(evidence.messageID) }.buttonStyle(.plain).foregroundStyle(tint)
                    }
                    Button("Read the evidence ↗") {
                        model.showMemory(sessionID: story.sessionID, query: moment.evidence.first?.quote ?? "")
                    }.buttonStyle(.plain).foregroundStyle(tint)
                }.font(.caption.weight(.medium))
                DisclosureGroup("Why this interpretation?") {
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(Array(moment.evidence.enumerated()), id: \.offset) { _, source in
                            Text("\(source.speaker == "user" ? "You" : "Agent"): “\(source.quote)”").font(.caption).textSelection(.enabled)
                        }
                        Button("This doesn’t fit") { model.dismissMoment(moment.id) }.font(.caption).buttonStyle(.plain).disabled(model.isShowcase || model.paused || !model.conversationMemoryEnabled)
                    }.padding(.top, 7)
                }.font(.caption).foregroundStyle(Palette.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.padding(21).background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(tint.opacity(0.25), lineWidth: 0.7))
    }
}
private struct PatternGlyph: View {
    let kind: BriefMomentKind
    let tint: Color
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18).fill(tint.opacity(0.06))
            if kind == .repair {
                Circle().trim(from: 0.08, to: 0.92).stroke(tint.opacity(0.6), style: StrokeStyle(lineWidth: 1.6, lineCap: .round)).padding(17)
                Image(systemName: "arrowtriangle.up.fill").font(.system(size: 8)).foregroundStyle(tint).rotationEffect(.degrees(35)).offset(x: 10, y: -13)
                Circle().fill(tint).frame(width: 5, height: 5).offset(x: -12, y: 10)
            } else {
                Path { p in p.move(to: CGPoint(x: 17, y: 49)); p.addLine(to: CGPoint(x: 33, y: 33)); p.addLine(to: CGPoint(x: 50, y: 19)); p.move(to: CGPoint(x: 33, y: 33)); p.addLine(to: CGPoint(x: 50, y: 43)) }
                    .stroke(tint.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                Circle().fill(tint).frame(width: 6, height: 6).offset(x: -17, y: 15)
                Circle().fill(tint).frame(width: 6, height: 6).offset(x: 16, y: -15)
                Circle().strokeBorder(tint, lineWidth: 1).frame(width: 6, height: 6).offset(x: 16, y: 9)
            }
        }
    }
}
