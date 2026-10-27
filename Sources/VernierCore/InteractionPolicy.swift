import Foundation
import CoreGraphics

public enum CapturePhase: String, Sendable {
    case paused, resting, disconnected, checking, current, waiting, issue, demo
    public var title: String {
        switch self {
        case .paused: "Capture paused"
        case .resting: "Resting with your Mac"
        case .disconnected: "Choose a connection"
        case .checking: "Saving the latest activity"
        case .current: "Capture is on"
        case .waiting: "Waiting for Codex"
        case .issue: "Connection needs attention"
        case .demo: "Exploring demo data"
        }
    }
    public var symbol: String {
        switch self {
        case .paused: "pause.fill"
        case .resting: "moon.fill"
        case .disconnected: "link"
        case .checking: "arrow.down.circle"
        case .current: "circle.fill"
        case .waiting: "clock"
        case .issue: "exclamationmark.triangle.fill"
        case .demo: "square.dashed"
        }
    }
}

public enum PillPresentation: String, Sendable {
    case hidden, compact, expanded
    public static func resolve(enabled: Bool, resting: Bool, studioFocused: Bool, quickPanelVisible: Bool, hovered: Bool, alwaysExpanded: Bool) -> Self {
        guard enabled, !resting, !studioFocused, !quickPanelVisible else { return .hidden }
        return hovered || alwaysExpanded ? .expanded : .compact
    }
    public var size: CGSize {
        switch self {
        case .hidden, .compact: CGSize(width: 28, height: 28)
        case .expanded: CGSize(width: 232, height: 48)
        }
    }
}

public enum QuickPanelLayout {
    public static let width: CGFloat = 356
    public static func size(screenHeight: CGFloat) -> CGSize {
        CGSize(width: width, height: min(414, max(200, screenHeight - 100)))
    }
    public static func constrain(_ frame: CGRect, to visible: CGRect) -> CGRect {
        var result = frame
        result.origin.x = min(max(frame.minX, visible.minX), max(visible.minX, visible.maxX - frame.width))
        result.origin.y = min(max(frame.minY, visible.minY), max(visible.minY, visible.maxY - frame.height))
        return result
    }
}

public enum SessionDisplay {
    /// A literal excerpt from already-consented local text. Never a generated assessment or provider title.
    public static func excerpt(_ text: String) -> String? {
        let cleaned = visibleText(text)
        let lines = cleaned.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard let line = lines.first(where: { line in
            line.count >= 5 && !["<", "```", "#", ".context/", "---", "cwd:", "Working directory:"].contains(where: { line.hasPrefix($0) })
        }) else { return nil }
        let compact = line.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return String(compact.prefix(86)) + (compact.count > 86 ? "…" : "")
    }
    public static func visibleText(_ text: String) -> String {
        var cleaned = text
        for tag in ["system_instruction", "environment_context", "user_instructions", "instructions"] {
            if let regex = try? NSRegularExpression(pattern: "<\(tag)\\b[^>]*>[\\s\\S]*?(?:</\(tag)>|$)", options: .caseInsensitive) {
                cleaned = regex.stringByReplacingMatches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: "")
            }
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    public static func fallback(createdAt: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDate(createdAt, inSameDayAs: now) { return "Today’s Codex session · \(createdAt.formatted(date: .omitted, time: .shortened))" }
        return "Codex session · \(createdAt.formatted(date: .abbreviated, time: .shortened))"
    }
}
