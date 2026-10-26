import SwiftUI
import VernierCore

struct RhythmStrip: View {
    let values: [Int]
    var compact = false
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: compact ? 2 : 5) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                    RoundedRectangle(cornerRadius: compact ? 1 : 2)
                        .fill(value > 0 ? Palette.mint.opacity(compact ? 0.65 : 0.8) : Palette.line.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .frame(height: value == 0 ? 2 : max(4, geometry.size.height * CGFloat(value) / CGFloat(max(1, values.max() ?? 1))))
                }
            }.frame(height: geometry.size.height, alignment: .bottom)
        }.accessibilityHidden(true)
    }
}

struct PresenceHero: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Your work with AI.")
                    .font(.system(size: 32, weight: .medium)).tracking(-0.7)
                Text("See how you prompt, steer and understand the work.")
                    .font(.callout).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .center, spacing: 14) {
                CaptureGlyph(phase: model.capturePhase)
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.capturePhase.title).font(.headline)
                    Text(model.captureDescription).font(.callout).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
                CaptureToggle(model: model)
            }.padding(17).background(CaptureStyle.color(model.capturePhase).opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(CaptureStyle.color(model.capturePhase).opacity(0.2), lineWidth: 0.5))
            HStack {
                Label("Local storage · you control capture", systemImage: "lock.shield")
                Spacer()
                Text(model.lastSync.map { "Last checked \($0.formatted(date: .omitted, time: .standard))" } ?? "Waiting for a verified check")
                    .monospacedDigit()
            }.font(.caption).foregroundStyle(Palette.secondary)
        }.padding(24).background(Palette.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Palette.line.opacity(0.6), lineWidth: 0.5))
    }
}

struct DayRhythmView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        InstrumentCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack { Eyebrow(text: "The shape of your day"); Spacer(); Text("Available history · 24 hours").font(.caption2).foregroundStyle(Palette.secondary) }
                if model.lastSync != nil || model.storedAt != nil {
                VStack { RhythmStrip(values: model.hourlyRhythm).frame(height: 43) }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(model.hourlyRhythm.reduce(0, +)) recorded turns in the last 24 hourly bins; source coverage may be partial")
                HStack {
                    Text("24h ago"); Spacer(); Text("Recorded turn boundaries"); Spacer(); Text("Now")
                }.font(.system(.caption2, design: .monospaced)).foregroundStyle(Palette.secondary)
                } else {
                    Text("Waiting for verified turn history.").font(.callout).foregroundStyle(Palette.secondary).padding(.vertical, 14)
                }
                Text("A record of when turns happened. Time, attention, understanding, and work outside the connected source remain unknown.")
                    .font(.caption).foregroundStyle(Palette.secondary)
            }
        }
    }
}

struct ResidencySettings: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "Always available")
            Toggle("Open Vernier at login", isOn: Binding(
                get: { model.loginStatus == .enabled || model.loginStatus == .needsApproval },
                set: { model.setLaunchAtLogin($0) }
            )).toggleStyle(.switch)
            HStack {
                Label(model.loginStatus.label, systemImage: model.loginStatus == .enabled ? "checkmark.circle" : "power")
                    .font(.caption).foregroundStyle(model.loginStatus == .enabled ? Palette.mint : Palette.secondary)
                Spacer()
                Button("Login Items…") { model.openLoginSettings() }.buttonStyle(.plain).font(.caption).foregroundStyle(Palette.secondary)
            }
            if let error = model.loginError { Text(error).font(.caption).foregroundStyle(Palette.amber) }
            if model.loginStatus == .needsApproval {
                Text("macOS needs your approval in System Settings → General → Login Items.").font(.caption).foregroundStyle(Palette.amber)
            }
            Text("Lives in the menu bar. Rests during sleep or an inactive login session, then refreshes after wake. Quit stays final until you open the app or log in again.")
                .font(.caption).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
