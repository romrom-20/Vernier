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
                Text(model.isShowcase ? "Showcase" : model.paused ? "Paused" : model.syncing ? "Syncing" : "Local")
                    .font(.caption.weight(.medium)).foregroundStyle(CaptureStyle.color(model.capturePhase))
                Button { model.closeQuickPanel() } label: { Image(systemName: "xmark").font(.caption).frame(width: 20, height: 20) }
                    .buttonStyle(.plain).foregroundStyle(Palette.secondary).accessibilityLabel("Close quick view")
            }.padding(.horizontal, 18).padding(.vertical, 15)
            Divider().overlay(Palette.line.opacity(0.5))
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    WorkBriefView(model: model, compact: true)
                    Divider().overlay(Palette.line.opacity(0.5))
                    DisclosureGroup("Capture details") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(model.captureDescription).font(.caption).foregroundStyle(Palette.secondary)
                            CaptureInventory(model: model, compact: true)
                            Text("\(model.library.totalMessageCount.formatted()) messages saved · \(model.library.sessions.count) sessions").font(.caption2).foregroundStyle(Palette.secondary)
                        }.padding(.top, 8)
                    }.font(.caption).foregroundStyle(Palette.secondary)
                    CaptureToggle(model: model, compact: true)
                }.padding(18)
            }.frame(maxHeight: .infinity)
            Divider().overlay(Palette.line.opacity(0.5))
            HStack {
                Button("Open dashboard") { model.openStudio(.overview) }.buttonStyle(QuietButtonStyle()).keyboardShortcut("o")
                Spacer()
                Button("Memory →") { model.showMemory() }.buttonStyle(.plain).font(.callout).foregroundStyle(Palette.mint)
            }.padding(.horizontal, 18).padding(.top, 12)
            HStack {
                Label("Saved privately on this Mac", systemImage: "lock").font(.caption2).foregroundStyle(Palette.secondary)
                Spacer()
                Button("Quit") { model.quit() }.buttonStyle(.plain).font(.caption).keyboardShortcut("q")
            }.padding(.horizontal, 18).padding(.vertical, 12)
        }.frame(width: QuickPanelLayout.width, height: height)
            .background(Palette.surface).foregroundStyle(Palette.text)
            .onExitCommand { model.closeQuickPanel() }
    }

}
