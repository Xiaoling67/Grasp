# PDF Slide Parsing — Feature Spec v1.0

> **Feature:** PDF slide parsing at lecture start
> **Target release:** v1.1
> **Status:** Spec draft
> **Author:** PM (cos agent)
> **Dependencies:** DeepSeekService.generateSlideStructure() ✅ exists, DatabaseService.saveSlideStructure() ✅ exists, SlideItem model ✅ exists

---

## 1. Problem Statement

`NewLectureModalView` already has an "Upload slides" button that lets users select a PDF file. The selected file URL is stored in `slideURL` and passed to `AppViewModel.startLecture()`. **However, the PDF is never parsed.** `DatabaseService.getSlideStructure()` always returns an empty array, which means:

- **All AI Notes** are generated with `slide_index = 0` — the slide-aware prompt logic in `DeepSeekService.generateNoteEntry()` never fires its "Slide structure" branch (line 44-70 of DeepSeekService.swift).
- **NotesPanelView's slide sections** never render — the `vm.slideStructure.isEmpty` check in line 12 falls through to the flat list, or slide sections display "Waiting for lecture…" for every slide heading.
- **Cold Call answers** see an empty slide structure, losing valuable context about what topics have been covered.
- **Concept Map (v1.1 future)** cannot anchor concept nodes to specific slides.

The infrastructure to fix this is **already in place**:
- `PDFKit` is a native macOS framework — no dependencies to add.
- `DeepSeekService.generateSlideStructure(slides: [[String: String]], subject: String) -> [SlideItem]` exists and works (line 146-173).
- `DatabaseService.saveSlideStructure(lectureId: String, structure: [SlideItem])` exists (line 195-198).
- `DatabaseService.getSlideStructure(lectureId: String) -> [SlideItem]` exists (line 199-203).
- `AppViewModel.slideStructure: [SlideItem]` is a `@Published` property (line 19) — already observed by `NotesPanelView`.
- `NotesPanelView` already has `slideSection(_ slide: SlideItem)` rendering code (line 59-82).
- The `lecture_slides` table exists in SQLite schema (DatabaseService.swift line 20).

---

## 2. What We're Building

### 2.1 PDF Parsing at Lecture Start

When the user taps "Start Recording" with a PDF selected:

1. **Extract text from each PDF page** using PDFKit (`PDFDocument`, `PDFPage`).
2. **Build an array of page dictionaries**: `[["text": "<page text>", "title": "<optional>"], ...]`.
3. **Call `DeepSeekService.generateSlideStructure()`** with the extracted pages and the lecture subject.
4. **Save the result** via `DatabaseService.saveSlideStructure(lectureId: structure:)`.
5. **Load into `AppViewModel.slideStructure`** so the UI updates immediately.

#### Error handling

| Scenario | Behavior |
|----------|----------|
| PDF cannot be opened (corrupt / permission) | Log error, show toast "Could not read slides", continue lecture without slides |
| PDF has 0 pages | Same as above |
| PDF page has no extractable text (image-only) | Pass `"(no text)"` for that page — `generateSlideStructure` handles this with its `"Visual: <title>"` fallback (DeepSeekService.swift line 163) |
| DeepSeek API call fails | Log error, show toast "Slide parsing failed, continuing without slides", continue lecture |
| DeepSeek returns malformed JSON | Falls through to `return slides.enumerated().map { SlideItem(...) }` fallback (line 170) — safe |

#### Where the parsing code goes

Option A (recommended): **Add a `SlideParserService` struct** — a small utility class or struct in `Grasp/Services/SlideParserService.swift` that wraps PDFKit. Single-purpose: `parse(url: URL) -> [[String: String]]`.

Option B: **Inline in AppViewModel.startLecture()** — simpler but adds ~30 lines to an already-long method. Acceptable for v1, extract later if needed.

**Recommendation:** Option A — testability and separation of concerns.

### 2.2 Slide List in Notes Panel

The `NotesPanelView` already renders slide sections when `vm.slideStructure` is non-empty (line 19-22). Once parsing works, this will *just work*.

**Current behavior (broken):** `vm.slideStructure` is always empty → flat `ForEach(vm.noteBlocks)` renders (line 17-18).

**Desired behavior:** After PDF parsing + DB save → `AppViewModel` loads slide structure on `startLecture()` → `NotesPanelView` renders slide headings with notes grouped beneath them.

#### UI details

| Element | Spec |
|---------|------|
| Slide section header | Uppercased slide title, 10pt semibold, `#C0C0C0` color (already implemented in `slideSection`) |
| Empty slide section | Shows "Waiting for lecture…" in `#E0E0E0` (already implemented) |
| Notes under a slide | Filtered by `slideIndex` matching, rendered via `rowFor(n)` (already implemented) |
| "+" button per slide | Already implemented on each slide header — creates a new blank note on that slide |
| Scrolling | LazyVStack — efficient for 10+ slides with many notes |

#### Loading on past lecture review

When opening a past lecture (via `openPastLecture`), the view model should load slides from the DB:

```swift
// In AppViewModel.openPastLecture():
slideStructure = db.getSlideStructure(lectureId: id)
```

This is already partially done — `PastLectureView` should populate `slideStructure` when loading.

### 2.3 Slide Indicator in Transcript (Optional for v1)

A subtle indicator in the transcript area showing which slide the professor is currently discussing. This requires the AI Note system to determine which slide the current transcript block refers to.

**Design proposal:**
- A small pill/chip above or inline with the transcript scroll area: **"Slide 3 · Supply and Demand Curves"**
- Updates when `generateNoteEntry()` returns a `slideIndex` different from the current indicator
- Very subtle — 10pt text, `#C0C0C0` color, no animation

**Implementation sketch:**
```swift
@Published var currentSlideIndex: Int? = nil

// In seal() after generateNoteEntry():
if let si = e?.0, si != currentSlideIndex {
    currentSlideIndex = si
}
```

Then in `TranscriptPanelView`, show a small floating label when `currentSlideIndex` is non-nil.

**Status:** Nice-to-have for v1.1. If scope is tight, defer to v1.2.

### 2.4 Wire to Concept Map (Future — v1.1+)

In a future release (v1.1 or v1.2), the slide structure anchors the Concept Map. Each concept node belongs to a slide. This spec does NOT implement the Concept Map, but the data model must support it.

**Data model readiness:**

`SlideItem` already has:
```swift
struct SlideItem: Codable {
    var index: Int
    var title: String
    var concepts: [String]    // ← anchors Concept Map nodes
    var keywords: [String]
}
```

No schema changes needed. The Concept Map feature reads `slideStructure` and creates nodes from `concepts` + `keywords`.

---

## 3. Implementation Plan

### 3.1 Files to Create

| File | Purpose | Lines (est.) |
|------|---------|-------------|
| `Grasp/Services/SlideParserService.swift` | PDFKit parsing utility | ~40 |

### 3.2 Files to Modify

| File | What to Change | Lines (est.) |
|------|---------------|-------------|
| `Grasp/ViewModels/AppViewModel.swift` | Add PDF parsing + DeepSeek call + slide loading in `startLecture()`; load slides in `openPastLecture()` | ~25 |
| `Grasp/Views/Notes/NotesPanelView.swift` | Minimal — fix "Waiting for lecture…" text to only show per-slide when that slide has no notes (already correct) | ~2 |
| `Grasp/Views/Transcript/TranscriptPanelView.swift` | Add slide indicator (if implementing §2.3) | ~15 |

### 3.3 No Changes Needed

| File | Reason |
|------|--------|
| `Models.swift` | `SlideItem` already exists, no new fields |
| `DeepSeekService.swift` | `generateSlideStructure()` already exists and works |
| `DatabaseService.swift` | `saveSlideStructure()` and `getSlideStructure()` already exist; `lecture_slides` table already exists |
| `NewLectureModalView.swift` | Already passes `slideURL` to `startLecture()` correctly; file picker already restricts to `.pdf` |

### 3.4 Step-by-Step

1. **Create `SlideParserService.swift`:**
   - Method `parsePDF(url: URL) -> [[String: String]]`
   - Uses `PDFDocument(url:)` to load the document
   - Iterates `document.pageCount`, calls `page.attributedString?.string` for each page
   - Returns array of `["text": "<content>", "title": "<page label or empty>"]`
   - Skips pages with no text (returns `"(no text)"` as text value)
   - Logs warnings for any pages that fail

2. **Modify `AppViewModel.startLecture()`:**
   - After creating the DB record and before/during mic setup, check if `slideURL != nil`
   - If set, spawn a non-blocking task:
     ```swift
     if let url = slideURL {
         Task {
             let pages = SlideParserService.parsePDF(url: url)
             guard !pages.isEmpty else { return }
             let slides = await ds.generateSlideStructure(slides: pages, subject: subject ?? "")
             db.saveSlideStructure(lectureId: lid, structure: slides)
             self.slideStructure = slides
         }
     }
     ```
   - Note: This runs in parallel with mic setup — no delay to lecture start
   - If parsing fails, show toast but don't block recording

3. **Modify `AppViewModel.openPastLecture()`:**
   - Add `slideStructure = db.getSlideStructure(lectureId: id)` at the end

4. **(Optional) Add slide indicator in transcript:**
   - Add `@Published var currentSlideIndex: Int?` to AppViewModel
   - Update in `seal()` after each successful note generation
   - Render in `TranscriptPanelView` as floating label

---

## 4. Algorithm: PDF Page Text Extraction

```swift
import PDFKit

struct SlideParserService {
    static func parsePDF(url: URL) -> [[String: String]] {
        guard let document = PDFDocument(url: url) else {
            return [] // corrupt or inaccessible
        }
        var pages: [[String: String]] = []
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else {
                pages.append(["text": "(no text)"])
                continue
            }
            // Try to get text content via attributed string
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
```

### Considerations

| Concern | Decision |
|---------|----------|
| **PDF outline / table of contents** | Ignored — page-by-page text extraction is simpler and sufficient for lecture slides |
| **Attributed string formatting** | Discarded — we only need plain text for the LLM |
| **Embedded images** | Not extracted — `PDFPage.attributedString` returns `nil` for image-only pages; `"(no text)"` triggers the DeepSeek "Visual:" fallback |
| **Scanned PDFs (no text layer)** | `attributedString` returns `nil` → treated as image-only → "Visual: [topic]" title from DeepSeek. OCR is **not** in scope for v1 |
| **Large PDFs (50+ pages)** | Each page is `<200 words on average for slides`. 50 pages × ~150 words = ~7,500 tokens. DeepSeek max_tokens=800 for response, input context handles this easily |
| **Concurrent parsing** | Runs in a `Task` (non-blocking). No actor isolation needed since `slideStructure` is `@MainActor` and updated via `self.slideStructure = ...` on main actor |

---

## 5. Acceptance Criteria

| # | Criteria | Verification |
|---|----------|-------------|
| 1 | Selecting a PDF before recording → pages are parsed → slide_structure saved to DB | `db.getSlideStructure(lectureId:)` returns non-empty array |
| 2 | Notes panel shows slide headings with notes grouped under them | `NotesPanelView` renders slideSection for each SlideItem, notes filtered by slideIndex |
| 3 | Works with multi-page PDFs (10+ slides) | Test with a 15-slide lecture deck; all slides appear in structure, DeepSeek does not truncate |
| 4 | Handles image-only slides gracefully | Slide with no text → `"(no text)"` → DeepSeek generates `"Visual: [topic]"` title |
| 5 | Non-PDF files rejected by the file picker | Already done: `NSOpenPanel.allowedContentTypes = [.pdf]` |
| 6 | Recording is NOT blocked by slide parsing | Mic starts immediately; slide parsing runs in parallel Task; toast shown on failure |
| 7 | Past lecture review shows slide structure | Open a past lecture that had slides loaded → Notes panel shows slide groupings |
| 8 | AI Notes use correct slide_index | `generateNoteEntry` receives non-empty `slides` → prompt uses slide structure branch → notes have correct `slideIndex` |
| 9 | Cold Call sees slide structure | `generateColdCallAnswer` receives non-empty `slides` → answer is slide-aware |

### Test Scenarios

#### Happy path
```
Input: 10-slide PDF with text on every page
Action: Upload → Start Recording
Expect: db.getSlideStructure() returns 10 SlideItems
        NotesPanelView shows 10 slide headings
        AI Notes have slide_index in [0..9]
        Cold Call context includes slide titles
```

#### Image-only slides
```
Input: PDF with 3 image-only slides (diagrams, no text layer)
Action: Upload → Start Recording
Expect: parsePDF returns ["text": "(no text)"] for all 3
        DeepSeek returns titles like "Visual: Diagram Description" (speculative but handled)
        No crash, no empty structure
```

#### Corrupt PDF
```
Input: Corrupt/invalid PDF file
Action: Upload → Start Recording
Expect: parsePDF returns [] 
        Toast: "Could not read slides"
        Lecture starts normally without slide structure
        All AI Notes have slide_index = 0
```

#### DeepSeek API failure
```
Input: Valid PDF, DeepSeek API returns 500
Action: Upload → Start Recording
Expect: generateSlideStructure returns fallback (enumerated SlideItems with generic titles)
        Structure saved to DB
        Notes panel shows fallback slide headings
```

---

## 6. Data Flow Diagram

```
User taps "Upload slides"
  → NSOpenPanel (allowedContentTypes: [.pdf])
  → slideURL = selected URL
  → slideName = lastPathComponent

User taps "Start Recording"
  → AppViewModel.startLecture(name:mode:subject:slideURL:)
    → db.startLecture() → lecture_id = lid
    → Audio setup (mic, Deepgram) ← starts immediately, no wait
    
    → Task {                                     ← parallel, non-blocking
        pages = SlideParserService.parsePDF(url: slideURL)
        if pages.isEmpty { showToast(); return }
        
        slides = await DeepSeekService.generateSlideStructure(
            slides: pages,
            subject: subject
        )
        
        db.saveSlideStructure(lectureId: lid, structure: slides)
        
        await MainActor.run {
            vm.slideStructure = slides
        }
    }

  → seal() fires (first transcript block sealed)
    → db.getSlideStructure(lectureId: lid) now returns real data
    → ds.generateNoteEntry(slides: [...], ...)
      → Prompt includes slide titles + concepts
      → Returns correct slideIndex
    → db.saveNoteBlock(slideIndex: correct, ...)
    → NotesPanelView re-renders with slide sections
```

---

## 7. Future Work (Not in Scope)

| Feature | Why defer | Depends on |
|---------|-----------|------------|
| **Concept Map** | Separate feature with its own spec | This spec (slide structure is the foundation) |
| **OCR for scanned PDFs** | Apple's VNRecognizeTextRequest adds complexity; corner case | User demand |
| **PPTX parsing** | Requires XML parsing or Apache POI; uncommon on macOS | User demand |
| **Auto-detect slide boundaries during lecture** | Would need audio analysis or slide-change detection | Research |
| **Annotate slides (draw on PDF in-app)** | Full PDF rendering + touch input | UX spec |
| **Slide thumbnails in notes panel** | Needs PDF page rendering, increases UI complexity | UX spec |

---

## 8. Appendix: Existing Code Reference

### 8.1 DeepSeekService.generateSlideStructure() — Already Exists

```swift
// DeepSeekService.swift, line 146-173
func generateSlideStructure(slides: [[String: String]], subject: String) async -> [SlideItem]
```

Takes an array of `["text": "..."]` dictionaries and returns parsed `[SlideItem]` via DeepSeek API. The prompt handles:
- Extracting titles, concepts, and keywords per slide
- Image-only slides → `"Visual: <topic>"` title
- Malformed JSON → fallback enumerated SlideItems

### 8.2 DatabaseService — Already Exists

```swift
// DatabaseService.swift, line 195-203
func saveSlideStructure(lectureId: String, structure: [SlideItem])
func getSlideStructure(lectureId: String) -> [SlideItem]
```

Stores as JSON blob in `lecture_slides` table (UPSERT on conflict).

### 8.3 AppViewModel — Affected Methods

```swift
// AppViewModel.swift, line 65-87 (startLecture)
// Currently ignores slideURL entirely — needs PDF parsing added

// AppViewModel.swift, line 329-330 (resetLive)
// Clears slideStructure on lecture stop — correct behavior

// AppViewModel.swift, line 316-319 (openPastLecture)
// Currently does NOT load slideStructure — needs to call db.getSlideStructure()
```

### 8.4 NotesPanelView — Already Renders Slides

```swift
// NotesPanelView.swift, line 12-23
// If slideStructure is non-empty, renders slide sections
// If slideStructure is empty, falls back to flat note list
// This will "just work" once slideStructure is populated
```

### 8.5 Existing References in Codebase

| Reference | File | Line |
|-----------|------|------|
| `MEDITUM` — "PDF slides uploaded but never parsed" | TECHNICAL_DEBT.md or ARCHITECTURE.md | — |
| `MEDITUM` — "slideIndex always 0" | ARCHITECTURE.md line 337 | — |
| Slide-aware prompt branch in generateNoteEntry | DeepSeekService.swift | 44-70 |
| `db.getSlideStructure()` call in note generation | AppViewModel.swift | 157 |
| `db.getSlideStructure()` call in cold call | AppViewModel.swift | 198 |
| slideURL passed to startLecture | NewLectureModalView.swift | 17 |
| slideURL declared in startLecture signature | AppViewModel.swift | 65 |
