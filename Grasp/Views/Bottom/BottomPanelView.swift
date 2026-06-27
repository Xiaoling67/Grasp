import SwiftUI

// Spec 4.6: Bottom panel — tabs + cards + ColdCall
struct BottomPanelView: View {
    @EnvironmentObject var vm: AppViewModel; @State private var ccW: CGFloat = 270

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 2) {
                    tabBtn("Current", "current"); tabBtn("Saved", "saved", c: vm.sessionSaves.count); tabBtn("Searched", "searched", c: vm.sessionSearches.count); autoTabBtn(); Spacer()
                }.padding(.horizontal, 16).frame(height: 32).overlay(Rectangle().fill(Color.pillBorderGray).frame(height: 1), alignment: .bottom)
                bodyContent
            }.frame(maxWidth: .infinity)

            Rectangle().fill(Color.pillBorderGray).frame(width: 4).gesture(DragGesture().onChanged { ccW = max(180, min(420, ccW - $0.translation.width)) })
            coldCall.frame(width: ccW)
        }.overlay(Rectangle().fill(Color.pillBorderGray).frame(height: 1), alignment: .top)
    }

    func tabBtn(_ label: String, _ tag: String, c: Int = 0) -> some View {
        Button(action: { vm.bottomTab = tag }) {
            HStack(spacing: 5) {
                Text(label).font(.inter(size: 11, weight: vm.bottomTab == tag ? .medium : .regular)).foregroundColor(vm.bottomTab == tag ? Color.nearBlack : Color.textTertiary)
                if c > 0 { Text("\(c)").font(.inter(size: 10)).foregroundColor(Color.mediumGray).padding(.horizontal, 5).background(Color.pillBorderGray).cornerRadius(10) }
            }.padding(.horizontal, 10).padding(.vertical, 4).background(vm.bottomTab == tag ? Color.fillTertiary : Color.clear).cornerRadius(4)
        }.buttonStyle(.plain)
    }

    func autoTabBtn() -> some View {
        Button(action: { vm.bottomTab = "auto"; vm.autoExplainNew = false }) {
            HStack(spacing: 4) {
                Text("Auto").font(.inter(size: 11, weight: vm.bottomTab == "auto" ? .medium : .regular))
                    .foregroundColor(vm.bottomTab == "auto" ? Color.nearBlack : Color.textTertiary)
                if vm.autoExplainNew || vm.autoExplainStreaming {
                    Circle().fill(Color.accentPurple).frame(width: 5, height: 5)
                }
            }.padding(.horizontal, 10).padding(.vertical, 4)
                .background(vm.bottomTab == "auto" ? Color.fillTertiary : Color.clear).cornerRadius(4)
        }.buttonStyle(.plain)
    }

    @ViewBuilder var bodyContent: some View {
        switch vm.bottomTab {
        case "current":
            if let c = vm.activeCard { switch c { case .search: SearchCardView(); case .save: SaveCardView() } }
            else if vm.searchStreaming { SearchCardView() }
            else { Text("Select text in the transcript to get an AI explanation").font(.inter(size: 12)).foregroundColor(Color.mutedGray).frame(maxWidth: .infinity, maxHeight: .infinity) }
        case "saved": listView(vm.sessionSaves, isSave: true)
        case "searched": searchListView(vm.sessionSearches)
        case "auto":
            if vm.autoExplainResult != nil || vm.autoExplainStreaming { AutoExplainCardView() }
            else { Text("Auto-explain activates when the professor uses a term you may not know.").font(.inter(size: 12)).foregroundColor(Color.mutedGray).multilineTextAlignment(.center).padding(16).frame(maxWidth: .infinity, maxHeight: .infinity) }
        default: EmptyView()
        }
    }

    func listView(_ saves: [SavedCard], isSave: Bool) -> some View {
        ScrollView { VStack(spacing: 0) {
            if saves.isEmpty { Text(isSave ? "No saves yet." : "No searches yet.").font(.inter(size: 12)).foregroundColor(Color.mutedGray).padding(8) }
            ForEach(Array(saves.enumerated()), id: \.offset) { _, s in
                Button(action: { vm.activeCard = .save(SaveDraft(type: s.type, original: s.original, translation: s.translation, lectureId: s.lectureId)); vm.bottomTab = "current" }) {
                    HStack(spacing: 8) { Text(s.type == "knowledge" ? "K" : "L").font(.inter(size: 9, weight: .bold)).padding(.horizontal, 5).padding(.vertical, 2).foregroundColor(s.type == "knowledge" ? Color.aiNewBorder : Color.accentGreen).background(s.type == "knowledge" ? Color.lightBlueBg : Color.lightGreenBg).cornerRadius(4); Text(s.original).font(.inter(size: 12)).foregroundColor(Color.mediumGray).lineLimit(1); Spacer() }.padding(.vertical, 6).padding(.horizontal, 8)
                }.buttonStyle(.plain)
            }
        } }
    }

    func searchListView(_ items: [SearchResultState]) -> some View {
        ScrollView { VStack(spacing: 0) {
            if items.isEmpty { Text("No searches yet.").font(.inter(size: 12)).foregroundColor(Color.mutedGray).padding(8) }
            ForEach(items) { s in
                Button(action: { vm.activeCard = .search(s); vm.bottomTab = "current" }) {
                    Text(s.query.isEmpty ? String(s.professional.prefix(60)) : s.query).font(.inter(size: 12)).foregroundColor(Color.mediumGray).lineLimit(1).padding(.vertical, 6).padding(.horizontal, 8).frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain)
            }
        } }
    }

    var coldCall: some View {
        Group {
            if let p = vm.coldCallPhase { ColdCallCardView(phase: p).padding(12) }
            else { VStack(spacing: 6) { Text("✋").font(.inter(size: 22)).opacity(0.25); Text("COLD CALL").font(.inter(size: 11, weight: .semibold)).foregroundColor(Color.textTertiary); Text("Appears when the professor\ncalls on the class").font(.inter(size: 11)).foregroundColor(Color.mutedGray).multilineTextAlignment(.center) }.frame(maxWidth: .infinity, maxHeight: .infinity) }
        }.background(Color.fillTertiary)
    }
}
