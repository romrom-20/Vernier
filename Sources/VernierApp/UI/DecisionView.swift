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
                    Eyebrow(text: "An account that can change with the evidence")
                    Text("Keep the decisions in view.").font(.system(size: 32, weight: .medium, design: .rounded)).tracking(-0.6)
                    Text("What you wanted. Who introduced the direction. What you contributed. What remains open.")
                        .font(.callout).foregroundStyle(Palette.secondary).lineSpacing(3)
                }
                Spacer()
                CaptureToggle(model: model, compact: true)
            }
            if !model.library.sessions.isEmpty {
                HStack {
                    Picker("Work to understand", selection: Binding(get: { model.decisionSession?.id ?? "" }, set: { id in
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
                    VStack(alignment: .leading, spacing: 15) {
                        ParticipationGlyph(kind: .soughtExplanation).frame(width: 52, height: 52)
                        Text(model.reviewingDecision ? "Reconstructing the decisions…" : "A reading starts with the evidence.").font(.title2)
                        Text("The local engine reads a recent exchange, checks text reuse, proposes an account and challenges it against the sources. Your later messages and corrections can change the account.")
                            .font(.callout).foregroundStyle(Palette.secondary).lineSpacing(3)
                        Button(model.reviewingDecision ? "Reviewing locally…" : "Review this work") { model.reviewDecision() }.buttonStyle(QuietButtonStyle()).disabled(!canReview || model.decisionSession == nil)
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
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Eyebrow(text: revision.status == .unknown ? "What remains uncertain" : "A working interpretation")
                Spacer()
                if revision.id != model.decisionHistory.first?.id { Text("Earlier account").font(.caption).foregroundStyle(Palette.amber) }
                else if !model.isDecisionCurrent { Text("New evidence is waiting").font(.caption).foregroundStyle(Palette.amber) }
                Label(model.isShowcase ? "Synthetic example" : "Reviewed locally", systemImage: "lock").font(.caption2).foregroundStyle(Palette.secondary)
            }
            Text(revision.summary).font(.system(size: 26, weight: .medium, design: .rounded)).tracking(-0.4).fixedSize(horizontal: false, vertical: true)
            if !revision.goal.isEmpty { Text("Saved request: " + revision.goal).font(.callout).foregroundStyle(Palette.secondary) }
            Text(revision.reason).font(.callout).lineSpacing(4).foregroundStyle(Palette.secondary).textSelection(.enabled)
            VStack(alignment: .leading, spacing: 13) {
                ForEach(revision.evidence) { source in
                    VStack(alignment: .leading, spacing: 7) {
                        Text((source.sessionID == revision.sessionID ? "" : "Retrieved from another conversation · ") + sourceLabel(source)).font(.caption.weight(.medium)).foregroundStyle(source.role == "assistant" ? Palette.lavender : Palette.mint)
                        Text("“\(source.quote)”").font(.callout).lineSpacing(3).textSelection(.enabled)
                        if source.role != "user_report" {
                            Button("Read original ↗") { model.showMemorySource(sessionID: source.sessionID, messageID: source.messageID) }.font(.caption).buttonStyle(.plain).foregroundStyle(Palette.mint)
                        }
                    }.padding(15).frame(maxWidth: .infinity, alignment: .leading).background(Palette.inset.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            VStack(alignment: .leading, spacing: 15) {
                explanation("Another possible reading", revision.alternative)
                explanation("Still unknown", revision.unknown)
            }
            HStack {
                Button { model.showDecisionSource(revision) } label: { Label("See the surrounding exchange", systemImage: "bubble.left.and.bubble.right") }.buttonStyle(QuietButtonStyle())
                Spacer()
                Text(revision.createdAt.formatted(date: .omitted, time: .shortened)).font(.caption).foregroundStyle(Palette.secondary)
            }
            DisclosureGroup("How this account was checked") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(revision.check)
                    Text("The action reading, source selection and challenge used \(revision.engine). A host check validates source IDs, text reuse and unsupported claims. Three passes of one model are not independent proof.")
                    Text("\(revision.loadedMessages) source messages, including any retrieved context; \(revision.storedMessages) saved in the conversation. Retrieval and clipping can miss context. User-supplied text is not proof of original authorship, attention or understanding.")
                }.font(.caption).foregroundStyle(Palette.secondary).padding(.top, 8)
            }.font(.caption)
        }.padding(25).frame(maxWidth: .infinity, alignment: .leading).background(Palette.surface, in: RoundedRectangle(cornerRadius: 22))
    }
    private func explanation(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) { Text(title).font(.caption.weight(.medium)); Text(value).font(.callout).foregroundStyle(Palette.secondary).lineSpacing(3) }
    }
    private func sourceLabel(_ source: DecisionEvidence) -> String {
        if source.role == "assistant" { return "The agent’s message" }
        if source.role == "user_report" { return "Your saved perspective" }
        switch source.origin {
        case .reusedAgent: return "Text you supplied · matches known agent wording"
        case .mixed: return "Added words in your supplied message"
        default: return "Your saved message"
        }
    }
}

struct DecisionEngineSettings: View {
    @ObservedObject var model: AppModel
    var body: some View {
        DisclosureGroup(model.localInsightsEnabled ? "Local reasoning is enabled" : "Enable the local reasoning engine") {
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
            Eyebrow(text: "An evolving picture of your work")
            if let review = model.currentDecision {
                Text(review.summary).font(.system(size: 19, weight: .medium, design: .rounded)).tracking(-0.3).lineLimit(4)
                if let anchor = review.evidence.first(where: { $0.messageID == review.anchorMessageID }) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Saved message").font(.caption2.weight(.medium)).foregroundStyle(Palette.mint)
                        Text("“\(String(anchor.quote.prefix(160)))”").font(.caption).foregroundStyle(Palette.secondary).lineLimit(3)
                    }
                }
                Text(review.unknown).font(.caption).foregroundStyle(Palette.secondary).lineLimit(3)
                Button("Read the evidence →") { model.openStudio(.overview) }.font(.caption.weight(.medium)).buttonStyle(.plain).foregroundStyle(Palette.mint)
                if !model.isDecisionCurrent { Text("New evidence is waiting for review.").font(.caption2).foregroundStyle(Palette.secondary) }
            } else {
                Text(model.reviewingDecision ? "Reading the decisions in context…" : "Your next reading starts with context.").font(.system(size: 20, weight: .medium, design: .rounded))
                Text(model.localInsightsEnabled ? "The local engine revisits saved work as new evidence arrives. Open the dashboard to review a conversation." : "Enable local reasoning in the dashboard to connect your requests, the agent’s proposals and what happened afterward.").font(.caption).foregroundStyle(Palette.secondary)
            }
            if model.reviewingDecision { HStack { ProgressView().controlSize(.mini); Text("Reviewing on this Mac").font(.caption2).foregroundStyle(Palette.secondary) } }
            if let error = model.decisionError { Text(error).font(.caption2).foregroundStyle(Palette.amber).lineLimit(2) }
        }
    }
}
