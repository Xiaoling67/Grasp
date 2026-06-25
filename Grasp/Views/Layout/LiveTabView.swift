import SwiftUI

struct LiveTabView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // ── Top Row: Transcript | Notes ──
                HStack(spacing: 0) {
                    TranscriptPanelView()

                    // Vertical divider with drag handle (runs full height of both rows)
                    Rectangle()
                        .fill(Color(hex: "E8E8E8"))
                        .frame(width: 1)
                        .gesture(DragGesture().onChanged {
                            vm.notesWidth = max(200, min(500,
                                vm.notesWidth - $0.translation.width))
                        })

                    NotesPanelView()
                        .frame(width: rightColumnWidth(geo))
                }
                .frame(height: topRowHeight(geo))

                // ── Horizontal divider ──
                Rectangle()
                    .fill(Color(hex: "F8F8F8"))
                    .frame(height: 5)
                    .overlay(
                        Rectangle().fill(Color(hex: "E8E8E8")).frame(height: 1),
                        alignment: .top
                    )
                    .overlay(
                        Rectangle().fill(Color(hex: "E8E8E8")).frame(height: 1),
                        alignment: .bottom
                    )

                // ── Bottom Row: Auto Explain | ColdCall/Save/Search ──
                HStack(spacing: 0) {
                    // Bottom-Left: Auto Explain (always visible)
                    AutoExplainBottomQuadrant()

                    // Vertical divider (same vertical line, continues from above)
                    Rectangle()
                        .fill(Color(hex: "E8E8E8"))
                        .frame(width: 1)

                    // Bottom-Right: Cold Call / Save / Search (contextual)
                    ContextualBottomQuadrant()
                        .frame(width: rightColumnWidth(geo))
                }
                .frame(height: bottomRowHeight(geo))

                // ── Bottom Panel (UNCHANGED) ──
                BottomPanelView()
            }
        }
    }

    // MARK: - Layout helpers

    private func rightColumnWidth(_ geo: GeometryProxy) -> CGFloat {
        vm.notesWidth
    }

    private func topRowHeight(_ geo: GeometryProxy) -> CGFloat {
        (geo.size.height - 5) * 0.65  // 65% of available height (minus 5px divider)
    }

    private func bottomRowHeight(_ geo: GeometryProxy) -> CGFloat {
        (geo.size.height - 5) * 0.35
    }
}

// MARK: - Bottom-Left Quadrant: Auto Explain

struct AutoExplainBottomQuadrant: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("AUTO EXPLAIN").font(.inter(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "5A5A5A"))
                Spacer()
                if vm.autoExplainNew || vm.autoExplainStreaming {
                    Circle().fill(Color(hex: "7C3AED")).frame(width: 5, height: 5)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color(hex: "F8F8F8"))
            .overlay(Rectangle().fill(Color(hex: "E8E8E8")).frame(height: 1),
                     alignment: .bottom)

            // Content
            if vm.autoExplainResult != nil || vm.autoExplainStreaming {
                AutoExplainCardView()
            } else {
                idlePlaceholder
            }
        }
        .background(Color.white)
    }

    var idlePlaceholder: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("Watching for unfamiliar terms…")
                .font(.inter(size: 12)).foregroundColor(Color(hex: "C0C0C0"))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Bottom-Right Quadrant: Contextual (Cold Call / Save / Search)

struct ContextualBottomQuadrant: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Content
            Group {
                if let p = vm.coldCallPhase {
                    ColdCallCardView(phase: p)
                        .padding(12)
                } else if let card = vm.activeCard {
                    switch card {
                    case .save:
                        SaveCardView()
                    case .search:
                        SearchCardView()
                    }
                } else {
                    emptyPlaceholder
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.white)
    }

    var emptyPlaceholder: some View {
        VStack(spacing: 6) {
            Spacer()
            Text("COLD CALL / SAVE / SEARCH")
                .font(.inter(size: 11, weight: .semibold))
                .foregroundColor(Color(hex: "9A9A9A"))
            Text("Activity appears here")
                .font(.inter(size: 11))
                .foregroundColor(Color(hex: "C0C0C0"))
            Spacer()
        }
    }
}
