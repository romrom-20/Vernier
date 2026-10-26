import SwiftUI
import VernierCore

enum CaptureStyle {
    static func color(_ phase: CapturePhase) -> Color {
        switch phase {
        case .paused: Palette.amber
        case .issue: Palette.rose
        case .disconnected, .resting, .waiting: Palette.secondary
        case .demo: Palette.lavender
        case .checking, .current: Palette.mint
        }
    }
}

struct CaptureToggle: View {
    @ObservedObject var model: AppModel
    var compact = false
    var body: some View {
        Button { model.toggleCapture() } label: {
            Label(model.paused ? "Resume capture" : "Pause capture", systemImage: model.paused ? "play.fill" : "pause.fill")
                .font(compact ? .caption.weight(.medium) : .callout.weight(.medium))
                .padding(.horizontal, compact ? 10 : 14).padding(.vertical, compact ? 7 : 10)
                .background(model.paused ? Palette.amber.opacity(0.16) : Palette.inset, in: Capsule())
                .overlay(Capsule().strokeBorder(model.paused ? Palette.amber.opacity(0.45) : Palette.line.opacity(0.6), lineWidth: 0.5))
        }.buttonStyle(.plain)
            .accessibilityHint(model.paused ? "Resume checking connected Codex history" : "Stop new reads and saves; keep the saved archive")
    }
}

struct CaptureGlyph: View {
    let phase: CapturePhase
    var size: CGFloat = 50
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Image(systemName: phase.symbol)
            .font(.system(size: size * 0.37, weight: .medium))
            .foregroundStyle(CaptureStyle.color(phase))
            .frame(width: size, height: size)
            .background(CaptureStyle.color(phase).opacity(0.1), in: RoundedRectangle(cornerRadius: size * 0.30))
            .contentTransition(.symbolEffect(.replace))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: phase)
            .accessibilityHidden(true)
    }
}

struct CaptureInventory: View {
    @ObservedObject var model: AppModel
    var compact = false
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 12) {
            HStack {
                Eyebrow(text: compact ? "Connected source" : model.paused || !model.codexEnabled ? "Your local archive" : "What Vernier saves")
                Spacer()
                Text("On this Mac").font(.caption2).foregroundStyle(Palette.secondary)
            }
            HStack(spacing: 11) {
                ProviderMark(provider: .codex)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Codex in Conductor").font(.callout.weight(.medium))
                    Text(model.codexEnabled ? model.captureModeTitle : "Disconnected · saved archive remains")
                        .font(.caption).foregroundStyle(Palette.secondary)
                }
                Spacer(minLength: 0)
            }
            if !compact {
                Text(model.captureModeDescription).font(.callout).foregroundStyle(Palette.secondary)
                if !model.conversationMemoryEnabled && model.library.totalMessageCount > 0 {
                    Text("New conversation capture is off. Previously saved messages remain in your archive.").font(.caption).foregroundStyle(Palette.secondary)
                }
                HStack(alignment: .firstTextBaseline, spacing: 24) {
                    inventoryCount(model.library.totalMessageCount, "saved messages")
                    inventoryCount(model.library.totalSignalCount, "agent activity records")
                    inventoryCount(model.library.sessions.count, "sessions")
                }
                HStack {
                    Button("Explore saved memory →") { model.showMemory() }.buttonStyle(.plain).foregroundStyle(Palette.mint)
                    Spacer()
                    Button("Manage capture") { model.openStudio(.privacy) }.buttonStyle(.plain).foregroundStyle(Palette.secondary)
                }.font(.caption.weight(.medium))
                DisclosureGroup("What remains outside this view") {
                    Text("Only connected local Codex history is covered. Screen contents, browser tabs, reading and comprehension are not observed. Other AI tools are not connected yet. Pausing stops synchronization; resuming can catch up the provider’s existing history.")
                        .font(.caption).foregroundStyle(Palette.secondary).padding(.top, 8)
                }.font(.caption).foregroundStyle(Palette.secondary)
                if model.conversationMemoryEnabled {
                    let completed = model.library.memoryCoverage.filter(\.complete).count
                    Text("\(completed) of \(model.library.sessions.count) text histories caught up. The rest are filling or unavailable.")
                        .font(.caption2).foregroundStyle(Palette.secondary)
                }
            }
        }
    }
    private func inventoryCount(_ count: Int, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(model.storedAt == nil && model.lastSync == nil ? "—" : count.formatted()).font(.system(size: 25, weight: .medium, design: .rounded)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(Palette.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
