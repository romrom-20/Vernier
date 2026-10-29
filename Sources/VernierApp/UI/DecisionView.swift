import SwiftUI
import VernierCore

struct DecisionOverviewView: View {
    @ObservedObject var model: AppModel
    @State private var perspective = ""
    @State private var addingPerspective = false
    @State private var saving = false
    @State private var perspectiveTarget: DecisionRevision?
    var body: some View {
        VStack(alignment: .leading, spacing: 23) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(text: "A little perspective on the work")
                    Text("See the next thing worth checking.").font(.system(size: 32, weight: .medium, design: .rounded)).tracking(-0.6)
                    Text("A short account of what changed, and one useful way back in.")
                        .font(.callout).foregroundStyle(Palette.secondary).lineSpacing(3)
                }
                Spacer()
                CaptureToggle(model: model, compact: true)
            }
            FollowingWorkStatus(model: model)
            if let signal = model.directionToCheck, signal.sessionID != model.decisionSession?.id {
                Button { model.openDirectionCheck() } label: {
                    HStack { Image(systemName: "arrow.triangle.branch"); Text(signal.reading?.headline ?? "A direction changed in another conversation"); Spacer(); Text("Take a look →") }
                        .font(.callout).foregroundStyle(Palette.amber).padding(16).background(Palette.amber.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
            }
            if !model.library.sessions.isEmpty {
                HStack {
                    Picker("Conversation", selection: Binding(get: { model.decisionSession?.id ?? "" }, set: { id in
                        model.selectDecisionSession(id)
                    })) {
                        ForEach(model.library.sessions) { session in Text(model.decisionTitle(session)).tag(session.id) }
                    }.frame(maxWidth: 580)
                    Spacer()
                    if model.reviewingDecision {
                        ProgressView().controlSize(.small).accessibilityLabel("Reviewing saved evidence locally")
                        Button("Stop review") { model.cancelDecisionReview() }.buttonStyle(.plain).font(.caption).foregroundStyle(Palette.secondary)
                    }
                }
            }
            if let revision = model.currentDecision {
                DecisionAccountView(model: model, revision: revision)
                if !model.currentPerspectives.isEmpty {
                    VStack(alignment: .leading, spacing: 9) {
                        Eyebrow(text: "Your perspective")
                        ForEach(model.currentPerspectives.suffix(3)) { report in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(report.anchorMessageID == revision.anchorMessageID ? "About this request" : "About an earlier request").font(.caption2).foregroundStyle(Palette.secondary)
                                Text(report.text).font(.callout).textSelection(.enabled)
                                if let prior = model.decisionHistory.first(where: { $0.id == report.revisionID }), prior.id != revision.id {
                                    Button("See the reading this referred to") { model.selectedDecisionRevisionID = prior.id }.buttonStyle(.plain).font(.caption).foregroundStyle(Palette.mint)
                                }
                            }
                        }
                        Text("Your account is kept separately from the model’s interpretation.").font(.caption).foregroundStyle(Palette.secondary)
                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(Palette.inset.opacity(0.55), in: RoundedRectangle(cornerRadius: 15))
                }
                HStack(spacing: 18) {
                    Button(addingPerspective ? "Close perspective" : "Add my perspective") {
                        if !addingPerspective {
                            if perspectiveTarget?.id != revision.id { perspective = "" }
                            perspectiveTarget = revision
                        }
                        addingPerspective.toggle()
                    }.buttonStyle(QuietButtonStyle())
                    Button(model.reviewingDecision ? "Reviewing…" : "Revisit with latest evidence") { model.reviewDecision() }
                        .buttonStyle(.plain).foregroundStyle(Palette.mint).disabled(!canReview)
                }
                if addingPerspective {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("What does this account miss?").font(.callout.weight(.medium))
                        if let target = perspectiveTarget { Text("About this saved request: " + target.goal).font(.caption).foregroundStyle(Palette.secondary) }
                        TextField("For example: I chose this deliberately because…", text: $perspective, axis: .vertical).lineLimit(3...6).textFieldStyle(.roundedBorder)
                        HStack {
                            Text("Saved on this Mac · \(perspective.count)/1,500 characters. A later review can consider it.").font(.caption).foregroundStyle(Palette.secondary)
                            Spacer()
                            Button(saving ? "Saving…" : "Save my perspective") {
                                saving = true
                                Task { if await model.saveDecisionPerspective(perspective, about: perspectiveTarget) { perspective = ""; addingPerspective = false; perspectiveTarget = nil }; saving = false }
                            }.buttonStyle(QuietButtonStyle()).disabled(perspective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || perspective.count > 1500 || saving || model.isShowcase || perspectiveTarget == nil)
                        }
                    }.padding(18).background(Palette.surface, in: RoundedRectangle(cornerRadius: 15))
                    if model.isShowcase { Text("The showcase is read-only; personal perspectives are saved only in the live app.").font(.caption).foregroundStyle(Palette.secondary) }
                }
                if model.decisionHistory.count > 1 {
                    DisclosureGroup("How this account has changed") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(model.decisionHistory.prefix(8)) { old in
                                Button { model.selectedDecisionRevisionID = old.id } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(old.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(Palette.secondary)
                                        Text(old.summary).font(.callout).lineLimit(2)
                                        Text(old.goal).font(.caption).foregroundStyle(Palette.secondary).lineLimit(2)
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                }.buttonStyle(.plain)
                            }
                            Button("Return to latest account") { model.selectedDecisionRevisionID = nil }.buttonStyle(.plain).foregroundStyle(Palette.mint)
                        }.padding(.top, 10)
                    }.font(.caption)
                }
            } else {
                InstrumentCard {
                    HStack(alignment: .top, spacing: 20) {
                        Image(systemName: "point.topleft.down.curvedto.point.bottomright.up").font(.system(size: 28, weight: .light)).foregroundStyle(Palette.mint).frame(width: 45)
                        VStack(alignment: .leading, spacing: 12) {
                            Text(model.reviewingDecision ? "Finding the thread of this work…" : "Let’s connect the request to what happened next.").font(.title2)
                            Text("Vernier looks for a changed direction, a result worth checking, or a problem that returned. The main view gives you a short takeaway; the messages stay one click away.").font(.callout).foregroundStyle(Palette.secondary).lineSpacing(3)
                            Button(model.reviewingDecision ? "Reading locally…" : "Find a useful next check") { model.reviewDecision() }.buttonStyle(QuietButtonStyle()).disabled(!canReview || model.decisionSession == nil)
                        }
                    }
                }
            }
            if let error = model.decisionError { Label(error, systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(Palette.amber) }
            if let notice = model.decisionNotice { Text(notice).font(.caption).foregroundStyle(Palette.secondary) }
            DecisionEngineSettings(model: model)
            PresenceExplanation(model: model)
        }
        .onChange(of: model.memoryEraseRevision) {
            perspective = ""; addingPerspective = false; perspectiveTarget = nil
        }
    }
    private var canReview: Bool { model.localInsightsEnabled && model.conversationMemoryEnabled && model.codexEnabled && !model.paused && !model.systemSuspended && !model.reviewingDecision && !model.isShowcase }
}

struct DecisionAccountView: View {
    @ObservedObject var model: AppModel
    let revision: DecisionRevision
    @State private var responding = false
    var body: some View {
        VStack(alignment: .leading, spacing: 21) {
            if let reading = revision.reading {
                HStack {
                    Label(reading.focus.label, systemImage: reading.focus == .directionChange ? "arrow.triangle.branch" : "sparkle.magnifyingglass")
                        .font(.caption.weight(.medium)).foregroundStyle(reading.focus == .directionChange ? Palette.amber : Palette.mint)
                    Spacer()
                    Text(model.isShowcase ? "Invented example" : reading.boundaryRule != nil ? "Source-backed question" : "A local interpretation").font(.caption2).foregroundStyle(Palette.secondary)
                }
                Text(reading.displayTitle).font(.system(size: 27, weight: .medium, design: .rounded)).tracking(-0.5).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Image(systemName: "scope").foregroundStyle(Palette.mint)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(reading.focus == .directionChange ? "Earlier requirement" : "Likely goal").font(.caption2).foregroundStyle(Palette.secondary)
                        Text(reading.goal).font(.callout.weight(.medium))
                    }
                }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Palette.inset.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
                Text(reading.account).font(.callout).lineSpacing(5).textSelection(.enabled)
                if reading.focus != .directionChange {
                    if reading.focus == .progress || reading.focus == .none { Text(reading.nextStep).font(.callout).foregroundStyle(Palette.secondary) }
                    Button { model.copyNextCheck(reading) } label: { Label("Copy this check", systemImage: "doc.on.doc") }.buttonStyle(QuietButtonStyle())
                }
                if reading.focus == .directionChange {
                    if revision.directionAcknowledged(by: model.decisionPerspectives) {
                        Label("Your response is saved. This direction won’t keep nudging you.", systemImage: "checkmark").font(.caption).foregroundStyle(Palette.secondary)
                    } else {
                        HStack(spacing: 16) {
                            Button("That was intentional") { respond(WorkReading.intentionalResponse) }.buttonStyle(QuietButtonStyle()).disabled(responding || model.isShowcase)
                            Button("I want to check this") { respond(WorkReading.checkResponse) }.buttonStyle(.plain).foregroundStyle(Palette.mint).disabled(responding || model.isShowcase)
                        }
                    }
                }
            } else {
                Label("No useful takeaway passed the checks yet", systemImage: "magnifyingglass").font(.title3)
                Text("The previous reading couldn’t reliably connect the request to a useful next step. You can retry with the latest conversation; your saved messages are still here.").font(.callout).foregroundStyle(Palette.secondary).lineSpacing(4)
            }
            if revision.id != model.decisionHistory.first?.id { Text("You’re viewing an earlier reading.").font(.caption).foregroundStyle(Palette.secondary) }
            else if !model.isDecisionCurrent { Text("More work has arrived since this reading. A newer result may change this check.").font(.caption).foregroundStyle(Palette.amber) }
            DisclosureGroup("Why this appeared · see the supporting messages") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(revision.evidence) { source in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(source.role == "assistant" ? "The agent’s report or proposal" : source.role == "user_report" ? "Your saved perspective" : "Your supplied words").font(.caption.weight(.medium)).foregroundStyle(source.role == "assistant" ? Palette.lavender : Palette.mint)
                            Text("“\(source.quote)”").font(.callout).textSelection(.enabled)
                            if source.role != "user_report" { Button("Read original ↗") { model.showMemorySource(sessionID: source.sessionID, messageID: source.messageID) }.buttonStyle(.plain).font(.caption).foregroundStyle(Palette.mint) }
                        }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Palette.inset.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                    }
                    Button("See the surrounding exchange") { model.showDecisionSource(revision) }.buttonStyle(QuietButtonStyle())
                    Text("A likely goal is inferred from a bounded excerpt. Agent reports are claims, not independently verified results. This does not establish what you read or understood outside the saved conversation.").font(.caption).foregroundStyle(Palette.secondary)
                }.padding(.top, 12)
            }.font(.caption)
            DisclosureGroup("Review details") {
                Text(revision.check + " Engine: " + revision.engine + ". \(revision.loadedMessages) messages selected from \(revision.storedMessages) saved here. Context may be missing. Your corrections can change the next reading.").font(.caption).foregroundStyle(Palette.secondary).padding(.top, 8)
            }.font(.caption)
        }.padding(26).frame(maxWidth: .infinity, alignment: .leading).background(Palette.surface, in: RoundedRectangle(cornerRadius: 22))
    }
    private func respond(_ text: String) {
        responding = true
        Task { _ = await model.saveDecisionPerspective(text, about: revision); responding = false }
    }
}

struct FollowingWorkStatus: View {
    @ObservedObject var model: AppModel
    private var ready: Bool { model.codexEnabled && model.conversationMemoryEnabled && !model.paused }
    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(ready && model.automaticDecisionReviews && model.localInsightsEnabled ? Palette.mint : Palette.amber).frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 4) {
                Text(model.paused ? "Updates are paused" : !ready ? "Connect saved Codex conversations to begin" : !model.localInsightsEnabled ? "Saved conversations are collecting; AI review is off" : model.automaticDecisionReviews ? "Following changed work automatically" : "Reviews are manual right now").font(.callout.weight(.medium))
                Text(model.paused ? "Resume capture to bring new work into view." : model.automaticDecisionReviews && model.localInsightsEnabled ? "Short local reviews after the conversation settles. The circle quietly marks a possible direction change." : "New messages won’t produce a reading until you review them or turn on automatic revisiting.").font(.caption).foregroundStyle(Palette.secondary)
            }
            Spacer(minLength: 12)
            if model.paused { CaptureToggle(model: model, compact: true) }
            else if ready && (!model.automaticDecisionReviews || !model.localInsightsEnabled) { Button("Follow changed work") { model.startFollowingWork() }.buttonStyle(QuietButtonStyle()).disabled(model.isShowcase) }
            else if !ready { Button("Connect saved conversations") { model.showMemory() }.buttonStyle(.plain).font(.caption).foregroundStyle(Palette.mint) }
        }.padding(15).background(Palette.inset.opacity(0.55), in: RoundedRectangle(cornerRadius: 13))
    }
}

struct DecisionEngineSettings: View {
    @ObservedObject var model: AppModel
    var body: some View {
        DisclosureGroup("Local model and review settings") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Review saved work on this Mac", isOn: $model.localInsightsEnabled).toggleStyle(.switch)
                Picker("Local model", selection: $model.reasoningModel) {
                    Text("Apple on-device · experimental").tag("apple")
                    Text("Gemma 4 E2B · experimental").tag("gemma4:e2b-it-qat")
                    Text("Qwen2.5 7B · experimental").tag("qwen2.5:7b")
                }.frame(maxWidth: 450)
                Toggle("Revisit changed work automatically", isOn: $model.automaticDecisionReviews).toggleStyle(.switch)
                    .disabled(!model.localInsightsEnabled)
                Text("Experimental: models can misread the exchange. Start with a manual review and compare its sources. Automatic reviews are off initially; collection keeps working without inference.").font(.caption).foregroundStyle(Palette.secondary)
                Text("The model runs locally: Apple’s on-device framework, or Ollama at 127.0.0.1. No cloud fallback or per-call API fee. Downloaded models must be installed separately. With Ollama, weights unload after 30 idle seconds.")
                    .font(.caption).foregroundStyle(Palette.secondary)
                HStack {
                    Button(model.checkingEngine ? "Checking…" : "Check local engine") { model.checkDecisionEngine() }.buttonStyle(QuietButtonStyle()).disabled(model.checkingEngine)
                    if let status = model.engineHealth { Text(status).font(.caption).foregroundStyle(Palette.secondary) }
                }
                if model.paused { Text("Collection is paused. Reviews resume when you resume capture.").font(.caption).foregroundStyle(Palette.secondary) }
                if !model.conversationMemoryEnabled { Button("Open conversation memory →") { model.showMemory() }.buttonStyle(.plain).foregroundStyle(Palette.mint) }
            }.padding(.top, 10)
        }.font(.caption)
    }
}

struct QuickDecisionView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let revision = model.directionToCheck ?? model.currentDecision
            if let reading = revision?.reading {
                Eyebrow(text: reading.focus.label)
                Text(reading.displayTitle).font(.system(size: 20, weight: .medium, design: .rounded)).tracking(-0.3).lineLimit(4)
                Text(reading.goal).font(.caption.weight(.medium)).foregroundStyle(Palette.mint).lineLimit(3)
                Text(reading.account).font(.caption).foregroundStyle(Palette.secondary).lineLimit(3)
                Button("Look at this →") {
                    if model.directionToCheck != nil { model.openDirectionCheck() } else { model.openStudio(.overview) }
                }.font(.caption.weight(.medium)).buttonStyle(.plain).foregroundStyle(Palette.mint)
            } else {
                Eyebrow(text: "Your next useful check")
                Text(model.reviewingDecision ? "Connecting the request to what happened next…" : model.automaticDecisionReviews ? "Following the work as it changes." : "Saved work is waiting for a review.").font(.system(size: 20, weight: .medium, design: .rounded))
                Text(model.paused ? "Capture is paused. Resume when you want new work brought into view." : model.automaticDecisionReviews ? "A short account will appear after the next local review. Open the dashboard to choose a conversation." : "Open the dashboard to review a conversation or turn on automatic revisiting.").font(.caption).foregroundStyle(Palette.secondary)
            }
            if model.reviewingDecision { HStack { ProgressView().controlSize(.mini); Text("Reading on this Mac").font(.caption2).foregroundStyle(Palette.secondary) } }
            if let error = model.decisionError { Text(error).font(.caption2).foregroundStyle(Palette.amber).lineLimit(2) }
        }
    }
}
