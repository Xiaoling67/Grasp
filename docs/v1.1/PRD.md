# Grasp — PRD v1.1 (Founder's Revision)

**Version:** 1.1-r2
**Date:** 2026-06-27
**Platform:** macOS 14.0+ | Swift 5.9 | SwiftUI + AppKit
**Status:** In development — rewrite to match Founder requirements
**Window:** Single-window app, default 1280×800, minimum 960×640

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
| **Selection popup** | Broken (NSEvent) | Fixed via NotificationCenter with **80ms debounce**. Slow, unresponsive. | **Instant** popup. No debounce. Direct synchronous tracking. Appears immediately on selection. |
| **AI Notes** | Flat per-seal notes, ≤25 words, level 0/1/2 | **Concept Map** — hierarchical tree with indented bullets, parent/child/depth indentation. **Founder hates it.** | **Apple Notes clone** — smooth scrolling, inline editing, rich text. No tree. No indented bullets. No custom hierarchy. |
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
- Three buttons in a pill-shaped toolbar:
  - **Search** (AI definition + analogy)
  - **Save as Knowledge (K)** — saves to SQLite, adds to Knowledge Profile
  - **Save as Language (L)** — only visible in International mode
- Buttons use SF Symbols + short labels.
- Background: `NSVisualEffectView` material (vibrant light) with rounded corners (10px).
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
- [ ] Popup buttons (Search / K / L) work correctly.

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
- No bullet characters (▸, •, ◦) — notes are plain rich-text blocks.
- No concept hierarchy rendering — all notes displayed as a flat, scrollable list of rich text entries.
- Header area with "AI NOTES" label (same style as Apple Notes' title area).
- Smooth scrolling with rubber-banding at edges (native NSScrollView behavior).

**2. Inline editing EXACTLY like Apple Notes:**
- **Click to edit** — tap anywhere on a note's text content to enter edit mode.
- Edit in place — no separate text field, no modal, no sheet. The text itself becomes editable.
- **Rich text support** — bold, italic, underline, strikethrough (via keyboard shortcuts ⌘B, ⌘I, ⌘U).
- **NSTextView-based** editing, not SwiftUI TextField. Use AppKit's NSTextView for native text editing behavior.
- **Auto-save on blur** — edits committed when focus leaves the note.
- **Return/Enter** — creates a new note below (like Notes app creates a new line within the note, but for Grasp: Enter should create a new note entry within the current note block).
- **Shift+Return** — line break within the same note.
- **Delete empty note** — if a note becomes empty on blur, remove it (like Notes app removes empty entries).

**3. AI-generated notes appear as editable rich text blocks:**
- Each AI note is a rich text block in the flat list.
- AI notes are pre-populated with content, fully editable.
- When AI generates a new note, it slides in with a smooth animation (opacity + slight vertical offset).
- New notes are distinguished by a subtle blue left border (2px, `#1A5FD4`) on the left edge — this fades after 5 seconds.
- After edit, the note is marked as `manual` and the blue border is removed.

**4. User-created notes:**
- Click the "+" button in the header (or press ⌘N) to create a new blank note.
- New note appears with cursor blinking, ready for typing.
- No blue border (user notes are never shown as "new").

**5. Scrolling behavior:**
- Native NSScrollView with smooth scrolling.
- Velocity-based deceleration.
- Rubber-banding at content edges.
- Auto-scroll to bottom when a new AI note arrives (unless user has scrolled up manually).

**6. Note deletion:**
- Hover over a note → subtle "×" button appears in the top-right corner of the note frame.
- Click "×" → note is deleted with a fade-out animation.
- **Backspace on empty note** — if the user empties a note and presses backspace (or blurs), the note is deleted.

**7. Rich text persistence:**
- Notes are saved as **HTML** or **RTF** in SQLite (not plain text), preserving rich text formatting.
- On reload, rich text is restored exactly as edited.

**8. Legacy data compatibility (v1.0 flat notes):**
- Old v1.0 notes are rendered as plain rich text blocks (no hierarchy).
- The concept map data model is **deleted** — no `ConceptNode`, no `conceptMap`, no tree structures.
- All notes become a flat array of editable rich text blocks.

### What to DELETE from codebase
- `ConceptNode` struct (data model)
- `ConceptNodeRow` view
- `buildConceptTree()` method
- `flattenNode()` method
- `collectChildren()` method
- `conceptNodeView()` method
- `conceptSlideSection()` method
- `buildConceptTree` call in `NotesPanelView`
- All level/indent/bullet logic in `NoteRow`
- `ConceptMap` related properties in `AppViewModel`
- Any code that renders hierarchical indentation

### What to BUILD
- Flat rich text editor using `NSTextView` wrapped in `NSViewRepresentable`
- Apple Notes-style visual layout (no bullets, no indentation)
- Inline editing with click-to-edit
- Rich text toolbar or keyboard shortcuts (⌘B, ⌘I, ⌘U)
- Smooth animations for add/remove notes
- Proper focus management between notes

### Acceptance Criteria
- [ ] Notes panel looks EXACTLY like Apple Notes — flat, white, no bullets, no indent.
- [ ] Click any note text → instantly editable in place.
- [ ] Rich text support: ⌘B bold, ⌘I italic, ⌘U underline work inside notes.
- [ ] Enter creates new note below within the note block.
- [ ] Shift+Enter creates line break within the same note.
- [ ] Auto-save on blur — edits persisted to SQLite.
- [ ] New AI notes slide in with animation.
- [ ] Blue left border on new AI notes, fades after 5 seconds.
- [ ] Hover "×" button on each note for deletion.
- [ ] Smooth scrolling with rubber-banding at edges.
- [ ] Notes persisted as RTF/HTML (rich text preserved on reload).
- [ ] All concept map / tree code is removed from the codebase.

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
- Visual: 1px `#E8E8E8` top line, 1px `#E8E8E8` bottom line, with a 10px active drag area in between.
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

### Exact Requirements (v1.1-r2)

**1. Design system — Create a centralized design token system:**
- Define colors as semantic tokens (not hardcoded hex):
  - `surfacePrimary` (white)
  - `surfaceSecondary` (light gray)
  - `textPrimary` (near-black)
  - `textSecondary` (medium gray)
  - `textTertiary` (light gray)
  - `accentBlue` (action blue)
  - `accentPurple` (AI/highlight purple)
  - `divider` (border lines)
  - `selection` (text selection highlight)
- Define typography as semantic tokens:
  - `body` (13pt Inter)
  - `caption` (11pt Inter)
  - `small` (10pt Inter)
  - `title` (14pt Inter semibold)
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
| surfacePrimary | `#FFFFFF` | `#FFFFFF` | Main backgrounds |
| surfaceSecondary | `#F8F8F8` | `#F5F5F5` | Header backgrounds, secondary fills |
| textPrimary | `#0A0A0A` | `#1A1A1A` | Body text |
| textSecondary | `#5A5A5A` | `#6B6B6B` | Labels, subtitles |
| textTertiary | `#C0C0C0` | `#9E9E9E` | Placeholder text |
| accentBlue | `#1A5FD4` | `#2563EB` | Buttons, links, selection highlight |
| accentPurple | `#7C3AED` | `#7C3AED` | AI indicator (unchanged, good) |
| divider | `#E8E8E8` | `#E5E5E5` | Separator lines |
| selection | `#E8F0FE` | `#DBEAFE` | Selected/highlighted backgrounds |

**4. Typography:**
- Use Inter font throughout (already bundled).
- Proper font weights: Regular (400), Medium (500), Semibold (600), Bold (700).
- Line heights: 1.4× font size for body text, 1.2× for headings.
- Proper letter-spacing: `-0.01em` for body text (Apple HIG standard).

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
- [ ] Consistent typography with proper line heights.
- [ ] macOS-native scrollbar and window styling.

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

### Test 1: Selection Popup Speed
1. Start a lecture with active transcription.
2. Select any 2+ characters in the transcript.
3. **Expected:** Popup appears immediately (no perceptible delay).
4. Verify no `asyncAfter` or `DispatchQueue` delay in the selection handler.

### Test 2: Apple Notes Behavior
1. Open the Notes panel.
2. **Expected:** Flat white panel, no bullets, no indentation.
3. Click on a note → it becomes editable in place.
4. Type text. Press ⌘B → bold. Press ⌘I → italic.
5. Press Enter → new note appears below.
6. Press Shift+Enter → line break within the same note.
7. Click elsewhere → changes are saved.
8. Verify RTF/HTML persistence by reloading the lecture.

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
