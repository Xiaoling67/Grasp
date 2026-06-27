# QA Report: Selection Popup Fix (commit c69f3e4)

**Date:** 2026-06-24  
**Commit:** `c69f3e4`  
**Scope:** Replace NSEvent monitor with NotificationCenter observation for selection popup  
**File changed:** `Grasp/Views/Transcript/TranscriptPanelView.swift` (+37, −18)

---

## Build Result

**✅ SUCCEEDED** — `xcodebuild -project Grasp.xcodeproj -scheme Grasp build` completed without errors.  
One pre-existing warning about the "Copy Inter Font" script phase (not related to this change).

---

## Test Cases

### 1. Selection popup appears when selecting text in transcript
**Result: PASS** ✅

The old approach used `NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp)` to detect selection after mouse release. The new approach observes `NSTextView.didChangeSelectionNotification` from `NotificationCenter.default`.

**Evidence:**
- `TranscriptPanelView.swift` line 50–54: Observer is added in `.onAppear` on `NotificationCenter.default` for `NSTextView.didChangeSelectionNotification` with `object: nil` (catches all NSTextViews).
- Line 40–42: `SelectionPopupView` is conditionally rendered when `popup` state is non-nil.
- SwiftUI's `.textSelection(.enabled)` on `BlockView` text (lines 98–102) creates a field editor NSTextView, which posts this notification when the user selects text.
- The commit message confirms this mechanism: *"SwiftUI's .textSelection(.enabled) creates a temporary NSTextView field editor that posts didChangeSelectionNotification."*

**Reliability improvement over old code:** The old code relied on `window.firstResponder as? NSTextView` which could fail if the first responder wasn't set yet at the time of the mouse-up event. The new approach directly uses the notification's `object` parameter, which is always the NSTextView that changed.

---

### 2. Selection in editable fields / search bars is ignored
**Result: PASS** ✅

**Evidence:**
- Line 58: `guard let tv = notification.object as? NSTextView, ... !tv.isEditable, tv.isSelectable else { return }`
- The `!tv.isEditable` check ensures NSTextViews used for text editing (TextField, search bars) do not trigger the popup.
- TextFields in the app (`NewLectureModalView`, `NotesPanelView`, `SettingsView`, `SearchHistoryView`, `SavedItemsView`, `SearchCardView`, `SaveCardView`) all use editable NSTextViews — these are correctly filtered out.
- Only transcript text views (non-editable, selectable) pass the guard.

---

### 3. Popup positioning near selected text
**Result: PASS** ✅

**Evidence — positioning calculation (lines 71–77):**
```swift
let glyphRange = lm.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
let rect = lm.boundingRect(forGlyphRange: glyphRange, in: tc)
let windowRect = tv.convert(rect, to: nil)
let popupX = windowRect.midX - panelFrame.minX
let popupY = (tv.window?.contentView?.frame.height ?? 600) - windowRect.minY - panelFrame.minY
```

- Uses `NSLayoutManager.boundingRect(forGlyphRange:in:)` for accurate bounding box of selected text.
- Converts to window coordinates with `tv.convert(rect, to: nil)` — accounts for scroll position.
- Transforms to panel-relative coordinates using `panelFrame.minX/minY`.

**Evidence — clamping (SelectionPopupView.swift line 18):**
```swift
.position(x: min(max(x - 60, 70), 700), y: max(y - 44, 8))
```
- Offsets popup ~60pt left (centering over selection) and ~44pt up (above the text).
- Clamps X to [70, 700] and Y to [8, ∞] to keep popup on-screen.

**Improvement over old code:** Old code used `event.locationInWindow` (mouse click position), which was imprecise for multi-character selections. New code uses the actual bounding rect of the selected glyphs.

---

### 4. Dismissal behavior
**Result: PASS** ✅ (with pre-existing minor gap noted)

| Trigger | Mechanism | Works? |
|---------|-----------|--------|
| **Button click** in popup | Each button calls `onDismiss()` → `popup = nil` | ✅ |
| **Click elsewhere** (deselect text) | Selection changes → notification fires → `range.length` is 0 → `popup = nil` | ✅ |
| **Click elsewhere** (change selection) | Selection changes → notification fires → new range checked → `popup = nil` if invalid | ✅ |
| **Select short text** (≤2 chars) | `guard range.length > 2 else { popup = nil; return }` | ✅ |
| **Select whitespace-only text** | `guard !selected.isEmpty else { popup = nil; return }` | ✅ |
| **Escape key** | No handler present | ❌ (pre-existing, not a regression) |

The Escape key dismissal was absent in the original implementation as well. This is a minor UX gap.

---

### 5. Selection in multiple sealed blocks
**Result: PASS** ✅

**Evidence:**
- `ForEach(vm.liveBlocks)` at line 20 renders a `BlockView` for each block.
- Each `BlockView` text has `.textSelection(.enabled)` (lines 98–102).
- The NotificationCenter observer uses `object: nil` (line 52), so it catches notifications from any NSTextView in the app.
- Selecting text in any block fires the same handler, showing the popup positioned over that block's text.

---

### 6. Short selection (1–2 characters) ignored
**Result: PASS** ✅

**Evidence (line 61):**
```swift
guard range.length > 2 else { popup = nil; return }
```
Selections of 1 or 2 characters are silently ignored (`popup = nil`), preventing accidental popup triggers on small selections.

---

### 7. Performance — NotificationCenter observer
**Result: PASS** ✅

**Analysis:**
- `NSTextView.didChangeSelectionNotification` fires on every selection change, potentially multiple times during a mouse drag.
- The handler performs lightweight operations only:
  1. Type check + property reads (`isEditable`, `isSelectable`, `selectedRange`) — O(1)
  2. Range length check — O(1)
  3. String substring + trim — O(n) but only for valid selections
  4. Layout manager queries — O(1) for bounding rect retrieval
- All work is on `.main` queue (line 53), which is required for UIKit/AppKit state access.
- No I/O, no network, no heavy computation in the hot path.
- **No concern — the handler returns early for the vast majority of events (editable fields, short selections, zero-length selections).**

**Memory:** Observer is stored in `@State private var selectionObserver: Any?` and properly removed in `.onDisappear` (line 82–85). No leak.

---

## Issues Found

### ⚠️ Issue 1 (Medium): Missing 80ms debounce — popup may appear during active text drag

**Severity:** Medium  
**Type:** UX regression  
**File:** `TranscriptPanelView.swift`  

**Description:**
The original code had an intentional 80ms delay after `leftMouseUp` before showing the popup:

```swift
// OLD:
mouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { event in
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {  // 80ms delay
        // check selection
    }
    return event
}
```

This ensured the popup only appeared **after** the user finished selecting text (released the mouse button). The new code shows the popup **immediately** when the selection changes, which occurs during mouse drag as the selection expands.

**Impact:**
- If `didChangeSelectionNotification` fires during continuous drag-selection (which it does in most NSTextView implementations), the popup appears and potentially flickers/updates position as the selection range changes.
- The popup appears at an intermediate selection position, then jumps to the final position when the user releases the mouse.
- This creates a distracting UX compared to the original behavior where the popup appeared cleanly after the user finished selecting.

**Recommendation:**
Add a debounce mechanism. Options:
1. Restore the 80ms `asyncAfter` pattern (simplest, most consistent with original).
2. Use a `Timer.publish` with a short debounce interval that resets on each notification.
3. Use a `Task.sleep` with cancellation to debounce.

---

## Code Review Summary

| Checklist Item | Status | Notes |
|---------------|--------|-------|
| Observer added in `onAppear` | ✅ | Line 50–79, inside `.onAppear` block |
| Observer removed in `onDisappear` | ✅ | Line 82–85, `removeObserver` called |
| No memory leak | ✅ | State property cleaned up; no retain cycle |
| Positioning math correct | ✅ | Bounding rect + coordinate conversion + clamping |
| `!tv.isEditable` guard | ✅ | Filters TextField/search bar selection |
| `range.length > 2` guard | ✅ | Filters short selections |
| `object: nil` observer | ✅ | Correct — field editors are transient, can't filter by specific instance |
| Window key check | ✅ | `window == NSApp.keyWindow` prevents stale window interactions |
| `panelFrame` updated on resize | ✅ | `.onChange(of: geo.size)` updates frame |

---

## Recommendation

**APPROVE with noted issue**

The fix correctly replaces the unreliable `NSEvent` + `firstResponder` approach with a `NotificationCenter`-based observer that reliably detects text selection changes in SwiftUI's `.textSelection(.enabled)` views. The core mechanism is sound and addresses the original bug (selection popup not appearing).

**One issue to consider fixing before merge:**

The **missing 80ms debounce** (Issue 1) is a UX regression. The original code waited for the user to finish selecting before showing the popup. The new code shows it immediately, which may cause flickering during drag-selection.

**Suggested fix:**
Replace the current handler body with a debounced version:

```swift
selectionObserver = NotificationCenter.default.addObserver(
    forName: NSTextView.didChangeSelectionNotification,
    object: nil,
    queue: .main
) { [self] notification in
    // Cancel any pending debounce task
    pendingSelectionTask?.cancel()
    pendingSelectionTask = Task {
        try? await Task.sleep(nanoseconds: 80_000_000)  // 80ms debounce
        guard !Task.isCancelled else { return }
        // ... existing selection handling code ...
    }
}
```

Add `@State private var pendingSelectionTask: Task<Void, Never>? = nil` to hold the debounce task.

**Alternative (simpler):** Keep the original 80ms `asyncAfter` pattern by wrapping the handler body in `DispatchQueue.main.asyncAfter(deadline: .now() + 0.08)` and keeping a cancelable work item.

---

*End of QA report.*
