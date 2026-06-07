import SwiftUI

// Spec 11: NotesPanel — collapsible, per-note edit
struct NotesPanelView: View {
    @EnvironmentObject var vm: AppViewModel; @State private var eid: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack { Text("NOTES").font(.inter(size: 11, weight: .semibold)).foregroundColor(Color(hex: "5A5A5A")); Spacer(); Text("\(vm.noteBlocks.count)").font(.inter(size: 10)).foregroundColor(Color(hex: "C0C0C0")); Button(action: add) { Image(systemName: "plus").font(.inter(size: 12)).foregroundColor(Color(hex: "5A5A5A")) }.buttonStyle(.plain) }.padding(.horizontal, 12).padding(.vertical, 8).background(Color(hex: "F8F8F8")).overlay(Rectangle().fill(Color(hex: "E8E8E8")).frame(height: 1), alignment: .bottom)
            if vm.noteBlocks.isEmpty { Text("AI notes will appear here…").font(.inter(size: 12)).foregroundColor(Color(hex: "C0C0C0")).frame(maxWidth: .infinity, maxHeight: .infinity).padding(.top, 20) }
            else { ScrollView { VStack(alignment: .leading, spacing: 0) { ForEach(grouped, id: \.key) { g in if let t = g.title, !t.isEmpty { Text(t.uppercased()).font(.inter(size: 10, weight: .semibold)).foregroundColor(Color(hex: "C0C0C0")).padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 4) }; ForEach(g.notes) { n in NoteRow(note: n, editing: eid == n.id, onEdit: { eid = n.id }, onSave: { vm.updateNote(id: n.id, content: $0, level: nil); eid = nil }, onDelete: { vm.deleteNote(id: n.id) }, onIndent: { vm.updateNote(id: n.id, content: n.content, level: max(0, min(2, n.level + 1))) }) } }; Color.clear.frame(height: 80) } } }
        }.background(Color.white)
    }

    var grouped: [(key: Int, title: String?, notes: [NoteBlock])] { var m = [Int: (String?, [NoteBlock])](); for n in vm.noteBlocks { if m[n.slideIndex] == nil { m[n.slideIndex] = (n.slideTitle, []) }; m[n.slideIndex]!.1.append(n) }; return m.keys.sorted().map { (key: $0, title: m[$0]!.0, notes: m[$0]!.1) } }
    func add() { guard let lid = vm.activeLectureId else { return }; let n = DatabaseService.shared.saveNoteBlock(lectureId: lid, slideIndex: vm.slideStructure.last?.index ?? 0, slideTitle: vm.slideStructure.last?.title, content: "", source: "user", level: 1); vm.noteBlocks.append(n); eid = n.id }
}

struct NoteRow: View {
    let note: NoteBlock; let editing: Bool; let onEdit: () -> Void; let onSave: (String) -> Void; let onDelete: () -> Void; let onIndent: () -> Void
    @State private var t = ""
    var pre: String { note.level == 0 ? "1." : note.level == 1 ? "·" : "○" }
    var padL: CGFloat { note.level == 0 ? 38 : note.level == 1 ? 42 : 56 }

    var body: some View {
        HStack(alignment: .top, spacing: 6) { Text(pre).font(.inter(size: note.level == 0 ? 12 : 14)).foregroundColor(Color(hex: "AAAAAA")).frame(width: 16).padding(.top, 1).padding(.leading, CGFloat(note.level * 12))
            if editing { TextField("", text: $t, onCommit: { onSave(t) }).textFieldStyle(.plain).font(.inter(size: 13)).onAppear { t = note.content } }
            else { Text(note.content.isEmpty ? " " : note.content).font(.inter(size: 13)).foregroundColor(note.content.isEmpty ? Color(hex: "C0C0C0") : Color(hex: "0A0A0A")).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle()).onTapGesture(count: 2) { onEdit() } }
            if note.source == "ai", !editing { Text("AI").font(.inter(size: 8, weight: .bold)).foregroundColor(Color(hex: "1A5FD4")).padding(.horizontal, 3).padding(.vertical, 1).background(Color(hex: "E8F0FE")).cornerRadius(3) }
        }.padding(.horizontal, 8).padding(.vertical, 4).background(editing ? Color(hex: "E8F0FE").opacity(0.3) : Color.clear).cornerRadius(4)
    }
}
