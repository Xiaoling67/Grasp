# QA Recheck — v1.1-r2

**Date:** 2026-06-27  
**Tester:** qa (recheck subagent)

---

## 1. Selection Popup Dismissal — ✅ PASS

- **Outside-tap dismiss:** Lines 43–47 of `TranscriptPanelView.swift` place a `Color.clear` overlay with `.contentShape(Rectangle())` and `.onTapGesture { popup = nil }` and `.allowsHitTesting(true)` inside the conditional `if let p = popup` block. This intercepts taps outside the popup and dismisses it.
- **Escape key dismiss:** Line 52 applies `.onKeyPress(.escape) { popup = nil; return .handled }` on the `SelectionPopupView`, combined with `.focusable()` on line 51.

Both mechanisms are present and correctly wired.

## 2. Hardcoded Hex Colors — ✅ PASS

- All 38 `Color(hex:` occurrences are **exclusively** in `Color+Hex.swift` (the design tokens file).
- Zero `Color(hex:` occurrences in any other `.swift` file under `Grasp/`.

## 3. Build — ✅ PASS

```
xcodebuild -project Grasp.xcodeproj -scheme Grasp build
** BUILD SUCCEEDED **
```

0 errors (1 pre-existing warning about Copy Inter Font script phase — unrelated).

---

## Verdict: APPROVED

All three checks pass. The two fixes (popup dismissal + hex color centralization) are correctly implemented.
