import SwiftUI

struct PastLectureView: View {
    let lectureId: String; let lectureMeta: Lecture?
    @EnvironmentObject var vm: AppViewModel
    @State private var blocks = [Block](); @State private var saves = [SavedCard]()
    @State private var searches = [SearchResult](); @State private var notes = [NoteBlock]()
    @State private var loading = true; @State private var tab = "transcript"
    @State private var edit = false; @State private var nameVal = ""

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack { if edit { TextField("", text: $nameVal, onCommit: commit).textFieldStyle(.plain).font(.inter(size: 15, weight: .semibold)).frame(width: 200).onAppear { nameVal = lectureMeta?.name ?? "" } } else { Text(lectureMeta?.name ?? "Untitled Lecture").font(.inter(size: 15, weight: .semibold)).onTapGesture { edit = true } }; if let s = lectureMeta?.subject { Text(s).font(.inter(size: 11, weight: .medium)).foregroundColor(Color.aiNewBorder).padding(.horizontal, 6).padding(.vertical, 1).background(Color.lightBlueBg).cornerRadius(4) }; Spacer() }
                if let d = lectureMeta?.startedAt { Text(fmt(d)).font(.inter(size: 11)).foregroundColor(Color.textTertiary) }
                HStack(spacing: 2) { tabBtn("Transcript", "transcript", c: blocks.count); tabBtn("Notes", "notes", c: notes.count); tabBtn("Saved", "saved", c: saves.count); tabBtn("Searches", "searches", c: searches.count) }
            }.padding(.horizontal, 20).padding(.top, 16).background(Color.fillTertiary).overlay(Rectangle().fill(Color.pillBorderGray).frame(height: 1), alignment: .bottom)
            if loading { HStack(spacing: 6) { ForEach(0..<3, id: \.self) { _ in Circle().fill(Color.pillBorderGray).frame(width: 6, height: 6) } }.padding(40) }
            else { ScrollView { LazyVStack(alignment: .leading, spacing: 10) { switch tab { case "transcript": transcriptBody; case "notes": notesBody; case "saved": savedBody; case "searches": searchedBody; default: EmptyView() } }.padding(20) } }
        }.background(Color.white).onAppear { load() }
    }

    func tabBtn(_ label: String, _ tag: String, c: Int) -> some View {
        Button(action: { tab = tag }) { HStack(spacing: 5) { Text(label).font(.inter(size: 12, weight: .medium)).foregroundColor(tab == tag ? Color.nearBlack : Color.mediumGray); if c > 0 { Text("\(c)").font(.inter(size: 10)).foregroundColor(tab == tag ? Color.aiNewBorder : Color.mediumGray).padding(.horizontal, 5).padding(.vertical, 1).background(tab == tag ? Color.lightBlueBg : Color.pillBorderGray).cornerRadius(8) } }.padding(.horizontal, 14).padding(.vertical, 8).overlay(Rectangle().fill(tab == tag ? Color.aiNewBorder : Color.clear).frame(height: 2), alignment: .bottom) }.buttonStyle(.plain)
    }

    @ViewBuilder var transcriptBody: some View {
        if blocks.isEmpty { Text("No transcript saved for this lecture.").font(.inter(size: 13)).foregroundColor(Color.textTertiary).padding(.top, 40).frame(maxWidth: .infinity) }
        else { ForEach(blocks) { b in VStack(alignment: .leading, spacing: 4) { Text(b.textEn).font(.inter(size: 13)).foregroundColor(Color.nearBlack).fixedSize(horizontal: false, vertical: true); if let zh = b.textZh, !zh.isEmpty { Text(zh).font(.inter(size: 12)).foregroundColor(Color.mediumGray).fixedSize(horizontal: false, vertical: true) } }.padding(12).frame(maxWidth: 680, alignment: .leading).background(Color.fillTertiary).cornerRadius(6).overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.pillBorderGray, lineWidth: 0.5)) } }
    }

    @ViewBuilder var notesBody: some View {
        if notes.isEmpty { Text("No notes from this lecture.").font(.inter(size: 13)).foregroundColor(Color.textTertiary).padding(.top, 40).frame(maxWidth: .infinity) }
        else { VStack(alignment: .leading, spacing: 8) { ForEach(Array(notesSorted.enumerated()), id: \.offset) { _, n in let pre = n.level == 0 ? "1." : n.level == 1 ? "·" : "○"; HStack(alignment: .top, spacing: 6) { Text(pre).font(.inter(size: 12)).foregroundColor(Color.notesDividerGray).frame(width: 16); Text(n.content).font(.inter(size: 13)).foregroundColor(n.source == "user" ? Color.deepBlue : Color.nearBlack).padding(.leading, CGFloat(n.level * 16)) }.fixedSize(horizontal: false, vertical: true) } } }
    }

    @ViewBuilder var savedBody: some View {
        if saves.isEmpty { Text("No saved items from this lecture.").font(.inter(size: 13)).foregroundColor(Color.textTertiary).padding(.top, 40).frame(maxWidth: .infinity) }
        else { VStack(spacing: 10) { ForEach(saves) { s in VStack(alignment: .leading, spacing: 6) { Text(s.type == "knowledge" ? "Knowledge" : "Language").font(.inter(size: 10, weight: .semibold)).foregroundColor(s.type == "knowledge" ? Color.knowledgeBlue : Color.accentGreen).padding(.horizontal, 5).padding(.vertical, 1).background(s.type == "knowledge" ? Color.lightBlueBg : Color.lightGreenBg).cornerRadius(3); Text(s.original).font(.inter(size: 13)).foregroundColor(Color.nearBlack).fixedSize(horizontal: false, vertical: true); if let t = s.translation { Text(t).font(.inter(size: 12)).foregroundColor(Color.mediumGray) }; if let n = s.note { Text(n).font(.inter(size: 12)).foregroundColor(Color.textTertiary) } }.padding(14).frame(maxWidth: 680, alignment: .leading).background(Color.fillTertiary).cornerRadius(6) } } }
    }

    @ViewBuilder var searchedBody: some View {
        if searches.isEmpty { Text("No AI searches from this lecture.").font(.inter(size: 13)).foregroundColor(Color.textTertiary).padding(.top, 40).frame(maxWidth: .infinity) }
        else { VStack(spacing: 10) { ForEach(searches) { s in VStack(alignment: .leading, spacing: 4) { Text("\"\(s.query)\"").font(.inter(size: 13)).foregroundColor(Color.nearBlack); if !s.resultPro.isEmpty { Text(s.resultPro).font(.inter(size: 13)).foregroundColor(Color.nearBlack) }; if !s.resultSimple.isEmpty { Text(s.resultSimple).font(.inter(size: 13)).foregroundColor(Color.mediumGray) }; if let n = s.note { Text(n).font(.inter(size: 12)).foregroundColor(Color.textTertiary) } }.padding(14).frame(maxWidth: 680, alignment: .leading).background(Color.fillTertiary).cornerRadius(6) } } }
    }

    var notesSorted: [NoteBlock] { notes.sorted { ($0.sortOrder, $0.createdAt ?? 0) < ($1.sortOrder, $1.createdAt ?? 0) } }
    func load() { loading = true; blocks = DatabaseService.shared.getBlocks(lectureId: lectureId); saves = DatabaseService.shared.getSaves(lectureId: lectureId); searches = DatabaseService.shared.getSearches(lectureId: lectureId); notes = DatabaseService.shared.getNoteBlocks(lectureId: lectureId); loading = false }
    func commit() { edit = false; DatabaseService.shared.updateLectureName(id: lectureId, name: nameVal.trimmingCharacters(in: .whitespaces)) }
    func fmt(_ ms: Int64) -> String { let d = Date(timeIntervalSince1970: Double(ms) / 1000); let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f.string(from: d) }
}
