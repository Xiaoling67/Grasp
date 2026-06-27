# Auto Explain Page Layout — UX Plan

**Feature:** Auto Explain prominence redesign  
**Author:** pm (DeepSeek)  
**Status:** Options for Founder decision  
**Target release:** v1.1

---

## Current Layout (Problem Statement)

```
┌──────────────────────────────────────────────────────────┐
│  Transcript Panel  │  Notes Panel                        │
│                    │                                     │
│  (word-by-word     │  (AI notes,          │              │
│   live blocks)     │   slide sections)    │              │
│                    │                                     │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  Bottom Panel (shared space)                             │
│  ┌──────┬───────┬──────────┬──────┐                      │
│  │Current│Saved│Searched│Auto│                      │
│  └──────┴───────┴──────────┴──────┘                      │
│  │                    │  │  Cold Call            │       │
│  │ Save/Search card   │  │  column               │       │
│  │ OR empty state     │  │  (270px)              │       │
│  │ OR Auto Explain    │  │                       │       │
│  │ (hidden in tab)    │  │                       │       │
│  └────────────────────┘  └───────────────────────┘       │
└──────────────────────────────────────────────────────────┘
```

**Problem:** Auto Explain is buried as the 4th tab in the bottom panel. When it fires, the user must notice the purple dot and manually switch to the Auto tab. It competes for space with Save and Search cards (Current tab) and the Saved/Searched history lists. There's no visual prominence — it looks like just another tab.

**RULES (must not violate):**
1. All 4 tabs (Current | Saved | Searched | Auto) remain exactly as-is
2. Cold Call column stays in the right column, unchanged
3. Auto Explain must get MORE prominence, not less
4. Save/Search/Saved workflow must not be disrupted

---

## Proposal A: Floating Card Overlay ("Auto Explain Popover")

### Description

When auto-explain fires, a compact card animates in from the bottom-right corner of the transcript area, overlaying the transcript and notes panel. It shows the term, a brief preview ("Defining X…"), and can be:
- **Clicked/tapped** → expands to full explanation (defintion + analogy) inline in the overlay
- **Dismissed (✕)** → disappears AND the full explanation is logged to the Auto tab (so nothing is lost)
- **Ignored** → auto-collapses back to the Auto tab after 12 seconds

The overlay is always **above** the transcript, not replacing anything. The full content persists in the Auto tab for reference.

```
┌──────────────────────────────────────────────────────────┐
│  Transcript Panel        │  Notes Panel                  │
│                          │                               │
│  ... professor said WACC  │                               │
│  is important...           │                               │
│                          │                               │
│  ┌──────────────────────┐│                               │
│  │ AUTO  WACC (Weighted ││                               │
│  │ Average Cost of      ││  ← floating card, semi-       │
│  │ Capital) — a measure ││    transparent shadow          │
│  │ of ...               ││                               │
│  │ [Save to Knowledge] ✕││                               │
│  └──────────────────────┘│                               │
├──────────────────────────────────────────────────────────┤
│  Bottom Panel (unchanged)                                │
│  ┌──────┬───────┬──────────┬──────┐  │  Cold Call       │
│  │Current│Saved│Searched│Auto│  │                  │
│  └──────┴───────┴──────────┴──────┘  │                  │
│  │ Save/Search cards        │  │  CC answer          │
│  └──────────────────────────┘  └──────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

### Visual spec
- Floating card: 340×200 (compact) / 340×400 (expanded), positioned bottom-right of the transcript panel
- Background: white, `cornerRadius(10)`, shadow opacity 0.15, y-offset 2
- Purple left border accent (2px, `#7C3AED`)
- Entry animation: slide up + fade in (0.3s ease-out)
- Exit animation: slide down + fade out (0.2s ease-in)
- 12s auto-dismiss timer (shown as a shrinking purple progress bar on the left edge)
- When dismissed: overlay removed, full content saved to Auto tab, `autoExplainNew = true` (purple dot appears on Auto tab)

### Files that change

| File | Change |
|------|--------|
| **NEW:** `Grasp/Views/Bottom/FloatingAutoExplainView.swift` | New floating card view (~80 lines) |
| `Grasp/Views/Layout/LiveTabView.swift` | Add `.overlay()` modifier to the transcript+notes HStack, conditionally showing `FloatingAutoExplainView` when `vm.showingFloatingAutoExplain` |
| `Grasp/ViewModels/AppViewModel.swift` | Add `@Published var showingFloatingAutoExplain: Bool` (default false), `autoExplainDismissTask: Task<Void, Never>?`, 12s timer logic in `autoExplain()`, `dismissFloatingAutoExplain()` method |
| `Grasp/Views/Bottom/AutoExplainCardView.swift` | **No change** — still renders inside the Auto tab |
| `Grasp/Views/Bottom/BottomPanelView.swift` | **No change** — all 4 tabs, Cold Call column unchanged |

### Acceptance criteria

| # | Criteria | Verification |
|---|----------|-------------|
| 1 | When auto-explain detects a term, a floating card appears over the transcript within 300ms | Visual inspection: card slides up from bottom-right of transcript area |
| 2 | Floating card shows the term + definition (streaming) | Card content matches streaming auto-explain output |
| 3 | User can click the card to expand inline (compact → full) | Tap test: compact card → full explanation shown in same overlay |
| 4 | User can dismiss with ✕ → overlay disappears, content preserved in Auto tab | Switch to Auto tab: full explanation is visible |
| 5 | After 12 seconds of no interaction, card auto-dismisses | Wait 12s: card animates out, purple dot appears on Auto tab |
| 6 | Auto tab still shows all auto-explain history | Multiple auto-explain events → each appears in Auto tab list |
| 7 | Cold Call column is unaffected | Cold Call detection + rendering works identically |
| 8 | Save/Search/Saved workflows are unaffected | User can select transcript text → Search/Save works as before |
| 9 | Floating card does not block transcript interaction | Card is `.allowsHitTesting(false)` on the transcript area behind it — user can still select text under/around it |

### Pros

- **Maximum prominence** — appears directly in the user's field of view, no tab-switching needed
- **Temporal** — doesn't permanently occupy space; disappears after viewing
- **Nothing lost** — all content preserved in Auto tab
- **Zero disruption** to existing bottom panel workflow
- **Delightful UX** — animation feels responsive and modern

### Cons

- **Overlays content** — may briefly cover a portion of the transcript (mitigated: compact size + bottom-right position)
- **12s timer may feel rushed** for slow readers (mitigated: clicking expands and pauses timer)
- **More code complexity** — overlay management, timer, animation, hit-testing
- **Potential visual clutter** if auto-explain fires rapidly (mitigated: debounce — new card replaces previous instead of stacking)

---

## Proposal B: Prominent Banner Between Transcript and Bottom Panel

### Description

Add a persistent banner zone between the transcript+notes area and the bottom panel. When auto-explain is idle, it shows a thin 4px purple accent line. When auto-explain fires, a card expands upward from that line showing the term, definition, and analogy — like a notification bar that slides open.

The banner is always visible at the bottom of the transcript area — it doesn't compete with the Bottom Panel's tabs at all.

```
┌──────────────────────────────────────────────────────────┐
│  Transcript Panel        │  Notes Panel                  │
│                          │                               │
│  ... professor said WACC  │                               │
│  is important...           │                               │
│                          │                               │
├──────────────────────────────────────────────────────────┤
│  ┌─ AUTO ─────────────────────────────────────────────┐│
│  │ WACC (Weighted Average Cost of Capital)            ││
│  │ A measure of a company's cost to borrow money...   ││
│  │ [Save to Knowledge]                        ✕      ││
│  └────────────────────────────────────────────────────┘│
├──────────────────────────────────────────────────────────┤
│  5px separator (same as current)                        │
├──────────────────────────────────────────────────────────┤
│  Bottom Panel (unchanged)                                │
│  ┌──────┬───────┬──────────┬──────┐  │  Cold Call       │
│  │Current│Saved│Searched│Auto│  │                  │
│  └──────┴───────┴──────────┴──────┘  │                  │
│  │ Save/Search cards        │  │  CC answer          │
│  └──────────────────────────┘  └──────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

### Visual spec
- Banner idle state: 4px purple line (`#7C3AED`), full width
- Banner active state: expands upward to show AutoExplainCardView content (~180px when expanded)
- Expansion animation: slide down + height change (0.25s ease-out)
- Collapse: slide up (0.2s ease-in)
- When multiple auto-explain events arrive, show the **latest** in the banner; earlier ones remain accessible in the Auto tab
- Dismiss (✕) collapses the banner back to the idle purple line
- Banner has the same full width as the transcript+notes area (spans both panels)

### Files that change

| File | Change |
|------|--------|
| `Grasp/Views/Layout/LiveTabView.swift` | Replace the `Rectangle().fill(Color(hex: "F8F8F8")).frame(height: 5)` separator with `AutoExplainBannerView()`, conditionally sized |
| **NEW:** `Grasp/Views/Bottom/AutoExplainBannerView.swift` | New banner view: thin accent line when idle, expanded card when active (~100 lines) |
| `Grasp/ViewModels/AppViewModel.swift` | Add `@Published var showAutoExplainBanner: Bool` (default false), banner state logic in `autoExplain()`, `dismissAutoExplainBanner()` method |
| `Grasp/Views/Bottom/AutoExplainCardView.swift` | **No change** — can optionally refactor to share content rendering with banner, but not required |
| `Grasp/Views/Bottom/BottomPanelView.swift` | **No change** — all 4 tabs, Cold Call column unchanged |

### Acceptance criteria

| # | Criteria | Verification |
|---|----------|-------------|
| 1 | When no auto-explain is active, a thin 4px purple line spans the width above the bottom panel | Visual inspection: purple line visible, no card content |
| 2 | When auto-explain fires, the banner expands upward to show term + definition | Content appears with slide animation |
| 3 | Banner shows streaming content (tokens appear as they arrive) | Comparison: banner streaming matches Auto tab streaming |
| 4 | Dismiss collapses the banner back to the idle line | Tap ✕ → animation collapses to 4px line |
| 5 | Auto tab still contains all auto-explain history | Switch to Auto tab: all explanations are listed |
| 6 | Bottom panel tabs, Save/Search/Saved, Cold Call all unaffected | Full workflow regression test |
| 7 | Multiple auto-explain events: banner shows latest, Auto tab shows all | Fire 3 auto-explains → banner shows #3, Auto tab lists all 3 |
| 8 | Purple dot on Auto tab syncs with banner state | When banner is active, Auto tab shows purple dot |

### Pros

- **Always visible line** — the purple accent line even in idle state signals that Auto Explain exists
- **Doesn't overlay any content** — it's between transcript and bottom panel, not covering either
- **Full width** — spans both transcript and notes panels, feels intentional and designed
- **Persistent but dismissible** — user controls when to collapse it
- **Separate from bottom panel tabs** — no competition with Save/Search/Saved workflow
- **Natural reading flow** — eye moves from transcript → banner → bottom panel

### Cons

- **Takes vertical space when expanded** (~180px + 4px = reduces bottom panel height when active)
- **May feel redundant** with the Auto tab having the same content
- **Purple line when idle** may confuse users who haven't seen it expand yet (mitigated: tooltip on first appearance)
- **Transitions between idle/active** need careful animation to avoid visual jump

---

## Proposal C: Smart Auto-Switch with Enhanced Auto Tab Header

### Description

Keep the existing layout almost entirely intact. Make two surgical changes:

1. **Auto-switch**: When auto-explain fires, automatically switch `vm.bottomTab` to `"auto"` — but ONLY if the user hasn't manually switched tabs in the last 5 seconds. If the user is actively using the Current/Saved/Searched tab, don't steal focus.

2. **Enhanced Auto tab header**: When the Auto tab is selected and has content, make the tab button visually prominent — purple background badge, auto-explain count, and a subtle pulsing indicator during streaming.

3. **Auto tab preview**: Add a small preview snippet of the latest auto-explain term in the tab button itself (e.g., "Auto: WACC") when there's a new result.

This is the **least invasive** option — it changes almost nothing about the layout.

```
┌──────────────────────────────────────────────────────────┐
│  Transcript Panel        │  Notes Panel                  │
│                          │                               │
│  ... professor said WACC  │                               │
│  is important...           │                               │
│                          │                               │
├──────────────────────────────────────────────────────────┤
│  Bottom Panel                                            │
│  ┌──────┬───────┬──────────┬─────────────────────────┐   │
│  │Current│Saved│Searched│⚡ Auto: WACC (3 new)│   │
│  │      │      │          │  (purple bg badge)      │   │
│  └──────┴───────┴──────────┴─────────────────────────┘   │
│  │                    │  │  Cold Call                    │
│  │  Auto Explain card  │  │  Column (270px)              │
│  │  (definition +     │  │                              │
│  │   analogy)          │  │                              │
│  └────────────────────┘  └──────────────────────────────┘│
└──────────────────────────────────────────────────────────┘
```

### Smart auto-switch logic (pseudocode)

```swift
// In AppViewModel.autoExplain():
let now = Date()
let userSwitchedTabRecently = (now - lastUserTabSwitchTime) < 5.0
if !userSwitchedTabRecently && bottomTab != "auto" {
    // Only auto-switch to Auto tab if user hasn't manually changed tabs recently
    withAnimation {
        bottomTab = "auto"
        autoExplainNew = false
    }
} else {
    // User is busy; just set the dot
    autoExplainNew = true
}

// Track user tab switches
// In setBottomTab(_:) setter:
lastUserTabSwitchTime = Date()
```

### Visual spec for enhanced tab
- When auto-explain has new content and Auto tab is NOT selected: tab shows a purple pill badge with count (e.g., "3 new") and the latest term name
- When Auto tab IS selected: badge changes to show streaming state
- Tab button has a subtle purple left border accent when selected and has content
- No layout changes to other tabs

### Files that change

| File | Change |
|------|--------|
| `Grasp/Views/Bottom/BottomPanelView.swift` | Modify `autoTabBtn()` to show term preview + count badge; add purple accent when selected with content. Modify `body` to use `@State` or `@Published` for `lastUserTabSwitchTime`. |
| `Grasp/ViewModels/AppViewModel.swift` | Add `@Published var lastUserTabSwitchTime: Date` (default `.distantPast`), `@Published var autoExplainCount: Int` (increment on each auto-explain event). Track tab switches. Add smart auto-switch logic in `autoExplain()`. |
| `Grasp/Views/Bottom/AutoExplainCardView.swift` | **No change** |
| `Grasp/Views/Layout/LiveTabView.swift` | **No change** |

### Acceptance criteria

| # | Criteria | Verification |
|---|----------|-------------|
| 1 | When auto-explain fires and user hasn't touched tabs for 5+ seconds, Auto tab auto-selects and shows the explanation | Keep hands away for 5s → auto-explain fires → Auto tab selected automatically |
| 2 | When auto-explain fires and user is actively using another tab (switched <5s ago), focus is NOT stolen | Switch to Current tab → within 5s auto-explain fires → Current tab stays; only purple dot appears |
| 3 | Auto tab button shows the latest term name when there are new results | e.g., "Auto: WACC" in the tab label |
| 4 | Auto tab button shows count badge ("2 new") for multiple undismissed results | Let 3 auto-explains fire without viewing → tab shows "3 new" |
| 5 | Pulsing animation during streaming on the Auto tab button | Visual: purple dot pulses subtly during `autoExplainStreaming` |
| 6 | All other tabs (Current, Saved, Searched) unchanged | Regression check: layout, badge counts, empty states all identical |
| 7 | Cold Call column unchanged | Identical layout and behavior |
| 8 | Previous auto-explain results still accessible in Auto tab when user switches away and back | Switch to another tab → back to Auto → history intact |
| 9 | No change to SearchCardView or SaveCardView behavior | Search and save workflows pass regression test |

### Pros

- **Minimal code change** — smallest diff of all proposals (~30 lines total)
- **Zero layout change** — no new UI elements, no repositioning
- **Zero vertical space impact** — bottom panel height unchanged
- **Smart about not disrupting** the user if they're actively working
- **Count + term preview** in the tab makes it clear what's waiting
- **No new view files** — only modifies existing files

### Cons

- **Auto-switch may still feel jarring** even with the 5s guard — user could be reading a search result and have it stolen
- **Doesn't add visual prominence** beyond the tab badge — Auto Explain is still a tab, not a primary UI element
- **No "always-on" visibility** — user must still be on the Auto tab to see content; there's no persistent presence
- **Count-based approach** may feel like a notification badge rather than a deliberate UX element
- **Less "delightful"** than Proposals A or B — it's a UX improvement, not a redesign

---

## Comparison Table

| Dimension | Proposal A (Floating Card) | Proposal B (Banner) | Proposal C (Smart Auto-Switch) |
|-----------|---------------------------|---------------------|-------------------------------|
| **Prominence** | ⭐⭐⭐⭐⭐ — impossible to miss | ⭐⭐⭐⭐ — always visible zone | ⭐⭐⭐ — better, but still a tab |
| **Disruption risk** | Low — overlay, dismissible | Low — between panels | Medium — may still steal focus |
| **Code complexity** | Medium (~120 new lines) | Medium (~110 new lines) | Low (~30 new lines, no new files) |
| **Vertical space impact** | Zero (overlay) | ~180px when expanded (from existing separator space) | Zero |
| **Content obstruction** | Brief, bottom-right corner | None | None |
| **"Always-on" presence** | Only when active | Purple line always present | Only tab dot when inactive |
| **Delight factor** | High — animation + auto-dismiss | Medium — smooth expansion | Low — functional improvement |
| **Implementation risk** | Low (no architectural changes) | Low | Very low |
| **Regression risk** | Low — overlay is additive | Low — banner replaces existing separator | Very low — only tab logic changes |
| **New files** | 1 | 1 | 0 |

---

## Founder Decision Needed

1. **Which proposal to implement?** (A, B, C, or a hybrid/mix)
2. **If A:** What should the auto-dismiss timer duration be? (proposed 12s)
3. **If B:** Should the idle-state purple line show a subtle tooltip on hover ("Auto Explain ready")?
4. **If C:** Should the 5-second guard be longer (e.g., 8s) or shorter (e.g., 3s)?
5. **Hybrid option:** Would you like B (banner) + C (auto-switch) together? The banner is always visible, and auto-switch adds extra convenience.
6. **Acceptance criteria** — any additional scenarios to test?
