import SwiftUI

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
