import SwiftUI

// Spec 4.8: block — 13px EN / 12px ZH / active dot / timestamp / highlight
struct BlockView: View {
    @EnvironmentObject var vm: AppViewModel; let block: LiveBlock; let isActive: Bool

    private var bgColor: Color {
        if vm.highlightedBlockIds.contains(block.id) {
            return .selectionBg
        }
        if isActive {
            return Color.pastelBlue
        }
        return Color.clear
    }

    private var timestampStr: String? {
        guard let createdAt = block.createdAt, let lectureStart = vm.activeLectureId else { return nil }
        let firstBlockTs = vm.liveBlocks.first(where: { $0.createdAt != nil })?.createdAt ?? createdAt
        let offsetMs = createdAt - firstBlockTs
        let totalSeconds = max(0, Int(offsetMs / 1000))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(block.textEn)
                .font(.inter(size: vm.transcriptEnglishFontSize))
                .foregroundColor(.textPrimary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            if vm.shouldShowTranslation, let zh = block.textZh, !zh.isEmpty {
                Text(zh)
                    .font(.inter(size: vm.transcriptTranslationFontSize))
                    .foregroundColor(.textSecondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if block.isSealed, let ts = timestampStr {
                Text(ts).font(.inter(size: 9, weight: .medium)).foregroundColor(.textTertiary).padding(.top, 2)
            }
            if isActive { HStack(spacing: 5) { Circle().fill(Color.accentBlue).frame(width: 6, height: 6); Text("Transcribing...").font(.inter(size: 10)).foregroundColor(.textTertiary) }.padding(.top, 2) }
        }
        .padding(.horizontal, Spacing.sm).padding(.vertical, 10)
        .background(bgColor)
        .cornerRadius(CornerRadius.card)
        .contextMenu {
            Button("Save as Knowledge (K)") { vm.handleSaveAction(type: "knowledge", text: block.textEn) }
            if vm.activeLectureMode == "international" { Button("Save as Language (L)") { vm.handleSaveAction(type: "language", text: block.textEn) } }
            Divider()
            Button("AI Search") { vm.triggerSearch(query: block.textEn, blockIndex: block.blockIndex) }
            Button("Copy to Notes") { vm.handleCopyToNotes(text: block.textEn) }
        }
    }
}
