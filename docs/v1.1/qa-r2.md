# QA Audit Report: v1.1-r2

**Version:** v1.1-r2  
**Date:** 2026-06-27  
**Build:** `xcodebuild -project Grasp.xcodeproj -scheme Grasp build`  
**PRD:** `/Users/catherineuspan/grasp/docs/v1.1/PRD.md` (526 lines)  
**Auditor:** QA (Hermes subagent)  

---

## Build Result: ✅ PASS

```
** BUILD SUCCEEDED **
```

---

## 1. Instant Selection Popup — ❌ REJECT (2 critical issues)

### ✅ Passed Checks

| # | Check | Status | Evidence |
|---|-------|--------|----------|
| 1.1 | No `asyncAfter` or debounce in selection tracking | ✅ PASS | `TranscriptPanelView.swift` uses `NotificationCenter.default.addObserver(forName: NSTextView.didChangeSelectionNotification, object: nil, queue: .main)` directly — no `asyncAfter`, no debounce. The only `asyncAfter` calls in the codebase are in `NotesPanelView.swift` line 250 (5s blue-border fade, valid, not selection-related) and `SaveCardView.swift` line 23 (dismiss delay, valid, not selection-related). |
| 1.2 | Direct main queue observer | ✅ PASS | `queue: .main` — synchronously dispatched in the current runloop. |
| 1.3 | Minimum 2 characters | ✅ PASS | Line 65: `guard range.length >= 2 else { popup = nil; return }` |
| 1.4 | Whitespace/punctuation-only ignored | ✅ PASS | Lines 68-74: trims whitespace, filters for letters+numbers. |
| 1.5 | Popup position (above/below) | ✅ PASS | Lines 87-90: above by default with 4px gap; below if clip detected (`aboveY > 80`). |
| 1.6 | NSVisualEffectView material | ✅ PASS | `SelectionPopupView.swift` line 37: `VisualEffectView(material: .popover, blendingMode: .behindWindow)`. |
| 1.7 | 3 buttons: Search, K, L (Intl) | ✅ PASS | Search (with magnifyingglass SF Symbol), K (bookmark.fill), L (character.bubble.fill, shown only when `vm.activeLectureMode == "international"`). |
| 1.8 | Pill shape / rounded corners | ✅ PASS | `RoundedRectangle(cornerRadius: CornerRadius.popup)` (12px). |
| 1.9 | Popup on new selection | ✅ PASS | Observer re-fires on any selection change — guard fails → `popup = nil` for the old one, then new popup is set if selection ≥ 2 chars. |

### ❌ Failed Checks

| # | Check | Status | Issue |
|---|-------|--------|-------|
| 1.10 | **Dismiss on outside tap** | ❌ FAIL | No tap gesture on the ZStack background or ScrollView to dismiss the popup. The `onDismiss` closure is only called from the popup's own buttons. The popup sits in a ZStack overlay without a background dismiss handler. |
| 1.11 | **Dismiss on Esc key** | ❌ FAIL | No keyboard handler for Esc (`NSEvent.keyDown` or SwiftUI `.onKeyPress`) in `TranscriptPanelView` or `SelectionPopupView`. The PRD specifies "Press Esc → dismiss immediately." |
| 1.12 | Dismiss on scroll | ⚠️ BORDERLINE | `onChange(of: geo.size)` sets `popup = nil`, but during NSScrollView scrolling, the view's geometry may not always change (the ScrollView clips its content). This may not fire reliably for all scroll events. The PRD says "Scrolling transcript → dismiss immediately." |

### Verdict: ❌ REJECT — Two critical dismiss mechanisms (outside tap, Esc) are missing from the selection popup.

---

## 2. Apple Notes Panel — ✅ PASS

### ✅ All Checks Pass

| # | Check | Status | Evidence |
|---|-------|--------|----------|
| 2.1 | ConceptNode struct DELETED from Models.swift | ✅ PASS | `Models.swift` has no `ConceptNode` — only `NoteBlock`, `Lecture`, `Block`, `SavedCard`, `SearchResult`, `SlideItem`, `LiveBlock`, `TabItem`, and UI state types. Zero matches for `ConceptNode` in entire codebase. |
| 2.2 | `concept_map` table methods DELETED from DatabaseService.swift | ✅ PASS | `DatabaseService.swift` has no `concept_map` table. The `note_blocks` table is used instead (line 17 in CREATE TABLE). No `concept_map` references anywhere. |
| 2.3 | `generateConceptMapUpdate` DELETED from DeepSeekService.swift | ✅ PASS | `DeepSeekService.swift` has `generateNoteEntry` (line 36) instead. No `generateConceptMapUpdate` anywhere. |
| 2.4 | `conceptMap`, `conceptMapTimer`, `fireConceptMapUpdate` DELETED from AppViewModel.swift | ✅ PASS | `AppViewModel.swift` has no `conceptMap`, `conceptMapTimer`, or `fireConceptMapUpdate`. Notes are a flat `@Published var noteBlocks = [NoteBlock]()` (line 22). |
| 2.5 | Flat rich-text list with NSTextView editing | ✅ PASS | `NotesPanelView.swift` uses `NoteRichEditor` → `NSTextFieldRepresentable` wrapping `NSTextView` with `isRichText = true`. |
| 2.6 | No bullets, no indentation, no tree | ✅ PASS | Flat `LazyVStack` with `ForEach(vm.noteBlocks)`. No bullet characters (▸ • ◦), no indent modifiers, no tree rendering. |
| 2.7 | Rich text: ⌘B, ⌘I, ⌘U | ✅ PASS | `NSTextView.isRichText = true` (line 279). AppKit handles ⌘B, ⌘I, ⌘U natively. |
| 2.8 | Enter = new note, Shift+Enter = line break | ✅ PASS | `Coordinator.textView(_:doCommandBy:)`: `insertNewline` without shift → `onEnter()` (creates new note below); `insertNewline` with shift → returns `false` (native line break). |
| 2.9 | New AI notes: slide-in animation | ✅ PASS | `.transition(.opacity.combined(with: .offset(y: 5)))` — opacity + slight vertical slide. |
| 2.10 | Blue left border on new notes, fades after 5s | ✅ PASS | `isNew && showBlueBorder ? Color.aiNewBorder : Color.clear` (3px width). `DispatchQueue.main.asyncAfter(deadline: .now() + 5.0)` fades it. |
| 2.11 | Hover × button for deletion | ✅ PASS | `Button(action: onDeleteEmpty) { Image(systemName: "xmark.circle.fill") }` shown when `hovered && !isEditing`. |
| 2.12 | Rich text saved as HTML | ✅ PASS | `textDidEndEditing` converts `NSTextStorage` to HTML via `attrStr.data(from:range:documentAttributes:)` with `.documentType: .html`. |
| 2.13 | Click to edit | ✅ PASS | `.onTapGesture { if !isEditing { onBeginEdit() } }` on `NoteRichEditor`. |
| 2.14 | Auto-save on blur | ✅ PASS | `textDidEndEditing` captures content and calls `onBlur()`. |

### Verdict: ✅ PASS — Notes panel is a complete Apple Notes-style rewrite. All concept map code removed.

---

## 3. All Movable Dividers — ✅ PASS

### ✅ All Checks Pass

| # | Check | Status | Evidence |
|---|-------|--------|----------|
| 3.1 | Horizontal divider IS draggable | ✅ PASS | `HorizontalDragHandle` struct in `LiveTabView.swift` (line 76-107) with `DragGesture(minimumDistance: 0)`. |
| 3.2 | 12px drag handle | ✅ PASS | `.frame(height: 12)` on the clear Rectangle. Overlaid with 1px top line + 1px bottom line, 10px active drag area between. |
| 3.3 | `resizeUpDown` cursor on hover | ✅ PASS | `.onHover { if hovering { NSCursor.resizeUpDown.push() } else { NSCursor.pop() } }` |
| 3.4 | `topRowRatio` @Published var exists | ✅ PASS | `AppViewModel.swift` line 46: `@Published var topRowRatio: CGFloat = 0.55` |
| 3.5 | Range: 0.30–0.80 | ✅ PASS | Line 98: `let ratio = max(0.30, min(0.80, dragY / totalHeight))` |
| 3.6 | Default: 55/45 | ✅ PASS | `topRowRatio = 0.55` |
| 3.7 | Both dividers work simultaneously | ✅ PASS | Vertical divider (lines 14-24) + Horizontal divider (lines 32-35, HorizontalDragHandle) are in the same layout hierarchy. |
| 3.8 | Vertical divider uses `resizeLeftRight` cursor | ✅ PASS | `.onHover { if hovering { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() } }` |

### Verdict: ✅ PASS — Both dividers are fully functional. Horizontal divider is newly draggable.

---

## 4. UI Polish — ❌ REJECT (1 critical issue)

### ✅ Passed Checks

| # | Check | Status | Evidence |
|---|-------|--------|----------|
| 4.1 | Design token system defined | ✅ PASS | `Color+Hex.swift` defines `Spacing` (xs/xxs/sm/md/lg/xl/xxl), `CornerRadius` (card/popup/pill), `AppTypography` (body/caption/small/title), and semantic Color extensions (`surfacePrimary`, `surfaceSecondary`, `textPrimary`, `textSecondary`, `textTertiary`, `accentBlue`, `accentPurple`, `divider`, `selectionBg`, `hoverBg`, `aiNewBorder`). |
| 4.2 | 4px grid spacing | ✅ PASS | Spacing enum values: xxxs=2, xxs=4, xs=8, sm=12, md=16, lg=24, xl=32, xxl=48 — follows 4px grid. |
| 4.3 | Corner radii | ✅ PASS | card=8, popup=12. |
| 4.4 | Typography tokens | ✅ PASS | body=13, caption=11, small=10, title=14. |
| 4.5 | Semantic colors match PRD spec | ✅ PASS | Colors match PRD §4.3 exactly: surfacePrimary=FFFFFF, surfaceSecondary=F5F5F5, textPrimary=1A1A1A, textSecondary=6B6B6B, textTertiary=9E9E9E, accentBlue=2563EB, accentPurple=7C3AED, divider=E5E5E5, selectionBg=DBEAFE. |
| 4.6 | 200ms animations | ✅ PASS | `.animation(.easeInOut(duration: 0.2), value: ...)` patterns used throughout (TranscriptPanelView, NotesPanelView, etc.). |

### ❌ Failed Checks

| # | Check | Status | Issue |
|---|-------|--------|-------|
| 4.7 | **No hardcoded hex colors remaining** | ❌ FAIL | 11 out of 34 Swift files still use `Color(hex: ...)` with raw hex values instead of semantic tokens. **Files with hardcoded hex colors:** |
| | | | • `TopBarView.swift` — 12 instances (hex: `5A5A5A`, `E8E8E8`, `B91C1C`, `DC3545`, `9A9A9A`, `1A5FD4`, `E8F0FE`, `C5D8FC`, `0A0A0A`) |
| | | | • `SidebarView.swift` — 8 instances (hex: `0A0A0A`, `C0C0C0`, `5A5A5A`, `E8E8E8`, `F8F8F8`, `1A5FD4`) |
| | | | • `ColdCallCardView.swift` — 8 instances (hex: `F59E0B`, `C0C0C0`, `0A0A0A`, `1A5FD4`, `E8F0FE`, `5A5A5A`, `15803D`, `F0FDF4`, `FBBF24`) |
| | | | • `ToastView.swift` — 3 instances (hex: `B91C1C`, `15803D`, `0A0A0A`) |
| | | | • `NewLectureModalView.swift` — 7 instances (hex: `0A0A0A`, `C0C0C0`, `5A5A5A`, `F8F8F8`, `E8E8E8`, `1A5FD4`) |
| | | | • `ExportModalView.swift` — 12 instances (hex: `0A0A0A`, `C0C0C0`, `5A5A5A`, `9A9A9A`, `E8E8E8`, `15803D`, `B91C1C`, `1A5FD4`) |
| | | | • `OnboardingModalView.swift` — 8 instances (hex: `1A5FD4`, `C5D8FC`, `E8E8E8`, `0A0A0A`, `5A5A5A`, `9A9A9A`, `E8F0FE`) |
| | | | • `PastLectureView.swift` — 14 instances (hex: `1A5FD4`, `E8F0FE`, `9A9A9A`, `F8F8F8`, `E8E8E8`, `0A0A0A`, `5A5A5A`, `AAAAAA`, `3B7DD8`, `3B67D6`, `16A34A`, `EEF4FF`, `F0FDF4`) |
| | | | • `SettingsView.swift` — 5 instances (hex: `0A0A0A`, `5A5A5A`, `C0C0C0`) |
| | | | • `KnowledgeProfileView.swift` — 11 instances (hex: `1A5FD4`, `0A0A0A`, `C0C0C0`, `E8E8E8`, `F5F5F5`, `D0D0D0`, `999999`, `F0F0F0`, `34C759`, `007AFF`, `8E8E93`, `FF9500`) |
| | | | • `SavedItemsView.swift` — 9 instances (hex: `0A0A0A`, `9A9A9A`, `F8F8F8`, `E8E8E8`, `3B67D6`, `16A34A`, `EEF4FF`, `F0FDF4`, `1A5FD4`, `5A5A5A`, `C0C0C0`, `E8F0FE`) |
| | | | • `SearchCardView.swift` — 7 instances (hex: `5A5A5A`, `C0C0C0`, `E8E8E8`, `B91C1C`, `0A0A0A`, `1A5FD4`, `F8F8F8`) |
| | | | • `AutoExplainCardView.swift` — 6 instances (hex: `7C3AED`, `5A5A5A`, `C0C0C0`, `E8E8E8`, `0A0A0A`, `EDE9FE`) |
| | | | • `SaveCardView.swift` — 7 instances (hex: `5A5A5A`, `C0C0C0`, `E8E8E8`, `0A0A0A`, `F8F8F8`, `B91C1C`) |
| | | | • `BottomPanelView.swift` — 10 instances (hex: `E8E8E8`, `0A0A0A`, `9A9A9A`, `5A5A5A`, `F8F8F8`, `7C3AED`, `C0C0C0`, `1A5FD4`, `15803D`, `E8F0FE`, `F0FDF4`) |
| | | | • `HomeView.swift` — 2 instances (hex: `1A5FD4`, `4A8BFA`) |
| | | | • `SearchHistoryView.swift` — 7 instances (hex: `0A0A0A`, `9A9A9A`, `F8F8F8`, `E8E8E8`, `15803D`, `F0FDF4`, `C0C0C0`, `1A5FD4`) |
| | | | • `TranscriptPanelView.swift` — 1 instance (hex: `C5D8FC` in Resume button stroke) |

### Verdict: ❌ REJECT — ~140+ instances of hardcoded hex colors remain across 18 files. The migration to semantic tokens is incomplete. PRD §4 explicitly requires "No hardcoded hex colors" and a centralized design token system.

---

## Overall Verdict: ❌ REJECT

### 2 Critical Issues Blocking Approval:

1. **Selection Popup Dismissal (Section 1):** Outside-tap dismiss and Esc-key dismiss are not implemented. The PRD is explicit: "Tap outside popup → dismiss immediately" and "Press Esc → dismiss immediately." Without these, the popup can become a persistent overlay that the user cannot dismiss except by making a new selection.

2. **Hardcoded Hex Colors (Section 4):** 18 out of 34 Swift files still use raw `Color(hex: ...)` values (~140+ instances) instead of semantic tokens. The PRD clearly states "No hardcoded hex colors remaining." This is a direct violation of the UI polish requirements. Files affected include TopBarView, SidebarView, ColdCallCardView, all Modals, PastLectureView, KnowledgeProfileView, SavedItemsView, Bottom panel views, and others.

### Items That PASS:

| Section | Result |
|---------|--------|
| Build | ✅ PASS |
| Selection Popup — Instant appearance mechanism | ✅ PASS |
| Selection Popup — Min 2 chars, content filtering | ✅ PASS |
| Selection Popup — NSVisualEffectView + 3 buttons | ✅ PASS |
| Selection Popup — Above/below positioning | ✅ PASS |
| **Selection Popup — Dismissal** | **❌ FAIL** |
| Apple Notes Panel — All concept map code deleted | ✅ PASS |
| Apple Notes Panel — Flat rich-text NSTextView editing | ✅ PASS |
| Apple Notes Panel — Enter/Shift+Enter, rich text, animations | ✅ PASS |
| Movable Dividers — Both draggable | ✅ PASS |
| Movable Dividers — topRowRatio, ranges, cursors | ✅ PASS |
| Design Tokens — Definition exists | ✅ PASS |
| **Hardcoded Hex Colors — No remaining** | **❌ FAIL** |
| 200ms animations | ✅ PASS |

### Recommended Fixes:

1. **Add outside-tap dismiss** in `TranscriptPanelView`: Add a `.onTapGesture { popup = nil }` on the ScrollView or ZStack background, or use an invisible overlay that captures taps outside the popup frame.

2. **Add Esc-key dismiss** in `TranscriptPanelView`: Use `.onKeyPress(.escape) { popup = nil; return .handled }` or an NSEvent local monitor.

3. **Migrate all hardcoded hex colors** to semantic tokens across all 18 affected files. Replace `Color(hex: "5A5A5A")` → `.textSecondary`, `Color(hex: "E8E8E8")` → `.divider`, `Color(hex: "FFFFFF")` → `.surfacePrimary`, `Color(hex: "F8F8F8")` → `.surfaceSecondary`, `Color(hex: "0A0A0A")` → `.textPrimary`, `Color(hex: "1A5FD4")` → `.accentBlue`, etc.
