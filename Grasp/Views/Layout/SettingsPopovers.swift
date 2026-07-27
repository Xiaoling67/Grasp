import SwiftUI

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
