import SwiftUI
import AppKit

// v1.1-r2: Instant pill-shaped popup with NSVisualEffectView material
struct SelectionPopupView: View {
    @EnvironmentObject var vm: AppViewModel; let query: String; let blockIndex: Int; let x: CGFloat; let y: CGFloat; let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            Button(action: { vm.handleSaveAction(type: "knowledge", text: query); onDismiss() }) {
                Label("K", systemImage: "bookmark.fill")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 12))
            }
            .popupBtn()

            popupDivider

            if vm.activeLectureMode == "international" {
                Button(action: { vm.handleSaveAction(type: "language", text: query); onDismiss() }) {
                    Label("L", systemImage: "character.bubble.fill")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 12))
                }
                .popupBtn()
                popupDivider
            }

            Button(action: { vm.triggerSearch(query: query, blockIndex: blockIndex); onDismiss() }) {
                Label("Search", systemImage: "magnifyingglass")
                    .font(.system(size: 12))
            }
            .popupBtn(color: .accentBlue)
        }
        .padding(.vertical, Spacing.xxs).padding(.horizontal, Spacing.xs)
        .background(
            VisualEffectView(material: .popover, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.popup))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.popup)
                .stroke(Color.divider, lineWidth: 1)
        )
        .position(x: min(max(x, 100), 750), y: max(y - 44, 8))
    }

    var popupDivider: some View {
        Rectangle().fill(Color.divider).frame(width: 1, height: 16).padding(.horizontal, 2)
    }
}

// NSVisualEffectView wrapper
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

extension View {
    func popupBtn(color: Color = Color.textPrimary) -> some View {
        self.buttonStyle(.plain).foregroundColor(color).padding(.horizontal, 8).frame(height: 24)
    }
}
