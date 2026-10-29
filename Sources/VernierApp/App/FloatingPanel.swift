import AppKit
import SwiftUI
import VernierCore

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func animationResizeTime(_ newFrame: NSRect) -> TimeInterval { 0.16 }
}

/// Keep capture controls usable without activating the dashboard or stealing focus.
final class PillActionButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var needsPanelToBecomeKey: Bool { false }
}

/// Mouse movement is handled by AppKit, preserving the nonactivating panel behavior.
final class PillHostingView: NSHostingView<PillView> {
    private var mouseDownPoint: NSPoint?
    private var initialCenter: NSPoint?
    private var didDrag = false
    var clicked: (() -> Void)?
    var captureToggled: (() -> Void)?
    var dashboardOpened: (() -> Void)?
    private(set) lazy var dashboardButton: PillActionButton = {
        let button = PillActionButton(frame: .zero)
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.focusRingType = .none
        button.image = NSImage(systemSymbolName: "arrow.up.forward.square", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 12, weight: .medium))
        button.contentTintColor = .secondaryLabelColor
        button.setAccessibilityLabel("Open dashboard")
        button.toolTip = "Open dashboard"
        button.target = self
        button.action = #selector(openDashboard)
        return button
    }()
    private(set) lazy var captureButton: PillActionButton = {
        let button = PillActionButton(frame: .zero)
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.focusRingType = .none
        button.target = self
        button.action = #selector(toggleCapture)
        return button
    }()
    func updateCaptureButton(paused: Bool) {
        captureButton.image = NSImage(systemSymbolName: paused ? "play.fill" : "pause.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold))
        captureButton.contentTintColor = paused ? .systemGreen : .secondaryLabelColor
        let label = paused ? "Resume capture" : "Pause capture"
        captureButton.setAccessibilityLabel(label)
        captureButton.toolTip = label
        layoutCaptureButton()
    }
    private func layoutCaptureButton() {
        if captureButton.superview == nil { addSubview(captureButton) }
        if dashboardButton.superview == nil { addSubview(dashboardButton) }
        captureButton.isHidden = bounds.width < 110
        dashboardButton.isHidden = captureButton.isHidden
        captureButton.frame = NSRect(x: bounds.width - 64, y: (bounds.height - 28) / 2, width: 28, height: 28)
        dashboardButton.frame = NSRect(x: bounds.width - 36, y: (bounds.height - 28) / 2, width: 28, height: 28)
    }
    override func layout() {
        super.layout()
        layoutCaptureButton()
    }
    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        guard bounds.contains(local) else { return nil }
        if !captureButton.isHidden && captureButton.frame.contains(local) { return captureButton }
        if !dashboardButton.isHidden && dashboardButton.frame.contains(local) { return dashboardButton }
        return self // The body pins/unpins controls; opening the dashboard is always explicit.
    }
    override func accessibilityChildren() -> [Any]? {
        var children = super.accessibilityChildren() ?? []
        if !captureButton.isHidden && !children.contains(where: { ($0 as? NSView) === captureButton }) { children.append(captureButton) }
        if !dashboardButton.isHidden && !children.contains(where: { ($0 as? NSView) === dashboardButton }) { children.append(dashboardButton) }
        return children
    }
    @objc private func toggleCapture() { captureToggled?() }
    @objc private func openDashboard() { dashboardOpened?() }

    var moved: (() -> Void)?
    var pillMenu: NSMenu?
    var hoverChanged: ((Bool) -> Void)?
    var pointerLocation: () -> NSPoint = { NSEvent.mouseLocation }
    private var hoverArea: NSTrackingArea?
    private var hoverExit: Task<Void, Never>?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        // One native tracking owner survives SwiftUI's compact/expanded layout changes.
        if hoverArea == nil {
            let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
            addTrackingArea(area)
            hoverArea = area
        }
    }
    override func mouseEntered(with event: NSEvent) { handleHoverEntry() }
    override func mouseExited(with event: NSEvent) { handleHoverExit() }
    func handleHoverEntry() {
        hoverExit?.cancel()
        hoverExit = nil
        hoverChanged?(true)
    }
    func handleHoverExit() {
        hoverExit?.cancel()
        hoverExit = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
            guard let self, self.mouseDownPoint == nil else { return }
            // AppKit can report an exit while the window is resizing under a stationary pointer.
            if self.window?.isVisible == true, self.window?.frame.contains(self.pointerLocation()) == true { return }
            self.hoverChanged?(false)
        }
    }
    override func menu(for event: NSEvent) -> NSMenu? { pillMenu }
    override var mouseDownCanMoveWindow: Bool { false }
    override func mouseDown(with event: NSEvent) {
        mouseDownPoint = NSEvent.mouseLocation
        didDrag = false
        if let frame = window?.frame { initialCenter = NSPoint(x: frame.midX, y: frame.midY) }
    }
    override func mouseDragged(with event: NSEvent) {
        guard let mouseDownPoint, let initialCenter, let frame = window?.frame else { return }
        let now = NSEvent.mouseLocation
        if hypot(now.x - mouseDownPoint.x, now.y - mouseDownPoint.y) >= 4 { didDrag = true }
        guard didDrag else { return }
        window?.setFrameOrigin(NSPoint(x: initialCenter.x + now.x - mouseDownPoint.x - frame.width / 2,
                                      y: initialCenter.y + now.y - mouseDownPoint.y - frame.height / 2))
    }
    override func mouseUp(with event: NSEvent) {
        guard mouseDownPoint != nil else { return }
        if didDrag { moved?() } else { clicked?() }
        self.mouseDownPoint = nil
        initialCenter = nil
        didDrag = false
        handleHoverExit()
    }
}

struct PillView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        GeometryReader { geometry in
            Group {
                if geometry.size.width < 110 {
                    indicator.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HStack(spacing: 11) {
                        InstrumentMark(size: 23)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(model.isShowcase ? "Vernier · Showcase" : Brand.name).font(.system(size: 12, weight: .medium))
                            Text(model.directionToCheck == nil ? model.capturePresenceLabel : "A direction to check")
                                .font(.system(size: 11)).foregroundStyle(Palette.secondary).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Color.clear.frame(width: 28, height: 28) // Native capture button owns this hit target.
                        Color.clear.frame(width: 9, height: 28) // Native dashboard button owns this target.
                    }.padding(.horizontal, 16).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }.background(.ultraThinMaterial, in: Capsule())
                .background(Palette.surface.opacity(0.85), in: Capsule())
                .overlay(Capsule().strokeBorder(Palette.line.opacity(0.75), lineWidth: 0.5))
                .foregroundStyle(Palette.text).contentShape(Capsule())
        }.accessibilityElement(children: .ignore)
            .accessibilityLabel("\(Brand.name), \(model.capturePhase.title). \(model.directionToCheck == nil ? "" : "Possible direction change to check. ")\(model.pillPinned ? "Release" : "Keep open") capture controls.")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { model.togglePillControls() }
            .help("Vernier remembers saved Codex work across Conductor workspaces, even when this circle is hidden. Hover for controls. Click to keep them open. Play/pause controls capture; the arrow opens the dashboard.")
    }
    @ViewBuilder private var indicator: some View {
        if model.directionToCheck != nil {
            Circle().strokeBorder(Palette.amber.opacity(0.65), lineWidth: 1)
                .overlay(Circle().fill(Palette.amber).frame(width: 6, height: 6)).frame(width: 15, height: 15)
        } else if model.capturePhase == .checking && !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled {
            ProgressView().controlSize(.mini).frame(width: 12, height: 12)
        } else if model.capturePhase == .current {
            Circle().strokeBorder(Palette.mint.opacity(0.65), lineWidth: 1)
                .overlay(Circle().fill(Palette.mint).frame(width: 4, height: 4))
                .frame(width: 14, height: 14)
        } else {
            Image(systemName: model.capturePhase.symbol).font(.system(size: 10, weight: .semibold))
                .foregroundStyle(CaptureStyle.color(model.capturePhase)).frame(width: 12, height: 12)
        }
    }
}
