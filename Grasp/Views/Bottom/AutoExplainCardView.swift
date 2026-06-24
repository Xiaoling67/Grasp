import SwiftUI

struct AutoExplainCardView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var saved = false

    private var pro: String { vm.autoExplainStreaming ? vm.autoExplainTokens : (vm.autoExplainResult?.professional ?? "") }
    private var intu: String { vm.autoExplainResult?.intuition ?? "" }
    private var term: String { vm.autoExplainResult?.query ?? "" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Text("AUTO").font(.inter(size: 9, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color(hex: "7C3AED")).cornerRadius(3)
                    Text(term).font(.inter(size: 11, weight: .semibold)).foregroundColor(Color(hex: "5A5A5A"))
                }
                Spacer()
                Button("✕") { vm.dismissAutoExplain() }.buttonStyle(.plain).font(.inter(size: 12)).foregroundColor(Color(hex: "C0C0C0"))
            }.padding(.horizontal, 12).padding(.vertical, 8)
                .overlay(Rectangle().fill(Color(hex: "E8E8E8")).frame(height: 0.5), alignment: .bottom)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 0) {
                        Text(pro).font(.inter(size: 13)).foregroundColor(Color(hex: "0A0A0A")).fixedSize(horizontal: false, vertical: true)
                        if vm.autoExplainStreaming { Text("▋").font(.inter(size: 13)).foregroundColor(Color(hex: "7C3AED")) }
                    }
                    if !intu.isEmpty {
                        Rectangle().fill(Color(hex: "E8E8E8")).frame(height: 0.5)
                        Text(intu).font(.inter(size: 13)).foregroundColor(Color(hex: "5A5A5A")).fixedSize(horizontal: false, vertical: true)
                    }
                }.padding(12)
            }

            if !vm.autoExplainStreaming && !pro.isEmpty {
                HStack {
                    Spacer()
                    Button(action: saveToK) { Text(saved ? "Saved ✓" : "+ Save to Knowledge").font(.inter(size: 11, weight: .medium)) }
                        .buttonStyle(.bordered).disabled(saved)
                }.padding(.horizontal, 12).padding(.vertical, 8)
                    .overlay(Rectangle().fill(Color(hex: "E8E8E8")).frame(height: 0.5), alignment: .top)
            }
        }
        .background(Color.white).cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "EDE9FE"), lineWidth: 1))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 1)
    }

    func saveToK() {
        guard let r = vm.autoExplainResult else { return }
        DatabaseService.shared.createSave(lectureId: vm.activeLectureId, blockId: nil, type: "knowledge",
                                          original: pro + (intu.isEmpty ? "" : " " + intu), translation: nil, note: nil)
        DatabaseService.shared.markSearchEngaged(id: r.id)
        saved = true
    }
}
