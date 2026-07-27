import SwiftUI

struct LiveTabView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                // ── Left column: Transcript / Auto Explain — independent height ──
                VStack(spacing: 0) {
                    TranscriptPanelView()
                        .frame(height: columnTopHeight(geo, ratio: vm.leftColumnRatio))

                    HorizontalDragHandle(rowRatio: $vm.leftColumnRatio, availableHeight: geo.size.height - 8)

                    AutoExplainBottomQuadrant()
                        .frame(height: columnBottomHeight(geo, ratio: vm.leftColumnRatio))
                }

                VerticalDragHandle(notesWidth: $vm.notesWidth, availableWidth: geo.size.width)

                // ── Right column: Notes / Save-Search — independent height ──
                VStack(spacing: 0) {
                    NotesPanelView()
                        .frame(height: columnTopHeight(geo, ratio: vm.rightColumnRatio))

                    HorizontalDragHandle(rowRatio: $vm.rightColumnRatio, availableHeight: geo.size.height - 8)

                    ContextualBottomQuadrant()
                        .frame(height: columnBottomHeight(geo, ratio: vm.rightColumnRatio))
                }
                .frame(width: vm.notesWidth)
            }
        }
    }

    // MARK: - Layout helpers

    private func columnTopHeight(_ geo: GeometryProxy, ratio: CGFloat) -> CGFloat {
        (geo.size.height - 8) * ratio
    }

    private func columnBottomHeight(_ geo: GeometryProxy, ratio: CGFloat) -> CGFloat {
        (geo.size.height - 8) * (1 - ratio)
    }
}
