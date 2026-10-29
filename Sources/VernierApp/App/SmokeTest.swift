import AppKit
import VernierCore

extension AppCoordinator {
    enum SmokeFailure: Error { case failed(String) }
    private func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw SmokeFailure.failed(message) }
        print("PASS: \(message)")
    }
    private func waitUntil(_ message: String, _ condition: @MainActor () -> Bool) async throws {
        for _ in 0..<150 {
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
        // Exercise the capture/hover controls before the assertion that requires an active desktop.
        openStudio(model.page)
        refreshPresence()
        print("Focus wait: active=\(NSApp.isActive), key=\(studio?.isKeyWindow == true), surface=\(surface), pill=\(pillPresentation)")
        try await waitUntil("Pill hides while Studio is focused") {
            NSApp.isActive && studio?.isKeyWindow == true && pill?.isVisible != true && pillPresentation == .hidden
        }
        studio?.orderOut(nil)
        hoverHost.handleHoverEntry()
        refreshPresence()
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
        try await runModelSmokeChecks()
    }
    /// Functional view-model routes and isolated storage; no window activation is required.
    func runModelSmokeChecks() async throws {
        let modelSuite = "local.vernier.model-smoke-\(UUID().uuidString)"
        let modelDefaults = UserDefaults(suiteName: modelSuite)!
        defer { modelDefaults.removePersistentDomain(forName: modelSuite) }
        let model = AppModel(preferences: Preferences(defaults: modelDefaults), isolated: true)
        try check(!model.automaticDecisionReviews, "New reasoning does not start background inference without the automatic-review choice")
        model.automaticDecisionReviews = true
        let beforeAutomaticStop = model.decisionGeneration
        model.automaticDecisionReviews = false
        try check(model.decisionGeneration > beforeAutomaticStop && !model.reviewingDecision, "Disabling automatic reviews invalidates pending review work")
        model.demoEnabled = false; model.paused = false
        model.openStudio = { [weak model] page in model?.page = page }
        let now = Date()
        let root = URL(fileURLWithPath: "/synthetic/conductor/workspaces")
        let raw: [String: Any] = ["id": "ui-fixture", "cwd": root.appendingPathComponent("repo/workspace").path, "createdAt": now.timeIntervalSince1970, "updatedAt": now.timeIntervalSince1970, "source": "vscode"]
        guard let session = MetadataBoundary.session(raw, root: root, salt: "isolated-ui", now: now, turnsComplete: false) else { throw SmokeFailure.failed("UI fixture normalizes") }
        model.library = SessionLibrary(sessions: [session], turns: [], notes: [:])
        model.codexEnabled = true
        model.lastSync = now
        model.paused = false
        model.openStudio(.sessions)
        await Task.yield()
        try check(model.knownTurnCount == nil, "Unavailable turn history stays unknown")
        model.inspectSession(session)
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
        await showcase.loadDailyParticipation()
        try check(showcase.dailyReport?.day == showcase.selectedWorkDay && showcase.dailyReport?.datedTotal == showcase.library.messages.filter { $0.sourceAt.map(showcase.selectedWorkDay.contains) == true }.count,
                  "The daily overview counts the selected source day from synthetic records")
        let dailyGeneration = showcase.dailyGeneration
        await showcase.loadDailyParticipation()
        try check(showcase.dailyGeneration == dailyGeneration, "Compact and full daily views reuse an unchanged projection")
        if let moment = showcase.dailyReport?.moments.first {
            showcase.openDailyMoment(moment)
            try check(!showcase.dailyConversationExpanded && showcase.workDetailExpanded && showcase.briefSessionID == moment.sessionID && showcase.storyFocusID == moment.id,
                      "A daily pattern opens its own saved exchange and source anchor")
            showcase.dailyConversationExpanded = false; showcase.workDetailExpanded = false; showcase.selectedDecisionSessionID = showcase.library.sessions.first?.id
        }
        showcase.clearDailyParticipation()
        try check(showcase.dailyReport == nil && showcase.dailyReflections.isEmpty && showcase.dailyLoadedKey == nil, "Daily erasure clears the recap and private check-ins")
        try check(showcase.workOverview?.workspaces == 3 && showcase.workOverview?.count(.goAhead) == 1 && showcase.workOverview?.failureCount == 1,
                  "Work overview spans workspaces with source-linked wording cues and failure status")
        try check(showcase.participationMoments.contains { $0.kind == .requestedEvidence } && showcase.participationMoments.contains { $0.kind == .setBoundary },
                  "Human-facing readings retain concrete checks and constraints, not just wording counts")
        if let reading = showcase.participationMoments.first {
            showcase.openParticipation(reading)
            try check(showcase.selectedParticipation?.id == reading.id && !showcase.workDetailExpanded,
                      "Quick view opens the selected human reading before the full source inspector")
            showcase.readParticipation(reading)
            try check(showcase.briefSessionID == reading.sessionID && showcase.storyFocusID == reading.anchorID && showcase.workDetailExpanded,
                      "The reading opens the exact human message in its own source conversation")
            showcase.briefSessionID = nil
            showcase.workDetailExpanded = false
        }
        try check(showcase.decisionHistory.count == 2 && showcase.currentDecision?.reading?.focus == .check && showcase.currentDecision?.reading?.nextStep.contains("blank emails") == true && showcase.isDecisionCurrent,
                  "Reasoning showcase has distinct source-backed revisions without model calls")
        let latestDecision = showcase.currentDecision!
        showcase.selectedDecisionRevisionID = showcase.decisionHistory.last!.id
        try check(showcase.currentDecision?.reading?.focus == .handoff && showcase.currentDecision?.id != latestDecision.id,
                  "Earlier account selection changes the displayed interpretation")
        showcase.selectedDecisionRevisionID = nil
        showcase.showDecisionSource(latestDecision)
        try check(showcase.briefSessionID == latestDecision.sessionID && showcase.storyFocusID == latestDecision.anchorMessageID && showcase.workDetailExpanded,
                  "Reasoning source action opens the precise conversation anchor")
        showcase.briefSessionID = nil; showcase.workDetailExpanded = false
        showcase.selectDecisionSession(showcase.library.sessions[1].id)
        try check(showcase.currentDecision == nil && showcase.decisionSession?.id == showcase.library.sessions[1].id,
                  "Changing conversations never borrows a neighboring interpretation")
        showcase.selectDecisionSession(latestDecision.sessionID)
        showcase.checkDecisionEngine()
        try check(showcase.engineHealth?.contains("does not contact") == true && !showcase.checkingEngine,
                  "Engine check in showcase cannot invoke personal inference")
        let savedLibrary = showcase.library, savedReadings = showcase.decisionRevisions
        showcase.library = ShowcaseFixtures.directionLibrary()
        showcase.decisionRevisions = ShowcaseFixtures.directionHistory(library: showcase.library)
        showcase.selectedDecisionSessionID = showcase.library.sessions[0].id; showcase.selectedDecisionRevisionID = nil
        try check(showcase.directionToCheck?.reading?.signalKey != nil, "An eligible source-backed direction question reaches the ambient cue")
        showcase.openDirectionCheck()
        try check(showcase.page == .overview && showcase.selectedDecisionRevisionID == showcase.directionToCheck?.id, "The cue opens its own conversation and reading")
        showcase.paused = true
        try check(showcase.directionToCheck == nil, "Pause suppresses the ambient direction question")
        showcase.paused = false
        let cue = showcase.currentDecision!
        showcase.decisionPerspectives = [.init(sessionID: cue.sessionID, text: WorkReading.intentionalResponse, createdAt: cue.createdAt.addingTimeInterval(-1), anchorMessageID: "earlier-approval", signalKey: cue.reading?.signalKey)]
        try check(showcase.directionToCheck == nil, "A saved intentional choice suppresses repeat nudges for the same proposal")
        showcase.decisionPerspectives = []; showcase.library = savedLibrary; showcase.decisionRevisions = savedReadings; showcase.selectedDecisionSessionID = latestDecision.sessionID; showcase.selectedDecisionRevisionID = nil
        model.localInsightsEnabled = true
        let beforeDecisionPause = model.decisionGeneration
        model.paused = true
        try check(model.decisionGeneration > beforeDecisionPause && !model.reviewingDecision,
                  "Pause cancels and invalidates an in-flight reasoning result")
        model.paused = false
        model.reviewDecision()
        try check(!model.reviewingDecision, "Isolated smoke checks cannot invoke reasoning inference")
        let decisionTestDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("vernier-ui-decision-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: decisionTestDirectory) }
        let decisionStore = try SessionStore(directory: decisionTestDirectory, gate: model.captureGate)
        model.store = decisionStore; model.conversationMemoryEnabled = true
        let fixtureToken = model.captureGate.token()!
        let fixture = ShowcaseFixtures.workLibrary()
        _ = try await decisionStore.apply(.init(sessions: fixture.sessions, turns: fixture.turns, truncated: false, observedAt: Date(), messages: fixture.messages), token: fixtureToken)
        let fixtureContext = try await decisionStore.decisionContext(sessionID: latestDecision.sessionID)!
        let storedDecision = DecisionRevision.validated(context: fixtureContext, draft: .init(kind: .evidenceRequest, goal: "Check blank emails", summary: "You requested a blank-email test.", reason: "The request names a missing check.", alternative: "It may be a routine release check.", unknown: "The result is not recorded.", sourceIDs: [fixtureContext.anchorID]), critique: .init(supported: true, reason: "Exact test request.", sourceIDs: [fixtureContext.anchorID]), engine: "synthetic-ui")
        let storedOK = try await decisionStore.saveDecisionRevision(storedDecision, context: fixtureContext, token: fixtureToken)
        try check(storedOK, "UI perspective fixture stores a source-validated account")
        model.library = fixture; model.decisionRevisions = [storedDecision]; model.selectDecisionSession(storedDecision.sessionID)
        let perspectiveSaved = await model.saveDecisionPerspective("I asked for the blank-email test after checking the normal import myself.")
        try check(perspectiveSaved && model.currentPerspectives.count == 1 && !model.reviewingDecision,
                  "Save perspective persists separately and respects isolated inference")
        model.selectDecisionSession(fixture.sessions[1].id)
        model.decisionRevisions = []
        let draftTargetSaved = await model.saveDecisionPerspective("This draft was about the previous request, not the newly selected conversation.", about: storedDecision)
        try check(draftTargetSaved && model.decisionPerspectives.count == 2 && model.decisionPerspectives.allSatisfy { $0.revisionID == storedDecision.id && $0.anchorMessageID == storedDecision.anchorMessageID },
                  "A perspective draft keeps its original request after selection or background history changes")
        model.store = nil; model.clearDecisionMemory()
        try check(model.decisionRevisions.isEmpty && model.decisionPerspectives.isEmpty, "Erasure clears the displayed reasoning and personal perspectives")
        showcase.showMemorySource(sessionID: latestDecision.sessionID, messageID: latestDecision.anchorMessageID)
        let firstRoute = showcase.memoryRouteRevision
        showcase.showMemorySource(sessionID: latestDecision.sessionID, messageID: latestDecision.anchorMessageID)
        let exactSources = await showcase.searchMemory("", sessionID: latestDecision.sessionID, sourceID: showcase.memorySourceID)
        try check(exactSources.count == 1 && exactSources.first?.id == latestDecision.anchorMessageID && showcase.memoryQuery.isEmpty && showcase.memoryRouteRevision == firstRoute + 1,
                  "Repeated source navigation resolves the exact record without searching common wording")
        showcase.showMemory()
        try check(showcase.memorySourceID == nil, "Browsing memory clears the focused source route")
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
        try check(showcase.selectedParticipation == nil && showcase.participationMoments.isEmpty && showcase.workOverview == nil && showcase.workOverviewLoadedKey == nil && showcase.sessionStory == nil && showcase.storyLoadedKey == nil && !showcase.storyLoading && showcase.storyGeneration > beforeErase,
                  "Memory erasure clears map text and invalidates pending projection results")
    }

}
