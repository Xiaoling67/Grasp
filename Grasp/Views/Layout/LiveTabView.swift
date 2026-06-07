import SwiftUI

struct LiveTabView: View {
    @EnvironmentObject var vm: AppViewModel
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                TranscriptPanelView()
                Rectangle().fill(Color(hex: "E8E8E8")).frame(width: 1)
                    .gesture(DragGesture().onChanged { vm.notesWidth = max(200, min(500, vm.notesWidth - $0.translation.width)) })
                NotesPanelView().frame(width: vm.notesWidth)
            }
            Rectangle().fill(Color(hex: "F8F8F8")).frame(height: 5)
                .overlay(Rectangle().fill(Color(hex: "E8E8E8")).frame(height: 1), alignment: .top)
                .overlay(Rectangle().fill(Color(hex: "E8E8E8")).frame(height: 1), alignment: .bottom)
            BottomPanelView()
        }
    }
}
