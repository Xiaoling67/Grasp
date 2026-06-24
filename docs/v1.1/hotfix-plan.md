# Hotfix Plan — v1.1

## Bug 1: Transcription shows text twice

**Observed:** The active block in the transcript displays the same words twice — once in black from `block.textEn`, once in grey from `vm.interimText`.

**Root cause confirmed.** In `TranscriptPanelView.swift` line 78–79, the active `BlockView` concatenates `block.textEn + " " + vm.interimText`. Meanwhile, `handleInterim` in `AppViewModel.swift` (line 124–134) does two things:

1. Sets `interimText = t` (the full interim transcription text).
2. Applies word-diff logic that appends new words directly to `block.textEn` (lines 128–132).

So when `activeBlockId` is set, the block both *has* the words already (via the diff) and *also* shows them again via `interimText`. The standalone display at lines 23–25 (`if !vm.interimText.isEmpty && vm.activeBlockId == nil`) is correct — it shows interim text when no active block exists yet.

**Fix approach — CONFIRMED.** In `TranscriptPanelView.swift`, change the active block display (line 78–79) to **not** append `interimText`. The block already has all words via the word-diff. Interim text should only appear standalone when `activeBlockId` is nil:

| Location | Current | Fix |
|----------|---------|-----|
| Lines 23–25 (standalone) | `if !vm.interimText.isEmpty && vm.activeBlockId == nil { Text(vm.interimText) }` | ✅ Keep as-is — correct behavior |
| Lines 78–79 (active block) | `(Text(block.textEn + " ") + Text(vm.interimText))` | ❌ Remove `interimText` concatenation; display only `block.textEn` |

**Files to change:**
- `Grasp/Views/Transcript/TranscriptPanelView.swift` (BlockView, active block branch)

---

## Bug 2: Auto Explain results appear in Search history

**Observed:** Auto Explain results show up in the "Searched" tab and persist in the DB searches table, polluting the user's search history.

**Root cause confirmed.** In `AppViewModel.swift`, the `autoExplain()` function has two paths that both call `sessionSearches.insert` and `db.saveSearch`:

**Path 1 — lookedUp case (lines 294–295):**
```swift
db.saveSearch(id: rid, lectureId: lectureId, query: detected.term, resultPro: r.professional, resultSimple: r.intuition)
sessionSearches.insert(r, at: 0)
```

**Path 2 — main streaming path (lines 318–319):**
```swift
db.saveSearch(id: rid, lectureId: lectureId, query: detected.term, resultPro: pro, resultSimple: intu)
sessionSearches.insert(r, at: 0)
```

These insert the auto-explain result into `sessionSearches` (which populates the "Searched" tab) and persist it to the `searches` table. By contrast, `triggerSearch()` (lines 370–371) does the same calls deliberately — that's correct for manual user searches. Auto Explain results should only appear in the Auto tab, fed by `autoExplainResult` / `autoExplainNew`, never in search history.

**Fix approach — CONFIRMED.** Remove `sessionSearches.insert(r, at: 0)` and `db.saveSearch(...)` from both paths in `autoExplain()`. Keep:

- `autoExplainResult = r` — updates the Auto Explain card
- `autoExplainNew = (bottomTab != "auto")` — badge notification logic
- `MemoryService.shared.recordInteraction(...)` — learning/memory tracking (not search history)

| Location in autoExplain() | Current | Fix |
|--------------------------|---------|-----|
| Lines 294–295 (lookedUp) | `db.saveSearch` + `sessionSearches.insert` | ❌ Remove both |
| Lines 318–319 (streaming) | `db.saveSearch` + `sessionSearches.insert` | ❌ Remove both |

**Files to change:**
- `Grasp/ViewModels/AppViewModel.swift` (autoExplain method, two locations)

---

## Summary

| # | Bug | Verified? | Fix Scope |
|---|-----|-----------|-----------|
| 1 | Transcription text duplication | ✅ Confirmed in source | `TranscriptPanelView.swift` — remove `interimText` from active BlockView |
| 2 | Auto Explain polluting search history | ✅ Confirmed in source | `AppViewModel.swift` — remove `sessionSearches.insert` + `db.saveSearch` from both autoExplain paths |

Both fixes are small, independent, and safe — no architectural changes required.
