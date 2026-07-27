import AppKit

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

extension NSColor {
    static let notesHighlightPurple = NSColor(calibratedRed: 0.69, green: 0.32, blue: 0.87, alpha: 1)
    static let notesHighlightPink = NSColor(calibratedRed: 1.00, green: 0.18, blue: 0.33, alpha: 1)
    static let notesHighlightOrange = NSColor(calibratedRed: 1.00, green: 0.58, blue: 0.00, alpha: 1)
    static let notesHighlightBlue = NSColor(calibratedRed: 0.00, green: 0.48, blue: 1.00, alpha: 1)
}

