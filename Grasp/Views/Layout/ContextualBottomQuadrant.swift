import SwiftUI

// MARK: - Bottom-Right Quadrant: Contextual (Cold Call / Save / Search)

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
