# Layout 2×2 Grid — Implementation Spec

**Feature:** Replace current `LiveTabView` content area (transcript | notes side-by-side) with a 2×2 grid layout.

**Status:** Implementation-ready
**Area:** `Grasp/Views/Layout/LiveTabView.swift`
**Depends on:** No new views; reuses existing `TranscriptPanelView`, `NotesPanelView`, `AutoExplainCardView`, `ColdCallCardView`, `SearchCardView`, `SaveCardView`.

---

## 1. Target layout (visual)

```
┌─────────────────────────────────────────────┐
│ TopBarView  [unchanged]                      │
├──────┬──────────────────┬────────────────────┤
│      │                   │                    │
│ Side │  TRANSCRIPT       │  AI NOTES          │
│ bar  │  (top-left)       │  (top-right)       │
│      │   • sealed blocks │   • concept map    │
│      │   • active block  │   • flat notes     │
│      │   • interim text  │   • add note btn   │
│      │                   │                    │
│      ├──────────────────┼────────────────────┤
│      │  AUTO EXPLAIN     │  COLD CALL /       │
│      │  (bottom-left)    │  SAVE / SEARCH     │
│      │  ★ always visible │  (bottom-right)    │
│      │  ★ never hidden   │  contextual:       │
│      │    behind a tab   │  - cold call >     │
│      │                   │  - save card >     │
│      │                   │  - search card >   │
│      │                   │  - empty state     │
├──────┴──────────────────┴────────────────────┤
│ Bottom Panel (UNCHANGED — tabs + CC col)      │
└─────────────────────────────────────────────┘
```

---

## 2. Vertical split ratio: **65/35** (top row / bottom row)

| Region | Ratio | Rationale |
|--------|-------|-----------|
| Top row (Transcript + Notes) | **65%** | Primary workspace, needs room for scrollable content |
| Bottom row (AutoExplain + ColdCall/etc) | **35%** | Cards are compact; auto-explain has ScrollView but doesn't need full height |

**Implementation:** Use `LayoutPriority` or a fixed fraction. Suggested approach: `GeometryReader` → `geo.size.height * 0.65` for the top row, remainder for bottom row. No user-resizable split handle between rows — the 65/35 split is fixed. The user can resize the overall window; the ratio scales proportionally.

> **Why no resize handle?** Unlike the Notes width which directly affects transcript reading comfort, the top/bottom split doesn't benefit from manual adjustment. The cards in the bottom row are designed to be compact. If future usage data shows a need, a drag handle can be added then.

---

## 3. Horizontal split ratio: **55/45** (left column / right column)

| Region | Ratio | Rationale |
|--------|-------|-----------|
| Left column (Transcript + AutoExplain) | **55%** | Transcript is wide; needs more horizontal space for line-length readability |
| Right column (Notes + ColdCall/Save/Search) | **45%** | Notes/cards work well at narrower widths |

**Implementation:** Same approach as top/bottom — `geo.size.width * 0.55` for left column. The **vertical divider between left and right columns IS resizable** via a drag handle (reuse the existing pattern from the current `notesWidth` handle). The divider runs the full height of both rows (top and bottom), so dragging it resizes both quadrants simultaneously.

> **Why keep a resize handle?** The horizontal split directly impacts readability of the transcript and the usefulness of the notes panel. Users vary in how much Notes width they prefer. This is the same interaction as the current layout.

---

## 4. Exact `LiveTabView.swift` code structure

```swift
import SwiftUI

struct LiveTabView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // ── Top Row: Transcript | Notes ──
                HStack(spacing: 0) {
                    TranscriptPanelView()
                        .frame(width: leftColumnWidth(geo))

                    // Vertical divider with drag handle
                    Rectangle()
                        .fill(Color(hex: "E8E8E8"))
                        .frame(width: 1)
                        .gesture(DragGesture().onChanged {
                            vm.notesWidth = max(200, min(500,
                                vm.notesWidth - $0.translation.width))
                        })

                    NotesPanelView()
                        .frame(width: rightColumnWidth(geo))
                }
                .frame(height: topRowHeight(geo))

                // ── Horizontal divider ──
                Rectangle()
                    .fill(Color(hex: "F8F8F8"))
                    .frame(height: 5)
                    .overlay(
                        Rectangle().fill(Color(hex: "E8E8E8")).frame(height: 1),
                        alignment: .top
                    )
                    .overlay(
                        Rectangle().fill(Color(hex: "E8E8E8")).frame(height: 1),
                        alignment: .bottom
                    )

                // ── Bottom Row: Auto Explain | ColdCall/Save/Search ──
                HStack(spacing: 0) {
                    // Bottom-Left: Auto Explain (always visible)
                    AutoExplainBottomQuadrant()
                        .frame(width: leftColumnWidth(geo))

                    // Divider (same vertical line, continues from above)
                    Rectangle()
                        .fill(Color(hex: "E8E8E8"))
                        .frame(width: 1)

                    // Bottom-Right: Cold Call / Save / Search (contextual)
                    ContextualBottomQuadrant()
                        .frame(width: rightColumnWidth(geo))
                }
                .frame(height: bottomRowHeight(geo))

                // ── Bottom Panel (UNCHANGED) ──
                BottomPanelView()
            }
        }
    }

    // MARK: - Layout helpers

    private func leftColumnWidth(_ geo: GeometryProxy) -> CGFloat {
        (geo.size.width - 1) * 0.55   // 55% of available width (minus 1px divider)
    }

    private func rightColumnWidth(_ geo: GeometryProxy) -> CGFloat {
        (geo.size.width - 1) * 0.45
    }

    private var dividerWidth: CGFloat { 1.0 }

    private func topRowHeight(_ geo: GeometryProxy) -> CGFloat {
        (geo.size.height - 5) * 0.65  // 65% of available height (minus 5px divider)
    }

    private func bottomRowHeight(_ geo: GeometryProxy) -> CGFloat {
        (geo.size.height - 5) * 0.35
    }
}
```

---

## 5. Bottom-Left Quadrant: `AutoExplainBottomQuadrant `

Always rendered, never removed from the view hierarchy. Even when idle, the container exists and shows a placeholder.

```swift
struct AutoExplainBottomQuadrant: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("AUTO EXPLAIN").font(.inter(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "5A5A5A"))
                Spacer()
                if vm.autoExplainNew || vm.autoExplainStreaming {
                    Circle().fill(Color(hex: "7C3AED")).frame(width: 5, height: 5)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color(hex: "F8F8F8"))
            .overlay(Rectangle().fill(Color(hex: "E8E8E8")).frame(height: 1),
                     alignment: .bottom)

            // Content
            if vm.autoExplainResult != nil || vm.autoExplainStreaming {
                AutoExplainCardView()
            } else {
                idlePlaceholder
            }
        }
        .background(Color.white)
    }

    var idlePlaceholder: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("Watching for unfamiliar terms…")
                .font(.inter(size: 12)).foregroundColor(Color(hex: "C0C0C0"))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
```

**Rules for AutoExplainBottomQuadrant:**
1. Always in the view tree — never conditionally removed (e.g., no `if` that hides the entire quadrant).
2. `idlePlaceholder` shows when `autoExplainResult == nil && !autoExplainStreaming`.
3. When `autoExplainResult != nil || autoExplainStreaming`, render `AutoExplainCardView()` inside the quadrant (the card fills available space).
4. The purple dot indicator (already in `vm.autoExplainNew`) shows when a new auto-explain arrived while the user was looking elsewhere.

---

## 6. Bottom-Right Quadrant: `ContextualBottomQuadrant`

Shows exactly one view at a time based on a priority chain:

```swift
struct ContextualBottomQuadrant: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Content
            Group {
                if let p = vm.coldCallPhase {
                    ColdCallCardView(phase: p)
                        .padding(12)
                } else if let card = vm.activeCard {
                    switch card {
                    case .save(let _):
                        SaveCardView()
                    case .search(let _):
                        SearchCardView()
                    }
                } else {
                    emptyPlaceholder
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.white)
    }

    var emptyPlaceholder: some View {
        VStack(spacing: 6) {
            Spacer()
            Text("COLD CALL / SAVE / SEARCH")
                .font(.inter(size: 11, weight: .semibold))
                .foregroundColor(Color(hex: "9A9A9A"))
            Text("Activity appears here")
                .font(.inter(size: 11))
                .foregroundColor(Color(hex: "C0C0C0"))
            Spacer()
        }
    }
}
```

### Priority chain (determines which view is shown)

| Priority | Condition | View to show |
|----------|-----------|-------------|
| 1 (highest) | `vm.coldCallPhase != nil` | `ColdCallCardView(phase:)` |
| 2 | `vm.activeCard == .save(_)` | `SaveCardView()` |
| 3 | `vm.activeCard == .search(_)` | `SearchCardView()` |
| 4 (default) | None of the above | Empty placeholder |

**Why cold call has highest priority:** Cold call is time-sensitive — the professor asked a question and the student needs to see it immediately. Save and Search are user-initiated actions that can wait a moment. If a cold call arrives while the user is looking at a saved card, cold call replaces it. When the cold call is dismissed (via the ✕ button or after 45s auto-dismiss), the view falls through to the next active state (save/search/empty).

**Edge cases:**
- *Cold call arrives while Save is visible:* Cold call takes over. Save is not lost — it's still in `vm.activeCard` and will reappear when the cold call is dismissed.
- *User initiates Search while a cold call is visible:* Cold call stays (higher priority). The search result is still processed; it's accessible via the bottom panel's "Searched" tab.
- *Both Save and Search are active:* Save wins (priority 2 > 3). Search results are not lost — accessible via bottom panel "Searched" tab and `vm.sessionSearches`.

---

## 7. Interaction with `BottomPanelView` (unchanged)

`BottomPanelView` stays **exactly as-is** — it is simply placed below the 2×2 grid in the VStack. No modifications to its tabs, cold call column, or internal logic.

### What this means for content overlap

The bottom panel's **Current tab** (`bottomTab == "current"`) currently shows `SearchCardView` / `SaveCardView` when there's an active card. After this change, both the bottom-right quadrant AND the bottom panel's Current tab can show the same card. This is **intentional redundancy** per the Founder's requirement:

| Location | Shows |
|----------|-------|
| **Bottom-right quadrant** (2×2 grid) | Featured/primary view — always visible at a glance |
| **Bottom panel → Current tab** | Same card, same state — gives access to the full-width card with more space, history lists, and the "Saved"/"Searched" tabs |

The bottom panel's **Auto tab** will continue to show `AutoExplainCardView`. When the user clicks the Auto tab, they get a full-width auto-explain view (the same data, just wider). This is also redundant but acceptable — users who prefer the dedicated tab experience get it.

**Future consideration (not for this PR):** The Auto tab in the bottom panel could be removed or turned into a "history" view once the 2×2 grid ships, but the spec requires keeping the bottom panel untouched now.

---

## 8. Resize handles summary

| Handle | Location | Resizable? | Default | Range | Behavior |
|--------|----------|-----------|---------|-------|----------|
| Vertical divider (left/right) | Between left and right columns, runs full height of both rows | **Yes** | 55/45 | Min left: 200px, Max left: 500px | Drag gesture updates `vm.notesWidth` (same published property, same code pattern). Affects both top and bottom rows simultaneously. |
| Horizontal divider (top/bottom) | Between top and bottom rows | **No** — fixed 65/35 | 65/35 | N/A | No drag handle. Fixed ratio. |

**Rationale for reusing `vm.notesWidth`:** The existing `notesWidth` property caps the Notes panel width. The left-column width = `geo.size.width - notesWidth - 1` (divider). This is exactly the current behavior — we just apply the same width to both rows. This avoids adding new published properties to `AppViewModel`.

---

## 9. Changes required to support files

### 9a. `LiveTabView.swift` (primary change)
Replace the current body with the new VStack structure (section 4). Add the two new helper views (`AutoExplainBottomQuadrant`, `ContextualBottomQuadrant`) either inline or in separate files.

### 9b. `AppViewModel.swift`
**No new published properties** needed. All relevant state already exists:
- `autoExplainResult`, `autoExplainStreaming`, `autoExplainNew`, `autoExplainTokens` — used by bottom-left quadrant
- `coldCallPhase` — used by bottom-right quadrant (priority 1)
- `activeCard` (`.save` / `.search`) — used by bottom-right quadrant (priority 2/3)
- `notesWidth` — reused for horizontal split handle

### 9c. `NotesPanelView.swift`
**No changes needed.** The view already fills available space via `.frame(maxWidth: .infinity)`.

### 9d. `TranscriptPanelView.swift`
**No changes needed.** The view already fills available space.

### 9e. `AutoExplainCardView.swift`
**No changes needed.** The card is self-contained. It will now be rendered inside the bottom-left quadrant container (which adds its own header). Note: the bottom-left quadrant wrapper already has a "AUTO EXPLAIN" header, so the card's internal header ("AUTO" badge + term name) will be nested inside that. The card will need to fill available height — verify it uses `.frame(maxWidth: .infinity, maxHeight: .infinity)` inside the quadrant.

### 9f. `BottomPanelView.swift`, `ColdCallCardView.swift`, `SearchCardView.swift`, `SaveCardView.swift`
**No changes needed.**

---

## 10. Verification checklist

- [ ] Transcript appears in top-left quadrant, sealed blocks + active block + interim text all functional
- [ ] Notes panel appears in top-right quadrant, concept map / flat notes / add/edit/delete all functional
- [ ] Auto Explain appears in bottom-left quadrant, always visible, never removed from hierarchy
- [ ] Auto Explain idle state shows "Watching for unfamiliar terms…" placeholder
- [ ] Auto Explain active state shows `AutoExplainCardView` with streaming/professional/intuition
- [ ] Cold call detected → bottom-right quadrant shows `ColdCallCardView`
- [ ] Save action (K/L shortcut) → bottom-right quadrant shows `SaveCardView`
- [ ] Search action → bottom-right quadrant shows `SearchCardView`
- [ ] Priority: cold call > save card > search card > empty placeholder
- [ ] Dismissing cold call reveals save/search if active, otherwise empty
- [ ] Vertical divider drag handle resizes both rows simultaneously (reuses `vm.notesWidth`)
- [ ] No changes to `BottomPanelView` whatsoever
- [ ] Keyboard shortcuts (K/L save, search, selection popup, right-click menu) all work
- [ ] No new published properties in `AppViewModel`

---

## 11. Open questions / future considerations

1. **Bottom panel Auto tab redundancy:** With Auto Explain permanently visible in the bottom-left quadrant, the Auto tab in the bottom panel is now redundant. Current spec says "keep bottom panel exactly as is." Future PR should consider: (a) removing the Auto tab, or (b) turning it into an auto-explain history view.

2. **Bottom panel Current tab redundancy:** Same card shows in both the bottom-right quadrant and the bottom panel's Current tab. This is acceptable but confusing. Future PR should consider: (a) removing the Current tab and only showing cards in the bottom-right quadrant, or (b) making the Current tab always show a history/list view while the featured card is in the quadrant.

3. **Fixed vs. resizable horizontal divider:** If users consistently adjust the top/bottom ratio, a drag handle can be added in a follow-up. Starting with fixed 65/35 keeps the first PR small.

4. **Bottom-right quadrant empty state:** The placeholder text "COLD CALL / SAVE / SEARCH — Activity appears here" may be too minimal. If user testing shows confusion, consider showing recent activity (last cold call, last save) in the empty state.
