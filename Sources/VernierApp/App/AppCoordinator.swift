import AppKit
import SwiftUI
import Combine
import VernierCore

@MainActor final class AppCoordinator: NSObject, NSApplicationDelegate, NSWindowDelegate, NSPopoverDelegate {
    let model: AppModel
    private(set) var statusItem: NSStatusItem?
    private(set) var popover = NSPopover()
    private(set) var studio: NSWindow?
    private(set) var pill: FloatingPanel?
    private var welcome: NSWindow?
    private var quickPreview: NSWindow?
    private var subscriptions: Set<AnyCancellable> = []
    private var syncTask: Task<Void, Never>?
    private var sleeping = false
    private var inactiveSession = false
    private let smokeTest: Bool
    private let pillAnchorSize = PillPresentation.expanded.size
    enum Surface { case ambient, quickView, studio, welcome }
    private(set) var surface: Surface = .ambient
    private(set) var pillPresentation: PillPresentation = .hidden
    private var lastPillTarget: NSRect?

    init(smokeTest: Bool = false, showcase: Bool = false) {
        self.smokeTest = smokeTest
        if smokeTest {
            let defaults = UserDefaults(suiteName: "local.vernier.smoke-test")!
            defaults.removePersistentDomain(forName: "local.vernier.smoke-test")
            model = AppModel(preferences: Preferences(defaults: defaults), isolated: true)
        } else if showcase {
            let defaults = UserDefaults(suiteName: "local.vernier.showcase")!
            defaults.removePersistentDomain(forName: "local.vernier.showcase")
            model = AppModel(preferences: Preferences(defaults: defaults), showcase: true)
        } else { model = AppModel() }
        super.init()
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--render-showcase") {
            Task { @MainActor in
                do { try await renderShowcase(); print("SYNTHETIC VIEW RENDERS SAVED"); NSApp.terminate(nil) }
                catch { fputs("SHOWCASE RENDER FAILED: \(error)\n", stderr); exit(1) }
            }
            return
        }
        if CommandLine.arguments.contains("--model-smoke-test") {
            Task { @MainActor in
                do { try await runModelSmokeChecks(); print("MODEL STATE CHECKS PASSED"); NSApp.terminate(nil) }
                catch { fputs("MODEL STATE CHECKS FAILED: \(error)\n", stderr); exit(1) }
            }
            return
        }
        if CommandLine.arguments.contains("--decision-model-probe") {
            Task { @MainActor in
                do { try await runDecisionModelProbe(); NSApp.terminate(nil) }
                catch { fputs("DECISION MODEL PROBE FAILED: \(error)\n", stderr); exit(1) }
            }
            return
        }
        if CommandLine.arguments.contains("--brief-model-probe") {
            Task { @MainActor in
                do { try await runLocalModelProbe(); NSApp.terminate(nil) }
                catch { fputs("LOCAL MODEL PROBE FAILED: \(error)\n", stderr); exit(1) }
            }
            return
        }
        NSApp.setActivationPolicy(.accessory)
        configureMainMenu()
        model.openStudio = { [weak self] page in self?.openStudio(page) }
        model.closeQuickPanel = { [weak self] in self?.closeQuickView() }
        model.showWelcome = { [weak self] in self?.openWelcome() }
        model.resetPill = { [weak self] in
            self?.model.preferences.pillOrigin = nil
            self?.restorePillPosition()
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.target = self
            button.action = #selector(togglePopover)
            button.image = makeStatusImage()
            button.setAccessibilityLabel(Brand.name)
        }
        popover.behavior = .transient
        popover.animates = false // Also respects reduced motion; no continuous animations anywhere.
        popover.delegate = self
        prepareQuickPanel()
        model.objectWillChange.sink { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshPresence() }
        }.store(in: &subscriptions)
        NotificationCenter.default.addObserver(self, selector: #selector(screenParametersChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        refreshPresence()
        if !smokeTest && !model.isShowcase {
            if CommandLine.arguments.contains("--connect-codex") {
                model.codexEnabled = true
                model.demoEnabled = false
                model.preferences.onboardingComplete = true
            }
            model.refreshLoginStatus()
            if CommandLine.arguments.contains("--enable-login") { model.setLaunchAtLogin(true) }
            if CommandLine.arguments.contains("--enable-conversation-memory") { model.conversationMemoryEnabled = true }
            if CommandLine.arguments.contains("--enable-local-insights") { model.localInsightsEnabled = true }
            if CommandLine.arguments.contains("--show-pill") { model.pillEnabled = true }
            syncTask = Task { await model.startSessionSync() }
            let workspace = NSWorkspace.shared.notificationCenter
            for name in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
                workspace.addObserver(self, selector: #selector(workspaceWillRest(_:)), name: name, object: nil)
            }
            for name in [NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
                workspace.addObserver(self, selector: #selector(workspaceDidWake(_:)), name: name, object: nil)
            }
        }
        if smokeTest {
            Task { @MainActor in
                do {
                    try await runSmokeTest(); print("NATIVE UI SMOKE PASSED")
                    NSApp.terminate(nil)
                }
                catch { fputs("NATIVE UI SMOKE FAILED: \(error)\n", stderr); exit(1) }
            }
        } else if !model.preferences.onboardingComplete { openWelcome() }
        else if model.isShowcase && CommandLine.arguments.contains("--quick-preview") { openQuickPreview() }
        else if !launchedAtLogin { openStudio(.overview) }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Activating a menu-bar surface must not also summon a dashboard behind it.
        guard surface != .quickView && !popover.isShown else { return false }
        openStudio(model.page); return true
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) {
        syncTask?.cancel()
        model.cancelWorkBrief(); model.cancelDecisionReview()
        model.setSystemSuspended(true)
        savePillPosition()
    }
    private var launchedAtLogin: Bool {
        let event = NSAppleEventManager.shared().currentAppleEvent
        return event?.eventID == kAEOpenApplication && event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }
    @objc private func workspaceWillRest(_ notification: Notification) {
        if notification.name == NSWorkspace.willSleepNotification { sleeping = true } else { inactiveSession = true }
        model.setSystemSuspended(sleeping || inactiveSession)
        pill?.orderOut(nil)
    }
    @objc private func workspaceDidWake(_ notification: Notification) {
        if notification.name == NSWorkspace.didWakeNotification { sleeping = false } else { inactiveSession = false }
        model.setSystemSuspended(sleeping || inactiveSession)
        restorePillPosition(); refreshPresence()
    }
    func applicationDidBecomeActive(_ notification: Notification) {
        if !smokeTest { model.requestInteractiveCheck() }
        refreshPresence()
    }
    func applicationDidResignActive(_ notification: Notification) { refreshPresence() }
    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === studio {
            model.studioVisible = false
            if surface == .studio { surface = .ambient }
            refreshPresence()
        } else if notification.object as? NSWindow === welcome {
            if surface == .welcome { surface = .ambient }
            refreshPresence()
        }
    }
    func windowDidBecomeKey(_ notification: Notification) {
        if notification.object as? NSWindow === studio {
            guard surface == .studio else {
                studio?.orderOut(nil)
                model.studioVisible = false
                refreshPresence()
                return
            }
            model.pillHovered = false
            refreshPresence()
        }
    }
    func windowDidResignKey(_ notification: Notification) { refreshPresence() }
    func windowDidMiniaturize(_ notification: Notification) {
        if notification.object as? NSWindow === studio { model.studioVisible = false }
        refreshPresence()
    }
    func windowDidDeminiaturize(_ notification: Notification) {
        if notification.object as? NSWindow === studio {
            if surface == .quickView { studio?.orderOut(nil); model.studioVisible = false }
            else { surface = .studio; model.studioVisible = true }
        }
        refreshPresence()
    }
    func popoverDidShow(_ notification: Notification) {
        guard surface == .quickView else { popover.performClose(nil); return }
        constrainQuickPanel()
    }
    private func constrainQuickPanel() {
        guard surface == .quickView, popover.isShown, let window = popover.contentViewController?.view.window,
              let screen = statusItem?.button?.window?.screen ?? window.screen else { return }
        let frame = QuickPanelLayout.constrain(window.frame, to: screen.visibleFrame)
        if frame != window.frame { window.setFrame(frame, display: true) }
    }
    func popoverDidClose(_ notification: Notification) {
        if surface == .quickView && !popover.isShown { surface = .ambient }
        refreshPresence()
    }
    func closeQuickView() {
        quickPreview?.orderOut(nil)
        if surface == .quickView { surface = .ambient }
        popover.performClose(nil)
        refreshPresence()
    }
    private func prepareQuickPanel() {
        let size = QuickPanelLayout.size(screenHeight: statusItem?.button?.window?.screen?.visibleFrame.height ?? NSScreen.main?.visibleFrame.height ?? 800)
        let host = NSHostingController(rootView: MenuBarView(model: model, height: size.height))
        host.sizingOptions = []
        host.preferredContentSize = size
        host.view.setFrameSize(size)
        popover.contentViewController = host
        popover.contentSize = size
    }

    /// Isolated visual-QA host of the exact menu-bar content. Never reads personal records.
    private func openQuickPreview() {
        guard model.isShowcase else { return }
        surface = .quickView
        refreshPresence()
        let size = QuickPanelLayout.size(screenHeight: NSScreen.main?.visibleFrame.height ?? 800)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Vernier · Synthetic quick-view preview"
        window.contentView = NSHostingView(rootView: MenuBarView(model: model, height: size.height))
        window.isReleasedWhenClosed = false
        window.center(); window.makeKeyAndOrderFront(nil)
        quickPreview = window
        NSApp.activate(ignoringOtherApps: true)
    }
    private func configureMainMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        let open = NSMenuItem(title: "Open dashboard", action: #selector(openStudioAction), keyEquivalent: "o")
        open.target = self
        appMenu.addItem(open)
        let quick = NSMenuItem(title: "Quick View", action: #selector(togglePopover), keyEquivalent: "")
        quick.target = self
        appMenu.addItem(quick)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide \(Brand.name)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit \(Brand.name)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        menu.addItem(appItem)
        let edit = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        edit.submenu = editMenu
        menu.addItem(edit)
        NSApp.mainMenu = menu
    }
    @objc private func openStudioAction() { openStudio(.overview) }
    @objc func togglePopover() {
        guard let button = statusItem?.button else { return }
        if surface == .quickView && popover.isShown { closeQuickView() } else {
            surface = .quickView
            studio?.orderOut(nil)
            welcome?.orderOut(nil)
            model.studioVisible = false
            model.pillHovered = false
            model.pillPinned = false
            refreshPresence()
            prepareQuickPanel()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            constrainQuickPanel()
            Task { @MainActor [weak self] in
                await Task.yield()
                self?.constrainQuickPanel()
            }
        }
    }
    func openStudio(_ page: StudioPage) {
        quickPreview?.orderOut(nil)
        surface = .studio
        model.page = page
        popover.performClose(nil)
        welcome?.orderOut(nil)
        if studio == nil {
            let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 900)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: min(1180, visible.width - 50), height: min(820, visible.height - 70)), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "\(Brand.name) Studio"
            window.minSize = NSSize(width: 860, height: 608)
            window.contentView = NSHostingView(rootView: StudioView(model: model))
            window.isReleasedWhenClosed = false
            window.setFrameAutosaveName(model.isShowcase ? "ShowcaseStudio" : smokeTest ? "SmokeStudio" : "StudioStory")
            window.center()
            studio = window
        }
        model.pillHovered = false
        model.pillPinned = false
        model.studioVisible = true
        studio?.delegate = self
        if !smokeTest { model.requestInteractiveCheck() }
        if studio?.isMiniaturized == true { studio?.deminiaturize(nil) }
        studio?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    func openWelcome() {
        surface = .welcome
        popover.performClose(nil)
        studio?.orderOut(nil)
        model.studioVisible = false
        if welcome == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 510), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Welcome to \(Brand.name)"
            window.contentView = NSHostingView(rootView: WelcomeView(model: model, complete: { [weak self] in self?.welcome?.close() }))
            window.isReleasedWhenClosed = false
            window.center()
            welcome = window
        }
        welcome?.delegate = self
        welcome?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    func refreshPresence() {
        statusItem?.button?.image = makeStatusImage()
        statusItem?.button?.toolTip = "\(Brand.name) · \(model.capturePhase.title) · \(model.captureModeTitle)"
        statusItem?.button?.setAccessibilityLabel("\(Brand.name), \(model.capturePhase.title)")
        let studioFocused = surface == .studio && NSApp.isActive && studio?.isVisible == true && studio?.isMiniaturized != true && studio?.isKeyWindow == true
        let presentation = PillPresentation.resolve(enabled: model.pillEnabled, resting: model.systemSuspended,
            studioFocused: studioFocused, quickPanelVisible: surface == .quickView || surface == .welcome,
            hovered: model.pillHovered || model.pillPinned, alwaysExpanded: model.pillAlwaysExpanded)
        guard presentation != .hidden else {
            pillPresentation = .hidden
            pill?.orderOut(nil)
            return
        }
        if pill == nil { createPill() }
        guard let pill else { return }
        if let host = pill.contentView as? PillHostingView {
            host.pillMenu = makePillMenu()
            host.updateCaptureButton(paused: model.paused)
        }
        let target = pillFrame(for: presentation)
        let animate = pill.isVisible && presentation != pillPresentation && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if lastPillTarget != target {
            lastPillTarget = target
            pill.setFrame(target, display: true, animate: animate)
        }
        pillPresentation = presentation
        pill.orderFrontRegardless()
    }
    private func createPill() {
        let panel = FloatingPanel(contentRect: NSRect(origin: .zero, size: pillAnchorSize), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenNone, .ignoresCycle]
        panel.title = "\(Brand.name) floating status"
        let host = PillHostingView(rootView: PillView(model: model))
        host.hoverChanged = { [weak self] hovered in
            guard let self, self.model.pillHovered != hovered else { return }
            self.model.pillHovered = hovered
        }
        host.captureToggled = { [weak self] in self?.model.toggleCapture() }
        host.dashboardOpened = { [weak self] in self?.openStudio(.overview) }
        host.clicked = { [weak self] in self?.model.togglePillControls() }
        host.moved = { [weak self] in self?.restoreAndSavePillPosition() }
        panel.contentView = host
        pill = panel
    }
    private func pillFrame(for presentation: PillPresentation) -> NSRect {
        let anchor = PanelPlacement.origin(saved: model.preferences.pillOrigin, size: pillAnchorSize, screens: NSScreen.screens.map(\.visibleFrame))
        let size = presentation.size
        return NSRect(x: anchor.x + (pillAnchorSize.width - size.width) / 2,
                      y: anchor.y + (pillAnchorSize.height - size.height) / 2, width: size.width, height: size.height)
    }
    @objc private func screenParametersChanged() { restorePillPosition() }
    private func restorePillPosition() {
        guard pill != nil else { return }
        refreshPresence()
    }
    private func restoreAndSavePillPosition() {
        savePillPosition()
        refreshPresence()
    }
    private func savePillPosition() {
        guard let pill else { return }
        let anchor = NSPoint(x: pill.frame.midX - pillAnchorSize.width / 2, y: pill.frame.midY - pillAnchorSize.height / 2)
        model.preferences.pillOrigin = PanelPlacement.origin(saved: anchor, size: pillAnchorSize, screens: NSScreen.screens.map(\.visibleFrame))
    }
    private func makePillMenu() -> NSMenu {
        let menu = NSMenu()
        let open = NSMenuItem(title: "Open dashboard", action: #selector(openStudioAction), keyEquivalent: "")
        open.target = self; menu.addItem(open)
        let pause = NSMenuItem(title: model.paused ? "Resume capture" : "Pause capture", action: #selector(toggleCaptureAction), keyEquivalent: "")
        pause.target = self; menu.addItem(pause)
        let hide = NSMenuItem(title: "Hide floating pill", action: #selector(hidePillAction), keyEquivalent: "")
        hide.target = self; menu.addItem(hide)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit \(Brand.name)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        return menu
    }
    @objc private func toggleCaptureAction() { model.toggleCapture() }
    @objc private func hidePillAction() { model.pillEnabled = false }
    private func makeStatusImage() -> NSImage {
        let state = model.projection.state
        let image = NSImage(size: NSSize(width: 27, height: 19), flipped: false) { _ in
            NSColor.labelColor.setStroke()
            NSColor.labelColor.setFill()
            let path = NSBezierPath(ovalIn: NSRect(x: 3.5, y: 3.5, width: 12, height: 12))
            path.lineWidth = 1
            path.stroke()
            let mark = NSBezierPath()
            mark.move(to: NSPoint(x: 9.5, y: 1)); mark.line(to: NSPoint(x: 9.5, y: 18))
            mark.move(to: NSPoint(x: 5, y: 7)); mark.line(to: NSPoint(x: 14, y: 7))
            mark.move(to: NSPoint(x: 7, y: 12)); mark.line(to: NSPoint(x: 12, y: 12))
            mark.lineWidth = 1.3
            mark.stroke()
            // Shape also communicates status; VoiceOver/tooltip provides the complete label.
            switch state {
            case .idle:
                NSBezierPath(ovalIn: NSRect(x: 22, y: 7, width: 4, height: 4)).stroke()
            case .observing:
                NSBezierPath(ovalIn: NSRect(x: 22, y: 7, width: 4, height: 4)).fill()
            case .paused:
                NSBezierPath(rect: NSRect(x: 22, y: 6, width: 1, height: 6)).fill()
                NSBezierPath(rect: NSRect(x: 25, y: 6, width: 1, height: 6)).fill()
            case .moment:
                let diamond = NSBezierPath()
                diamond.move(to: NSPoint(x: 24, y: 5))
                diamond.line(to: NSPoint(x: 27, y: 9))
                diamond.line(to: NSPoint(x: 24, y: 13))
                diamond.line(to: NSPoint(x: 21, y: 9))
                diamond.close(); diamond.stroke()
            case .connectorIssue:
                NSBezierPath(rect: NSRect(x: 23, y: 8, width: 2, height: 5)).fill()
                NSBezierPath(ovalIn: NSRect(x: 23, y: 5, width: 2, height: 2)).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
