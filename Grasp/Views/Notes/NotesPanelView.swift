import AppKit
import SwiftUI
import UniformTypeIdentifiers

// Apple Notes-style editor: one continuous NSTextView inside one NSScrollView.
// The DB still stores flat note_blocks, but the user edits a single flowing document.
struct NotesPanelView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var focusRequest = 0
    @State private var commandRequest = NotesEditorCommandRequest()
    @State private var knownNoteIds = Set<String>()
    @State private var showAINewBorder = false

    var body: some View {
        VStack(spacing: 0) {
            header
            formattingToolbar

            ZStack(alignment: .topLeading) {
                NotesDocumentEditorView(
                    notes: vm.noteBlocks,
                    displayFontSize: vm.displayFontSize,
                    focusRequest: focusRequest,
                    commandRequest: commandRequest,
                    saveDocument: saveDocument
                )
                .overlay(Rectangle().fill(showAINewBorder ? Color.aiNewBorder : Color.clear).frame(width: 3), alignment: .leading)

                if vm.noteBlocks.isEmpty {
                    emptyState
                        .padding(.top, 72)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(false)
                }
            }
            .background(Color.warmCream)
        }
        .background(Color.appBackground)
        .onAppear {
            knownNoteIds = Set(vm.noteBlocks.map(\.id))
        }
        .onChange(of: vm.noteBlocks.map(\.id)) { _, ids in
            let currentIds = Set(ids)
            let insertedIds = currentIds.subtracting(knownNoteIds)
            let insertedAI = vm.noteBlocks.contains { insertedIds.contains($0.id) && $0.source == "ai" }
            if insertedAI {
                showAINewBorder = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    withAnimation(.easeInOut(duration: 0.8)) { showAINewBorder = false }
                }
            }
            knownNoteIds = currentIds
        }
        .onChange(of: vm.newNoteRequest) { _, _ in
            addNoteAndFocus()
        }
    }

    var header: some View {
        PanelHeaderView(title: "AI NOTES", status: vm.aiNotesStatus) {
            EmptyView()
        } settings: {
            AINotesSettingsPopover()
                .environmentObject(vm)
        }
    }

    var statusPillBackground: Color {
        switch vm.aiNotesStatus {
        case "Writing...", "Summarizing...":
            return .pastelPink
        case "Updated", "Summary added":
            return .pastelBlueStrong
        case "Duplicate skipped":
            return .pastelGreen
        default:
            return .warmCream
        }
    }

    var detailControl: some View {
        HStack(spacing: 8) {
            Text("Detail")
                .font(.inter(size: 10, weight: .semibold))
                .foregroundColor(.textTertiary)
            detailButton("concise", "Concise")
            detailButton("balanced", "Balanced")
            detailButton("detailed", "Detailed")
            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 5)
        .background(Color.warmCream)
        .overlay(Rectangle().fill(Color.divider).frame(height: 1), alignment: .bottom)
    }

    func detailButton(_ level: String, _ label: String) -> some View {
        let selected = vm.aiNoteDetailLevel == level
        let fill = detailFill(level, selected: selected)
        let border = detailBorder(level, selected: selected)
        return Button {
            vm.setAINoteDetailLevel(level)
        } label: {
            Text(label)
                .font(.inter(size: 11, weight: selected ? .semibold : .medium))
                .foregroundColor(selected ? .textPrimary : .textSecondary)
                .frame(minWidth: 62, minHeight: 24)
                .padding(.horizontal, 4)
                .background(fill)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help("AI Notes detail: \(label)")
    }

    func detailFill(_ level: String, selected: Bool) -> Color {
        guard selected else { return Color.hoverBg.opacity(0.82) }
        switch level {
        case "concise": return .pastelBlueStrong
        case "detailed": return .pastelPink
        default: return .pastelGreen
        }
    }

    func detailBorder(_ level: String, selected: Bool) -> Color {
        guard selected else { return .pillBorderGray }
        switch level {
        case "concise": return .lightBlueBorder
        case "detailed": return .pastelPinkBorder
        default: return .pastelGreenBorder
        }
    }

    var formattingToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    fontSizeOption("small", "Small")
                    fontSizeOption("medium", "Medium")
                    fontSizeOption("large", "Large")
                } label: {
                    Text("Aa")
                        .font(.inter(size: 12, weight: .bold))
                        .foregroundColor(.textPrimary)
                        .frame(width: 28, height: 26)
                        .background(Color.pastelGreen)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.pastelGreenBorder, lineWidth: 1))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Font size")

                toolbarButton("bold", "Bold") { send(.bold) }
                toolbarButton("italic", "Italic") { send(.italic) }
                toolbarButton("underline", "Underline") { send(.underline) }
                Divider().frame(height: 20)
                toolbarButton("1", "Numbered list") { send(.outline1) }
                toolbarButton("1.1", "Sub-numbered list") { send(.outline2) }
                toolbarButton("•", "Bullet list") { send(.outline3) }
                Divider().frame(height: 20)
                toolbarButton("tablecells", "Insert table") { send(.table) }
                toolbarButton("photo", "Insert image") { send(.image) }
                colorButton(.labelColor, "Black text") { send(.textBlack) }
                Divider().frame(height: 20)
                colorButton(.notesHighlightPurple, "Purple highlight") { send(.highlightPurple) }
                colorButton(.notesHighlightPink, "Pink highlight") { send(.highlightPink) }
                colorButton(.notesHighlightOrange, "Orange highlight") { send(.highlightOrange) }
                colorButton(.notesHighlightBlue, "Blue highlight") { send(.highlightBlue) }
            }
            .padding(.horizontal, Spacing.md)
        }
        .padding(.vertical, Spacing.xxs)
        .background(Color.warmCream)
        .overlay(Rectangle().fill(Color.divider).frame(height: 1), alignment: .bottom)
    }

    func fontSizeOption(_ size: String, _ label: String) -> some View {
        Button {
            vm.setDisplayFontSize(size)
        } label: {
            if vm.displayFontSize == size {
                Label(label, systemImage: "checkmark")
            } else {
                Text(label)
            }
        }
    }

    func toolbarButton(_ symbol: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if symbol.contains(".") || symbol == "1" || symbol == "•" {
                Text(symbol)
                    .font(.inter(size: 11, weight: .semibold))
                    .frame(width: 34, height: 24)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 28, height: 24)
            }
        }
        .foregroundColor(.textSecondary)
        .buttonStyle(.plain)
        .background(Color.hoverBg.opacity(0.9))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.pillBorderGray, lineWidth: 1))
        .help(help)
    }

    func colorButton(_ color: NSColor, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(Color(nsColor: color))
                .frame(width: 14, height: 14)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    func send(_ command: NotesEditorCommand) {
        commandRequest = NotesEditorCommandRequest(command: command)
    }

    var emptyState: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "note.text")
                .font(.system(size: 32))
                .foregroundColor(.accentBlue.opacity(0.55))
            Text("Click anywhere to start a note")
                .font(.inter(size: AppTypography.caption))
                .foregroundColor(.textTertiary)
        }
    }

    func addNoteAndFocus() {
        if let lid = vm.activeLectureId {
            let slideIdx = vm.slideStructure.last?.index ?? vm.noteBlocks.last?.slideIndex ?? 0
            let slideTitle = vm.slideStructure.last?.title ?? vm.noteBlocks.last?.slideTitle
            let note = vm.saveNoteBlockToDb(lectureId: lid, slideIndex: slideIdx, slideTitle: slideTitle, content: "", source: "user")
            vm.noteBlocks.append(note)
        }
        focusRequest += 1
    }

    func saveDocument(_ snapshot: NotesDocumentSnapshot) {
        guard let lid = vm.activeLectureId else { return }
        guard !snapshot.plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            for note in vm.noteBlocks { vm.deleteNote(id: note.id) }
            return
        }
        if let first = vm.noteBlocks.first {
            if first.content != snapshot.html {
                vm.updateNote(id: first.id, content: snapshot.html, level: 0)
                if let index = vm.noteBlocks.firstIndex(where: { $0.id == first.id }) {
                    vm.noteBlocks[index].content = snapshot.html
                    vm.noteBlocks[index].source = "user"
                }
            }
            for note in vm.noteBlocks.dropFirst() {
                vm.deleteNote(id: note.id)
            }
        } else {
            let note = vm.saveNoteBlockToDb(lectureId: lid, slideIndex: 0, slideTitle: nil, content: snapshot.html, source: "user")
            vm.noteBlocks.append(note)
        }
        vm.learnNoteStyle(from: snapshot.plainText)
    }
}

struct AINotesSettingsPopover: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Notes Settings")
                .font(.inter(size: 13, weight: .semibold))
                .foregroundColor(.textPrimary)

            VStack(alignment: .leading, spacing: 7) {
                Text("Detail")
                    .font(.inter(size: 11, weight: .semibold))
                    .foregroundColor(.textSecondary)
                HStack(spacing: 8) {
                    settingsDetailButton("concise", "Concise")
                    settingsDetailButton("balanced", "Balanced")
                    settingsDetailButton("detailed", "Detailed")
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("Note framework")
                    .font(.inter(size: 11, weight: .semibold))
                    .foregroundColor(.textSecondary)
                TextEditor(text: Binding(
                    get: { vm.aiNoteFramework },
                    set: { vm.setAINoteFramework($0) }
                ))
                .font(.inter(size: 12))
                .frame(height: 130)
                .scrollContentBackground(.hidden)
                .background(Color.warmCream)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.pillBorderGray, lineWidth: 1))
                Text("Example: Definition -> mechanism -> example -> exam cue. The AI will use this as your preferred note structure.")
                    .font(.inter(size: 11))
                    .foregroundColor(.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func settingsDetailButton(_ level: String, _ label: String) -> some View {
        let selected = vm.aiNoteDetailLevel == level
        let fill: Color
        let border: Color
        switch level {
        case "concise":
            fill = selected ? .pastelBlueStrong : Color.hoverBg
            border = selected ? .lightBlueBorder : .pillBorderGray
        case "detailed":
            fill = selected ? .pastelPink : Color.hoverBg
            border = selected ? .pastelPinkBorder : .pillBorderGray
        default:
            fill = selected ? .pastelGreen : Color.hoverBg
            border = selected ? .pastelGreenBorder : .pillBorderGray
        }
        return Button {
            vm.setAINoteDetailLevel(level)
        } label: {
            Text(label)
                .font(.inter(size: 11, weight: selected ? .semibold : .medium))
                .foregroundColor(selected ? .textPrimary : .textSecondary)
                .frame(maxWidth: .infinity, minHeight: 28)
                .background(fill)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

