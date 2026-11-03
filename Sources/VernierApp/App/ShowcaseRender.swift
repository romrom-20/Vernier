import AppKit
import SwiftUI
import VernierCore

extension AppCoordinator {
    /// Explicit offscreen rendering of our own synthetic views. No desktop or other app is captured.
    func renderShowcase() async throws {
        guard model.isShowcase, let flag = CommandLine.arguments.firstIndex(of: "--render-showcase"), flag + 1 < CommandLine.arguments.count else { throw DecisionGenerationError.unavailable }
        let directory = URL(fileURLWithPath: CommandLine.arguments[flag + 1], isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        await model.loadDailyParticipation()
        try await snapshot(AnyView(StudioView(model: model)), size: NSSize(width: 1180, height: 820), file: directory.appendingPathComponent("overview.png"))
        try await snapshot(AnyView(StudioView(model: model)), size: NSSize(width: 860, height: 760), file: directory.appendingPathComponent("overview-narrow.png"))
        try await snapshot(AnyView(StudioView(model: model)), size: NSSize(width: 1180, height: 820), file: directory.appendingPathComponent("overview-light.png"), dark: false)
        try await snapshot(AnyView(MenuBarView(model: model)), size: NSSize(width: 382, height: 414), file: directory.appendingPathComponent("quick-view.png"))
        let original = model.library
        model.library = ShowcaseFixtures.quickReviewLibrary(); model.clearDailyParticipation()
        await model.loadDailyParticipation()
        try await snapshot(AnyView(MenuBarView(model: model)), size: NSSize(width: 382, height: 414), file: directory.appendingPathComponent("quick-checks.png"))
        try await snapshot(AnyView(MenuBarView(model: model)), size: NSSize(width: 382, height: 414), file: directory.appendingPathComponent("quick-checks-dark.png"), dark: true)
        let pillPreview = PillHostingView(rootView: PillView(model: model))
        pillPreview.updateCaptureButton(paused: false)
        try await snapshot(view: pillPreview, size: NSSize(width: 232, height: 48), file: directory.appendingPathComponent("pill.png"))
        model.library = ShowcaseFixtures.quickReviewLibrary(includeLastReply: false); model.clearDailyParticipation()
        await model.loadDailyParticipation()
        try await snapshot(AnyView(MenuBarView(model: model)), size: NSSize(width: 382, height: 414), file: directory.appendingPathComponent("quick-pending.png"))
        model.library = original; model.clearDailyParticipation()
        await model.loadDailyParticipation()
        model.briefSessionID = model.library.sessions.first?.id
        model.storyFocusID = model.currentDecision?.anchorMessageID
        await model.loadSessionStory()
        try await snapshot(AnyView(VStack(alignment: .leading, spacing: 14) { Eyebrow(text: "Showcase · invented conversation"); SessionStoryView(model: model) }.padding(24).background(Palette.canvas)), size: NSSize(width: 1000, height: 760), file: directory.appendingPathComponent("session-map.png"))
        for name in ["overview.png", "quick-view.png", "session-map.png"] {
            guard FileManager.default.fileExists(atPath: directory.appendingPathComponent(name).path) else { throw DecisionGenerationError.invalidResponse }
        }
        guard NSApp.activationPolicy() == .prohibited, !NSApp.isActive, NSApp.windows.allSatisfy({ !$0.isVisible && !$0.isKeyWindow }) else { throw DecisionGenerationError.invalidResponse }
        print("OFFSCREEN ISOLATION PASSED: no app activation or visible/key windows; invented records only")
    }
    private func snapshot(_ root: AnyView, size: NSSize, file: URL, dark: Bool = true) async throws {
        let view = NSHostingView(rootView: root.environment(\.colorScheme, dark ? .dark : .light).transaction { $0.disablesAnimations = true })
        try await snapshot(view: view, size: size, file: file, dark: dark)
    }
    private func snapshot(view: NSView, size: NSSize, file: URL, dark: Bool = true) async throws {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.contentView = view
        view.frame = NSRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(800))
        view.layoutSubtreeIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw DecisionGenerationError.invalidResponse }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw DecisionGenerationError.invalidResponse }
        try data.write(to: file, options: .atomic)
        window.contentView = nil
    }
}
