import AppKit
import SwiftUI
import UniformTypeIdentifiers

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
