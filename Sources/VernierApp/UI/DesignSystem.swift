import SwiftUI
import AppKit
import VernierCore

enum Palette {
    static func adaptive(_ dark: UInt32, _ light: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let hex = isDark ? dark : light
            return NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
        })
    }
    static let canvas = adaptive(0x0B1012, 0xF4F5F0)
    static let surface = adaptive(0x151C1E, 0xFFFFFF)
    static let inset = adaptive(0x1C2527, 0xE8EDE7)
    static let line = adaptive(0x344041, 0xBCC7BF)
    static let text = adaptive(0xEDF1E9, 0x1C2925)
    static let secondary = adaptive(0x99A8A3, 0x4C6258)
    static let mint = adaptive(0xB7E5BE, 0x28633E)
    static let amber = adaptive(0xF2C98E, 0x80521A)
    static let lavender = adaptive(0xC5B8FA, 0x68529B)
    static let rose = adaptive(0xF2A6A0, 0xA13530)
    static func state(_ state: InstrumentState) -> Color {
        switch state {
        case .idle, .paused: secondary
        case .observing: mint
        case .moment: amber
        case .connectorIssue: rose
        }
    }
}

struct InstrumentMark: View {
    var size: CGFloat = 28
    var body: some View {
        ZStack {
            Circle().strokeBorder(Palette.secondary.opacity(0.35), lineWidth: 1).padding(size * 0.12)
            Path { path in
                path.move(to: CGPoint(x: size * 0.5, y: 0)); path.addLine(to: CGPoint(x: size * 0.5, y: size))
                path.move(to: CGPoint(x: size * 0.23, y: size * 0.38)); path.addLine(to: CGPoint(x: size * 0.77, y: size * 0.38))
                path.move(to: CGPoint(x: size * 0.34, y: size * 0.66)); path.addLine(to: CGPoint(x: size * 0.66, y: size * 0.66))
            }.stroke(Palette.mint, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View { Text(text.uppercased()).font(.caption2.weight(.medium)).tracking(1.6).foregroundStyle(Palette.secondary) }
}
struct DemoBadge: View {
    var body: some View {
        Label("Demo data", systemImage: "square.dashed").font(.caption.weight(.medium))
            .foregroundStyle(Palette.lavender).padding(.horizontal, 9).padding(.vertical, 5)
            .background(Palette.lavender.opacity(0.09), in: Capsule())
            .accessibilityLabel("Demo data. All activity is fictional.")
    }
}
struct StatusLine: View {
    @ObservedObject var model: AppModel
    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(Palette.state(model.projection.state)).frame(width: 6, height: 6).accessibilityHidden(true)
            Text(model.demoEnabled ? model.projection.status : model.ambientLabel).font(.caption).foregroundStyle(Palette.secondary)
        }.accessibilityElement(children: .combine)
    }
}
struct InstrumentCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.line.opacity(0.65), lineWidth: 0.5))
    }
}
struct ProviderMark: View {
    let provider: Provider
    var body: some View {
        Text(provider.monogram).font(.system(.caption, design: .monospaced).weight(.medium))
            .foregroundStyle(provider == .claudeCode ? Palette.amber : provider == .codex ? Palette.mint : Palette.lavender)
            .frame(width: 31, height: 31).background(Palette.inset, in: RoundedRectangle(cornerRadius: 8))
            .accessibilityHidden(true)
    }
}
struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.padding(.horizontal, 12).padding(.vertical, 9)
            .background(configuration.isPressed ? Palette.line : Palette.inset, in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(Palette.text).contentShape(RoundedRectangle(cornerRadius: 8))
    }
}
struct EmptyState: View {
    var title = "A quiet place to begin."
    var detail = "No live sources are connected. Explore the demo or see what’s coming in Connections."
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "circle.dotted").font(.system(size: 32, weight: .ultraLight)).foregroundStyle(Palette.secondary)
            Text(title).font(.title2.weight(.medium))
            Text(detail).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 25)
    }
}
