import SwiftUI
import VernierCore

/// Fixed outer bounds keep native popover positioning stable as capture state changes.
struct MenuBarView: View {
    @ObservedObject var model: AppModel
    var height: CGFloat = QuickPanelLayout.preferredHeight
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                InstrumentMark(size: 25)
                Text(Brand.name).font(.headline).help("Control–Option–Command–V opens this recap from another app")
                Spacer()
                Text(model.isShowcase ? "Showcase" : model.paused ? "Paused" : model.syncing ? "Syncing" : model.codexEnabled ? "Connected" : "Off")
                    .font(.caption.weight(.medium)).foregroundStyle(CaptureStyle.color(model.capturePhase))
                Button { model.toggleCapture() } label: {
                    Image(systemName: model.paused ? "play.fill" : "pause.fill").font(.caption).frame(width: 25, height: 25)
                        .background(Palette.inset, in: Circle())
                }.buttonStyle(.plain).accessibilityLabel(model.paused ? "Resume capture" : "Pause capture")
                Button { model.closeQuickPanel() } label: { Image(systemName: "xmark").font(.caption).frame(width: 20, height: 20) }
                    .buttonStyle(.plain).foregroundStyle(Palette.secondary).accessibilityLabel("Close quick view")
            }.padding(.horizontal, 18).padding(.vertical, 15)
                .background { VernierField().opacity(0.075) }
            Divider().overlay(Palette.line.opacity(0.5))
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    QuickDailyView(model: model)

                }.padding(.horizontal, 18).padding(.vertical, 14)
            }.frame(maxHeight: .infinity)
            Divider().overlay(Palette.line.opacity(0.5))
            HStack {
                Button { model.openQuickRecap() } label: {
                    Label(model.quickRecapButtonTitle, systemImage: "arrow.up.left.and.arrow.down.right").frame(maxWidth: .infinity)
                }.buttonStyle(RecapButtonStyle()).keyboardShortcut("o").accessibilityLabel(model.quickRecapButtonTitle)
                Spacer()
                Button("Saved chats") { model.showMemory() }.buttonStyle(.plain).font(.callout).foregroundStyle(Palette.accent)
            }.padding(.horizontal, 18).padding(.top, 12)
            HStack {
                Label(model.isShowcase ? "Synthetic preview · no history read" : "Codex · saved on this Mac", systemImage: "lock").font(.caption2).foregroundStyle(Palette.secondary)
                Spacer()
                Text(GlobalShortcut.display).font(.system(.caption2, design: .monospaced)).foregroundStyle(Palette.secondary)
                    .accessibilityLabel("Open quick recap: Control Option Command V")
                Button("Quit") { model.quit() }.buttonStyle(.plain).font(.caption).keyboardShortcut("q")
            }.padding(.horizontal, 18).padding(.vertical, 12)
        }.frame(width: QuickPanelLayout.width, height: height)
            .background { VernierBackdrop() }.foregroundStyle(Palette.text)
            .onExitCommand { model.closeQuickPanel() }
    }

}
