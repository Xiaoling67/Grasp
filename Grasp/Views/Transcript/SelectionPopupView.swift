import SwiftUI

// Spec 4.9 & 25: Glassmorphism popup K/L/Search/Notes
struct SelectionPopupView: View {
    @EnvironmentObject var vm: AppViewModel; let query: String; let blockIndex: Int; let x: CGFloat; let y: CGFloat; let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            Button(vm.activeLectureMode == "international" ? "K" : "Save") { vm.handleSaveAction(type: "knowledge", text: query); onDismiss() }.popupBtn()
            if vm.activeLectureMode == "international" { popupDivider; Button("L") { vm.handleSaveAction(type: "language", text: query); onDismiss() }.popupBtn() }
            popupDivider; Button("Search") { vm.triggerSearch(query: query, blockIndex: blockIndex); onDismiss() }.popupBtn(color: Color(hex: "1A5FD4"))
            popupDivider; Button("Notes") { vm.handleCopyToNotes(text: query); onDismiss() }.popupBtn(color: Color(hex: "15803D"))
        }
        .padding(.vertical, 4).padding(.horizontal, 5)
        .background(RoundedRectangle(cornerRadius: 15).fill(.regularMaterial))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(.black.opacity(0.09), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.08), radius: 18, y: 2)
        .position(x: min(max(x - 60, 70), 700), y: max(y - 44, 8))
    }
    var popupDivider: some View { Rectangle().fill(Color(hex: "E8E8E8")).frame(width: 1, height: 16).padding(.horizontal, 2) }
}

extension View {
    func popupBtn(color: Color = Color(hex: "0A0A0A")) -> some View {
        self.buttonStyle(.plain).font(.inter(size: 12, weight: .medium)).foregroundColor(color).padding(.horizontal, 10).frame(height: 24)
    }
}
