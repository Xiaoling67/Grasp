import SwiftUI

// Spec 16: Search History — expandable cards
struct SearchHistoryView: View {
    @EnvironmentObject var vm: AppViewModel; @State private var searches = [SearchResult](); @State private var loading = true; @State private var sq = ""; @State private var expanded: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack { Text("Search History").font(.inter(size: 16, weight: .semibold)).foregroundColor(Color.nearBlack); Spacer(); Text("\(searches.count) total").font(.inter(size: 12)).foregroundColor(Color.textTertiary) }.padding(.horizontal, 20).padding(.top, 24)
                TextField("Search queries...", text: $sq).textFieldStyle(.plain).font(.inter(size: 12)).padding(.horizontal, 8).padding(.vertical, 5).background(Color.fillTertiary).cornerRadius(4).overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.pillBorderGray, lineWidth: 1)).frame(width: 300).padding(.horizontal, 20).padding(.bottom, 12)
            }.background(Color.fillTertiary).overlay(Rectangle().fill(Color.pillBorderGray).frame(height: 1), alignment: .bottom)

            if loading { HStack(spacing: 6) { ForEach(0..<3, id: \.self) { _ in Circle().fill(Color.pillBorderGray).frame(width: 6, height: 6) } }.padding(40).frame(maxWidth: .infinity) }
            else if filtered.isEmpty { Text(searches.isEmpty ? "No searches yet. Select text during a lecture and press the search shortcut." : "No searches match your filter.").font(.inter(size: 13)).foregroundColor(Color.textTertiary).padding(40).frame(maxWidth: .infinity) }
            else { ScrollView { VStack(spacing: 8) { ForEach(filtered) { s in card(s) }.padding(20) } } }
        }.background(Color.white).onAppear { load() }
    }

    var filtered: [SearchResult] { if sq.isEmpty { return searches }; let q = sq.lowercased(); return searches.filter { $0.query.lowercased().contains(q) || $0.resultPro.lowercased().contains(q) || $0.resultSimple.lowercased().contains(q) || ($0.lectureName?.lowercased().contains(q) ?? false) } }

    func card(_ s: SearchResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { expanded = expanded == s.id ? nil : s.id }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) { Text("\"\(s.query)\"").font(.inter(size: 13)).foregroundColor(Color.nearBlack).lineLimit(1); HStack(spacing: 8) { if let ln = s.lectureName { Button(action: { vm.openPastLecture(id: s.lectureId ?? "", name: ln) }) { Text(ln).font(.inter(size: 11)).foregroundColor(Color.aiNewBorder) }.buttonStyle(.plain) }; Text(fmt(s.createdAt)).font(.inter(size: 11)).foregroundColor(Color.mutedGray); if s.saved == 1 { Text("Saved").font(.inter(size: 10)).foregroundColor(Color.accentGreen).padding(.horizontal, 5).padding(.vertical, 1).background(Color.lightGreenBg).cornerRadius(3) } } }
                    Spacer(); Text(expanded == s.id ? "▾" : "▸").font(.inter(size: 11)).foregroundColor(Color.mutedGray)
                }.padding(12)
            }.buttonStyle(.plain)
            if expanded == s.id {
                VStack(alignment: .leading, spacing: 6) { if !s.resultPro.isEmpty { Text(s.resultPro).font(.inter(size: 13)).foregroundColor(Color.nearBlack).fixedSize(horizontal: false, vertical: true) }; if !s.resultSimple.isEmpty { Text(s.resultSimple).font(.inter(size: 13)).foregroundColor(Color.mediumGray).fixedSize(horizontal: false, vertical: true) }; if let n = s.note { Text(n).font(.inter(size: 12)).foregroundColor(Color.textTertiary) } }.padding(.horizontal, 12).padding(.bottom, 12)
            }
        }.background(Color.fillTertiary).cornerRadius(6)
    }

    func load() { loading = true; searches = DatabaseService.shared.getAllSearches(); loading = false }
    func fmt(_ ms: Int64?) -> String { guard let ms else { return "" }; let d = Date(timeIntervalSince1970: Double(ms) / 1000); let f = DateFormatter(); f.dateStyle = .medium; return f.string(from: d) }
}
