import SwiftUI
import AppKit

// v1.1-r2: Apple Notes-style flat rich-text editor
// No tree, no bullets, no indentation, no concept map.
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
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(vm.noteBlocks) { note in
                                NoteRichEditor(
                                    note: note,
                                    isEditing: editingId == note.id,
                                    isNew: newNoteIds.contains(note.id),
                                    onBeginEdit: { beginEdit(note) },
                                    onCreateNewAfter: { commitAndCreateBelow(note) },
                                    onSave: { content in saveNote(note, content) },
                                    onDeleteEmpty: { deleteNote(note) }
                                )
                                .id(note.id)
                                .transition(.opacity.combined(with: .offset(y: 5)))
                            }
                            Color.clear.frame(height: 80).id("notes-bot")
                        }
                    }
                    .onChange(of: vm.noteBlocks.count) { count in
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
        .contentShape(Rectangle())
        .onTapGesture { commitEdit() }
    }

    // MARK: - Header

    var header: some View {
        HStack {
            Text("AI NOTES")
                .font(.inter(size: AppTypography.caption, weight: .semibold))
                .foregroundColor(.textSecondary)
                .tracking(0.5)
            Spacer()
            Text("\(vm.noteBlocks.count)")
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

    func beginEdit(_ note: NoteBlock) {
        if editingId == note.id { return }
        commitEdit()
        editingId = note.id
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
        editingId = n.id
    }

    func addNoteBelow(_ note: NoteBlock) {
        guard let lid = vm.activeLectureId else {
            // If no active lecture, still allow adding a note
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

// MARK: - NoteRichEditor — NSTextView-based editable note

struct NoteRichEditor: View {
    let note: NoteBlock
    let isEditing: Bool
    let isNew: Bool
    let onBeginEdit: () -> Void
    let onCreateNewAfter: () -> Void
    let onSave: (String) -> Void
    let onDeleteEmpty: () -> Void

    @State private var hovered = false
    @State private var showBlueBorder = false
    @State private var editingContent: String = ""

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Blue left border for new AI notes
            Rectangle()
                .fill(isNew && showBlueBorder ? Color.aiNewBorder : Color.clear)
                .frame(width: 3)
                .padding(.trailing, Spacing.xxs)

            // Content area
            VStack(alignment: .leading, spacing: 0) {
                if isEditing {
                    NSTextFieldRepresentable(
                        text: $editingContent,
                        noteId: note.id,
                        isNew: note.content.isEmpty,
                        onBlur: {
                            // Save content on blur
                            let trimmed = editingContent.trimmingCharacters(in: .whitespacesAndNewlines)
                            if trimmed.isEmpty && note.source == "user" {
                                onDeleteEmpty()
                            } else {
                                onSave(editingContent)
                            }
                        },
                        onEnter: {
                            // Enter key pressed: save current, create new below
                            onSave(editingContent)
                            onCreateNewAfter()
                        },
                        onDeleteEmpty: {
                            onDeleteEmpty()
                        }
                    )
                    .frame(minHeight: 20)
                } else {
                    // Display mode
                    if note.content.isEmpty {
                        Text("Click to edit…")
                            .font(.inter(size: AppTypography.body))
                            .foregroundColor(.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, Spacing.xxs)
                    } else {
                        AttributedTextDisplay(html: note.content)
                            .padding(.vertical, Spacing.xxs)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Delete button on hover
            if hovered && !isEditing {
                Button(action: onDeleteEmpty) {
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
        .contentShape(Rectangle())
        .onTapGesture { if !isEditing { onBeginEdit() } }
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.15)) {
                hovered = h
            }
        }
        .onAppear {
            if isNew {
                showBlueBorder = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    withAnimation(.easeInOut(duration: 1.0)) {
                        showBlueBorder = false
                    }
                }
            }
        }
        .onChange(of: isEditing) { _, editing in
            if editing {
                editingContent = note.content
            }
        }
    }
}

// MARK: - NSTextFieldRepresentable — wraps NSTextView for rich text editing

struct NSTextFieldRepresentable: NSViewRepresentable {
    @Binding var text: String
    let noteId: String
    let isNew: Bool
    let onBlur: () -> Void
    let onEnter: () -> Void
    let onDeleteEmpty: () -> Void

    func makeNSView(context: Context) -> NSTextView {
        let tv = NSTextView()
        tv.isEditable = true
        tv.isSelectable = true
        tv.isRichText = true
        tv.font = NSFont(name: "Inter", size: 13)
        tv.textColor = .controlTextColor
        tv.drawsBackground = false
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.lineFragmentPadding = 0
        tv.allowsUndo = true

        // Set initial text content
        if !text.isEmpty {
            if let data = text.data(using: .utf8),
               let attrStr = try? NSAttributedString(data: data,
                    options: [.documentType: NSAttributedString.DocumentType.html],
                    documentAttributes: nil) {
                tv.textStorage?.setAttributedString(attrStr)
            } else {
                tv.string = text
            }
        }

        tv.delegate = context.coordinator
        context.coordinator.textView = tv
        context.coordinator.onBlur = onBlur
        context.coordinator.onEnter = onEnter
        context.coordinator.onDeleteEmpty = onDeleteEmpty
        context.coordinator.textBinding = $text

        tv.allowsImageEditing = false
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isContinuousSpellCheckingEnabled = false

        // Focus
        DispatchQueue.main.async {
            tv.window?.makeFirstResponder(tv)
        }

        return tv
    }

    func updateNSView(_ nsView: NSTextView, context: Context) {
        // On creation, content is already set
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        weak var textView: NSTextView?
        var onBlur: (() -> Void)?
        var onEnter: (() -> Void)?
        var onDeleteEmpty: (() -> Void)?
        var textBinding: Binding<String>?

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                // Check for Shift+Return
                if let event = NSApp.currentEvent, event.modifierFlags.contains(.shift) {
                    return false  // line break
                }
                // Enter key — create new note below
                onEnter?()
                return true
            }
            if commandSelector == #selector(NSResponder.deleteBackward(_:)) {
                if textView.string.isEmpty {
                    onDeleteEmpty?()
                    return true
                }
            }
            return false
        }

        func textDidEndEditing(_ notification: Notification) {
            // Capture the text content as HTML
            guard let tv = textView else { return }
            if let attrStr = tv.textStorage, attrStr.length > 0 {
                let range = NSRange(location: 0, length: attrStr.length)
                if let htmlData = try? attrStr.data(from: range,
                    documentAttributes: [.documentType: NSAttributedString.DocumentType.html]) {
                    let html = String(data: htmlData, encoding: .utf8) ?? tv.string
                    textBinding?.wrappedValue = html
                } else {
                    textBinding?.wrappedValue = tv.string
                }
            } else {
                textBinding?.wrappedValue = tv.string
            }
            onBlur?()
        }
    }
}

// MARK: - HTML Attributed String Display

struct AttributedTextDisplay: View {
    let html: String

    var body: some View {
        if let data = html.data(using: .utf8),
           let attrStr = try? NSAttributedString(data: data,
                options: [.documentType: NSAttributedString.DocumentType.html],
                documentAttributes: nil) {
            Text(AttributedString(attrStr))
                .font(.inter(size: AppTypography.body))
                .foregroundColor(.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(html)
                .font(.inter(size: AppTypography.body))
                .foregroundColor(.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
