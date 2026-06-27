import SwiftUI

// Spec 14: Search card with streaming + follow-up + quick note
struct SearchCardView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var note = ""; @State private var followUp = ""; @State private var saved = false
    @State private var engageTimer: Timer? = nil

    private var result: SearchResultState? { if case .search(let r) = vm.activeCard { return r }; return nil }
    private var pro: String { vm.searchStreaming ? vm.streamingTokens : (result?.professional ?? "") }
    private var intu: String { result?.intuition ?? "" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("SEARCH").font(.inter(size: 11, weight: .semibold)).foregroundColor(Color.mediumGray)
                Spacer(); Button("✕") { dismiss() }.buttonStyle(.plain).font(.inter(size: 12)).foregroundColor(Color.mutedGray)
            }.padding(.horizontal, 12).padding(.vertical, 8)
                .overlay(Rectangle().fill(Color.pillBorderGray).frame(height: 0.5), alignment: .bottom)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if let e = result?.error { Text(e).font(.inter(size: 12)).foregroundColor(Color.accentRed) }
                    else {
                        HStack(alignment: .top, spacing: 0) { Text(pro).font(.inter(size: 13)).foregroundColor(Color.nearBlack).fixedSize(horizontal: false, vertical: true); if vm.searchStreaming { Text("▋").font(.inter(size: 13)).foregroundColor(Color.aiNewBorder) } }
                        if !intu.isEmpty { Rectangle().fill(Color.pillBorderGray).frame(height: 0.5); Text(intu).font(.inter(size: 13)).foregroundColor(Color.mediumGray).fixedSize(horizontal: false, vertical: true) }
                        if !vm.searchStreaming && result?.error == nil {
                            Rectangle().fill(Color.pillBorderGray).frame(height: 0.5)
                            HStack(spacing: 6) {
                                TextField("Ask a follow-up…", text: $followUp).textFieldStyle(.plain).font(.inter(size: 12)).padding(.horizontal, 8).padding(.vertical, 5).background(Color.fillTertiary).cornerRadius(4).overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.pillBorderGray, lineWidth: 0.5)).onSubmit { send() }
                                Button(action: send) { Text("→").font(.inter(size: 14)).foregroundColor(followUp.isEmpty ? Color.mutedGray : Color.aiNewBorder).padding(.horizontal, 8) }.buttonStyle(.plain).disabled(followUp.isEmpty)
                            }
                            TextField("Quick note…", text: $note, axis: .vertical).textFieldStyle(.plain).font(.inter(size: 12)).padding(8).background(Color.fillTertiary).cornerRadius(4).overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.pillBorderGray, lineWidth: 0.5))
                        }
                    }
                }.padding(12)
            }
            if !vm.searchStreaming && result?.error == nil && !pro.isEmpty {
                HStack { Spacer(); Button(action: saveToK) { Text(saved ? "Saved ✓" : "+ Save to Knowledge").font(.inter(size: 11, weight: .medium)) }.buttonStyle(.bordered).disabled(saved) }.padding(.horizontal, 12).padding(.vertical, 8).overlay(Rectangle().fill(Color.pillBorderGray).frame(height: 0.5), alignment: .top)
            }
        }.background(Color.white).cornerRadius(8).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.pillBorderGray, lineWidth: 0.5)).shadow(color: .black.opacity(0.06), radius: 8, y: 1)
        .onAppear { if !vm.searchStreaming { startEngageTimer() } }
        .onChange(of: vm.searchStreaming) { streaming in if !streaming { startEngageTimer() } }
    }

    func send() {
        guard !followUp.isEmpty, let lid = vm.activeLectureId else { return }
        let q = followUp.trimmingCharacters(in: .whitespacesAndNewlines); followUp = ""
        if let r = result { DatabaseService.shared.markSearchEngaged(id: r.id) }
        vm.triggerSearch(query: q, blockIndex: 9999, lectureId: lid)
    }
    func saveToK() {
        guard let r = result else { return }
        DatabaseService.shared.createSave(lectureId: vm.activeLectureId, blockId: nil, type: "knowledge", original: pro + (intu.isEmpty ? "" : " " + intu), translation: nil, note: note.isEmpty ? nil : note)
        DatabaseService.shared.markSearchSaved(id: r.id)
        DatabaseService.shared.markSearchEngaged(id: r.id)
        saved = true
    }
    func dismiss() {
        if let r = result { DatabaseService.shared.markSearchDismissed(id: r.id) }
        engageTimer?.invalidate(); engageTimer = nil
        vm.activeCard = nil
    }
    func startEngageTimer() {
        engageTimer?.invalidate()
        engageTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { _ in
            if let r = result { DatabaseService.shared.markSearchEngaged(id: r.id) }
        }
    }
}
