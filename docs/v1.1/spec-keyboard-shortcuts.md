# Feature Spec: Keyboard Shortcuts (v1.1)

**Status:** Draft  
**Owner:** pm (DeepSeek)  
**Parent task:** `grasp` kanban — Feature: Keyboard Shortcuts  
**Estimated effort:** 1–2 engineer sessions  

---

## 1. Overview

The README documents 7 keyboard shortcuts for the Grasp macOS app. Currently only `⌘N` (New Lecture) is implemented. This spec covers the 5 missing shortcuts:

| Shortcut | Action | Context required |
|---|---|---|
| `⌘⇧P` | Pause / resume recording | Lecture active (`isRecording == true`) |
| `⌘⇧K` | Save selected text as Knowledge | Lecture active + text selection |
| `⌘⇧L` | Save selected text as Language | Lecture active + text selection + International mode |
| `⌘⇧E` | Search selected text via DeepSeek AI | Lecture active + text selection |
| `⌘⇧X` | Open Export modal | Always available |

`⌘N` already works and is not modified.

---

## 2. Acceptance Criteria

### 2.1 `⌘⇧P` — Pause / Resume

- Calls `vm.togglePause()` (already exists).
- No-op when `vm.isRecording == false`.
- **No text selection needed.**
- Visual: toggles `vm.isPaused` which already pauses transcription and sealing.

### 2.2 `⌘⇧K` — Save as Knowledge

- Reads the current text selection from the transcript `NSTextView`.
- Calls `vm.handleSaveAction(type: "knowledge", text: <selected text>)`.
- No-op when `vm.isRecording == false`.
- No-op when selection is empty (length < 1 after trimming).
- Shows a toast if no selection exists: `"No text selected."` (type: `"info"`).
- Should also work if the transcript has scroll-frozen text selected.

### 2.3 `⌘⇧L` — Save as Language

- Same as ⌘⇧K but calls `vm.handleSaveAction(type: "language", text: <selected text>)`.
- No-op when `vm.activeLectureMode != "international"`.
- No-op when `vm.isRecording == false`.
- No-op when selection is empty.
- Shows toast `"Language saving is only available in International mode."` if mode is wrong.
- Shows toast `"No text selected."` if selection is empty.

### 2.4 `⌘⇧E` — Search Selection

- Reads the current text selection.
- Calls `vm.triggerSearch(query: <selected text>, blockIndex: 0)`.
  - `blockIndex: 0` is a safe default — `triggerSearch` uses it to load recent context blocks from DB. The popup path passes the real block index (from the `BlockView`), but a keyboard shortcut doesn't have that context. The caller could locate the active/last block or just use 0. Using `0` falls back to the last 10 recent blocks which is acceptable.
- No-op when `vm.isRecording == false`.
- Shows toast `"No text selected."` if selection is empty.

### 2.5 `⌘⇧X` — Export

- Sets `vm.showExportModal = true`.
- No guard — always available (like the existing `⌘N`).

---

## 3. Shared Mechanism: Current Selection

The existing code in `TranscriptPanelView` (lines 46–62) already captures the current selection via an `NSEvent` local monitor:

```swift
mouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { event in
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
        guard let window = NSApp.keyWindow,
              let tv = window.firstResponder as? NSTextView else { return }
        let range = tv.selectedRange()
        guard range.length > 2 else { popup = nil; return }
        let selected = (tv.string as NSString)
            .substring(with: range)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selected.isEmpty else { popup = nil; return }
        // ...
        popup = (selected, 0, localX, localY)
    }
    return event
}
```

### 3.1 Proposed shared pattern

Add a **static/class-level property** on `AppViewModel` to hold the last known selection. The existing `NSEvent` monitor already has the selection; it just needs to write it somewhere accessible to the keyboard shortcut handler.

**Option A (Recommended): `AppViewModel.lastSelectedText`**

Add to `AppViewModel`:

```swift
@MainActor
static var lastSelectedText: String = ""
```

In `TranscriptPanelView.onAppear`, after the selection is extracted, add:

```swift
AppViewModel.lastSelectedText = selected
```

The keyboard shortcuts check this static property.

**Option B (Alternative): Read `NSTextView` directly in the shortcut**

The shortcut action could look up `NSApp.keyWindow?.firstResponder as? NSTextView` and read `selectedRange()` directly. This is more "live" but couples the shortcut to the responder chain — may fail if the transcript `NSTextView` isn't the first responder (e.g., user clicked into a text field in the bottom panel).

**Recommendation:** Use Option A for v1. It's simple, works regardless of focus, and reuses the existing infrastructure. The selection is captured on every `leftMouseUp` so it's always up to date.

### 3.2 Minimum selection length

The `mouseUpMonitor` currently requires `range.length > 2` (3+ characters) to show the popup. For keyboard shortcuts, use a more permissive threshold: `selectedText.trimmingCharacters(in: .whitespaces).count >= 1`.

---

## 4. Implementation Plan

### 4.1 Add `lastSelectedText` to AppViewModel

**File:** `Grasp/ViewModels/AppViewModel.swift`

Add at the bottom of the `@Published` block, before the `// Debug` section:

```swift
/// Holds the most recent text selection from the transcript, for keyboard shortcuts.
static var lastSelectedText: String = ""
```

### 4.2 Write selection in TranscriptPanelView

**File:** `Grasp/Views/Transcript/TranscriptPanelView.swift`

Inside the `NSEvent.addLocalMonitorForEvents` block, after the selection is trimmed and validated, add:

```swift
AppViewModel.lastSelectedText = selected
```

Place this right after the `guard !selected.isEmpty` check and before the popup position calculations, so it's set regardless of whether the popup is shown.

### 4.3 Add CommandMenu shortcuts in GraspApp

**File:** `Grasp/GraspApp.swift`

Extend the `.commands` block. The existing pattern:

```swift
.commands {
    CommandGroup(replacing: .newItem) {}
    CommandMenu("Lecture") {
        Button("New Lecture") { vm.showNewLectureModal = true }
            .keyboardShortcut("n", modifiers: [.command])
    }
}
```

Add a **second CommandMenu** (or merge into the existing one):

```swift
CommandMenu("Edit") {
    Button("Pause/Resume Recording") { vm.togglePause() }
        .keyboardShortcut("p", modifiers: [.command, .shift])
        .disabled(!vm.isRecording)

    Divider()

    Button("Save as Knowledge") { handleShortcutSave(vm: vm, type: "knowledge") }
        .keyboardShortcut("k", modifiers: [.command, .shift])
        .disabled(!vm.isRecording)

    Button("Save as Language") { handleShortcutSave(vm: vm, type: "language") }
        .keyboardShortcut("l", modifiers: [.command, .shift])
        .disabled(!vm.isRecording || vm.activeLectureMode != "international")

    Button("Search Selection") { handleShortcutSearch(vm: vm) }
        .keyboardShortcut("e", modifiers: [.command, .shift])
        .disabled(!vm.isRecording)

    Divider()

    Button("Export…") { vm.showExportModal = true }
        .keyboardShortcut("x", modifiers: [.command, .shift])
}
```

**Notes:**
- `Divider()` is a SwiftUI `View` and works inside `CommandMenu`.
- `.disabled()` on menu items grays them out when the precondition isn't met — this is standard macOS UX.
- The handler functions (below) can be defined as private functions inside `GraspApp` or as extensions on `AppViewModel`.

### 4.4 Handler functions

Add to `GraspApp.swift` (or a new helper file `Grasp/ViewModels/KeyboardShortcuts.swift`):

```swift
// MARK: - Keyboard Shortcut Handlers

@MainActor
private func handleShortcutSave(vm: AppViewModel, type: String) {
    let text = AppViewModel.lastSelectedText
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else {
        vm.showToast("No text selected.", type: "info")
        return
    }
    if type == "language" && vm.activeLectureMode != "international" {
        vm.showToast("Language saving is only available in International mode.", type: "info")
        return
    }
    vm.handleSaveAction(type: type, text: text)
}

@MainActor
private func handleShortcutSearch(vm: AppViewModel) {
    let text = AppViewModel.lastSelectedText
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else {
        vm.showToast("No text selected.", type: "info")
        return
    }
    vm.triggerSearch(query: text, blockIndex: 0)
}
```

### 4.5 Insertion in the existing CommandMenu (Alternative Approach)

Alternatively, the 5 shortcuts can be added directly into the existing `CommandMenu("Lecture")` block rather than creating a separate `CommandMenu("Edit")`. This keeps all lecture-related shortcuts in one place but may crowd the menu. **Decision required from Founder / cos.** The spec above uses a second menu (`Edit`) to keep the Lecture menu clean, but either placement works technically.

---

## 5. Edge Cases & Guards

| Scenario | Expected Behavior |
|---|---|
| No lecture active, user presses `⌘⇧P` | Button is disabled in menu; no-op |
| No lecture active, user presses `⌘⇧K/L/E` | Button is disabled in menu; no-op |
| No lecture active, user presses `⌘⇧X` | Export modal opens (no guard) |
| Lecture active, no text selected, user presses `⌘⇧K/L/E` | Toast: "No text selected." (type: "info") |
| Lecture active in Standard mode, user presses `⌘⇧L` | Toast: "Language saving is only available in International mode." |
| International mode, `⌘⇧L` with selection | Works same as `⌘⇧K` but `type: "language"` |
| Lecture paused, user presses `⌘⇧P` | Unpauses (`isPaused = false`) |
| Keyboard shortcut fired while `ExportModalView` or `NewLectureModalView` is shown | Shortcuts still work — `AppViewModel.lastSelectedText` holds the last selection before the modal appeared |
| User has text selected in a _past lecture_ tab (not live) | `isRecording` is false → shortcuts are disabled; safe no-op |

---

## 6. Non-Goals

- **No new UI** — shortcuts reuse existing handlers and views.
- **No new NSTextView responders** — reuses the existing mouse-up monitor.
- **No menu bar icon** — the shortcuts appear in the standard macOS menu bar automatically when defined in `.commands`.
- **No custom shortcut-remapping UI** — users can remap via System Settings → Keyboard → Keyboard Shortcuts → App Shortcuts as with any standard macOS app.

---

## 7. Files to Modify

| File | Changes |
|---|---|
| `Grasp/ViewModels/AppViewModel.swift` | Add `static var lastSelectedText: String = ""` |
| `Grasp/Views/Transcript/TranscriptPanelView.swift` | Write selected text to `AppViewModel.lastSelectedText` in the mouse-up monitor |
| `Grasp/GraspApp.swift` | Add `CommandMenu` with 5 buttons + keyboard shortcuts + handler functions |

---

## 8. Verification Steps

1. **Unit/Manual:**
   - Launch app, press `⌘⇧X` → Export modal appears.
   - Start a lecture. Press `⌘⇧P` → transcription pauses (`isPaused == true`). Press again → resumes.
   - Select text in transcript. Press `⌘⇧K` → `SaveCardView` appears with type "knowledge".
   - Select text in transcript. Press `⌘⇧E` → `SearchCardView` appears with results.
   - Switch to International mode. Select text. Press `⌘⇧L` → `SaveCardView` appears with type "language".

2. **Edge cases:**
   - Press `⌘⇧L` in Standard mode → toast shown, no save triggered.
   - Press any save/search shortcut without selecting text → toast shown.
   - Verify menu items are grayed out when no lecture is active.
   - Press `⌘⇧P` repeatedly → toggles each time.
   - Verify all shortcuts appear in the macOS menu bar and can be seen via the app menu.
