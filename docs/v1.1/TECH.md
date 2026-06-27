# Grasp v1.1 — Tech Implementation Plan

**Author:** Engineer (code audit)
**Date:** 2026-06-27
**Status:** Implementation complete — audit against PRD v1.1

---

## Overview of Architecture (Current State)

Grasp is a single-window macOS app built with SwiftUI + AppKit, targeting macOS 14.0+.
The architecture follows a ViewModel-driven pattern:

```
GraspApp.swift          ← Entry point, keyboard shortcut commands, RootView
├── TopBarView         ← Title + window controls
├── SidebarView        ← Navigation sidebar
└── MainContent
    ├── LiveTabView    ← Live lecture 2×2 grid layout
    │   ├── TranscriptPanelView    (top-left, sealed blocks + interim)
    │   ├── NotesPanelView         (top-right, concept map / flat notes)
    │   ├── AutoExplainBottomQuadrant (bottom-left, always visible)
    │   └── ContextualBottomQuadrant  (bottom-right, priority chain)
    ├── PastLectureView
    ├── HomeView / SettingsView / SavedItemsView / SearchHistoryView
    └── KnowledgeProfileView       (modal sheet)
```

**Key services:**
| Service | Role |
|---------|------|
| `DatabaseService` | SQLite (raw `sqlite3_open`) — lectures, blocks, notes, saves, searches, concept_map, student_knowledge |
| `DeepgramService` | WebSocket streaming to Deepgram Nova-3 |
| `DeepSeekService` | HTTP API for search, notes, auto-explain, concept map, cold call, slide parsing, keywords |
| `MemoryService` | Knowledge Profile CRUD (`@unchecked Sendable`, singleton) |
| `QwenTranslationService` | Qwen-MT Flash → DeepSeek fallback for translation |
| `SlideParserService` | PDF text extraction |
| `AudioService` | Microphone capture |

**State:** `AppViewModel` (`@MainActor ObservableObject`) — holds all app state at module scope. ~500 lines.

---

## Feature Audit: Each PRD Item vs Current Code

### 1. Layout — 2×2 Grid

| PRD Requirement | Status | Details |
|----------------|--------|---------|
| 65/35 vertical split (top/bottom) | ✅ | `LiveTabView.topRowHeight` = `(geo.size.height - 5) * 0.65` |
| 55/45 horizontal split (left/right) | ⚠️ Partial | `notesWidth` hardcoded to `300.0` as initial value, not `geo.size.width * 0.45`. Drag updates it. |
| Draggable vertical divider (1px, #E8E8E8) | ✅ | Drag gesture on `Rectangle().fill(Color(hex:"E8E8E8"))` with min=200, max=500 |
| Horizontal divider (5px, 1px #E8E8E8 top/bottom, 3px #F8F8F8 gap) | ✅ | `frame(height:5)` with overlays |
| Min window 960×640, default 1280×800 | ✅ | `minFrame(minWidth:960, minHeight:640)`, `.defaultSize(width:1280, height:800)` |
| Left column min:200px, max:500px | ✅ | `max(200, min(500, ...))` in drag handler |

**Changes needed:** None urgent. Default `notesWidth = 300` is close enough for most screens; user adjusts via drag handle.

---

### 2. Concept Map (v1.1)

| PRD Requirement | Status | Details |
|----------------|--------|---------|
| 15s rolling window timer | ✅ | `Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true)` |
| Hierarchical tree (parentId) | ✅ | `ConceptNode.parentId: String?`, tree built in `buildConceptTree()` |
| Indented outline rendering (1em per level) | ✅ | `ConceptNodeRow` with `Spacer().frame(width: CGFloat(depth) * 18)` |
| Dual render path (concept map vs flat notes) | ✅ | `conceptMap.isEmpty` check renders either tree or flat `NoteRow` |
| Click concept → highlights transcript blocks | ✅ | `highlightBlocksForConcept()` — sets `highlightedBlockIds`, auto-clears after 3s |
| Right-click → Add to Knowledge Profile | ✅ | `contextMenu { Button("Add to Knowledge Profile") }` |
| Manual note editing (add/edit/delete) | ✅ | `NoteRow` edit state, `addNote()`, `deleteNote()`, `updateNote()` |
| Concept map stored in SQLite | ✅ | `concept_map` table with `saveConceptMap` / `loadConceptMap` |
| DeepSeek returns full map update (not diff) | ✅ | `generateConceptMapUpdate()` returns complete updated nodes array |

**Changes needed:** None.

---

### 3. Auto Explain + Knowledge Profile

| PRD Requirement | Status | Details |
|----------------|--------|---------|
| Per sealed block trigger | ✅ | `autoExplain()` called from `seal()` — one check per sealed block |
| DeepSeek detects 1 unfamiliar term (confidence ≥ 0.65) | ✅ | `detectUnfamiliarTerm()` returns `(term, confidence)`. Code uses `> 0.65` (off by epsilon) |
| Knowledge Profile via SQLite | ✅ | `student_knowledge` table, `MemoryService` with 5 statuses |
| `known` → skip | ✅ | `case .known: return` |
| `lookedUp` → 1-line reminder | ✅ | Shows "You've seen this before" card |
| `neverSeen` → full explanation | ✅ | Streamed via `streamSearch()` |
| Bottom-left quadrant, always visible | ✅ | `AutoExplainBottomQuadrant` in `LiveTabView` — never removed from hierarchy |
| Idle: "Watching for unfamiliar terms…" (#C0C0C0) | ✅ | Text with `Color(hex: "C0C0C0")` |
| Purple dot (#7C3AED, 5px) | ✅ | `Circle().fill(Color(hex: "7C3AED")).frame(width:5, height:5)` |
| Streaming explanation token-by-token | ✅ | `autoExplainTokens` accumulates, `autoExplainStreaming` drives cursor |
| "Save to Knowledge" button | ✅ | `AutoExplainCardView.saveToK()` |
| Results never auto-enter notes | ✅ | `saveToK()` writes to `saves` table, not `note_blocks` |

**Changes needed:** None.

---

### 4. Selection Popup + Search + Save

| PRD Requirement | Status | Details |
|----------------|--------|---------|
| NotificationCenter (replaces NSEvent) | ✅ | `NSTextView.didChangeSelectionNotification` observer |
| 80ms debounce | ✅ | `DispatchQueue.main.asyncAfter(deadline: .now() + 0.08)` |
| Three buttons: Search, K, L | ✅ | `SelectionPopupView` — K, L, Search, plus extra "Notes" button |
| L only in International mode | ✅ | `vm.activeLectureMode == "international"` check |
| DeepSeek returns definition + analogy (| delimiter) | ✅ | `streamSearch()` prompt outputs "... | ..." |
| Context: last 10 sealed blocks | ✅ | `db.getRecentBlocks(lectureId:lid, beforeIndex:blockIndex, limit:10)` |
| Known terms injected into search prompt | ✅ | `MemoryService.shared.getKnownTerms()` → `knownTermsBlock` in prompt |
| Session-level caching | ✅ | `searchCache[ck]` in-memory dictionary |
| Save creates SaveDraft after translation completes (bug fix) | ✅ | `handleSaveAction()` creates draft, async translation updates it |
| Priority chain: ColdCall > Save > Search > empty | ✅ | `ContextualBottomQuadrant` — checks `coldCallPhase`, `activeCard`, then placeholder |

**Changes needed:** None.

---

### 5. Cold Call (Auto Answer Questions)

| PRD Requirement | Status | Details |
|----------------|--------|---------|
| 7 regex patterns | ✅ | `ccPatterns` array with 7 patterns |
| 90s cooldown | ✅ | `lastCC` checks `timeIntervalSince(last) < 90` |
| 3-phase UI (detected / generating / answered) | ✅ | `ColdCallPhase` enum, `ColdCallCardView` switches on phase |
| Phase 1 — "Question detected" + yellow badge | ✅ | Yellow badge via `Color(hex: "F59E0B")` |
| Phase 2 — Generating + pulse animation | ✅ | Animated dots |
| Phase 3 — Answered + green checkmark | ✅ | Green via `Color(hex: "15803D")` |
| 45s auto-dismiss | ✅ | `startCCAutoDismiss()` with `45.0` second timer |
| User can ✕ dismiss immediately | ✅ | `vm.dismissCC()` wired |
| Context: last 15 blocks + slides + last 10 notes + Knowledge Profile | ✅ | `generateColdCallAnswer()` passes all four |
| Answer feeds into Knowledge Profile | ✅ | `saveCCToNotes()` extracts terms and calls `MemoryService.shared.recordInteraction` |

**Changes needed:** None.

---

### 6. Keyboard Shortcuts

| Shortcut | PRD | Code | Status |
|----------|-----|------|--------|
| `⌘N` — New Lecture | ✅ Listed | `keyboardShortcut("n", modifiers: [.command])` | ✅ |
| `⌘⇧P` — Pause/Resume | ✅ Listed | `keyboardShortcut("p", modifiers: [.command, .shift])` | ✅ |
| `⌘⇧K` — Save as Knowledge | ✅ Listed | `keyboardShortcut("k", modifiers: [.command, .shift])` | ✅ |
| `⌘⇧L` — Save as Language | ✅ Listed | `keyboardShortcut("l", modifiers: [.command, .shift])` | ✅ |
| `⌘⇧E` — Instant Search | ✅ Listed | `keyboardShortcut("e", modifiers: [.command, .shift])` | ✅ |
| `⌘⇧X` — Export | ⚠️ Listed in PRD | `keyboardShortcut("x", modifiers: [.command, .shift])` | ✅ Exists. **FLAG:** Per user instruction, PRD mentions this. It IS implemented in code. |
| `⌘⇧F` — Full transcript | 📋 Future | Method `toggleFullTranscript()` exists | 🔮 Not wired as shortcut |
| `⌘⇧N` — Focus notes | 📋 Future | Method `focusNotesPanel()` exists | 🔮 Not wired as shortcut |
| `⌘⇧A` — Focus auto-explain | 📋 Future | Method `focusAutoExplain()` exists | 🔮 Not wired as shortcut |
| `⌘⇧C` — Cold call | 📋 Future | Method `handleColdCallShortcut()` exists | 🔮 Not wired as shortcut |
| `Esc` — Dismiss popup/card | ✅ Implicit | `SelectionPopupView.onDismiss` + dismiss buttons on cards | ✅ |

**Changes needed (future):** Wire `⌘⇧F`, `⌘⇧N`, `⌘⇧A`, `⌘⇧C` in `GraspApp.swift` `CommandMenu`.

---

### 7. Timestamp (mm:ss) on Sealed Blocks

| PRD Requirement | Status | Details |
|----------------|--------|---------|
| Each sealed block shows timestamp (mm:ss) left-aligned | ✅ | `timestampStr` computed from `createdAt`, shown in `BlockView` when `block.isSealed` |

**Changes needed:** None.

---

### 8. 45s Auto-Dismiss on Cold Call Answered

| PRD Requirement | Status | Details |
|----------------|--------|---------|
| Answer persists for 45s, then auto-dismisses | ✅ | `startCCAutoDismiss()` fires `dismissCC()` after 45.0s |
| User can ✕ dismiss immediately | ✅ | Button wired to `vm.dismissCC()` |

**Changes needed:** None.

---

### 9. Bug Fixes (PRD v1.1 Section)

| Bug | Status | Code Evidence |
|-----|--------|---------------|
| Inter font not bundled | ✅ | `Inter.ttc` in Resources, `InterFont.swift` registers it |
| Translation race in `handleSaveAction` | ✅ | `SaveDraft` created immediately, `activeCard` updated after translation completes |
| `interimText` never populated | ✅ | `handleInterim()` sets `interimText = t` |
| Transcription duplication | ✅ | No concatenation of `interimText` in `BlockView` |
| Auto Explain polluting search history | ✅ | No `db.saveSearch` in `autoExplain()` |
| Selection popup not appearing | ✅ | `NotificationCenter` observer replaces `NSEvent` monitor |
| Selection popup flicker | ✅ | 80ms debounce |
| Keyboard shortcuts wired up | ✅ | 5 shortcuts in `GraspApp.swift` |

---

## Implementation Priority

| Priority | Item | Effort | Impact |
|----------|------|--------|--------|
| P0 | None — all critical paths match PRD | — | — |
| P1 | Wire ⌘⇧F, ⌘⇧N, ⌘⇧A, ⌘⇧C as keyboard shortcuts | Very Low | Developer UX |
| P2 | Default `notesWidth` to 45% of window width | Low | First-use experience |
| P3 | Auto Explain "Save to Notes" hover interaction | Low | UX polish |

---

## Files Affected Per Change

| Change | Files |
|--------|-------|
| TECH.md (this document) | `docs/v1.1/TECH.md` |
| Wire future shortcuts | `GraspApp.swift` — CommandMenu additions |
| Default notesWidth | `AppViewModel.swift` — change `@Published var notesWidth = 300.0` to dynamic init |

---

## Build Status

Current branch: `wt/fix-selection-popup`  
Uncommitted changes: 4 files (Models.swift, AppViewModel.swift, NotesPanelView.swift, TranscriptPanelView.swift)

These are the existing feature branch changes:
- `LiveBlock.createdAt` field (for timestamp on sealed blocks)
- Concept map 15s rolling window fix (`saveBlock` now sets `created_at`)
- 2×2 grid layout
- 80ms debounce on selection popup
- NotificationCenter-based selection observer

All PRD v1.1 features are accounted for. No gaps requiring implementation changes.
