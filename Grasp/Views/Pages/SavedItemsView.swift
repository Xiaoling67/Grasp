import SwiftUI

// Spec 15: Saved Items — grid + filter + search
struct SavedItemsView: View {
    @EnvironmentObject var vm: AppViewModel; @State private var saves = [SavedCard](); @State private var loading = true; @State private var filter = "all"; @State private var search = ""

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack { Text("Saved Items").font(.inter(size: 16, weight: .semibold)).foregroundColor(Color.nearBlack); Spacer(); Text("\(saves.count) total").font(.inter(size: 12)).foregroundColor(Color.textTertiary) }.padding(.horizontal, 20).padding(.top, 24)
                HStack(spacing: 8) {
                    filterBtn("All", "all", all: saves.count)
                    filterBtn("Knowledge", "knowledge", all: saves.filter { $0.type == "knowledge" }.count)
                    filterBtn("Language", "language", all: saves.filter { $0.type == "language" }.count)
                    Spacer(); TextField("Search saved items...", text: $search).textFieldStyle(.plain).font(.inter(size: 12)).padding(.horizontal, 8).padding(.vertical, 5).background(Color.fillTertiary).cornerRadius(4).overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.pillBorderGray, lineWidth: 1)).frame(width: 200)
                }.padding(.horizontal, 20).padding(.bottom, 12)
            }.background(Color.fillTertiary).overlay(Rectangle().fill(Color.pillBorderGray).frame(height: 1), alignment: .bottom)

            if loading { HStack(spacing: 6) { ForEach(0..<3, id: \.self) { _ in Circle().fill(Color.pillBorderGray).frame(width: 6, height: 6) } }.padding(40).frame(maxWidth: .infinity) }
            else if filtered.isEmpty { Text(saves.isEmpty ? "No saved items yet. Select text during a lecture and save it." : "No items match your search.").font(.inter(size: 13)).foregroundColor(Color.textTertiary).padding(40).frame(maxWidth: .infinity) }
            else { ScrollView { LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12)], spacing: 12) { ForEach(filtered) { s in card(s) } }.padding(20) } }
        }.background(Color.white).onAppear { load() }
    }

    func filterBtn(_ label: String, _ tag: String, all: Int) -> some View {
        Button(action: { filter = tag }) { Text("\(label) \(all)").font(.inter(size: 11, weight: .medium)).foregroundColor(filter == tag ? Color.nearBlack : Color.mediumGray).padding(.horizontal, 10).padding(.vertical, 4).background(filter == tag ? Color.white : Color.clear).cornerRadius(4).overlay(filter == tag ? RoundedRectangle(cornerRadius: 4).stroke(Color.pillBorderGray, lineWidth: 1) : nil) }.buttonStyle(.plain)
    }

    var filtered: [SavedCard] { saves.filter { s in if filter != "all" && s.type != filter { return false }; if !search.isEmpty { let q = search.lowercased(); return (s.original.lowercased().contains(q) || (s.translation?.lowercased().contains(q) ?? false) || (s.note?.lowercased().contains(q) ?? false) || (s.lectureName?.lowercased().contains(q) ?? false)) }; return true } }

    func card(_ s: SavedCard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(s.type == "knowledge" ? "Knowledge" : "Language").font(.inter(size: 10, weight: .semibold)).foregroundColor(s.type == "knowledge" ? Color.knowledgeBlue : Color.accentGreen).padding(.horizontal, 5).padding(.vertical, 1).background(s.type == "knowledge" ? Color.lightBlueBg : Color.lightGreenBg).cornerRadius(3)
                if let ln = s.lectureName { Button(action: { vm.openPastLecture(id: s.lectureId ?? "", name: ln) }) { Text(ln).font(.inter(size: 11)).foregroundColor(Color.aiNewBorder) }.buttonStyle(.plain) }
                Spacer()
            }
            Text(s.original).font(.inter(size: 13)).foregroundColor(Color.nearBlack).fixedSize(horizontal: false, vertical: true)
            if let t = s.translation { Text(t).font(.inter(size: 12)).foregroundColor(Color.mediumGray) }
            if let n = s.note { Text(n).font(.inter(size: 12)).foregroundColor(Color.textTertiary) }
            HStack { Text(fmt(s.createdAt)).font(.inter(size: 11)).foregroundColor(Color.mutedGray); if let subj = s.lectureSubject { Text(subj).font(.inter(size: 10)).foregroundColor(Color.aiNewBorder).padding(.horizontal, 5).padding(.vertical, 1).background(Color.lightBlueBg).cornerRadius(3) } }
        }.padding(14).background(Color.fillTertiary).cornerRadius(6)
    }

    func load() { loading = true; saves = DatabaseService.shared.getAllSaves(); loading = false }
    func fmt(_ ms: Int64?) -> String { guard let ms else { return "" }; let d = Date(timeIntervalSince1970: Double(ms) / 1000); let f = DateFormatter(); f.dateStyle = .medium; return f.string(from: d) }
}
