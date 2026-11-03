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
    static let canvas = adaptive(0x111827, 0xF4F2EE)
    static let surface = adaptive(0x1B2639, 0xFFFEFC)
    static let inset = adaptive(0x273349, 0xECE8E3)
    static let line = adaptive(0x4C586E, 0xC8C1BA)
    static let text = adaptive(0xF5F0EA, 0x282936)
    static let secondary = adaptive(0xB5C0D0, 0x625E6C)
    static let mint = adaptive(0xB7E5BE, 0x28633E)
    static let amber = adaptive(0xF2C98E, 0x80521A)
    static let lavender = adaptive(0xC5B8FA, 0x68529B)
    static let rose = adaptive(0xF2A6A0, 0xA13530)
    static let accent = adaptive(0xECE5F1, 0x474052)
    static let accentPink = Color(red: 0.89, green: 0.20, blue: 0.58)
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
            }.stroke(Palette.accent, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
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
            .background(Palette.accent.opacity(configuration.isPressed ? 0.18 : 0.085), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(Palette.accent).contentShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// A static, code-drawn brand field. No animation, image download, shader or blur loop.
struct VernierField: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(colors: [Color(red: 0.035, green: 0.26, blue: 0.37), Color(red: 0.0, green: 0.55, blue: 0.72)], startPoint: .leading, endPoint: .trailing)
                RadialGradient(colors: [Palette.accentPink.opacity(0.85), Palette.accentPink.opacity(0)], center: UnitPoint(x: 0.83, y: 1.15), startRadius: 0, endRadius: max(100, geometry.size.width * 0.32))
                RadialGradient(colors: [Color.white.opacity(0.22), Color.white.opacity(0)], center: UnitPoint(x: 0.72, y: -0.7), startRadius: 0, endRadius: max(100, geometry.size.width * 0.35))
                Canvas { context, size in
                    var lines = Path()
                    stride(from: CGFloat(0), to: size.width, by: 9).forEach { x in
                        lines.move(to: CGPoint(x: x, y: 0)); lines.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    context.stroke(lines, with: .color(.white.opacity(0.065)), lineWidth: 1)
                }
            }
        }.clipped().accessibilityHidden(true).allowsHitTesting(false)
    }
}

struct VernierBackdrop: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Palette.canvas
                if scheme == .dark {
                    RadialGradient(colors: [Color(red: 0.16, green: 0.32, blue: 0.47).opacity(0.62), .clear], center: .topLeading, startRadius: 0, endRadius: max(300, geometry.size.width * 0.85))
                    RadialGradient(colors: [Palette.accentPink.opacity(0.10), .clear], center: .bottomTrailing, startRadius: 0, endRadius: max(260, geometry.size.width * 0.8))
                }
            }
        }.accessibilityHidden(true).allowsHitTesting(false)
    }
}

struct RecapButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.padding(.horizontal, 12).padding(.vertical, 9)
            .foregroundStyle(Color(red: 0.12, green: 0.15, blue: 0.22))
            .background(Color(red: 0.96, green: 0.93, blue: 0.89).opacity(configuration.isPressed ? 0.84 : 1), in: RoundedRectangle(cornerRadius: 9))
            .contentShape(RoundedRectangle(cornerRadius: 9))
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
