import SwiftUI
import VernierCore

struct WorkBriefView: View {
    @ObservedObject var model: AppModel
    var compact = false
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 12 : 18) {
            HStack {
                Eyebrow(text: compact ? "Your session brief" : "What stands out in your work")
                Spacer()
                if model.currentBrief != nil { Text(model.isShowcase ? "Synthetic example" : "AI · on this Mac").font(.caption2).foregroundStyle(Palette.secondary) }
            }
            if !compact, !model.library.sessions.isEmpty {
                Picker("Session", selection: Binding(get: { model.briefSession?.id ?? "" }, set: { id in
                    model.cancelWorkBrief(); model.briefSessionID = id; model.briefError = nil
                    if model.localInsightsEnabled { model.generateWorkBrief() }
                })) {
                    ForEach(model.library.sessions) { session in Text(model.library.title(for: session)).tag(session.id) }
                }.font(.callout)
            }
            if let brief = model.currentBrief {
                VStack(alignment: .leading, spacing: 5) {
                    Text("AI’s reading of your goal").font(.caption).foregroundStyle(Palette.secondary)
                    Text(brief.goal).font(compact ? .callout.weight(.semibold) : .title3.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true).lineLimit(compact ? 3 : nil)
                    if !compact, let evidence = brief.goalEvidence {
                        Button("See the request behind this goal →") { model.showMemory(sessionID: brief.sessionID, query: evidence.quote) }
                            .buttonStyle(.plain).font(.caption).foregroundStyle(Palette.mint)
                    }
                }
                if compact {
                    if let moment = brief.visibleMoments.first {
                        Label(moment.kind.label, systemImage: moment.kind.symbol).font(.caption.weight(.medium)).foregroundStyle(Palette.mint)
                        Text(moment.detail).font(.caption).foregroundStyle(Palette.secondary).lineLimit(3)
                    }
                    Text("Next: \(brief.nextStep)").font(.caption.weight(.medium)).lineLimit(3)
                } else {
                    VStack(alignment: .leading, spacing: 7) {
                        Eyebrow(text: "A way forward")
                        Text(brief.nextStep).font(.callout).fixedSize(horizontal: false, vertical: true)
                    }.padding(15).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.mint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    if !brief.visibleMoments.isEmpty {
                        Text("\(brief.visibleMoments.count) suggested observations in this excerpt").font(.caption).foregroundStyle(Palette.secondary)
                        ForEach(brief.visibleMoments) { moment in
                            Divider().overlay(Palette.line.opacity(0.5))
                            VStack(alignment: .leading, spacing: 9) {
                                Label(moment.kind.label, systemImage: moment.kind.symbol).font(.caption.weight(.medium)).foregroundStyle(Palette.mint)
                                Text(moment.title).font(.headline)
                                Text(moment.detail).font(.callout).foregroundStyle(Palette.secondary)
                                DisclosureGroup("Why this appeared") {
                                    VStack(alignment: .leading, spacing: 12) {
                                        ForEach(Array(moment.evidence.enumerated()), id: \.offset) { _, evidence in
                                            VStack(alignment: .leading, spacing: 5) {
                                                Text(evidence.speaker == "user" ? "Your recorded message" : "Agent’s recorded reply").font(.caption2).foregroundStyle(Palette.secondary)
                                                Text("“\(evidence.quote)”").font(.callout).textSelection(.enabled)
                                                Button("Open source message →") { model.showMemory(sessionID: brief.sessionID, query: evidence.quote) }
                                                    .buttonStyle(.plain).font(.caption).foregroundStyle(Palette.mint)
                                            }
                                        }
                                        Button("This interpretation doesn’t fit") { model.dismissMoment(moment.id) }
                                            .buttonStyle(.plain).font(.caption).foregroundStyle(Palette.secondary)
                                            .disabled(model.paused || !model.conversationMemoryEnabled)
                                    }.padding(.top, 10)
                                }.font(.caption)
                            }
                        }
                    } else {
                        Text("No source-supported observations are active in this excerpt. That does not establish that the whole session was smooth.")
                            .font(.callout).foregroundStyle(Palette.secondary)
                    }
                }
                Text("Reviewed \(brief.reviewedMessages) of \(brief.storedMessages) saved messages · \(brief.generatedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2).foregroundStyle(Palette.secondary)
                if brief.sourceUpdatedAt < (model.briefSession?.updatedAt ?? .distantPast) || brief.storedMessages != model.briefSession.flatMap({ model.library.digest(for: $0)?.messageCount }) {
                    Text("Newer conversation is available.").font(.caption2).foregroundStyle(Palette.secondary)
                }
                if !compact {
                    DisclosureGroup("About this brief") {
                        Text("AI interpretation of a bounded excerpt, not a score or a measurement of fatigue or understanding. \(brief.clippedMessages) messages shortened; \(brief.missingSourceTimes) lack exact source times. \(brief.omittedSuggestions) suggestions omitted because their sources or categories could not be supported. \(brief.engine).")
                            .font(.caption).foregroundStyle(Palette.secondary).padding(.top, 8)
                    }.font(.caption).foregroundStyle(Palette.secondary)
                }
            } else {
                Text("What happened—and how can you move forward?").font(compact ? .callout.weight(.semibold) : .title3.weight(.medium))
                Text("Review the working goal, possible handoff stretches, repeated repair, and the direction you gave. Each observation comes with source messages and a small next step.")
                    .font(.caption).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
                if !model.localInsightsEnabled {
                    Text("An on-device AI brief uses your saved Codex conversation. Text stays on this Mac; no additional API account is needed.").font(.caption).foregroundStyle(Palette.secondary)
                }
            }
            if let error = model.briefError { Text(error).font(.caption).foregroundStyle(Palette.amber) }
            if model.generatingBrief {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Reviewing the saved excerpt locally…").font(.caption)
                    Spacer()
                    Button("Cancel") { model.cancelWorkBrief() }.buttonStyle(.plain).font(.caption)
                }
            } else if !model.isShowcase {
                if let reason = model.briefUnavailable {
                    Text(reason).font(.caption).foregroundStyle(Palette.secondary)
                } else if model.paused {
                    Text("Resume capture to generate or update a brief.").font(.caption).foregroundStyle(Palette.secondary)
                } else if !model.conversationMemoryEnabled || !model.codexEnabled {
                    Button("Connect conversation memory →") { model.openStudio(.memory) }.buttonStyle(.plain).font(.callout).foregroundStyle(Palette.mint)
                } else {
                    Button(model.localInsightsEnabled ? (model.currentBrief == nil ? "Generate local brief" : "Refresh local brief") : "Turn on local AI briefs") {
                        if !model.localInsightsEnabled { model.localInsightsEnabled = true }
                        else { model.generateWorkBrief() }
                    }.buttonStyle(QuietButtonStyle()).disabled(model.briefSession == nil)
                }
            }
        }
    }
}
