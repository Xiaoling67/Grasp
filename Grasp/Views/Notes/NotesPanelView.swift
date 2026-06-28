import SwiftUI
import AppKit

// v1.1-r2: Apple Notes-style flat rich-text editor
// No tree, no bullets, no indentation, no concept map.
// NSTextView is always present — click to edit, double-click to select word.
// No container onTapGesture that would intercept NSTextView clicks.
struct NotesPanelView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var editingId: String? = nil
    @State private var newNoteIds = Set<String>()  // for blue-border animation

    var body: some View {
        VStack(spacing: 0) {
            header

            if vm.noteBlocks.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { addNote() }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(vm.noteBlocks) { note in
                                NoteRow(
                                    note: note,
                                    isEditing: bindingIsEditing(note.id),
                                    isNew: newNoteIds.contains(note.id),
                                    beginEdit: { beginEdit(note) },
                                    createNewBelow: { commitAndCreateBelow(note) },
                                    save: { content in saveNote(note, content) },
                                    deleteEmpty: { deleteNote(note) }
                                )
                                .id(note.id)
                                .transition(.opacity.combined(with: .offset(y: 5)))
                            }
                            // Empty area tap: create new note at bottom
                            Color.clear
                                .frame(height: 120)
                                .contentShape(Rectangle())
                                .onTapGesture { addNote() }
                            Color.clear.frame(height: 80).id("notes-bot")
                        }
                    }
                    .onChange(of: vm.noteBlocks.count) { _, count in
                        if count > 0, let last = vm.noteBlocks.last {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .background(Color.surfacePrimary)
        // NO onTapGesture on the container — it would intercept NSTextView clicks
    }

    // MARK: - Header

    var header: some View {
        HStack {
            Text("AI NOTES")
                .font(.inter(size: AppTypography.caption, weight: .semibold))
                .foregroundColor(.textSecondary)
                .tracking(0.5)
            Spacer()
            Text("\\(vm.noteBlocks.count)")
                .font(.inter(size: AppTypography.small))
                .foregroundColor(.textTertiary)
            Button(action: addNote) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSecondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("New note (⌘N)")
        }
        .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.xs)
        .background(Color.surfaceSecondary)
        .overlay(Rectangle().fill(Color.divider).frame(height: 1), alignment: .bottom)
    }

    var emptyState: some View {
        VStack(spacing: Spacing.sm) {
            Spacer()
            Image(systemName: "note.text")
                .font(.system(size: 32))
                .foregroundColor(.textTertiary)
            Text("AI notes will appear here…")
                .font(.inter(size: AppTypography.caption))
                .foregroundColor(.textTertiary)
            Spacer()
        }
    }

    // MARK: - Edit state management

    private func bindingIsEditing(_ id: String) -> Binding<Bool> {
        Binding(get: { editingId == id }, set: { if $0 { editingId = id } else { editingId = nil } })
    }

    func beginEdit(_ note: NoteBlock) {
        if editingId == note.id { return }
        commitEdit()
        editingId = note.id  // set synchronously, no DispatchQueue.main.asyncAfter
        newNoteIds.remove(note.id)
    }

    func commitEdit() {
        editingId = nil
    }

    func commitAndCreateBelow(_ note: NoteBlock) {
        commitEdit()
        addNoteBelow(note)
    }

    func deleteNote(_ note: NoteBlock) {
        withAnimation(.easeInOut(duration: 0.2)) {
            vm.deleteNote(id: note.id)
        }
        if editingId == note.id { editingId = nil }
        newNoteIds.remove(note.id)
    }

    func saveNote(_ note: NoteBlock, _ content: String) {
        vm.updateNote(id: note.id, content: content, level: nil)
        if let idx = vm.noteBlocks.firstIndex(where: { $0.id == note.id }) {
            vm.noteBlocks[idx].content = content
        }
    }

    // MARK: - Add helpers

    func addNote() {
        guard let lid = vm.activeLectureId else { return }
        commitEdit()
        let slideIdx = vm.slideStructure.last?.index ?? vm.noteBlocks.last?.slideIndex ?? 0
        let slideTitle = vm.slideStructure.last?.title ?? vm.noteBlocks.last?.slideTitle
        let n = vm.saveNoteBlockToDb(lectureId: lid, slideIndex: slideIdx, slideTitle: slideTitle, content: "", source: "user")
        vm.noteBlocks.append(n)
        editingId = n.id  // synchronous — next view update makes NSTextView first responder
    }

    func addNoteBelow(_ note: NoteBlock) {
        guard let lid = vm.activeLectureId else {
            let n = vm.saveNoteBlockToDb(lectureId: "local", slideIndex: 0, slideTitle: nil, content: "", source: "user")
            if let idx = vm.noteBlocks.firstIndex(where: { $0.id == note.id }) {
                vm.noteBlocks.insert(n, at: idx + 1)
            } else {
                vm.noteBlocks.append(n)
            }
            editingId = n.id
            return
        }
        let n = vm.saveNoteBlockToDb(lectureId: lid, slideIndex: note.slideIndex, slideTitle: note.slideTitle, content: "", source: "user")
        if let idx = vm.noteBlocks.firstIndex(where: { $0.id == note.id }) {
            vm.noteBlocks.insert(n, at: idx + 1)
        } else {
            vm.noteBlocks.append(n)
        }
        editingId = n.id
    }
}

// MARK: - NoteRow — SwiftUI wrapper with blue border + hover delete

struct NoteRow: View {
    let note: NoteBlock
    @Binding var isEditing: Bool
    let isNew: Bool
    let beginEdit: () -> Void
    let createNewBelow: () -> Void
    let save: (String) -> Void
    let deleteEmpty: () -> Void

    @State private var hovered = false
    @State private var showBlueBorder = false

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Blue left border for new AI notes
            Rectangle()
                .fill(isNew && showBlueBorder ? Color.aiNewBorder : Color.clear)
                .frame(width: 3)
                .padding(.trailing, Spacing.xxs)

            // NSTextView — always present, handles clicks natively
            NoteRichEditorView(
                note: note,
                isEditing: $isEditing,
                beginEdit: beginEdit,
                createNewBelow: createNewBelow,
                save: save,
                deleteEmpty: deleteEmpty
            )

            // Delete button on hover
            if hovered && !isEditing {
                Button(action: deleteEmpty) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.textTertiary)
                }
                .buttonStyle(.plain)
                .padding(.leading, Spacing.xxs)
                .padding(.top, Spacing.xxs)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(isEditing ? Color.selectionBg.opacity(0.3) : hovered ? Color.hoverBg.opacity(0.5) : Color.clear)
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.15)) { hovered = h }
        }
        .onAppear {
            if isNew {
                showBlueBorder = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    withAnimation(.easeInOut(duration: 1.0)) { showBlueBorder = false }
                }
            }
        }
    }
}

// MARK: - NoteRichEditorView — NSViewRepresentable wrapping NSTextView

struct NoteRichEditorView: NSViewRepresentable {
    let note: NoteBlock
    @Binding var isEditing: Bool
    let beginEdit: () -> Void
    let createNewBelow: () -> Void
    let save: (String) -> Void
    let deleteEmpty: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NoteTextView {
        let tv = NoteTextView()
        tv.isEditable = false       // start in viewing mode; mouseDown enables
        tv.isSelectable = false
        tv.isRichText = true
        tv.font = NSFont(name: "Inter", size: 13)
        tv.textColor = NSColor.labelColor
        tv.drawsBackground = false
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.lineFragmentPadding = 0
        tv.allowsUndo = true
        tv.allowsImageEditing = false
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isContinuousSpellCheckingEnabled = false

        // Set initial content
        if !note.content.isEmpty {
            if let data = note.content.data(using: .utf8),
               let attrStr = try? NSAttributedString(data: data,
                    options: [.documentType: NSAttributedString.DocumentType.html],
                    documentAttributes: nil) {
                tv.textStorage?.setAttributedString(attrStr)
            } else {
                tv.string = note.content
            }
        }

        tv.delegate = context.coordinator
        context.coordinator.textView = tv
        context.coordinator.beginEdit = beginEdit
        context.coordinator.createNewBelow = createNewBelow
        context.coordinator.save = save
        context.coordinator.deleteEmpty = deleteEmpty
        context.coordinator.isEditingBinding = $isEditing
        context.coordinator.onSingleClick = beginEdit
        tv.singleClickHandler = { [weak coordinator = context.coordinator] in
            coordinator?.beginEdit?()
        }

        return tv
    }

    func updateNSView(_ tv: NoteTextView, context: Context) {
        context.coordinator.beginEdit = beginEdit
        context.coordinator.createNewBelow = createNewBelow
        context.coordinator.save = save
        context.coordinator.deleteEmpty = deleteEmpty
        context.coordinator.isEditingBinding = $isEditing

        if isEditing {
            if !tv.isEditable {
                tv.isEditable = true
                tv.isSelectable = true
            }
            if let window = tv.window, window.firstResponder !== tv {
                DispatchQueue.main.async {
                    window.makeFirstResponder(tv)
                }
            }
        } else {
            tv.isEditable = false
            tv.isSelectable = false
            tv.window?.makeFirstResponder(nil)
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        weak var textView: NoteTextView?
        var beginEdit: (() -> Void)?
        var createNewBelow: (() -> Void)?
        var save: ((String) -> Void)?
        var deleteEmpty: (() -> Void)?
        var isEditingBinding: Binding<Bool>?
        var onSingleClick: (() -> Void)?

        // MARK: - Enter and Delete key handling

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if let event = NSApp.currentEvent, event.modifierFlags.contains(.shift) {
                    return false  // Shift+Return → line break within note
                }
                // Enter → save current, create new note below
                saveContent(textView)
                createNewBelow?()
                return true
            }
            if commandSelector == #selector(NSResponder.deleteBackward(_:)) {
                if textView.string.isEmpty {
                    deleteEmpty?()
                    return true
                }
            }
            return false
        }

        // MARK: - Focus events

        func textDidBeginEditing(_ notification: Notification) {
            // Fired when NSTextView becomes first responder
            isEditingBinding?.wrappedValue = true
        }

        func textDidEndEditing(_ notification: Notification) {
            saveContent(notification.object as? NSTextView ?? textView)
            isEditingBinding?.wrappedValue = false
        }

        // MARK: - Helpers

        private func saveContent(_ tv: NSTextView?) {
            guard let tv = tv ?? textView else { return }
            let html: String
            if let attrStr = tv.textStorage, attrStr.length > 0 {
                let range = NSRange(location: 0, length: attrStr.length)
                if let htmlData = try? attrStr.data(from: range,
                    documentAttributes: [.documentType: NSAttributedString.DocumentType.html]) {
                    html = String(data: htmlData, encoding: .utf8) ?? tv.string
                } else {
                    html = tv.string
                }
            } else {
                html = tv.string
            }
            save?(html)
        }
    }
}

// MARK: - NoteTextView — custom NSTextView for click handling

class NoteTextView: NSTextView {
    var singleClickHandler: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        if event.clickCount >= 2 {
            // Double-click: enable editing (word selection is native NSTextView behavior)
            if !isEditable {
                isEditable = true
                isSelectable = true
            }
            window?.makeFirstResponder(self)
            super.mouseDown(with: event)
            return
        }

        // Single click: enable editing and become first responder
        if !isEditable {
            singleClickHandler?()
            isEditable = true
            isSelectable = true
        }
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }
}
