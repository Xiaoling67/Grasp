import PDFKit

struct SlideParserService {
    /// Parse a PDF at the given URL and return an array of page dictionaries.
    /// Each dictionary contains "text" (page content or "(no text)" for image-only pages).
    /// Returns an empty array if the PDF cannot be opened (corrupt / permission / 0 pages).
    static func parse(url: URL) -> [[String: String]] {
        guard let document = PDFDocument(url: url) else {
            print("[SlideParserService] Failed to open PDF at \(url)")
            return []
        }
        guard document.pageCount > 0 else {
            print("[SlideParserService] PDF has 0 pages")
            return []
        }
        var pages: [[String: String]] = []
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else {
                print("[SlideParserService] Warning: could not read page \(i + 1), treating as no-text")
                pages.append(["text": "(no text)"])
                continue
            }
            let text = page.attributedString?.string
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if text.isEmpty {
                // Image-only or unreadable page
                pages.append(["text": "(no text)"])
            } else {
                pages.append(["text": text])
            }
        }
        return pages
    }
}
