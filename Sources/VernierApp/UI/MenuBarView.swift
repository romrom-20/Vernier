import SwiftUI
import VernierCore

/// Fixed outer bounds keep native popover positioning stable as capture state changes.
struct MenuBarView: View {
    @ObservedObject var model: AppModel
    var height: CGFloat = 414
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                InstrumentMark(size: 25)
                Text(Brand.name).font(.headline)
                Spacer()
                Text(model.isShowcase ? "Showcase" : model.paused ? "Paused" : model.syncing ? "Syncing" : model.codexEnabled ? "Following" : "Off")
                    .font(.caption.weight(.medium)).foregroundStyle(CaptureStyle.color(model.capturePhase))
                Button { model.toggleCapture() } label: {
                    Image(systemName: model.paused ? "play.fill" : "pause.fill").font(.caption).frame(width: 25, height: 25)
                        .background(Palette.inset, in: Circle())
                }.buttonStyle(.plain).accessibilityLabel(model.paused ? "Resume capture" : "Pause capture")
                Button { model.closeQuickPanel() } label: { Image(systemName: "xmark").font(.caption).frame(width: 20, height: 20) }
                    .buttonStyle(.plain).foregroundStyle(Palette.secondary).accessibilityLabel("Close quick view")
            }.padding(.horizontal, 18).padding(.vertical, 15)
            Divider().overlay(Palette.line.opacity(0.5))
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    QuickDecisionView(model: model)

                }.padding(18)
            }.frame(maxHeight: .infinity)
            Divider().overlay(Palette.line.opacity(0.5))
            HStack {
                Button { model.openStudio(.overview) } label: {
                    Label("Open dashboard", systemImage: "arrow.up.left.and.arrow.down.right").frame(maxWidth: .infinity)
                }.buttonStyle(QuietButtonStyle()).keyboardShortcut("o").accessibilityLabel("Open dashboard and understand your participation")
                Spacer()
                Button("Memory →") { model.showMemory() }.buttonStyle(.plain).font(.callout).foregroundStyle(Palette.mint)
            }.padding(.horizontal, 18).padding(.top, 12)
            HStack {
                Label(model.isShowcase ? "Synthetic preview · no history read" : "Codex · saved on this Mac", systemImage: "lock").font(.caption2).foregroundStyle(Palette.secondary)
                Spacer()
                Button("Quit") { model.quit() }.buttonStyle(.plain).font(.caption).keyboardShortcut("q")
            }.padding(.horizontal, 18).padding(.vertical, 12)
        }.frame(width: QuickPanelLayout.width, height: height)
            .background(Palette.surface).foregroundStyle(Palette.text)
            .onExitCommand { model.closeQuickPanel() }
    }

}
