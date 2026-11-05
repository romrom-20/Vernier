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
        if let report = model.dailyReport {
            let projectView = AnyView(DailyProjectsView(model: model, report: report).disclosureGroupStyle(RecapDisclosureStyle()).padding(20).background(Palette.canvas))
            try await snapshot(projectView, size: NSSize(width: 660, height: 124), file: directory.appendingPathComponent("across-work-collapsed.png"))
            model.dailyProjectsExpanded = true
            try await snapshot(projectView, size: NSSize(width: 660, height: 600), file: directory.appendingPathComponent("across-work-expanded.png"))
            model.dailyProjectsExpanded = false
        }
        try await snapshot(AnyView(StudioView(model: model)), size: NSSize(width: 1180, height: 820), file: directory.appendingPathComponent("overview.png"))
        try await snapshot(AnyView(StudioView(model: model)), size: NSSize(width: 1180, height: 910), file: directory.appendingPathComponent("overview-public.png"))
        try await snapshot(AnyView(StudioView(model: model)), size: NSSize(width: 1180, height: 1600), file: directory.appendingPathComponent("overview-full.png"))
        try await snapshot(AnyView(StudioView(model: model)), size: NSSize(width: 860, height: 760), file: directory.appendingPathComponent("overview-narrow.png"))
        try await snapshot(AnyView(StudioView(model: model)), size: NSSize(width: 1180, height: 820), file: directory.appendingPathComponent("overview-light.png"), dark: false)
        try await snapshot(AnyView(MenuBarView(model: model)), size: NSSize(width: QuickPanelLayout.width, height: QuickPanelLayout.preferredHeight), file: directory.appendingPathComponent("quick-view.png"))
        let original = model.library, originalReadings = model.decisionRevisions
        model.library = ShowcaseFixtures.checkpointLibrary(); model.decisionRevisions = ShowcaseFixtures.checkpointHistory(library: model.library); model.clearDailyParticipation()
        await model.loadDailyParticipation()
        guard model.quickInsights.count == 3 else { throw DecisionGenerationError.invalidResponse }
        try await snapshot(AnyView(MenuBarView(model: model)), size: NSSize(width: QuickPanelLayout.width, height: QuickPanelLayout.preferredHeight), file: directory.appendingPathComponent("quick-checkpoints.png"))
        try await snapshot(AnyView(DailyContextView(model: model).disclosureGroupStyle(RecapDisclosureStyle()).padding(24).frame(width: 760, height: 1000, alignment: .topLeading).background(Palette.canvas)), size: NSSize(width: 760, height: 1000), file: directory.appendingPathComponent("all-checkpoints.png"))
        guard let reports = model.quickInsights.first(where: { $0.reading.hasBothReporters }) else { throw DecisionGenerationError.invalidResponse }
        let reportsView = VStack(alignment: .leading, spacing: 18) {
            Eyebrow(text: "Vernier · separate reports · invented example")
            DecisionAccountView(model: model, revision: reports.revision)
        }.padding(28).frame(width: 760, height: 740, alignment: .topLeading)
            .background { VernierBackdrop() }.foregroundStyle(Palette.text)
            .disclosureGroupStyle(RecapDisclosureStyle())
        try await snapshot(AnyView(reportsView), size: NSSize(width: 760, height: 740), file: directory.appendingPathComponent("speaker-reports.png"))
        model.library = ShowcaseFixtures.quickReviewLibrary(); model.decisionRevisions = ShowcaseFixtures.decisionHistory(library: model.library); model.clearDailyParticipation()
        await model.loadDailyParticipation()
        // Exercise the production host on a light window: a separate SwiftUI render hid this inheritance bug.
        prepareQuickPanel()
        if let actualHost = popover.contentViewController?.view {
            try await snapshot(view: actualHost, size: NSSize(width: QuickPanelLayout.width, height: QuickPanelLayout.preferredHeight), file: directory.appendingPathComponent("quick-production-host.png"), dark: false)
            guard actualHost.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua else { throw DecisionGenerationError.invalidResponse }
        } else { throw DecisionGenerationError.invalidResponse }
        try await snapshot(AnyView(MenuBarView(model: model)), size: NSSize(width: QuickPanelLayout.width, height: QuickPanelLayout.preferredHeight), file: directory.appendingPathComponent("quick-checks.png"))
        try await snapshot(AnyView(MenuBarView(model: model)), size: NSSize(width: QuickPanelLayout.width, height: QuickPanelLayout.preferredHeight), file: directory.appendingPathComponent("quick-checks-dark.png"), dark: true)
        let pillPreview = PillHostingView(rootView: PillView(model: model))
        pillPreview.updateCaptureButton(paused: false)
        try await snapshot(view: pillPreview, size: NSSize(width: 232, height: 48), file: directory.appendingPathComponent("pill.png"))
        model.library = ShowcaseFixtures.quickReviewLibrary(includeLastReply: false); model.clearDailyParticipation()
        await model.loadDailyParticipation()
        try await snapshot(AnyView(MenuBarView(model: model)), size: NSSize(width: QuickPanelLayout.width, height: QuickPanelLayout.preferredHeight), file: directory.appendingPathComponent("quick-pending.png"))
        model.library = original; model.decisionRevisions = originalReadings; model.clearDailyParticipation()
        await model.loadDailyParticipation()
        model.briefSessionID = model.library.sessions.first?.id
        model.storyFocusID = model.currentDecision?.anchorMessageID
        await model.loadSessionStory()
        try await snapshot(AnyView(VStack(alignment: .leading, spacing: 14) { Eyebrow(text: "Showcase · invented conversation"); SessionStoryView(model: model) }.padding(24).background(Palette.canvas)), size: NSSize(width: 1000, height: 760), file: directory.appendingPathComponent("session-map.png"))
        model.library = ShowcaseFixtures.directionLibrary()
        model.decisionRevisions = ShowcaseFixtures.directionHistory(library: model.library)
        model.selectedDecisionSessionID = model.library.sessions.first?.id
        model.selectedDecisionRevisionID = model.decisionRevisions.first?.id
        if let revision = model.currentDecision {
            let direction = VStack(alignment: .leading, spacing: 18) {
                Eyebrow(text: "Vernier · a choice to revisit · invented example")
                DecisionAccountView(model: model, revision: revision)
            }.padding(28).frame(width: 1000, height: 530, alignment: .topLeading)
                .background { VernierBackdrop() }.foregroundStyle(Palette.text)
                .disclosureGroupStyle(RecapDisclosureStyle())
            try await snapshot(AnyView(direction), size: NSSize(width: 1000, height: 530), file: directory.appendingPathComponent("direction-check.png"))
        } else { throw DecisionGenerationError.invalidResponse }
        model.library = ShowcaseFixtures.recallLibrary()
        model.decisionRevisions = ShowcaseFixtures.recallHistory(library: model.library)
        guard let revision = model.decisionRevisions.first, revision.reading != nil, let memory = revision.memoryRecall, !memory.entries.isEmpty else { throw DecisionGenerationError.invalidResponse }
        let memoryView = VStack(alignment: .leading, spacing: 18) {
            Eyebrow(text: "Vernier · remembering earlier context · invented example")
            Text("Earlier statements, with their original messages.").font(.title2.weight(.medium))
            Text("Current request: Check the export shortcut against the original accessibility requirement.").font(.callout)
            ConversationRecallView(model: model, memory: memory)
        }.padding(28).frame(width: 900, height: 980, alignment: .topLeading)
            .background { VernierBackdrop() }.foregroundStyle(Palette.text)
        try await snapshot(AnyView(memoryView), size: NSSize(width: 900, height: 980), file: directory.appendingPathComponent("conversation-recall.png"))
        let relatedExample = ShowcaseFixtures.relatedMemoryExample()
        model.library = relatedExample.library
        let casebookView = VStack(alignment: .leading, spacing: 18) {
            Eyebrow(text: "Vernier · connections across conversations · invented example")
            Text("Possible related conversations").font(.title2.weight(.medium))
            RelatedConversationMemoryView(model: model, memory: relatedExample.memory)
        }.padding(28).frame(width: 900, height: 820, alignment: .topLeading)
            .background { VernierBackdrop() }.foregroundStyle(Palette.text)
        try await snapshot(AnyView(casebookView), size: NSSize(width: 900, height: 820), file: directory.appendingPathComponent("related-conversation-memory.png"))
        for name in ["overview.png", "quick-view.png", "session-map.png", "conversation-recall.png", "related-conversation-memory.png"] {
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
