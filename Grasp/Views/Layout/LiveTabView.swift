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
                        .fill(Color.divider)
                        .frame(width: 1)
                        .gesture(DragGesture().onChanged {
                            vm.notesWidth = max(200, min(500,
                                vm.notesWidth - $0.translation.width))
                        })
                        .onHover { hovering in
                            if hovering { NSCursor.resizeLeftRight.push() }
                            else { NSCursor.pop() }
                        }

                    NotesPanelView()
                        .frame(width: rightColumnWidth(geo))
                }
                .frame(height: topRowHeight(geo))

                // ── Horizontal divider — DRAGGABLE (v1.1-r2) ──
                HorizontalDragHandle(
                    topRowRatio: $vm.topRowRatio,
                    availableHeight: geo.size.height - 5  // subtract divider height
                )

                // ── Bottom Row: Auto Explain | ColdCall/Save/Search ──
                HStack(spacing: 0) {
                    // Bottom-Left: Auto Explain (always visible)
                    AutoExplainBottomQuadrant()

                    // Vertical divider (same vertical line, continues from above)
                    Rectangle()
                        .fill(Color.divider)
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
        (geo.size.height - 12) * vm.topRowRatio
    }

    private func bottomRowHeight(_ geo: GeometryProxy) -> CGFloat {
        (geo.size.height - 12) * (1 - vm.topRowRatio)
    }
}

// MARK: - Draggable Horizontal Divider

struct HorizontalDragHandle: View {
    @Binding var topRowRatio: CGFloat
    let availableHeight: CGFloat

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 12)
            .overlay(
                Rectangle().fill(Color.divider).frame(height: 1),
                alignment: .top
            )
            .overlay(
                Rectangle().fill(Color.divider).frame(height: 1),
                alignment: .bottom
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let totalHeight = availableHeight
                        let dragY = value.startLocation.y + value.translation.height
                        let ratio = max(0.30, min(0.80, dragY / totalHeight))
                        topRowRatio = ratio
                    }
            )
            .onHover { hovering in
                if hovering { NSCursor.resizeUpDown.push() }
                else { NSCursor.pop() }
            }
    }
}

// MARK: - Bottom-Left Quadrant: Auto Explain

struct AutoExplainBottomQuadrant: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("AUTO EXPLAIN").font(.inter(size: AppTypography.caption, weight: .semibold))
                    .foregroundColor(.textSecondary)
                Spacer()
                if vm.autoExplainNew || vm.autoExplainStreaming {
                    Circle().fill(Color.accentPurple).frame(width: 5, height: 5)
                }
            }
            .padding(.horizontal, Spacing.sm).padding(.vertical, Spacing.xs)
            .background(Color.surfaceSecondary)
            .overlay(Rectangle().fill(Color.divider).frame(height: 1),
                     alignment: .bottom)

            // Content
            if vm.autoExplainResult != nil || vm.autoExplainStreaming {
                AutoExplainCardView()
            } else {
                idlePlaceholder
            }
        }
        .background(Color.surfacePrimary)
    }

    var idlePlaceholder: some View {
        VStack(spacing: Spacing.xs) {
            Spacer()
            Text("Watching for unfamiliar terms…")
                .font(.inter(size: AppTypography.caption)).foregroundColor(.textTertiary)
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
                        .padding(Spacing.sm)
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
        .background(Color.surfacePrimary)
    }

    var emptyPlaceholder: some View {
        VStack(spacing: Spacing.xxs) {
            Spacer()
            Text("COLD CALL / SAVE / SEARCH")
                .font(.inter(size: AppTypography.caption, weight: .semibold))
                .foregroundColor(.textTertiary)
            Text("Activity appears here")
                .font(.inter(size: AppTypography.caption))
                .foregroundColor(.textTertiary)
            Spacer()
        }
    }
}
