import SwiftUI

struct NotesPanelView: View {
    @EnvironmentObject var vm: AppViewModel
    // Single source of truth for which note is being edited
    @State private var editingId: String? = nil
    @State private var editText = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            if vm.noteBlocks.isEmpty && vm.slideStructure.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if vm.slideStructure.isEmpty {
                            ForEach(vm.noteBlocks) { n in rowFor(n) }
                        } else {
                            ForEach(vm.slideStructure, id: \.index) { slide in
                                slideSection(slide)
                            }
                        }
                        Color.clear.frame(height: 80)
                    }
                }
            }
        }
        .background(Color.white)
        // Save when tapping outside any note (clicking the scroll area)
        .contentShape(Rectangle())
        .onTapGesture { commitEdit() }
    }

    // MARK: - Header

    var header: some View {
        HStack {
            Text("NOTES").font(.inter(size: 11, weight: .semibold)).foregroundColor(Color(hex: "5A5A5A"))
            Spacer()
            Text("\(vm.noteBlocks.count)").font(.inter(size: 10)).foregroundColor(Color(hex: "C0C0C0"))
            Button(action: addNote) {
                Image(systemName: "plus").font(.system(size: 12)).foregroundColor(Color(hex: "5A5A5A"))
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color(hex: "F8F8F8"))
        .overlay(Rectangle().fill(Color(hex: "E8E8E8")).frame(height: 1), alignment: .bottom)
    }

    var emptyState: some View {
        Text("AI notes will appear here…")
            .font(.inter(size: 12)).foregroundColor(Color(hex: "C0C0C0"))
            .frame(maxWidth: .infinity, maxHeight: .infinity).padding(.top, 20)
    }

    // MARK: - Slide section (skeleton)

    func slideSection(_ slide: SlideItem) -> some View {
        let notes = vm.noteBlocks.filter { $0.slideIndex == slide.index }
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text(slide.title.uppercased())
                    .font(.inter(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: "C0C0C0"))
                    .tracking(0.3)
                Spacer()
                Button(action: { addNoteToSlide(slide) }) {
                    Image(systemName: "plus").font(.system(size: 10)).foregroundColor(Color(hex: "CCCCCC"))
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 4)

            if notes.isEmpty {
                Text("Waiting for lecture…")
                    .font(.inter(size: 12)).foregroundColor(Color(hex: "E0E0E0"))
                    .padding(.horizontal, 18).padding(.vertical, 4)
            } else {
                ForEach(notes) { n in rowFor(n) }
            }
        }
    }

    // MARK: - Note row factory

    func rowFor(_ note: NoteBlock) -> some View {
        NoteRow(
            note: note,
            isEditing: editingId == note.id,
            editText: editingId == note.id ? $editText : .constant(note.content),
            onBeginEdit: { beginEdit(note) },
            onCommit: { commitEdit(); addNoteBelow(note) },
            onBlur: { commitEdit() },
            onDelete: { vm.deleteNote(id: note.id); if editingId == note.id { editingId = nil } },
            onIndent: { vm.updateNote(id: note.id, content: note.content, level: max(0, min(2, note.level + 1))) }
        )
    }

    // MARK: - Edit state management

    func beginEdit(_ note: NoteBlock) {
        if editingId == note.id { return }
        commitEdit()
        editingId = note.id
        editText = note.content
    }

    func commitEdit() {
        guard let id = editingId else { return }
        let trimmed = editText.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            // Delete empty notes created by user but not filled in
            if let n = vm.noteBlocks.first(where: { $0.id == id }), n.source == "user" {
                vm.deleteNote(id: id)
            }
        } else {
            vm.updateNote(id: id, content: trimmed, level: nil)
            if let i = vm.noteBlocks.firstIndex(where: { $0.id == id }) {
                vm.noteBlocks[i].content = trimmed
            }
        }
        editingId = nil
    }

    // MARK: - Add helpers

    func addNote() {
        guard let lid = vm.activeLectureId else { return }
        commitEdit()
        let slideIdx = vm.slideStructure.last?.index ?? vm.noteBlocks.last?.slideIndex ?? 0
        let slideTitle = vm.slideStructure.last?.title ?? vm.noteBlocks.last?.slideTitle
        let n = DatabaseService.shared.saveNoteBlock(lectureId: lid, slideIndex: slideIdx, slideTitle: slideTitle, content: "", source: "user", level: 1)
        vm.noteBlocks.append(n)
        editingId = n.id; editText = ""
    }

    func addNoteToSlide(_ slide: SlideItem) {
        guard let lid = vm.activeLectureId else { return }
        commitEdit()
        let n = DatabaseService.shared.saveNoteBlock(lectureId: lid, slideIndex: slide.index, slideTitle: slide.title, content: "", source: "user", level: 1)
        vm.noteBlocks.append(n)
        editingId = n.id; editText = ""
    }

    func addNoteBelow(_ note: NoteBlock) {
        guard let lid = vm.activeLectureId else { return }
        let n = DatabaseService.shared.saveNoteBlock(lectureId: lid, slideIndex: note.slideIndex, slideTitle: note.slideTitle, content: "", source: "user", level: note.level)
        if let idx = vm.noteBlocks.firstIndex(where: { $0.id == note.id }) {
            vm.noteBlocks.insert(n, at: idx + 1)
        } else { vm.noteBlocks.append(n) }
        editingId = n.id; editText = ""
    }
}

// MARK: - NoteRow

struct NoteRow: View {
    let note: NoteBlock
    let isEditing: Bool
    @Binding var editText: String
    let onBeginEdit: () -> Void
    let onCommit: () -> Void     // Enter key → save + new note below
    let onBlur: () -> Void       // focus lost → save
    let onDelete: () -> Void
    let onIndent: () -> Void

    @State private var hovered = false
    @FocusState private var focused: Bool

    var bullet: String { note.level == 0 ? "▸" : note.level == 1 ? "•" : "◦" }
    var indent: CGFloat { CGFloat(note.level) * 14 }
    var bulletColor: Color { Color(hex: note.level == 0 ? "9A9A9A" : "CCCCCC") }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Indent spacer
            Spacer().frame(width: 14 + indent)

            // Bullet
            Text(bullet)
                .font(.inter(size: note.level == 0 ? 11 : 13))
                .foregroundColor(bulletColor)
                .frame(width: 14)
                .padding(.top, 3)

            // Content — TextField always present when editing, Text otherwise
            if isEditing {
                TextField("", text: $editText)
                    .textFieldStyle(.plain)
                    .font(.inter(size: 13))
                    .foregroundColor(Color(hex: "0A0A0A"))
                    .focused($focused)
                    .onAppear { focused = true }
                    .onSubmit { onCommit() }
                    .onChange(of: focused) { _, f in if !f { onBlur() } }
                    .padding(.vertical, 3)
                    .frame(maxWidth: .infinity)
            } else {
                Text(note.content.isEmpty ? "Click to edit…" : note.content)
                    .font(.inter(size: 13))
                    .foregroundColor(note.content.isEmpty ? Color(hex: "DDDDDD") : Color(hex: "0A0A0A"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
                    .onTapGesture { onBeginEdit() }
            }

            // Right side decorations
            HStack(spacing: 4) {
                if note.source == "ai" && !isEditing {
                    Text("AI")
                        .font(.inter(size: 8, weight: .bold)).foregroundColor(Color(hex: "1A5FD4"))
                        .padding(.horizontal, 3).padding(.vertical, 1)
                        .background(Color(hex: "E8F0FE")).cornerRadius(3)
                }
                if hovered && !isEditing {
                    Button(action: onDelete) {
                        Image(systemName: "xmark").font(.system(size: 9)).foregroundColor(Color(hex: "AAAAAA"))
                    }.buttonStyle(.plain)
                }
            }.frame(minWidth: 20)
        }
        .padding(.horizontal, 8).padding(.vertical, 2)
        .background(isEditing ? Color(hex: "EEF3FF").opacity(0.5) : hovered ? Color(hex: "F8F8F8") : Color.clear)
        .cornerRadius(4)
        .onHover { hovered = $0 }
        .contextMenu {
            Button("Delete", action: onDelete)
            Button(note.level < 2 ? "Indent →" : "Outdent ←", action: onIndent)
        }
    }
}
