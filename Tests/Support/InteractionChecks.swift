import CoreGraphics
import Foundation
import VernierCore

extension SessionChecks {
    static func interaction() async throws {
        for height: CGFloat in [480, 600, 768, 1080, 1440] {
            let size = QuickPanelLayout.size(screenHeight: height)
            try expect(size.width == 356 && size.height <= height - 100 && size.height <= 414, "Quick view can exceed the available display")
        }
        let screen = CGRect(x: -1440, y: 0, width: 1440, height: 850)
        let popup = CGRect(x: -100, y: 640, width: 382, height: 440)
        try expect(screen.contains(QuickPanelLayout.constrain(popup, to: screen)), "Native popover chrome escapes the display")
        try expect(PillPresentation.resolve(enabled: true, resting: false, studioFocused: false, quickPanelVisible: false, hovered: false, alwaysExpanded: false) == .compact, "Quiet pill should be a small handle")
        try expect(PillPresentation.resolve(enabled: true, resting: false, studioFocused: false, quickPanelVisible: false, hovered: true, alwaysExpanded: false) == .expanded, "Hover must reveal context")
        for studio in [true, false] {
            for quickView in [true, false] where studio || quickView {
                try expect(PillPresentation.resolve(enabled: true, resting: false, studioFocused: studio, quickPanelVisible: quickView, hovered: true, alwaysExpanded: true) == .hidden, "Pill duplicates an open Vernier surface")
            }
        }
        try expect(PillPresentation.resolve(enabled: true, resting: true, studioFocused: false, quickPanelVisible: false, hovered: true, alwaysExpanded: true) == .hidden, "Pill must stay hidden during system rest")
        try expect(CapturePhase.paused.title == "Capture paused" && CapturePhase.paused.symbol == "pause.fill", "Pause lacks an explicit visual/text state")
    }
    static func sessionExcerpts() async throws {
        let text = "<environment_context>private-path</environment_context>\n<system_instruction>App-injected setup</system_instruction>\nBuild a local memory instrument for Codex."
        try expect(SessionDisplay.excerpt(text) == "Build a local memory instrument for Codex.", "Injected context became a session title")
        try expect(SessionDisplay.excerpt("<system_instruction>" + String(repeating: "Injected setup. ", count: 2000)) == nil, "Truncated context became a title")
        try expect(SessionDisplay.excerpt(String(repeating: "clear request ", count: 40))!.count <= 87, "Excerpt overwhelms a session row")
        try expect(!SessionDisplay.fallback(createdAt: Date()).contains("hash"), "Fallback needs a readable date")
    }
}
