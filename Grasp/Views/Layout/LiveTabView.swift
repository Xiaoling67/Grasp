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

// MARK: - Draggable Vertical Divider

struct VerticalDragHandle: View {
    @Binding var notesWidth: Double
    let availableWidth: CGFloat
    @State private var dragStartNotesWidth: Double?

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 6)
            .overlay(Rectangle().fill(Color.divider).frame(width: 2))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if dragStartNotesWidth == nil {
                            dragStartNotesWidth = notesWidth
                        }
                        let start = dragStartNotesWidth ?? notesWidth
                        let minWidth = 240.0
                        let maxWidth = max(minWidth, Double(availableWidth) - 320.0)
                        notesWidth = max(minWidth, min(maxWidth, start - value.translation.width))
                    }
                    .onEnded { _ in
                        dragStartNotesWidth = nil
                    }
            )
            .onHover { hovering in
                if hovering { NSCursor.resizeLeftRight.push() }
                else { NSCursor.pop() }
            }
    }
}

// MARK: - Draggable Horizontal Divider

struct HorizontalDragHandle: View {
    @Binding var rowRatio: CGFloat
    let availableHeight: CGFloat
    @State private var dragStartRatio: CGFloat?

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 8)
            .overlay(Rectangle().fill(Color.divider).frame(height: 2))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if dragStartRatio == nil {
                            dragStartRatio = rowRatio
                        }
                        let start = dragStartRatio ?? rowRatio
                        let totalHeight = max(1, availableHeight)
                        let ratio = max(0.30, min(0.80, (start * totalHeight + value.translation.height) / totalHeight))
                        rowRatio = ratio
                    }
                    .onEnded { _ in
                        dragStartRatio = nil
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
            PanelHeaderView(title: "AUTO EXPLAIN", status: vm.autoExplainStreaming ? "Working" : nil) {
                if vm.autoExplainNew || vm.autoExplainStreaming {
                    Circle().fill(Color.accentPurple).frame(width: 5, height: 5)
                }
            } settings: {
                AutoExplainSettingsPopover()
                    .environmentObject(vm)
            }

            // Content
            if vm.autoExplainResult != nil || vm.autoExplainStreaming {
                AutoExplainCardView()
            } else {
                idlePlaceholder
            }
        }
        .background(Color.warmCream)
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

// MARK: - Bottom-Right Quadrant: Contextual (Save / Search)

struct ContextualBottomQuadrant: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            PanelHeaderView(title: "SAVE / SEARCH", status: activityStatus) {
                EmptyView()
            } settings: {
                PanelInfoSettingsPopover(
                    title: "Activity Settings",
                    bodyText: "This panel shows saved selections and search results from the live transcript."
                )
            }

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
        .background(Color.warmCream)
    }

    var emptyPlaceholder: some View {
        VStack(spacing: Spacing.xxs) {
            Spacer()
            Text("Activity appears here")
                .font(.inter(size: AppTypography.caption))
                .foregroundColor(.textTertiary)
            Spacer()
        }
    }

    private var activityStatus: String? {
        if vm.coldCallPhase != nil { return "Cold Call" }
        if vm.activeCard != nil { return "Active" }
        return nil
    }
}

struct PanelHeaderView<Trailing: View, Settings: View>: View {
    let title: String
    var status: String?
    @ViewBuilder let trailing: () -> Trailing
    @ViewBuilder let settings: () -> Settings
    @State private var showingSettings = false

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.inter(size: AppTypography.caption, weight: .semibold))
                .foregroundColor(.nearBlack)
            if let status, !status.isEmpty {
                HStack(spacing: 5) {
                    // Spins while status ends in "..." — makes in-progress states (Writing,
                    // Catching up, Summarizing) visibly alive instead of a static label that
                    // reads as frozen during a multi-second API call.
                    if status.hasSuffix("...") {
                        ProgressView().controlSize(.mini).scaleEffect(0.6)
                    }
                    Text(status)
                        .font(.inter(size: 10, weight: .medium))
                        .foregroundColor(.textSecondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.warmCream)
                .cornerRadius(8)
            }
            Spacer()
            trailing()
            Button {
                showingSettings.toggle()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSecondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("\(title) settings")
            .popover(isPresented: $showingSettings, arrowEdge: .bottom) {
                settings()
                    .frame(width: 320)
                    .padding(14)
                    .background(Color.surfacePrimary)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(Color.pastelBlue)
        .overlay(Rectangle().fill(Color.divider).frame(height: 1), alignment: .bottom)
    }
}

struct PanelInfoSettingsPopover: View {
    let title: String
    let bodyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.inter(size: 13, weight: .semibold))
                .foregroundColor(.textPrimary)
            Text(bodyText)
                .font(.inter(size: 12))
                .foregroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct AutoExplainSettingsPopover: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Auto Explain Settings")
                .font(.inter(size: 13, weight: .semibold))
                .foregroundColor(.textPrimary)
            Text("Existing knowledge")
                .font(.inter(size: 11, weight: .semibold))
                .foregroundColor(.textSecondary)
            TextEditor(text: Binding(
                get: { vm.autoExplainKnowledge },
                set: { vm.setAutoExplainKnowledge($0) }
            ))
            .font(.inter(size: 12))
            .frame(height: 120)
            .scrollContentBackground(.hidden)
            .background(Color.warmCream)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.pillBorderGray, lineWidth: 1))
            Text("Add terms, formulas, or topics you already understand. Auto Explain will avoid spending attention on them.")
                .font(.inter(size: 11))
                .foregroundColor(.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
