import SwiftUI
import AppKit

// v1.1-r2: Instant pill-shaped popup with NSVisualEffectView material
// 4 consistent buttons: K (bookmark.fill), L (character.bubble.fill), Search (magnifyingglass), Note (square.and.pencil)
struct SelectionPopupView: View {
    @EnvironmentObject var vm: AppViewModel
    let query: String
    let blockIndex: Int
    let x: CGFloat
    let y: CGFloat
    let panelSize: CGSize
    let onDismiss: () -> Void

    private var estimatedWidth: CGFloat {
        vm.activeLectureMode == "international" ? 262 : 218
    }

    private var clampedX: CGFloat {
        min(max(x, estimatedWidth / 2 + Spacing.xs), panelSize.width - estimatedWidth / 2 - Spacing.xs)
    }

    private var clampedY: CGFloat {
        min(max(y, 18), panelSize.height - 18)
    }

    var body: some View {
        HStack(spacing: 2) {
            // K — bookmark.fill icon + "K" label
            popupButton(icon: "bookmark.fill", label: "K") {
                vm.handleSaveAction(type: "knowledge", text: query)
                onDismiss()
            }

            popupDivider

            // L — character.bubble.fill icon + "L" label (International mode only)
            if vm.activeLectureMode == "international" {
                popupButton(icon: "character.bubble.fill", label: "L") {
                    vm.handleSaveAction(type: "language", text: query)
                    onDismiss()
                }
                popupDivider
            }

            // Search — magnifyingglass icon + "Search" label
            popupButton(icon: "magnifyingglass", label: "Search") {
                vm.triggerSearch(query: query, blockIndex: blockIndex)
                onDismiss()
            }

            popupDivider

            // Note — square.and.pencil icon + "Note" label → copies to notes
            popupButton(icon: "square.and.pencil", label: "Note") {
                vm.handleCopyToNotes(text: query)
                onDismiss()
            }
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
        .position(x: clampedX, y: clampedY)
    }

    /// Consistent button style: icon + short label, plain appearance, same dimensions
    private func popupButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.system(size: 12))
        }
        .buttonStyle(.plain)
        .foregroundColor(.textPrimary)
        .padding(.horizontal, 8)
        .frame(height: 24)
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
