import AppKit
import VernierCore

extension AppCoordinator {
    enum SmokeFailure: Error { case failed(String) }
    private func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw SmokeFailure.failed(message) }
        print("PASS: \(message)")
    }
    private func waitUntil(_ message: String, _ condition: @MainActor () -> Bool) async throws {
        for _ in 0..<50 {
            if condition() { print("PASS: \(message)"); return }
            try await Task.sleep(for: .milliseconds(20))
        }
        throw SmokeFailure.failed(message)
    }
    /// Exercises real native windows on a logged-in Mac, with isolated preferences. No screenshots or other apps inspected.
    func runSmokeTest() async throws {
        try check(statusItem?.button != nil, "Native status item exists")
        try check(!model.localInsightsEnabled, "Local analysis is off for a fresh installation")
        model.localInsightsEnabled = true
        model.generateWorkBrief()
        try check(!model.generatingBrief, "Isolated UI checks cannot invoke the local model")
        let priorGeneration = model.briefGeneration
        model.localInsightsEnabled = false
        try check(model.briefGeneration > priorGeneration && !model.generatingBrief, "Local analysis opt-out cancels and invalidates pending results")
        try check(!model.pillEnabled && pill == nil, "Pill is off on first launch")
        // Status bar attachment completes after didFinishLaunching returns to AppKit.
        try await Task.sleep(for: .milliseconds(200))
        togglePopover()
        try await waitUntil("Anchored popover opens") { popover.isShown }
        let panelSize = popover.contentSize
        try check(panelSize.width == QuickPanelLayout.width && panelSize.height <= 414, "Quick view has bounded dimensions")
        if let window = popover.contentViewController?.view.window, let screen = window.screen {
            print("Quick-view geometry: \(window.frame), display: \(screen.frame)")
            try await waitUntil("Quick view is fully on screen") { window.frame.minY >= screen.frame.minY && window.frame.maxY <= screen.frame.maxY }
        }
        model.paused = true
        popover.contentViewController?.view.layoutSubtreeIfNeeded()
        try check(popover.contentSize == panelSize && model.capturePhase == .paused, "Pause changes meaning without moving the quick-view frame")
        model.paused = false
        _ = applicationShouldHandleReopen(NSApp, hasVisibleWindows: false)
        try check(surface == .quickView && popover.isShown && studio?.isVisible != true, "App activation does not open a dashboard behind quick view")
        model.openStudio(.overview)
        try await waitUntil("Open dashboard replaces quick view with one dashboard") {
            surface == .studio && !popover.isShown && studio?.isVisible == true
        }
        togglePopover()
        try await waitUntil("Menu-bar quick view replaces the dashboard without stacking windows") {
            surface == .quickView && popover.isShown && studio?.isVisible != true && !model.studioVisible
        }
        closeQuickView()
        try check(!popover.isShown && surface == .ambient, "Popover closes")
        openStudio(.overview)
        try check(studio?.isVisible == true, "Studio opens")
        studio?.close()
        try check(studio?.isVisible == false, "Studio closes")
        try check(!model.studioVisible, "Closing Studio switches to background cadence")
        try check(statusItem?.button != nil, "Status item survives closing Studio")
        for _ in 0..<4 {
            togglePopover()
            model.openStudio(.overview)
            togglePopover()
            await Task.yield()
            try await Task.sleep(for: .milliseconds(40))
            guard surface == .quickView && popover.isShown && studio?.isVisible != true else {
                throw SmokeFailure.failed("Rapid surface changes stacked or reopened a window")
            }
            closeQuickView()
        }
        try check(!popover.isShown && studio?.isVisible != true, "Repeated quick-view/dashboard transitions leave no stale surface")
        openStudio(.connections)
        try check(studio?.isVisible == true && model.page == .connections, "Studio reopens to Connections")
        for page in StudioPage.allCases {
            model.page = page
            studio?.contentView?.layoutSubtreeIfNeeded()
            await Task.yield()
        }
        model.pillEnabled = true
        openStudio(model.page)
        refreshPresence()
        try await waitUntil("Pill hides while Studio is focused") {
            NSApp.isActive && studio?.isKeyWindow == true && pill?.isVisible != true && pillPresentation == .hidden
        }
        studio?.orderOut(nil)
        model.pillHovered = false
        refreshPresence()
        try check(pill?.isVisible == true && pillPresentation == .compact, "Quiet pill appears as a small circle")
        guard let hoverHost = pill?.contentView as? PillHostingView else { throw SmokeFailure.failed("Native hover host exists") }
        hoverHost.pointerLocation = { [weak hoverHost] in
            guard let frame = hoverHost?.window?.frame else { return .zero }
            return NSPoint(x: frame.midX, y: frame.midY)
        }
        hoverHost.handleHoverEntry()
        refreshPresence()
        try await waitUntil("Hover expands the pill") { abs((pill?.frame.width ?? 0) - PillPresentation.expanded.size.width) < 1 }
        for _ in 0..<4 {
            hoverHost.handleHoverExit() // Resizing can emit exit despite the pointer remaining inside.
            refreshPresence()           // Background model updates must not restart a resize.
            try await Task.sleep(for: .milliseconds(240))
        }
        print("Hover regression state: hovered=\(model.pillHovered), presentation=\(pillPresentation), visible=\(pill?.isVisible == true), sameHost=\(pill?.contentView === hoverHost), studioVisible=\(studio?.isVisible == true), studioKey=\(studio?.isKeyWindow == true)")
        try check(model.pillHovered && pillPresentation == .expanded && pill?.contentView === hoverHost,
                  "Stationary hover survives repeated resize exits without replacing the host")
        hoverHost.clicked?()
        model.pillHovered = false
        refreshPresence()
        try check(model.pillPinned && pillPresentation == .expanded && studio?.isVisible != true,
                  "Circle body pins controls without opening the dashboard")
        hoverHost.clicked?()
        hoverHost.handleHoverEntry()
        refreshPresence()
        let captureButton = hoverHost.captureButton
        let capturePoint = hoverHost.convert(NSPoint(x: captureButton.frame.midX, y: captureButton.frame.midY), to: hoverHost.superview)
        try check(!captureButton.isHidden && hoverHost.hitTest(capturePoint) === captureButton && !captureButton.needsPanelToBecomeKey,
                  "Expanded capture control receives clicks without activating the panel")
        let priorPause = model.paused
        captureButton.performClick(nil)
        try await waitUntil("Pill capture button toggles and persists without opening Studio") {
            model.paused != priorPause && model.preferences.paused == model.paused && studio?.isVisible != true && pill?.isVisible == true
        }
        captureButton.performClick(nil)
        try await waitUntil("Pill capture button toggles back without opening Studio") {
            model.paused == priorPause && model.preferences.paused == priorPause && studio?.isVisible != true && pill?.isVisible == true
        }
        let dashboardButton = hoverHost.dashboardButton
        let dashboardPoint = hoverHost.convert(NSPoint(x: dashboardButton.frame.midX, y: dashboardButton.frame.midY), to: hoverHost.superview)
        try check(!dashboardButton.isHidden && hoverHost.hitTest(dashboardPoint) === dashboardButton && dashboardButton !== captureButton,
                  "Dashboard arrow has its own distinct native hit target")
        dashboardButton.performClick(nil)
        try await waitUntil("Only the dashboard arrow opens Studio and clears pinned controls") {
            surface == .studio && studio?.isVisible == true && !popover.isShown && !model.pillPinned && pill?.isVisible != true
        }
        studio?.close()
        hoverHost.handleHoverEntry()
        refreshPresence()
        hoverHost.pointerLocation = { NSPoint(x: -100_000, y: -100_000) }
        hoverHost.handleHoverExit()
        hoverHost.handleHoverEntry()
        try await Task.sleep(for: .milliseconds(240))
        try check(model.pillHovered && pillPresentation == .expanded, "Re-entry cancels pending hover dismissal")
        hoverHost.handleHoverExit()
        try await waitUntil("Real pointer exit clears hover") { !model.pillHovered }
        try await waitUntil("Pill retracts after hover") { abs((pill?.frame.width ?? 0) - PillPresentation.compact.size.width) < 1 }
        hoverHost.pointerLocation = { NSEvent.mouseLocation }
        togglePopover()
        try await waitUntil("Quick view opens while pill is present") { popover.isShown }
        try check(pill?.isVisible != true, "Pill hides behind the quick view")
        togglePopover()
        refreshPresence()
        try check(pill?.canBecomeKey == false && pill?.canBecomeMain == false, "Pill cannot steal keyboard focus")
        try check(pill?.styleMask.contains(.nonactivatingPanel) == true, "Pill uses nonactivating panel")
        try check(pill?.collectionBehavior.contains(.fullScreenNone) == true, "Pill excluded from full-screen Spaces")
        try check(pill?.collectionBehavior.contains(.canJoinAllSpaces) == true, "Pill follows ordinary desktop Spaces")
        model.setSystemSuspended(true)
        refreshPresence()
        try check(pill?.isVisible == false && model.projection.state == .paused, "System rest hides pill and closes capture gate")
        model.paused = true
        model.setSystemSuspended(false)
        refreshPresence()
        try check(model.paused && model.projection.state == .paused, "Wake preserves the user’s Pause setting")
        try check(model.projection.state == .paused && model.preferences.paused, "Pause visible and persisted")
        model.demoEnabled = false
        try check(model.projection.events.isEmpty && model.projection.eventCount == nil, "Empty state has no demo events or fabricated zero")
        model.pillEnabled = false
        refreshPresence()
        try check(pill?.isVisible == false, "Pill hides when disabled")
        openWelcome()
        model.finishOnboarding()
        try check(model.preferences.onboardingComplete, "Onboarding completes with zero connectors")
        for name in [NSAppearance.Name.aqua, .darkAqua, .accessibilityHighContrastDarkAqua] {
            studio?.appearance = NSAppearance(named: name)
            studio?.contentView?.layoutSubtreeIfNeeded()
            await Task.yield()
        }
        try check(model.projection.coverage == "0 of 3 live sources connected", "No live coverage claimed")
        let now = Date()
        let root = URL(fileURLWithPath: "/synthetic/conductor/workspaces")
        let raw: [String: Any] = ["id": "ui-fixture", "cwd": root.appendingPathComponent("repo/workspace").path, "createdAt": now.timeIntervalSince1970, "updatedAt": now.timeIntervalSince1970, "source": "vscode"]
        guard let session = MetadataBoundary.session(raw, root: root, salt: "isolated-ui", now: now, turnsComplete: false) else { throw SmokeFailure.failed("UI fixture normalizes") }
        model.library = SessionLibrary(sessions: [session], turns: [], notes: [:])
        model.codexEnabled = true
        model.lastSync = now
        model.paused = false
        openStudio(.sessions)
        studio?.contentView?.layoutSubtreeIfNeeded()
        await Task.yield()
        try check(model.knownTurnCount == nil, "Unavailable turn history stays unknown")
        model.inspectSession(session)
        studio?.contentView?.layoutSubtreeIfNeeded()
        await Task.yield()
        try check(model.selectedSessionID == session.id && model.page == .decisions, "Session evidence route opens for isolated fixture")
        try check(model.projection.status == "Codex session metadata connected", "Metadata projection uses distinct connection wording")
        let showcaseSuite = "local.vernier.showcase-test-\(UUID().uuidString)"
        let showcaseDefaults = UserDefaults(suiteName: showcaseSuite)!
        defer { showcaseDefaults.removePersistentDomain(forName: showcaseSuite) }
        let showcase = AppModel(preferences: Preferences(defaults: showcaseDefaults), showcase: true)
        await showcase.startSessionSync()
        showcase.setLaunchAtLogin(true)
        try check(showcase.isShowcase && showcase.isolatedEnvironment && showcase.library.totalMessageCount == 18 && showcase.loginStatus == .off,
                  "Showcase remains isolated from store, connector and login service")
        await showcase.loadSessionStory()
        try check(showcase.currentStory?.followUps == 4 && showcase.currentStory?.runs.count == 9,
                  "Visual showcase loads real fixture exchanges rather than decorative data")
        await showcase.loadWorkOverview()
        try check(showcase.workOverview?.workspaces == 3 && showcase.workOverview?.count(.goAhead) == 1 && showcase.workOverview?.failureCount == 1,
                  "Work overview spans workspaces with source-linked wording cues and failure status")
        let overviewGeneration = showcase.workOverviewGeneration
        await showcase.loadWorkOverview()
        try check(showcase.workOverviewGeneration == overviewGeneration, "Quick view and dashboard reuse an unchanged bounded work overview")
        if let work = showcase.workOverview?.sessions.last {
            showcase.inspectWork(work, messageID: work.agentLast?.id)
            try check(showcase.briefSessionID == work.id && showcase.workDetailExpanded && showcase.storyFocusID == work.agentLast?.id,
                      "A work thread routes to its own conversation and source, not the latest session")
            showcase.briefSessionID = nil
        }
        let loadedGeneration = showcase.storyGeneration
        await showcase.loadSessionStory()
        try check(showcase.storyGeneration == loadedGeneration, "Reopening an unchanged story reuses its bounded in-memory projection")
        let beforeFocus = showcase.storyFocusRevision
        showcase.focusStory("showcase-story-message-3")
        showcase.focusStory("showcase-story-message-3")
        try check(showcase.storyFocusRevision == beforeFocus + 2 && showcase.currentStory?.run(containing: showcase.storyFocusID ?? "") != nil,
                  "Repeated evidence navigation can focus the same map point again")
        let showcaseSearch = await showcase.searchMemory("hover")
        try check(showcaseSearch.count == 2 && showcaseSearch.allSatisfy { $0.id.hasPrefix("showcase-") },
                  "Showcase search reads only in-memory synthetic messages")
        try check(showcase.currentBrief?.engine == "Synthetic showcase · no model ran" && showcase.currentBrief?.visibleMoments.isEmpty == false,
                  "Showcase brief is labeled synthetic and resolves to its selected session")
        if let evidence = showcase.currentBrief?.moments.first?.evidence.first {
            model.showMemory(sessionID: "synthetic-source", query: evidence.quote)
            try check(model.page == .memory && model.memorySessionID == "synthetic-source" && model.memoryQuery == evidence.quote,
                      "Brief citations route to session-scoped conversation search")
        }
        showcase.library = ShowcaseFixtures.library()
        await showcase.loadSessionStory()
        try check(showcase.currentStory?.loadedMessages == 2 && showcase.storyGeneration > loadedGeneration,
                  "Changed source coverage reloads the map rather than keeping an old projection")
        let beforeErase = showcase.storyGeneration
        await showcase.eraseConversationMemory()
        try check(showcase.workOverview == nil && showcase.workOverviewLoadedKey == nil && showcase.sessionStory == nil && showcase.storyLoadedKey == nil && !showcase.storyLoading && showcase.storyGeneration > beforeErase,
                  "Memory erasure clears map text and invalidates pending projection results")
    }
}
