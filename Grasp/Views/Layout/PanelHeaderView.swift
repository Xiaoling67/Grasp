import SwiftUI

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
