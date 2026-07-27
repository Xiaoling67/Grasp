# Grasp — PRD v1.1 (Founder's Revision)

**Version:** 1.1-r3
**Date:** 2026-06-28
**Platform:** macOS 14.0+ | Swift 5.9 | SwiftUI + AppKit
**Status:** In development — rewrite to match Founder requirements
**Window:** Single-window app, default 1280×800, minimum 960×640

---

## v1.1-r3 Implementation Clarifications

This section locks the execution details that were missing from v1.1-r2 and caused partial implementations to still feel wrong.

1. **Divider drag math must be relative to drag start.** Vertical and horizontal dividers must store their starting width/ratio at drag begin, then apply `start + translation`. They must not repeatedly add/subtract `translation` from the already-mutated value during `onChanged`, because that creates runaway resizing and visible jumps.

2. **Notes are flat everywhere, not only in the live panel.** Past lecture views, export flows, and any read-only note surfaces must render notes as plain flat entries. They must not show bullets, indentation, `level`-based prefixes, or concept-map hierarchy.

3. **Rich-text note storage needs read-safe fallback.** Notes saved as HTML/RTF must render back as user-readable text in read-only surfaces. Raw HTML tags must never appear in the UI or exported documents.

4. **`NSTextView` should be selectable/editable at creation time.** The Notes editor should rely on native `NSTextView` click, double-click, selection, and keyboard handling. SwiftUI state may mark which note is active, but it must not make the text view temporarily unselectable or steal focus during normal clicks.

5. **Empty note deletion is part of save semantics.** If a note is empty or whitespace-only when editing ends, it should be removed rather than persisted as a blank HTML/text row.

6. **Selection popup coordinates must be panel-relative and clamped.** Popup placement must be calculated from the selected glyph rect plus the text view container origin, then clamped to the current transcript panel size. It must not use fixed global bounds such as `100...750`.

7. **Selection popup dismissal must cover real macOS interactions.** The popup must dismiss on outside click, Esc, any text-entry key, layout resize, and transcript scroll start/scroll movement.

8. **AI notes must be generated from sealed transcript blocks.** When a transcript block is sealed, Grasp must call the AI note generator with the sealed block, recent notes, slide structure, and subject, then append at most one new flat note. Having an editor UI without this sealed-block-to-note append path does not satisfy “Real-Time AI Notes.”

9. **AI notes must not reintroduce hierarchy through data.** The note generator prompt and save path must not request or depend on `level 0/1/2`. Saved AI notes should use `source = "ai"` for visual new-note treatment, but all user-visible note surfaces must remain flat.

10. **Rich-text parsing must be format-aware.** Plain AI-generated text must be assigned directly to `NSTextView.string`. Only content that actually looks like HTML/RTF should go through rich-text parsing. Plain text must never disappear, gain unexpected spacing, or render as markup because it was parsed as HTML.

11. **`⌘N` must be context-aware.** During an active live lecture on the live tab, `⌘N` creates a new blank note with focus in the Notes panel. Outside that context, `⌘N` opens the New Lecture flow.

12. **Apple Notes means one flowing text document, not many editor rows.** The Notes panel must be implemented as one native `NSScrollView` containing one continuous `NSTextView`. `note_blocks` may remain the persistence format, but the UI must not render one `NSTextView` per note row. Users should experience a single editable page: click anywhere to place the cursor, double-click to select words, press Return for a new line, and keep typing without crossing component boundaries.

13. **Numbering is text formatting, not data hierarchy.** AI notes may use Apple Notes-style structured numbering up to three visible depths: `1.`, `1.1`, and `1.1.1`. The third depth should be reserved for concrete examples, formulas, data points, exceptions, or short supporting details. This must not revive `level 0/1/2`, tree rendering, parent/child note records, bullets, or indentation-driven concept maps.

14. **AI notes should choose practical structure by content.** Default AI output should use one or two numbered depths. Use the third depth only when the transcript contains enough detail to justify it. For comparisons, classifications, variables, or data-heavy explanations, the AI may append a compact markdown-style table inside the same document text.

15. **The Notes toolbar should expose native editing commands.** The live Notes panel must provide Apple Notes-like controls for bold, italic, underline, text color, highlight color, three numbering insertions (`1.`, `1.1`, `1.1.1`), and a quick table template. Keyboard shortcuts such as `⌘B`, `⌘I`, and `⌘U` must continue to work through native `NSTextView` editing behavior.

16. **Images must persist, not only appear in memory.** User image insertion must use native `NSTextAttachment` and save rich notes with an attachment-preserving format. If the note contains images, Grasp stores RTF/base64 content and restores it into the same continuous `NSTextView` on reload. AI image generation is a later provider/model integration, but it must reuse this same attachment-capable note document.

17. **AI Notes must have product-quality generation control.** Each sealed transcript block should produce a note only when the model is confident the content is useful, specific, and non-duplicative. Weak/filler content should be skipped. The AI prompt must prefer definitions, frameworks, formulas, causal mechanisms, comparisons, exam-worthy distinctions, concrete numbers, and examples over generic summaries.

18. **Stopping a lecture must not lose the final note.** If the user stops while an active transcript block exists, Grasp must seal that block, allow its AI note task to finish, and only then finalize the lecture. The app must not set a state that prevents the final sealed block from appending an AI note, and must not cancel the latest note task before it has a chance to save.

19. **Every lecture should end with a reviewable summary.** On stop, after the final live note finishes, Grasp should append a concise `Summary` section with 3-5 numbered takeaways and a compact `Key Terms` table when real terms are present. This turns the live stream into a review artifact instead of a pile of fragments.

20. **AI Notes status must be visible.** The Notes header should show a small native status pill such as `Ready`, `Writing...`, `Listening`, `Updated`, `Summarizing...`, or `Summary added`, so the user can tell whether the AI is working, skipped low-value content, or finished.

21. **AI Notes should learn from user edits locally.** When the user edits the continuous notes document, Grasp should infer a lightweight note style guide from the plain text: concision level, numbering preference, third-depth usage, and table preference. This guide should be stored locally in settings and passed into future AI note and summary prompts. No extra user setup should be required.

22. **AI Notes needs a local duplicate gate.** Even if the model misses a duplicate, Grasp should normalize the candidate note and compare it with recent notes before saving. Highly overlapping or contained notes should be skipped locally and the AI Notes status should reflect that a duplicate was skipped.

23. **AI Notes must use transcript context without mining stale content.** Each AI note request should include the current sealed transcript block plus a short rolling window of recent sealed blocks. The model may use prior blocks only to resolve pronouns, continuity, slide focus, and topic context. It must create new notes from the current sealed block only, so old content is not repeatedly re-mined.

24. **AI Notes should capture professor emphasis.** The note generator should explicitly watch for emphasis cues such as "remember", "key", "exam", "important", "the point is", and "notice". When such cues are present, the output should surface them as `Key point:` or `Exam cue:` inside the Apple Notes-style text.

25. **AI Notes detail must be user-controllable.** The Notes panel should expose a three-level detail control above the editor: `Concise`, `Balanced`, and `Detailed`. The selected level should persist locally and affect both real-time AI notes and end-of-lecture summaries.

26. **Detail levels must have concrete generation standards.** `Concise` means one line, roughly 12-20 words, usually only `1.`. `Balanced` means 1-3 lines, roughly 22-45 words, usually `1.` and `1.1`, with `1.1.1` only for concrete examples/formulas/exam cues. `Detailed` means 3-6 lines, roughly 45-90 words, allowing mechanisms, examples, formulas, exceptions, and compact tables when useful.

27. **The four live quadrants must share one panel grammar.** Transcript, AI Notes, Auto Explain, and Cold Call / Save / Search must each have the same pastel-blue panel header treatment. No quadrant should look more "official" than the others because only some panels have headers. Each header must include a small settings gear on the right.

28. **AI Notes settings must live behind the header gear.** The AI Notes gear should contain the `Concise / Balanced / Detailed` control and a free-form "note framework" field where the user can describe their preferred generated-note structure. This framework must persist locally and be passed into AI note and summary prompts.

29. **Auto Explain settings must let users declare existing knowledge.** The Auto Explain gear should expose a free-form "existing knowledge" field. Terms, formulas, and concepts entered there should persist locally and should be sent to Auto Explain detection/search prompts so Grasp avoids explaining what the user already knows.

---

## Product Summary

Grasp is a next-generation AI note-taking assistant for live lectures and meetings.

### Core capabilities

1. **Real-Time AI Notes, Editable Anytime** — Notes generate in real time. User can edit any note at any moment during the lecture. AI never overwrites user edits. Once the user changes a note, Grasp marks it as manual and leaves it alone.

2. **Pre-Lecture Setup** — Upload materials (slides, PDFs) before the lecture. Tell Grasp the desired structure and detail level. AI uses this guidance from the start.

3. **Learning Memory** — Grasp remembers how and where the user edits notes over time. Learns conciseness level, structure preference, what gets kept vs deleted. Goal: minimize manual editing over time until notes match preferences by default.

4. **Smart Background & Explanations** — Based on user settings (per-lecture or global), Grasp surfaces background info and concept explanations during the lecture. Pulls from lecture history and knowledge profile.

---

## Change Log (v1.0 → v1.1-r2)

| Area | v1.0 (shipped) | v1.1-r1 (failed — shipped to Founder) | v1.1-r2 (THIS — Founder's requirements) |
|------|----------------|----------------------------------------|------------------------------------------|
| **Layout** | Side-by-side (transcript \| notes) with bottom panel tabs | 2×2 grid layout (65/35 vertical, 55/45 horizontal). Horizontal divider **fixed**. | 2×2 grid layout. **ALL dividers draggable** — vertical AND horizontal. User freely resizes all 4 quadrants. |
|| **Selection popup** | Broken (NSEvent) | Fixed via NotificationCenter with **80ms debounce**. Slow, unresponsive. | **Instant** popup. **4 consistent buttons** (K, L, Search, Note) — all icon + label or all icon-only. No mixing. Added **Note** button copies to notes. |
| **AI Notes** | Flat per-seal notes, ≤25 words, level 0/1/2 | **Concept Map** — hierarchical tree with indented bullets, parent/child/depth indentation. **Founder hates it.** | **Apple Notes clone** — one continuous rich-text document, click to edit, double-click word select, numbered text structure up to `1.1.1`, no tree data, no conflicting tap gestures. NSTextView responds to clicks immediately. |
| **Dividers** | Static | Vertical resizable; horizontal fixed 65/35 | **ALL dividers movable** — vertical AND horizontal. 4 freely resizable quadrants. |
| **UI quality** | Prototype | Prototype with hardcoded hex colors | **Beautiful, polished** — design system, proper spacing, animations, native feel. |
| Auto Explain | Stateless per block | Student Knowledge Profile (SQLite) | Unchanged from v1.1-r1 |
| Search & Save | Selection popup broken | Selection popup fixed (but slow) | Selection popup **instant** |
| Transcription | Word-by-word display, semantic blocking | Same + PDF slide parsing | Unchanged from v1.1-r1 |
| Cold Call | 7 regex patterns, 90s cooldown, 3-phase UI | Same + answers feed into Knowledge Profile | Unchanged from v1.1-r1 |
| Keyboard shortcuts | Only ⌘N wired up | All shortcuts implemented | Unchanged from v1.1-r1 |
| Bug fixes | None (shipped with known bugs) | 7 bugs fixed | All v1.1-r1 fixes kept |
| Layout interactivity | Static | Resizable vertical divider only; fixed 65/35 horizontal | **Full 2×2 resize:** both dividers draggable |

---

## 1. Selection Popup — MUST BE INSTANT

**Founder's exact words:**
> "在 transcription 那个地方划词的时候，它出现的特别慢，而且划词非常不灵敏，出现就是我划完词以后，然后它那个对话框弹出的也特别慢"

**Translation:** When selecting text in the transcript, the popup appears very slowly. Text selection is unresponsive. After finishing the selection, the dialog box appears with significant delay.

### Root Cause of Failure (v1.1-r1)
The previous implementation used `NotificationCenter.default.addObserver(forName: NSTextView.didChangeSelectionNotification)` with `DispatchQueue.main.asyncAfter(deadline: .now() + 0.08)`. The 80ms debounce plus the NotificationCenter dispatch adds ~100-150ms latency. This makes the popup feel sluggish and disconnected from the user's selection gesture.

### Exact Behavior (v1.1-r2)

**1. Instant popup on selection:**
- **No debounce.** Zero artificial delay.
- Use `NSTextView.didChangeSelectionNotification` directly on the main queue — no `asyncAfter`.
- Popup position calculated in the **same runloop cycle** as the selection change.
- Popup must appear within **1 frame** (≤16ms) of the user completing selection.

**2. Selection sensitivity:**
- Minimum selection length: **2 characters** (not 3 as in v1.1-r1).
- Empty/whitespace-only selections are ignored.
- Selection of punctuation-only or whitespace-only is ignored.

**3. Popup positioning:**
- Popup appears **above** the selected text, centered horizontally.
- If above placement would clip the window top, popup appears **below** the selection.
- Popup follows window scroll — repositions on scroll events.
- Small vertical gap (4px) between selected text and popup.

**4. Popup content:**
|- **Four buttons** in a pill-shaped toolbar, all with **consistent styling** (all icon + short label, or all icon-only — must be uniform):
|  - **K** (`bookmark.fill` icon) — saves to SQLite, adds to Knowledge Profile
|  - **L** (`character.bubble.fill` icon) — only visible in International mode
|  - **Search** (`magnifyingglass` icon) — AI definition + analogy
|  - **Note** (`square.and.pencil` icon) — copies selected text directly to notes via `vm.handleCopyToNotes(text:)`
|- ALL buttons must have identical visual style. If one shows an icon + label, all must show icon + label. If one is icon-only, all must be icon-only. No mixing.
|- Background: `NSVisualEffectView` material (vibrant light) with rounded corners (10px).
- Pill shape: compact, floats above content, no blocking of surrounding text.

**5. Dismissal:**
- Tap outside popup → dismiss immediately.
- Press `Esc` → dismiss immediately.
- Start typing → dismiss immediately.
- Scrolling transcript → dismiss immediately.
- Selecting different text → dismiss old popup, show new popup for new selection.

### Acceptance Criteria
- [ ] Popup appears instantly (≤1 frame) after text selection.
- [ ] No artificial delay, debounce, or `asyncAfter` in the selection-to-popup path.
- [ ] Minimum 2-character selection triggers popup.
- [ ] Popup correctly positions above selection (or below if clipped).
- [ ] Popup dismisses on outside tap, Esc, new selection, or scroll.
- [ ] Popup uses `NSVisualEffectView` material (vibrant).
- [ ] Popup buttons (Search / K / L / Note) work correctly.
- [ ] All 4 buttons have consistent visual styling (all icon+label or all icon-only — no mixing).

---

## 2. AI Notes Panel — EXACT CLONE OF APPLE NOTES

**Founder's exact words:**
> "我右面那个就是 AI 笔记的智能生成，它也没有给我按照我是说的是要必须是像 MacBook，就是苹果公司出的那款原生自带的那款 note 笔记一样那样顺滑，然后完全要做成那一模一样的东西，你现在一条一条非常的不灵敏"

**Translation:** The AI Notes panel on the right does not match what I asked for. I said it MUST be exactly like Apple's native Notes app on Mac — smooth, exactly the same. Right now it's a clunky item-by-item list that is unresponsive.

### Why v1.1-r1 Failed
The previous implementation used a **hierarchical concept tree** (`ConceptNode`, `buildConceptTree`, `ConceptNodeRow`) with:
- Indented bullets (▸, •, ◦) at different levels
- Depth-based indentation (18px per level)
- Parent/child/sibling tree rendering
- Distinct bullet colors per level (blue/gray/light gray)

This is **WRONG**. The Founder explicitly wants Apple Notes behavior, not an indented outline.

### Exact Behavior (v1.1-r2)

The Notes panel must behave **IDENTICALLY** to Apple's native Notes app on macOS:

**1. Visual layout:**
- Plain white background, no tree, no indentation.
- No bullet characters (▸, •, ◦) for AI structure. AI structure uses typed numbering such as `1.`, `1.1`, and `1.1.1`.
- No concept hierarchy rendering — all notes are displayed inside one continuous rich-text document.
- Header area with "AI NOTES" label (same style as Apple Notes' title area).
- Smooth scrolling with rubber-banding at edges (native NSScrollView behavior).

**2. Inline editing EXACTLY like Apple Notes:**
|- **Click to edit** — single-click on any note's text content immediately enters edit mode. The NSTextView becomes first responder and shows a blinking cursor at the click location.
|- **Double-click to edit** — double-clicking a note enters edit mode AND selects the word under the cursor (matching Apple Notes behavior for word selection).
|- **Click empty area to create** — clicking on an empty/whitespace area in the notes panel (not on any existing note) creates a new blank note at the bottom of the list with the cursor blinking and ready for typing. This matches Apple Notes' behavior of "click anywhere to start typing."
|- Edit in place — no separate text field, no modal, no sheet. The text itself becomes editable.
|- **Rich text support** — bold, italic, underline, text color, highlight color, and quick table templates via toolbar controls. Keyboard shortcuts `⌘B`, `⌘I`, and `⌘U` must work inside the editor.
|- **NSTextView-based** editing, not SwiftUI TextField. Use AppKit's NSTextView for native text editing behavior.
|- **Auto-save on blur** — edits committed when focus leaves the note.
|- **Return/Enter** — creates a new line in the same continuous Notes document, matching Apple Notes behavior.
|- **Shift+Return** — also inserts a line break; no special row-splitting behavior.
|- **Delete empty note** — if a note becomes empty on blur, remove it (like Notes app removes empty entries).

**3. AI-generated notes appear as editable rich text inside the same document:**
- Each AI note is appended into the single flowing rich text document.
- AI notes are pre-populated with content, fully editable.
- AI notes use structured numbering when helpful:
  - `1.` for the main idea.
  - `1.1` for a short explanation, definition, or relation.
  - `1.1.1` only for concrete examples, formulas, numbers, exceptions, or supporting details.
- For comparisons, classifications, variables, or data-heavy explanations, AI notes may include a compact markdown-style table after the relevant numbered line.
- AI must never overwrite user edits. New AI text appends to the end of the document.
- AI should skip low-confidence filler and duplicated content instead of adding noisy notes.
- The Notes header should show AI generation status while writing, listening, or summarizing.
- Stopping the lecture should first preserve the final transcript block and its AI note, then append a `Summary` section for review.
- User edits should update a local style guide so later AI notes match the student's preferred concision, numbering, depth, and table usage.
- Candidate AI notes should pass a local duplicate check before being saved.
- AI should use recent transcript context for continuity, while mining only the current sealed block for new notes.
- Professor-emphasized ideas should surface as `Key point:` or `Exam cue:` phrasing.
- Users can select `Concise`, `Balanced`, or `Detailed` from the AI Notes settings gear; the choice persists and changes note length/detail.
- Users can provide a custom note-generation framework in the AI Notes settings gear.
- Users can provide existing knowledge in the Auto Explain settings gear, so the app avoids explaining familiar terms.

**4. User-created notes:**
- Click the "+" button in the header (or press ⌘N) to create a new blank note.
- New note appears with cursor blinking, ready for typing.
- No blue border (user notes are never shown as "new").

**5. Scrolling behavior:**
- Native NSScrollView with smooth scrolling.
- Velocity-based deceleration.
- Rubber-banding at content edges.
- Auto-scroll to bottom when a new AI note arrives (unless user has scrolled up manually).

**6. Deletion/editing semantics:**
- Because the editor is one continuous document, deletion is native text deletion inside `NSTextView`.
- Empty or whitespace-only persisted note content is removed on save.
- Do not add per-row delete buttons unless the product returns to row-based note records, which this revision rejects.

**7. Rich text persistence:**
- Notes are saved as **HTML** or **RTF** in SQLite (not plain text), preserving rich text formatting.
- On reload, rich text is restored exactly as edited.
- Read-only surfaces and export must strip HTML safely to readable text when they do not render rich text.

**7.1 Images, attachments, and AI-generated images:**
- User-inserted images are inserted through the Notes toolbar image button.
- Images are inserted as native `NSTextAttachment` objects inside the continuous `NSTextView`.
- Notes containing image attachments are persisted as RTF/base64, because HTML serialization is not reliable enough for native attachments.
- On reload, images must rehydrate into the `NSTextView` at the original position.
- Read-only surfaces and export must show readable text, not raw RTF/base64 payloads.
- AI-generated images are a later feature built on the same attachment-capable document. They require an image generation provider/model, prompt provenance, and a clear label that the image was AI-generated.

**8. Legacy data compatibility (v1.0 flat notes):**
|- Old v1.0 notes are rendered as plain rich text blocks (no hierarchy).
|- The concept map data model is **deleted** — no `ConceptNode`, no `conceptMap`, no tree structures.
|- All notes become a flat array of editable rich text blocks.

**9. Single-document NSTextView responsiveness — CRITICAL IMPLEMENTATION NOTES:**

These issues have been observed in the current implementation and must be fixed to achieve Apple Notes-level behavior:

|- **No row-based editors:**
|  - Do not render a `ForEach` of note rows containing many `NSTextView` instances.
|  - The Notes panel must expose one document surface: one `NSScrollView` and one `NSTextView`.
|  - Native `NSTextView` behavior should handle single-click cursor placement, double-click word selection, triple-click line selection, and keyboard editing.

|- **Focus must target the document editor immediately:**
|  - `⌘N`, the header plus button, and clicking the empty editor area must call `makeFirstResponder()` on the single document `NSTextView`.
|  - Do not use SwiftUI tap gestures on the editor container to fake editing mode.
|  - Test: clicking anywhere in the editor should immediately show a blinking cursor with zero perceptible delay.

|- **The wrapped NSTextView must respond to clicks immediately:**
|  - Override `mouseDown:` only to synchronously call `makeFirstResponder()`, then forward to `super`.
|  - Ensure `NSTextView.isSelectable = true` and `NSTextView.isEditable = true` are set at init time.
|  - Verify: clicking anywhere in the note document should immediately show a blinking cursor and allow typing.

### What to DELETE from codebase
- `ConceptNode` struct (data model)
- `ConceptNodeRow` view
- `buildConceptTree()` method
- `flattenNode()` method
- `collectChildren()` method
- `conceptNodeView()` method
- `conceptSlideSection()` method
- `buildConceptTree` call in `NotesPanelView`
- All row-level editor logic and multiple-`NSTextView` note rows
- `ConceptMap` related properties in `AppViewModel`
- Any code that renders hierarchical indentation

### What to BUILD
- Single continuous rich text document using one `NSTextView` inside one `NSScrollView`
- Apple Notes-style visual layout (no bullets, no indentation)
- Inline editing with click-to-edit
- Rich text toolbar and keyboard shortcuts (⌘B, ⌘I, ⌘U)
- Text color, highlight color, and three quick numbering insertions (`1.`, `1.1`, `1.1.1`)
- Quick table template insertion for comparison/data notes
- Image insertion using a visible toolbar button and native `NSTextAttachment`
- Attachment-preserving persistence for notes that contain images
- AI prompt rules that generate useful numbered text and compact tables without data hierarchy
- Proper focus management for the single document editor

### Acceptance Criteria
|- [ ] Notes panel feels like Apple Notes — one white flowing document, no rows, no concept map, no tree indentation.
|- [ ] Click any note text → instantly editable in place (blinking cursor appears immediately).
|- [ ] Click empty/whitespace area in notes panel → cursor appears in the single document and user can type.
|- [ ] Double-click any note → enters edit mode AND selects the word under cursor.
|- [ ] Rich text support: ⌘B bold, ⌘I italic, ⌘U underline work inside notes.
|- [ ] Toolbar supports bold, italic, underline, text color, highlight color, `1.`, `1.1`, `1.1.1`, and table template insertion.
|- [ ] Enter inserts a new line in the same continuous document.
|- [ ] Shift+Enter inserts a line break in the same continuous document.
|- [ ] Auto-save on blur — edits persisted to SQLite.
|- [ ] New AI notes append to the bottom of the continuous document without overwriting user edits.
|- [ ] AI notes use up to three visible numbering depths as text, not data hierarchy.
|- [ ] AI notes can include compact markdown-style tables for comparison/data content.
|- [ ] AI skips low-confidence filler or duplicate content instead of appending noise.
|- [ ] User note edits update a locally stored AI note style guide.
|- [ ] AI note and summary prompts receive the learned style guide.
|- [ ] Candidate AI notes are locally duplicate-checked against recent notes before save.
|- [ ] AI note generation receives a rolling transcript context window, not only the current block.
|- [ ] AI prompt explicitly restricts note creation to the current sealed block.
|- [ ] AI prompt captures professor emphasis cues as `Key point:` or `Exam cue:`.
|- [ ] Notes panel exposes a three-level AI detail control: `Concise`, `Balanced`, `Detailed`.
|- [ ] AI detail level persists locally.
|- [ ] AI note and summary prompts receive concrete detail policies for the selected level.
|- [ ] AI Notes settings gear exposes a free-form note framework input.
|- [ ] The note framework persists locally and is passed into AI note and summary prompts.
|- [ ] Auto Explain settings gear exposes a free-form existing-knowledge input.
|- [ ] Existing knowledge persists locally and is passed into Auto Explain detection/search prompts.
|- [ ] Stopping a lecture does not cancel or lose the final sealed block's AI note.
|- [ ] Stopping a lecture appends a concise `Summary` section when enough transcript/notes exist.
|- [ ] Notes header shows an AI Notes status pill.
|- [ ] Smooth scrolling with rubber-banding at edges.
|- [ ] Notes persisted as RTF/HTML (rich text preserved on reload).
|- [ ] User can insert an image from the Notes toolbar.
|- [ ] Notes containing images persist as attachment-capable RTF/base64 and reload into the editor.
|- [ ] Raw HTML never appears in read-only note views or exports.
|- [ ] AI-generated images are not marked complete until an image provider/model is integrated.
|- [ ] All concept map / tree code is removed from the codebase.
|- [ ] NotesPanelView uses exactly one document `NSTextView` inside one `NSScrollView`.
|- [ ] No row-based `NoteRichEditor` / `NoteRow` implementation remains.
|- [ ] The document NSTextView responds to mouseDown immediately — no SwiftUI gesture steal.

---

## 3. ALL Dividers Must Be Movable

**Founder's exact words:**
> "主面板上这些这些这些个线都是可以互相移动的，这样可以调整窗口大小呀，横着的线可以竖着线都可以都可以移动的"

**Translation:** All these lines on the main panel should be movable to adjust window sizes. Horizontal lines and vertical lines should all be movable.

### Why v1.1-r1 Failed
The horizontal divider between top and bottom rows was **fixed at 65/35** — a visual-only separator with no drag interaction. The vertical divider was draggable, but the horizontal was not. This prevents users from freely resizing the 4 quadrants.

### Exact Behavior (v1.1-r2)

**1. Vertical divider (between left and right columns):**
- Keep existing drag implementation (works correctly).
- Drag gesture updates `vm.notesWidth` or equivalent.
- Runs full height of the 2×2 grid (top row + bottom row).
- Moves both columns simultaneously.
- Min: left column 200px. Max: left column 500px.

**2. Horizontal divider (between top and bottom rows):**
- **NEW: Must become draggable.**
- Drag handle: a 12px-tall strip between the top and bottom rows.
- Visual: 1px semantic soft divider top line, 1px semantic soft divider bottom line, with a 10px active drag area in between.
- On hover: cursor changes to `resizeUpDown` (pointing hand with vertical arrows).
- Drag gesture updates `vm.topRowRatio` (float, 0.3–0.8).
- Dragging the horizontal divider resizes all 4 quadrants simultaneously.
- Min top row height: 30% of available height. Max: 80%.
- Min bottom row height: 20% of available height. Max: 70%.
- Default: 55% top / 45% bottom (**changed from 65/35** — more balanced).
- Smooth, real-time resize during drag (no snap, no animation, instant following of cursor).

**3. Combined behavior:**
- Both dividers are independent and can be moved simultaneously (though in practice, the user moves one at a time).
- Window resize respects divider positions as ratios (not absolute pixel values), so resizing the window preserves the user's preferred layout proportions.
- The 4 quadrants freely resize based on both divider positions.

### Acceptance Criteria
- [ ] Horizontal divider is draggable with `resizeUpDown` cursor on hover.
- [ ] Drag handle is 12px tall and visually clear.
- [ ] Dragging horizontal divider smoothly resizes top/bottom rows.
- [ ] Top row range: 30%–80%. Bottom row range: 20%–70%.
- [ ] Default split: 55/45 (top/bottom).
- [ ] Window resize preserves user's divider ratios.
- [ ] Both dividers work independently and simultaneously.

---

## 4. Beautiful, Polished UI

**Founder's exact words:**
> "现在的界面怎么这么丑呢"

**Translation:** The current interface is so ugly.

### Why v1.1-r1 Failed
The UI used hardcoded hex colors everywhere (`#5A5A5A`, `#C0C0C0`, `#E8E8E8`, `#F8F8F8`), basic SwiftUI shapes, no design system, no animations, and no attention to visual detail. It looked like a prototype, not a professional app.

### Exact Requirements (v1.1-r3)

**1. Design system — Create a centralized design token system:**
- Define colors as semantic tokens (not hardcoded hex):
  - `appBackground` (soft page blue)
  - `surfacePrimary` (clean white document surface)
  - `surfaceSecondary` (soft blue header fill)
  - `pastelBlue` / `pastelBlueStrong` (primary learning/AI surface)
  - `pastelGreen` / `pastelGreenBorder` (legacy aliases mapped to the Grasp blue system)
  - `pastelYellow` / `pastelYellowBorder` (legacy warning only; do not use in the main live lecture UI)
  - `pastelPink` (AI activity, rich/detail, warm assistive state)
  - `textPrimary` (near-black)
  - `textSecondary` (medium gray)
  - `textTertiary` (light gray)
  - `accentBlue` (action blue)
  - `accentPurple` (AI/highlight purple)
  - `divider` (border lines)
  - `selection` (text selection highlight)
- Define typography as semantic tokens:
  - `body` (14pt rounded macOS system font)
  - `caption` (11pt rounded macOS system font)
  - `small` (10pt rounded macOS system font)
  - `title` (16pt rounded macOS system font semibold)
- Define spacing as 4px grid:
  - `xs: 4`, `sm: 8`, `md: 12`, `lg: 16`, `xl: 24`, `xxl: 32`

**2. Visual polish:**
- Proper corner radii on all cards (8px standard, 12px for popups).
- Subtle shadows (`NSShadow` or SwiftUI shadow) with low opacity on floating elements (popup, cards).
- Smooth 200ms ease-in-out animations on all state transitions (show/hide, add/remove).
- Consistent padding using the 4px grid system — no arbitrary padding values.
- Proper `NSScrollView` integration for smooth scrolling everywhere.
- Use `VisualEffectView` (NSVisualEffectView) for floating/overlay elements to match macOS design language.

**3. Color palette refresh:**
| Token | Old color | New color | Usage |
|-------|-----------|-----------|-------|
| appBackground | `#F8F8F8` | `#F8FBFF` | App shell and sidebar |
| surfacePrimary | `#FFFFFF` | `#FFFFFF` | Main document/card backgrounds |
| surfaceSecondary | `#F8F8F8` | `#F1F8FF` | Header backgrounds, secondary fills |
| pastelBlue | `#E8F0FE` | `#EAF5FF` | Primary selected/learning surface |
| pastelGreen | n/a | `#EAF5FF` | Legacy alias for soft blue balanced state |
| pastelGreenBorder | n/a | `#CFEAFF` | Legacy alias for soft blue border |
| pastelYellow | n/a | `#FFF4CC` | Legacy warning only, not live lecture UI |
| pastelYellowBorder | n/a | `#E8C85C` | Legacy warning border only |
| pastelPink | n/a | `#FFE8EF` | AI writing/detail assistive state |
| textPrimary | `#0A0A0A` | `#202124` | Body text |
| textSecondary | `#5A5A5A` | `#626B78` | Labels, subtitles |
| textTertiary | `#C0C0C0` | `#98A1AD` | Placeholder text |
| accentBlue | `#1A5FD4` | `#2384E8` | Primary action, active learning state |
| accentPurple | `#7C3AED` | `#B57BE8` | Secondary AI accent only |
| divider | `#E8E8E8` | `#DDEAF6` | Soft separator lines |
| selection | `#E8F0FE` | `#DDF0FF` | Selected/highlighted backgrounds |

Blue should be the primary brand color for Grasp because it feels focused, trustworthy, and study-oriented. The current app blue system is: primary `#2384E8`, soft fill `#EAF5FF`, and soft border `#CFEAFF`. Green should not appear in the live lecture UI; legacy green token names are kept only as compatibility aliases and mapped to blue. Pink should be used sparingly for AI activity or richer/detail states. Filled controls must use same-hue borders: blue fill with blue border, pink fill with pink border.

**4. Typography:**
- Use rounded macOS system typography for app UI and the native notes editor. The bundled Inter font may remain for compatibility, but the visible product font should feel softer and more Apple-like.
- Proper font weights: Regular (400), Medium (500), Semibold (600), Bold (700).
- Line heights: 1.45× font size for body text, 1.2× for headings.
- Letter spacing must remain `0`; do not use negative tracking with the rounded typeface.

**5. Animations:**
- All view transitions: `.animation(.easeInOut(duration: 0.2), value: state)`.
- New content appearing: fade + slight vertical slide (5px offset).
- Content disappearing: fade + slight scale down (0.95).
- Divider drag: instant, no animation (follows cursor exactly).
- Popup appear/disappear: fade + scale (1.0 → 1.02 → 1.0).

**6. Layout polish:**
- Proper margins: 16px horizontal padding in quadrants (was 12px in v1.1-r1).
- Consistent 8px spacing between elements.
- 12px padding inside cards.
- Header height: 32px (was variable — standardize).
- Proper hit targets: minimum 32×32 for buttons.

**7. macOS native feel:**
- Title bar integration: use `.windowToolbarStyle(.unified)` for compact look.
- Proper resize cursors on dividers.
- Native scrollbar styling (no custom scrollbar override).
- Proper window shadow and corner radius (standard macOS window).

### Acceptance Criteria
- [ ] Design token system implemented as Swift constants/enums.
- [ ] All hardcoded hex colors replaced with semantic tokens.
- [ ] Consistent 4px grid spacing throughout the app.
- [ ] Smooth 200ms animations on all state transitions.
- [ ] Proper corner radii (8px cards, 12px popups).
- [ ] Subtle shadows on floating elements.
- [ ] Professional color palette matches new spec.
- [ ] Main theme uses soft blue as the primary app color, white for document surfaces, and pink only for AI/rich states.
- [ ] Filled pastel controls use color-matched borders; green is not used in the live lecture UI.
- [ ] Consistent typography with proper line heights.
- [ ] UI and notes editor use rounded macOS system typography; no negative tracking.
- [ ] macOS-native scrollbar and window styling.
- [ ] Transcript, AI Notes, Auto Explain, and Cold Call / Save / Search use one unified panel header component.
- [ ] Each of the four live quadrants has a visible settings gear in the top-right of its panel header.

---

## 5. Layout — 2×2 Grid with ALL Movable Dividers

### ASCII Diagram

```
┌────────────────────────────────────────────────────────┐
│ TopBarView  [unchanged]                                 │
├──────┬──────────────────────┬───────────────────────────┤
│      │                       │                           │
│ Side │  TRANSCRIPT           │  AI NOTES                │
│ bar  │  (top-left)           │  (top-right)             │
│      │   • sealed blocks     │   • Apple Notes-style    │
│      │   • active block      │   • rich text inline     │
│      │   • interim text      │   • click to edit        │
│      │   • translation       │   • flat, no bullets     │
│      │                       │                           │
│      ├── ◀── DRAG ──▶       ├── ◀── DRAG ──▶          │
│      │  (horizontal divider) │  (horizontal divider)    │
│      │                       │                           │
│      │  AUTO EXPLAIN         │  CONTEXTUAL              │
│      │  (bottom-left)        │  (bottom-right)          │
│      │  ★ always visible     │   priority chain:        │
│      │  ★ never hidden       │   1. Cold Call Card      │
│      │    behind a tab       │   2. Save Card           │
│      │                       │   3. Search Card         │
│      │                       │   4. Empty placeholder   │
├──────┴──────────────────────┴───────────────────────────┤
│ Bottom Panel (UNCHANGED — tabs + CC column)              │
└────────────────────────────────────────────────────────┘
```

### Dimensions

| Region | Default Ratio | Resizable? | Range | Notes |
|--------|---------------|------------|-------|-------|
| Top row (Transcript + Notes) | **55%** of window height | **Yes** — draggable horizontal divider | 30%–80% | Default changed from 65% to 55% |
| Bottom row (AutoExplain + Contextual) | **45%** of window height | **Yes** — linked to top row | 20%–70% | Default changed from 35% to 45% |
| Left column (Transcript + AutoExplain) | **55%** of window width | **Yes** — draggable vertical divider | Left min: 200px, Left max: 500px | Unchanged from v1.1-r1 |
| Right column (Notes + Contextual) | **45%** of window width | **Yes** — linked to left column | Derived from left width | Unchanged from v1.1-r1 |

### Divider Specs

| Divider | Location | Thickness | Visual | Interaction |
|---------|----------|-----------|--------|-------------|
| **Vertical** ⬥ | Between left/right columns, full height of both rows | 1px line + 4px hit area (total 5px) | Line fill `#E5E5E5`. On hover: 2px `#2563EB` accent line appears. | Drag gesture → updates `vm.notesWidth`. Affects both rows simultaneously. Cursor: `resizeLeftRight`. |
| **Horizontal** ⬥ | Between top/bottom rows | 1px line + 10px hit area (total 12px) | 1px `#E5E5E5` top, 1px `#E5E5E5` bottom, 10px transparent drag area. On hover: accent highlight. | **NEW: Draggable.** Drag gesture → updates `vm.topRowRatio`. Affects both columns simultaneously. Cursor: `resizeUpDown`. |

### Quadrant Behavior Summary

| Quadrant | View | Always visible? | Content |
|----------|------|-----------------|---------|
| Top-left | `TranscriptPanelView` | Yes | Sealed blocks + active block + interim text + translation inline |
| Top-right | `NotesPanelView` | Yes | **Apple Notes-style** rich text editor — flat, inline editable, no bullets |
| Bottom-left | `AutoExplainBottomQuadrant` | Yes — **never removed from hierarchy** | Idle placeholder OR `AutoExplainCardView`. Header always shows "AUTO EXPLAIN" |
| Bottom-right | `ContextualBottomQuadrant` | Yes — **always present in hierarchy** | One of: `ColdCallCardView` > `SaveCardView` > `SearchCardView` > empty placeholder |

### Window Resize Behavior

- Ratios scale proportionally — divider positions are stored as ratios, not pixels.
- Minimum window: 960×640. Below this, left column may clip (min 200px enforced).
- Top/bottom ratios preserved on window resize.

---

## 6. Bug Fixes (carried forward from v1.1-r1)

| Bug | Fix |
|-----|-----|
| Inter font not bundled | Build script copies `Inter.ttc` to app bundle |
| Translation race in `handleSaveAction` | `SaveDraft` created after async translation completes (not synchronously) |
| `interimText` never populated | `handleInterim` sets `interimText = t` |
| Transcription duplication | Removed `interimText` concatenation in `BlockView` |
| Auto Explain polluting search history | Removed `db.saveSearch` from `autoExplain()` |
| Keyboard shortcuts not wired up | All 5 documented shortcuts (`⌘⇧P`, `⌘⇧K`, `⌘⇧L`, `⌘⇧E`, `⌘⇧X`) implemented |

**Note:** The selection popup NotificationCenter fix from v1.1-r1 is **replaced** by the new instant-popup approach (Section 1). The old 80ms debounce fix is obsolete.

---

## 7. Keyboard Shortcuts

| Shortcut | Action | Notes |
|----------|--------|-------|
| `⌘⇧P` | Pause/Resume transcription | Unchanged |
| `⌘⇧F` | Toggle full transcript view | Unchanged |
| `⌘N` | New lecture / New note (in notes panel) | Unchanged |
| `⌘⇧N` | Focus notes panel | Unchanged |
| `⌘⇧K` | Save selected text as Knowledge | Unchanged |
| `⌘⇧L` | Save selected text as Language | International mode only |
| `⌘⇧E` | Trigger Instant Search on selected text | Unchanged |
| `⌘B` | Bold (in notes rich text editor) | **NEW** |
| `⌘I` | Italic (in notes rich text editor) | **NEW** |
| `⌘U` | Underline (in notes rich text editor) | **NEW** |
| `Esc` | Dismiss selection popup / current card | Unchanged |
| `⌘⇧A` | Focus auto-explain panel | Unchanged |
| `⌘⇧C` | Show/hide cold call card | Unchanged |

---

## 8. Known Issues (pre-existing, unchanged from v1.1-r1)

| Issue | Severity | Notes |
|-------|----------|-------|
| `DatabaseService` not thread-safe (no locking) | HIGH | Raw `sqlite3_open` — no WAL, no mutex, no serialization queue. Concurrent `Task` access can corrupt DB. |
| `@Published` vars written from `URLSession` background queue | MEDIUM | `streamingTokens`, `autoExplainTokens` written off main thread. Causes missed/delayed UI updates. |
| `DeepgramService.pending` array race (audio vs main thread) | MEDIUM | Concurrent reads/writes on `pending` array with no synchronization. |
| UTF-8 byte-by-byte SSE decoding | MEDIUM | Multi-byte characters (non-ASCII) lost during SSE streaming decode. |
| Export blocks main thread | LOW | `NSMutableAttributedString` build on main thread — freezes UI for lectures with large transcripts. |
| No WebSocket reconnection on network drop | LOW | Deepgram WebSocket disconnect does not auto-reconnect. User must manually restart transcription. |
| Settings toggles (font size, show translation, hover freeze) disconnected | LOW | UI controls exist but have no effect on the rendering. |
| No unit tests | — | Entire codebase has zero unit or UI tests. |

---

## 9. Non-Goals (v1.1-r2)

- No mobile app (iOS/Android)
- No cloud sync or user accounts
- No offline transcription
- No custom model fine-tuning
- No export formats beyond RTF
- No bottom panel modification (kept exactly as v1.0)
- No removal of redundant bottom-panel tabs (Auto tab, Current tab — kept for now)
- **No hierarchical concept maps** — explicitly removed per Founder's requirements
- **No bullet lists in notes** — explicitly removed per Founder's requirements
- **No indented outlines** — explicitly removed per Founder's requirements

---

## Appendix A: Files to Modify

| File | Change |
|------|--------|
| `Grasp/Views/Notes/NotesPanelView.swift` | **Full rewrite** — remove concept map tree, build Apple Notes-style rich text editor |
| `Grasp/Views/Transcript/TranscriptPanelView.swift` | Remove 80ms `asyncAfter` debounce. Replace with instant synchronous popup. |
| `Grasp/Views/Layout/LiveTabView.swift` | Add draggable horizontal divider. Update layout helpers for top/bottom ratio. |
| `Grasp/Models/AppViewModel.swift` | Remove `conceptMap` property and all tree-related methods. Add `topRowRatio` property. Add rich text support. |
| `Grasp/Models/ConceptNode.swift` | **Delete file** — concept map data model no longer needed. |
| `Grasp/Models/NoteBlock.swift` | Update to support rich text storage (RTF/HTML). |
| `Grasp/Design/DesignTokens.swift` | **New file** — centralized design tokens (colors, fonts, spacing). |
| `Grasp/Views/Components/SelectionPopupView.swift` | Rewrite for instant appearance, NSVisualEffectView, pill shape. |

## Appendix B: Files to Delete

| File | Reason |
|------|--------|
| `Grasp/Models/ConceptNode.swift` | Concept map model — Founder explicitly rejected hierarchical notes |
| Any remaining code that renders concept tree, indented bullets, or depth-based layout | Replaced by flat rich text notes |

## Appendix C: Acceptance Test Script

### Test 1: Selection Popup Speed & Consistency
1. Start a lecture with active transcription.
2. Select any 2+ characters in the transcript.
3. **Expected:** Popup appears immediately (no perceptible delay).
4. Verify no `asyncAfter` or `DispatchQueue` delay in the selection handler.
5. **Expected:** Popup shows 4 buttons (K, L, Search, Note) with consistent styling — all icon+label or all icon-only, no mixing.
6. Click the Note button → selected text is copied to a new note in the Notes panel.

### Test 2: Apple Notes Behavior
1. Open the Notes panel.
2. **Expected:** Flat white panel, no bullets, no indentation.
3. Click on an empty/whitespace area in the notes panel → **Expected:** A new blank note appears with blinking cursor.
4. Click on an existing note → **Expected:** It becomes editable in place immediately (blinking cursor).
5. Double-click an existing note → **Expected:** Edit mode + word under cursor is selected.
6. Type text. Press ⌘B → bold. Press ⌘I → italic.
7. Press Enter → new note appears below.
8. Press Shift+Enter → line break within the same note.
9. Click elsewhere → changes are saved.
10. Verify RTF/HTML persistence by reloading the lecture.
11. Verify no conflicting `.onTapGesture` on the Notes panel container VStack/ScrollView.
12. Verify `editingId` is set synchronously (no `DispatchQueue.main.asyncAfter` in the click-to-edit path).

### Test 3: All Dividers Movable
1. Drag the vertical divider → left/right columns resize.
2. Drag the horizontal divider → top/bottom rows resize.
3. Verify horizontal drag works smoothly.
4. Verify min/max constraints: top row 30%–80%, left column 200px–500px.
5. Resize the window → divider ratios are preserved.

### Test 4: UI Polish
1. Verify consistent spacing (4px grid throughout).
2. Verify no hardcoded hex colors (all use design tokens).
3. Verify smooth 200ms animations on all state transitions.
4. Verify proper corner radii (8px cards, 12px popups).
5. Verify shadows on floating elements.
6. Visually compare to Apple Notes for fit and finish.
