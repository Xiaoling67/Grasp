# Grasp v1.1-r2 — Implementation Plan

**Date:** 2026-06-27
**Version:** 1.1-r2
**Engineer:** Hermes Agent (DeepSeek)

## Overview

This document describes the implementation of v1.1-r2, a major rewrite of the Grasp app focused on:
1. **Instant selection popup** — no debounce, ≤1 frame appearance
2. **Apple Notes-style AI Notes panel** — flat rich-text, no concept tree
3. **All movable dividers** — both vertical and horizontal draggable
4. **UI polish** — design token system, semantic colors, consistent spacing

## Files Modified

| File | Change |
|------|--------|
| `Grasp/Views/Color+Hex.swift` | Added complete design token system (Spacing, CornerRadius, AppTypography, semantic Color extensions) |
| `Grasp/Models/Models.swift` | Removed `ConceptNode` struct and concept map related types |
| `Grasp/Services/DatabaseService.swift` | Removed `concept_map` table creation, `saveConceptMap`, `loadConceptMap`, `deleteConceptMap` methods |
| `Grasp/Services/DeepSeekService.swift` | Removed `generateConceptMapUpdate` method (~77 lines) |
| `Grasp/ViewModels/AppViewModel.swift` | Removed concept map timer/properties/methods; added `topRowRatio`, `deepgramStatus`; simplified note management |
| `Grasp/Views/Transcript/TranscriptPanelView.swift` | Removed 80ms `asyncAfter` debounce; instant synchronous selection popup; minimum 2 chars; punctuation check; above/below positioning |
| `Grasp/Views/Transcript/SelectionPopupView.swift` | Rewrote with `NSVisualEffectView` material background, SF Symbols, pill shape, accent colors |
| `Grasp/Views/Notes/NotesPanelView.swift` | Full rewrite: removed all tree/concept map code; Apple Notes-style flat rich-text editor with `NSTextView`, Enter/Shift+Enter, blue border animation, hover delete, rich text persistence |
| `Grasp/Views/Layout/LiveTabView.swift` | Added draggable horizontal divider (`HorizontalDragHandle`), `topRowRatio` binding, cursor changes on hover; updated all colors/spacing to design tokens |

## Detailed Changes

### 1. Design Token System (`Color+Hex.swift`)

Added semantic enums and color extensions:
- **`Spacing`** — 4px grid: xxxs(2), xxs(4), xs(8), sm(12), md(16), lg(24), xl(32), xxl(48)
- **`CornerRadius`** — card(8), popup(12), pill(980)
- **`AppTypography`** — body(13), caption(11), small(10), title(14)
- **`Color` extensions** — surfacePrimary, surfaceSecondary, textPrimary, textSecondary, textTertiary, accentBlue, accentPurple, divider, selectionBg, hoverBg, aiNewBorder

### 2. Instant Selection Popup (`TranscriptPanelView.swift`)

**Before (v1.1-r1):**
- 80ms `DispatchQueue.main.asyncAfter` debounce
- Minimum 3-character selection
- White background with border
- `asyncAfter` adds ~80-150ms latency

**After (v1.1-r2):**
- **Zero debounce** — `NSTextView.didChangeSelectionNotification` handled synchronously on `.main` queue
- **Minimum 2 characters** (checks for alphanumeric content, ignores punctuation-only)
- **Popups above selection** by default, below if clipped
- Uses `NSVisualEffectView` with `.popover` material for native macOS look
- SF Symbols: Search (magnifyinglass), Save K (bookmark.fill), Save L (character.bubble.fill)
- `.accentBlue` color for Search button

### 3. Apple Notes Panel (`NotesPanelView.swift`)

**Before (v1.1-r1):**
- Hierarchical concept tree with indented bullets (▸, •, ◦)
- Depth-based indentation (18px per level)
- `ConceptNode`, `ConceptNodeRow`, `buildConceptTree()`, `flattenNode()`, `collectChildren()`
- SwiftUI `TextField` for editing
- Hardcoded hex colors

**After (v1.1-r2):**
- **Flat rich-text list** — no bullets, no indent, no tree
- **NSTextView-based inline editing** — wrapped in `NSViewRepresentable`
- **Rich text support**: ⌘B (bold), ⌘I (italic), ⌘U (underline) — native NSTextView handles these
- **Enter** creates new note below; **Shift+Enter** inserts line break within note
- **Auto-save on blur** — rich text persisted as HTML in SQLite
- **Delete empty note on blur** — removes empty user-created notes
- **New AI notes** slide in with opacity + vertical offset animation
- **Blue left border** (3px, `#1A5FD4`) on new AI notes, fades after 5 seconds
- **Hover × button** for deletion with fade animation
- **Design tokens** throughout for colors, spacing, typography

**Key architectural decisions:**
- `NSTextFieldRepresentable` wraps NSTextView with Coordinator for delegate callbacks
- Rich text saved as HTML in `note_blocks.content` column (backward compatible with plain text)
- `AttributedTextDisplay` renders HTML back in display mode
- The `NoteBlock` model still uses `content` (String) — now stores HTML instead of plain text

### 4. All Movable Dividers (`LiveTabView.swift`)

**Vertical divider:**
- Kept existing implementation with `DragGesture`
- Now shows `NSCursor.resizeLeftRight` on hover
- Uses design tokens for colors

**Horizontal divider (NEW):**
- `HorizontalDragHandle` view — 12px tall drag area
- 1px `#E5E5E5` top/bottom lines with 10px transparent hit area
- `DragGesture(minimumDistance: 0)` updates `vm.topRowRatio`
- Range: 0.30-0.80 (top row), default: 0.55
- `NSCursor.resizeUpDown` on hover
- Both columns resize simultaneously

### 5. Concept Map Removal

**Deleted from codebase:**
- `ConceptNode` struct (`Models.swift`)
- `conceptMap` property, `conceptMapTimer`, `lastConceptMapFire`, `startConceptMapTimer()`, `fireConceptMapUpdate()` (`AppViewModel.swift`)
- `generateConceptMapUpdate()` method (`DeepSeekService.swift`)
- `saveConceptMap()`, `loadConceptMap()`, `deleteConceptMap()` (`DatabaseService.swift`)
- `concept_map` table creation in `DatabaseService.init()`
- `buildConceptTree()`, `collectChildren()`, `flattenNode()`, `conceptNodeView()`, `conceptSlideSection()`, `ConceptNodeRow` (`NotesPanelView.swift`)
- `highlightBlocksForConcept()`, `addConceptToProfile()` (`AppViewModel.swift`)

**Preserved:**
- `NoteBlock` model (used for flat notes)
- `saveNoteBlock`, `updateNoteBlock`, `deleteNoteBlock`, `getNoteBlocks` in DatabaseService
- `handleCopyToNotes`, `updateNote`, `deleteNote` in AppViewModel

## Build Verification

The project builds successfully with:
```
xcodebuild -project Grasp.xcodeproj -scheme Grasp build
```

Only warnings: (1) Run script build phase 'Copy Inter Font' — pre-existing, non-blocking. (2) Deprecated `onChange(of:perform:)` in `SearchCardView.swift` — pre-existing, non-blocking.

## Edge Cases & Gotchas

1. **Empty note deletion**: If user creates a note, presses Enter (creating empty note below), then blurs — the empty note is deleted. The original created note remains.
2. **Rich text fallback**: If HTML content cannot be parsed, `AttributedTextDisplay` falls back to plain text rendering.
3. **NSTextView focus**: The `makeFirstResponder` call is dispatched async to ensure the view hierarchy is ready.
4. **Blue border timing**: New AI notes get a 3px blue left border that fades over 1 second after 5 seconds.
5. **Popup positioning**: Above selection with 4px gap; if above would clip (y < 80), positions below.
6. **Punctuation-only selection**: Ignored by the popup trigger (checks for isLetter || isNumber characters).

## Future Considerations

- Rich text persistence could be enhanced with a dedicated RTF column
- The `NSTextView` wrapper could be extracted to a reusable component
- Horizontal divider drag could use visual feedback (accent highlight on hover)
- Notes panel could benefit from keyboard navigation (Tab between notes)
