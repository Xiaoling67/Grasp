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

struct NotesDocumentSnapshot {
    let html: String
    let plainText: String
}

enum NotesEditorCommand {
    case bold, italic, underline
    case outline1, outline2, outline3
    case table, image
    case textBlack, highlightPurple, highlightPink, highlightOrange, highlightBlue
}

struct NotesEditorCommandRequest: Equatable {
    let id = UUID()
    var command: NotesEditorCommand?
}

struct NotesDocumentEditorView: NSViewRepresentable {
    let notes: [NoteBlock]
    let displayFontSize: String
    let focusRequest: Int
    let commandRequest: NotesEditorCommandRequest
    let saveDocument: (NotesDocumentSnapshot) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(saveDocument: saveDocument)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .white
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = NotesTextView()
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 40, height: 28)
        textView.textContainer?.lineFragmentPadding = 0
        textView.drawsBackground = true
        textView.backgroundColor = .white
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = true
        textView.importsGraphics = true
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.font = NotesDocumentFormatter.bodyFont(for: displayFontSize)
        textView.textColor = .labelColor
        textView.typingAttributes = [
            .font: NotesDocumentFormatter.bodyFont(for: displayFontSize),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: NotesDocumentFormatter.paragraphStyle
        ]
        textView.delegate = context.coordinator

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.displayFontSize = displayFontSize
        context.coordinator.render(notes: notes, force: true)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.saveDocument = saveDocument
        context.coordinator.displayFontSize = displayFontSize
        context.coordinator.render(notes: notes, force: false)

        guard let textView = context.coordinator.textView else { return }
        if focusRequest != context.coordinator.lastFocusRequest {
            context.coordinator.lastFocusRequest = focusRequest
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
                textView.moveToEndOfDocument(nil)
            }
        }
        if commandRequest.id != context.coordinator.lastCommandRequest {
            context.coordinator.lastCommandRequest = commandRequest.id
            if let command = commandRequest.command {
                context.coordinator.apply(command)
            }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        weak var textView: NSTextView?
        var saveDocument: (NotesDocumentSnapshot) -> Void
        var lastRenderedIds = [String]()
        var lastRenderedText = ""
        var lastRenderedDisplayFontSize = ""
        var displayFontSize = "medium"
        var lastFocusRequest = 0
        var lastCommandRequest = UUID()
        // Depth counter, not a bool: back-to-back AI note writes (e.g. draining a merged
        // backlog) can overlap before the first write's deferred clear runs. A bool would let
        // the first write's clear close the guard while the second write's deferred
        // notification is still in flight.
        private var renderingDepth = 0
        private var isRendering: Bool { renderingDepth > 0 }

        init(saveDocument: @escaping (NotesDocumentSnapshot) -> Void) {
            self.saveDocument = saveDocument
        }

        func render(notes: [NoteBlock], force: Bool) {
            guard let textView else { return }
            let ids = notes.map(\.id)
            let text = NotesDocumentFormatter.documentText(from: notes)
            let fontSizeChanged = displayFontSize != lastRenderedDisplayFontSize

            guard force || fontSizeChanged || ids != lastRenderedIds || text != lastRenderedText else { return }

            // Whether to patch in-place vs. fully rebuild must be decided from the data alone,
            // not from focus state — first-responder tracking here proved unreliable and was
            // the real cause behind notes silently failing to appear until something else (e.g.
            // stopping the lecture) forced a full rebuild. A pure append (existing ids
            // untouched, new ones added at the end) is always safe to patch in-place; anything
            // else (edits, deletions, reordering, font size change) gets a full, deterministic
            // rebuild.
            let isPureAppend = !force && !fontSizeChanged && ids.starts(with: lastRenderedIds) && ids.count > lastRenderedIds.count
            if isPureAppend {
                appendInsertedNotes(notes: notes, ids: ids)
                return
            }

            beginRendering()
            textView.textStorage?.setAttributedString(NotesDocumentFormatter.attributedDocument(from: notes, displayFontSize: displayFontSize))
            textView.font = NotesDocumentFormatter.bodyFont(for: displayFontSize)
            textView.typingAttributes[.font] = NotesDocumentFormatter.bodyFont(for: displayFontSize)
            endRenderingNextTick()
            lastRenderedIds = ids
            lastRenderedText = text
            lastRenderedDisplayFontSize = displayFontSize
        }

        // NSTextView can post its "did change" notification on a later runloop turn than the
        // programmatic edit that caused it (large replacements trigger a layout pass first).
        // Clearing the guard synchronously left a window where that deferred notification
        // arrived after the flag was already false, so our own AI-driven writes were
        // misread as a user edit — which fed into saveDocument() and could quietly wipe out
        // notes the user never touched. Deferring the clear to the next tick closes that gap;
        // the depth counter makes it safe even when two writes overlap.
        private func beginRendering() { renderingDepth += 1 }
        private func endRenderingNextTick() {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.renderingDepth = max(0, self.renderingDepth - 1)
            }
        }

        private func appendInsertedNotes(notes: [NoteBlock], ids: [String]) {
            guard let textView else { return }
            let inserted = notes.filter { !lastRenderedIds.contains($0.id) }
            guard !inserted.isEmpty else { return }

            let desiredParagraphs = NotesDocumentFormatter.paragraphs(from: NotesDocumentFormatter.documentText(from: notes))
            if NotesDocumentFormatter.paragraphs(from: textView.string) == desiredParagraphs {
                lastRenderedIds = ids
                lastRenderedText = NotesDocumentFormatter.documentText(from: notes)
                return
            }

            let appendText = inserted.map(\.displayText).joined(separator: "\n\n")
            guard !appendText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                lastRenderedIds = ids
                lastRenderedText = NotesDocumentFormatter.documentText(from: notes)
                return
            }

            // Only auto-follow if the reader was already at (or near) the bottom — otherwise a
            // new note would yank them away while they're reading back through older ones,
            // same reasoning as the transcript panel's freeze-on-hover.
            let shouldAutoScroll = textView.enclosingScrollView.map(isNearBottom) ?? true

            let prefix = textView.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : "\n\n"
            let attributed = NotesDocumentFormatter.attributedString(prefix + appendText, displayFontSize: displayFontSize)
            beginRendering()
            textView.textStorage?.append(attributed)
            endRenderingNextTick()
            lastRenderedIds = ids
            lastRenderedText = NotesDocumentFormatter.documentText(from: notes)
            lastRenderedDisplayFontSize = displayFontSize

            if shouldAutoScroll {
                DispatchQueue.main.async { [weak textView] in
                    guard let textView else { return }
                    textView.scrollRangeToVisible(NSRange(location: (textView.string as NSString).length, length: 0))
                }
            }
        }

        private func isNearBottom(_ scrollView: NSScrollView) -> Bool {
            guard let documentView = scrollView.documentView else { return true }
            let visibleMaxY = scrollView.contentView.bounds.maxY
            let remaining = documentView.bounds.height - visibleMaxY
            return remaining < 80
        }

        func textDidChange(_ notification: Notification) {
            guard !isRendering, let textView = notification.object as? NSTextView else { return }
            saveDocument(NotesDocumentFormatter.snapshot(from: textView))
        }

        func apply(_ command: NotesEditorCommand) {
            guard let textView else { return }
            textView.window?.makeFirstResponder(textView)
            switch command {
            case .bold:
                toggleFontTrait(.boldFontMask)
            case .italic:
                toggleItalic()
            case .underline:
                toggleUnderline()
            case .outline1:
                insertListMarker(level: 1)
            case .outline2:
                insertListMarker(level: 2)
            case .outline3:
                insertListMarker(level: 3)
            case .table:
                insert("\n| Topic | Detail | Example |\n| --- | --- | --- |\n|  |  |  |\n")
            case .image:
                insertImage()
            case .textBlack:
                applyForeground(.labelColor)
            case .highlightPurple:
                applyBackground(NSColor.notesHighlightPurple.withAlphaComponent(0.22))
            case .highlightPink:
                applyBackground(NSColor.notesHighlightPink.withAlphaComponent(0.18))
            case .highlightOrange:
                applyBackground(NSColor.notesHighlightOrange.withAlphaComponent(0.20))
            case .highlightBlue:
                applyBackground(NSColor.notesHighlightBlue.withAlphaComponent(0.18))
            }
            textDidChange(Notification(name: NSText.didChangeNotification, object: textView))
        }

        private func insert(_ string: String) {
            guard let textView else { return }
            textView.insertText(string, replacementRange: textView.selectedRange())
        }

        private func insertListMarker(level: Int) {
            guard let textView else { return }
            let range = textView.selectedRange()
            let marker: String
            switch level {
            case 1:
                marker = "\(nextNumberedListIndex(before: range.location)). "
            case 2:
                marker = "\(nextSubnumberedListIndex(before: range.location)) "
            default:
                marker = "• "
            }
            let needsNewline = range.location > 0
                && (textView.string as NSString).substring(with: NSRange(location: range.location - 1, length: 1)) != "\n"
            insert((needsNewline ? "\n" : "") + marker)
        }

        private func nextNumberedListIndex(before location: Int) -> Int {
            guard let textView else { return 1 }
            let safeLocation = max(0, min(location, (textView.string as NSString).length))
            let preceding = (textView.string as NSString).substring(to: safeLocation)
            let count = preceding
                .components(separatedBy: .newlines)
                .filter { line in
                    line.trimmingCharacters(in: .whitespaces)
                        .range(of: #"^\d+\.\s"#, options: .regularExpression) != nil
                }
                .count
            return count + 1
        }

        private func nextSubnumberedListIndex(before location: Int) -> String {
            guard let textView else { return "1.1" }
            let safeLocation = max(0, min(location, (textView.string as NSString).length))
            let lines = (textView.string as NSString)
                .substring(to: safeLocation)
                .components(separatedBy: .newlines)

            var parent = 1
            var childCount = 0
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if let match = trimmed.range(of: #"^(\d+)\.\s"#, options: .regularExpression) {
                    let marker = trimmed[match].prefix { $0.isNumber }
                    parent = Int(marker) ?? parent
                    childCount = 0
                } else if trimmed.range(of: #"^\d+\.\d+\s"#, options: .regularExpression) != nil {
                    childCount += 1
                }
            }
            return "\(parent).\(childCount + 1)"
        }

        private func insertImage() {
            guard let textView else { return }
            let panel = NSOpenPanel()
            panel.allowedContentTypes = [.image]
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.begin { [weak self, weak textView] response in
                guard response == .OK,
                      let url = panel.url,
                      let image = NSImage(contentsOf: url),
                      let textView else { return }

                let attachment = NSTextAttachment()
                attachment.image = Self.scaledImage(image, maxWidth: 520)
                let attributed = NSMutableAttributedString(string: "\n")
                attributed.append(NSAttributedString(attachment: attachment))
                attributed.append(NSAttributedString(string: "\n"))
                textView.textStorage?.replaceCharacters(in: textView.selectedRange(), with: attributed)
                self?.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))
            }
        }

        private static func scaledImage(_ image: NSImage, maxWidth: CGFloat) -> NSImage {
            let size = image.size
            guard size.width > maxWidth, size.width > 0 else { return image }
            let scale = maxWidth / size.width
            let newSize = NSSize(width: maxWidth, height: max(1, size.height * scale))
            let scaled = NSImage(size: newSize)
            scaled.lockFocus()
            image.draw(in: NSRect(origin: .zero, size: newSize), from: .zero, operation: .copy, fraction: 1)
            scaled.unlockFocus()
            return scaled
        }

        private func applyForeground(_ color: NSColor) {
            guard let textView else { return }
            if textView.selectedRange().length > 0 {
                textView.textStorage?.addAttribute(.foregroundColor, value: color, range: textView.selectedRange())
            }
            textView.typingAttributes[.foregroundColor] = color
        }

        private func applyBackground(_ color: NSColor) {
            guard let textView else { return }
            if textView.selectedRange().length > 0 {
                textView.textStorage?.addAttribute(.backgroundColor, value: color, range: textView.selectedRange())
            }
            textView.typingAttributes[.backgroundColor] = color
        }

        private func toggleFontTrait(_ trait: NSFontTraitMask) {
            guard let textView else { return }
            let manager = NSFontManager.shared
            let selectedRange = textView.selectedRange()
            if selectedRange.length > 0, let storage = textView.textStorage {
                storage.enumerateAttribute(.font, in: selectedRange) { value, range, _ in
                    let font = (value as? NSFont) ?? textView.font ?? NotesDocumentFormatter.bodyFont
                    let converted: NSFont
                    if manager.traits(of: font).contains(trait) {
                        converted = manager.convert(font, toNotHaveTrait: trait)
                    } else {
                        converted = manager.convert(font, toHaveTrait: trait)
                    }
                    storage.addAttribute(.font, value: converted, range: range)
                }
            } else {
                let font = (textView.typingAttributes[.font] as? NSFont) ?? textView.font ?? NotesDocumentFormatter.bodyFont
                let converted = manager.traits(of: font).contains(trait)
                    ? manager.convert(font, toNotHaveTrait: trait)
                    : manager.convert(font, toHaveTrait: trait)
                textView.typingAttributes[.font] = converted
            }
        }

        private func toggleItalic() {
            guard let textView else { return }
            let manager = NSFontManager.shared
            let selectedRange = textView.selectedRange()
            if selectedRange.length > 0, let storage = textView.textStorage {
                let firstFont = storage.attribute(.font, at: selectedRange.location, effectiveRange: nil) as? NSFont
                let firstIsItalic = firstFont.map { manager.traits(of: $0).contains(.italicFontMask) } ?? false
                let firstIsOblique = (storage.attribute(.obliqueness, at: selectedRange.location, effectiveRange: nil) as? NSNumber)?.doubleValue ?? 0 > 0
                let shouldRemove = firstIsItalic || firstIsOblique
                storage.enumerateAttribute(.font, in: selectedRange) { value, range, _ in
                    let font = (value as? NSFont) ?? textView.font ?? NotesDocumentFormatter.bodyFont
                    if shouldRemove {
                        storage.addAttribute(.font, value: manager.convert(font, toNotHaveTrait: .italicFontMask), range: range)
                        storage.removeAttribute(.obliqueness, range: range)
                    } else {
                        let converted = manager.convert(font, toHaveTrait: .italicFontMask)
                        if manager.traits(of: converted).contains(.italicFontMask) {
                            storage.addAttribute(.font, value: converted, range: range)
                        } else {
                            storage.addAttribute(.obliqueness, value: 0.18, range: range)
                        }
                    }
                }
            } else {
                let font = (textView.typingAttributes[.font] as? NSFont) ?? textView.font ?? NotesDocumentFormatter.bodyFont
                let isItalic = manager.traits(of: font).contains(.italicFontMask)
                let isOblique = (textView.typingAttributes[.obliqueness] as? NSNumber)?.doubleValue ?? 0 > 0
                if isItalic || isOblique {
                    textView.typingAttributes[.font] = manager.convert(font, toNotHaveTrait: .italicFontMask)
                    textView.typingAttributes.removeValue(forKey: .obliqueness)
                } else {
                    let converted = manager.convert(font, toHaveTrait: .italicFontMask)
                    if manager.traits(of: converted).contains(.italicFontMask) {
                        textView.typingAttributes[.font] = converted
                    } else {
                        textView.typingAttributes[.obliqueness] = 0.18
                    }
                }
            }
        }

        private func toggleUnderline() {
            guard let textView else { return }
            let selectedRange = textView.selectedRange()
            if selectedRange.length > 0, let storage = textView.textStorage {
                let hasUnderline = storage.attribute(.underlineStyle, at: selectedRange.location, effectiveRange: nil) != nil
                if hasUnderline {
                    storage.removeAttribute(.underlineStyle, range: selectedRange)
                } else {
                    storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: selectedRange)
                }
            } else {
                if textView.typingAttributes[.underlineStyle] != nil {
                    textView.typingAttributes.removeValue(forKey: .underlineStyle)
                } else {
                    textView.typingAttributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
                }
            }
        }
    }
}

enum NotesDocumentFormatter {
    static let bodyFont = bodyFont(for: "medium")
    static let headingFont = headingFont(for: "medium")
    static let subheadingFont = subheadingFont(for: "medium")

    static func bodyFont(for displayFontSize: String) -> NSFont {
        NSFont.systemFont(ofSize: noteFontSizes(for: displayFontSize).body, weight: .regular)
    }

    static func headingFont(for displayFontSize: String) -> NSFont {
        NSFont.systemFont(ofSize: noteFontSizes(for: displayFontSize).heading, weight: .semibold)
    }

    static func subheadingFont(for displayFontSize: String) -> NSFont {
        NSFont.systemFont(ofSize: noteFontSizes(for: displayFontSize).subheading, weight: .semibold)
    }

    private static func noteFontSizes(for displayFontSize: String) -> (body: CGFloat, subheading: CGFloat, heading: CGFloat) {
        switch displayFontSize {
        case "small": return (11.5, 13, 14.5)
        case "large": return (14, 15.5, 17)
        default: return (12.5, 14, 15.5)
        }
    }

    static var paragraphStyle: NSParagraphStyle {
        paragraphStyle(for: 0)
    }

    static func paragraphStyle(for level: Int) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = level == 1 ? 1 : 2
        switch level {
        case 1:
            style.minimumLineHeight = 17
            style.paragraphSpacingBefore = 8
            style.paragraphSpacing = 11
            style.firstLineHeadIndent = 0
        case 2:
            style.minimumLineHeight = 15
            style.paragraphSpacingBefore = 2
            style.paragraphSpacing = 8
            style.firstLineHeadIndent = 24
        case 3:
            style.minimumLineHeight = 14
            style.paragraphSpacingBefore = 1
            style.paragraphSpacing = 4
            style.firstLineHeadIndent = 39
        default:
            style.minimumLineHeight = 13
            style.paragraphSpacingBefore = 1
            style.paragraphSpacing = 4
            style.firstLineHeadIndent = 0
        }
        style.headIndent = style.firstLineHeadIndent
        return style
    }

    static func documentText(from notes: [NoteBlock]) -> String {
        notes.map(\.displayText)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")
    }

    static func attributedDocument(from notes: [NoteBlock], displayFontSize: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for note in notes {
            if result.length > 0 {
                result.append(attributedString("\n\n", displayFontSize: displayFontSize))
            }
            result.append(attributedNote(note, displayFontSize: displayFontSize))
        }
        return result
    }

    static func attributedNote(_ note: NoteBlock, displayFontSize: String) -> NSAttributedString {
        if note.content.hasPrefix(Self.rtfPrefix),
           let data = Data(base64Encoded: String(note.content.dropFirst(Self.rtfPrefix.count))),
           let parsed = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
           ) {
            return normalizedFonts(parsed, displayFontSize: displayFontSize)
        }
        guard note.content.looksLikeRichTextHTML,
              let data = note.content.data(using: .utf8),
              let parsed = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.html],
                documentAttributes: nil
              ) else {
            return attributedString(note.content, displayFontSize: displayFontSize)
        }
        return normalizedFonts(parsed, displayFontSize: displayFontSize)
    }

    static func attributedString(_ string: String, displayFontSize: String = "medium") -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = string.components(separatedBy: .newlines)
        for index in lines.indices {
            if index > 0 { result.append(NSAttributedString(string: "\n")) }
            let line = lines[index]
            let level = outlineLevel(for: line)
            let font = font(for: level, displayFontSize: displayFontSize)
            result.append(NSAttributedString(
                string: line,
                attributes: [
                    .font: font,
                    .foregroundColor: NSColor.labelColor,
                    .paragraphStyle: paragraphStyle(for: level)
                ]
            ))
        }
        return result
    }

    private static func font(for level: Int, displayFontSize: String) -> NSFont {
        level == 1 ? headingFont(for: displayFontSize) : level == 2 ? subheadingFont(for: displayFontSize) : bodyFont(for: displayFontSize)
    }

    private static func normalizedFonts(_ attributed: NSAttributedString, displayFontSize: String) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributed)
        let fullRange = NSRange(location: 0, length: mutable.length)
        guard fullRange.length > 0 else { return mutable }
        let string = mutable.string as NSString
        string.enumerateSubstrings(in: fullRange, options: [.byParagraphs, .substringNotRequired]) { _, range, _, _ in
            let line = string.substring(with: range)
            let baseFont = font(for: outlineLevel(for: line), displayFontSize: displayFontSize)
            mutable.addAttribute(.paragraphStyle, value: paragraphStyle(for: outlineLevel(for: line)), range: range)
            mutable.enumerateAttribute(.font, in: range) { value, subrange, _ in
                let existing = (value as? NSFont) ?? baseFont
                var font = baseFont
                let traits = NSFontManager.shared.traits(of: existing)
                if traits.contains(.boldFontMask) {
                    font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
                }
                if traits.contains(.italicFontMask) {
                    font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
                }
                mutable.addAttribute(.font, value: font, range: subrange)
            }
        }
        return mutable
    }

    static func outlineLevel(for line: String) -> Int {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil { return 1 }
        if trimmed.range(of: #"^\d+\.\d+\s"#, options: .regularExpression) != nil { return 2 }
        if trimmed.hasPrefix("• ") { return 3 }
        return 0
    }

    static func paragraphs(from string: String) -> [String] {
        string
            .components(separatedBy: CharacterSet.newlines)
            .reduce(into: [String]()) { result, line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    if result.last?.isEmpty == false { result.append("") }
                } else if result.last?.isEmpty == true {
                    result[result.count - 1] = trimmed
                } else {
                    result.append(trimmed)
                }
            }
            .filter { !$0.isEmpty }
    }

    static func snapshot(from textView: NSTextView) -> NotesDocumentSnapshot {
        let range = NSRange(location: 0, length: textView.textStorage?.length ?? 0)
        if containsAttachment(textView.textStorage),
           let rtf = try? textView.textStorage?.data(
            from: range,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
           ) {
            return NotesDocumentSnapshot(html: rtfPrefix + rtf.base64EncodedString(), plainText: textView.string)
        }
        let data = try? textView.textStorage?.data(
            from: range,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.html]
        )
        let html = data.flatMap { String(data: $0, encoding: .utf8) } ?? textView.string
        return NotesDocumentSnapshot(html: html, plainText: textView.string)
    }

    static let rtfPrefix = "grasp-rtf-base64:"

    private static func containsAttachment(_ storage: NSTextStorage?) -> Bool {
        guard let storage else { return false }
        var found = false
        storage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: storage.length)) { value, _, stop in
            if value is NSTextAttachment {
                found = true
                stop.pointee = true
            }
        }
        return found
    }
}

private extension NSColor {
    static let notesHighlightPurple = NSColor(calibratedRed: 0.69, green: 0.32, blue: 0.87, alpha: 1)
    static let notesHighlightPink = NSColor(calibratedRed: 1.00, green: 0.18, blue: 0.33, alpha: 1)
    static let notesHighlightOrange = NSColor(calibratedRed: 1.00, green: 0.58, blue: 0.00, alpha: 1)
    static let notesHighlightBlue = NSColor(calibratedRed: 0.00, green: 0.48, blue: 1.00, alpha: 1)
}

final class NotesTextView: NSTextView {
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }
}
