# UX Page Layout Redesign — v1.1 (Revised)

**Status:** Draft · **Author:** PM · **Date:** 2026-06-25

**Founder Requirements (exact words):**
1. **"左上notes"** — Notes goes to the **top-left**, becomes the primary content
2. **"Transcript变小，且放下面"** — Transcript shrinks and moves **below Notes**
3. **Keep ALL existing features** — bottom panel with 4 tabs (Current/Saved/Searched/Auto), Cold Call column (270px), sidebar (200px), top bar, recording controls

---

## 0. Current Layout (baseline)

```
┌──────────────────────────────────────────────────────────────┐
│ TopBarView (tabs, sidebar toggle, +New, record controls)      │
├──────┬────────────────────────────┬──────────────────────────┤
│      │                            │                          │
│ Side │   Transcript Panel         │  Notes Panel             │
│ bar  │   (fills remaining         │  (default 300px,         │
│ 200px│    vertical+horizontal     │   resizable 200–500)     │
│      │    space, ~55% width)      │                          │
│      │                            │                          │
├──────┴────────────────────────────┴──────────────────────────┤
│ Bottom Panel (Current | Saved | Searched | Auto)     │ CC   │
│                                                      │ 270px│
│   ── Auto tab #4, hidden behind click                 │      │
│   ── Shows placeholder unless streaming               │      │
└──────────────────────────────────────────────────────────────┘
```

**Problems with current layout (relative to Founder's vision):**
1. **Transcript dominates** — it's the first thing the user sees (~55% of width, fills remaining vertical space)
2. **Notes is pushed to the right** — secondary position, 300px wide, competes with the user's attention
3. **Auto Explain is invisible** — buried as tab #4 in the bottom panel, easy to miss

---

## 1. Design Philosophy for a Lecture Assistant

During a live lecture, the student's needs rank by value:

| Priority | Need | Current State | Desired State |
|----------|------|---------------|---------------|
| 🥇 | **Notes (AI-generated, structured)** — most valuable for review after class | Right column, 300px, secondary | **Hero position, top-left, as large as possible** |
| 🥈 | **Transcript (raw text, reference)** — reference material, scanned occasionally | Primary, ~55% width, top | Below Notes, smaller, accessible |
| 🥉 | **Auto Explain** — term definitions on demand | Hidden behind tab #4 | Always visible somewhere |

The new layout flips the priority: **Notes becomes the primary surface**, Transcript becomes secondary reference below it.

---

## 2. Option A — "Vertical Stack" (Notes Hero Above Transcript)

### Layout

```
┌──────────────────────────────────────────────────────────────┐
│ TopBarView                                                     │
├──────┬────────────────────────────────┬──────────────────────┤
│      │                                │                      │
│ Side │  NOTES (hero, top, primary)    │   AUTO DOCK         │
│ bar  │  ~52–60% of vertical space     │   (always visible,  │
│ 200px│  fills available horizontal    │    fixed 160px)     │
│      │  width                          │                      │
│      ├────────────────────────────────┤                      │
│      │  TRANSCRIPT (secondary,        │   (auto dock spans  │
│      │  below, smaller)               │    full height of   │
│      │  ~28–36% of vertical space     │    notes + trans.)  │
│      │                                │                      │
├──────┴────────────────────────────────┴──────────────────────┤
│ Bottom Panel (Current | Saved | Searched | Auto)     │ CC   │
│                                                      │ 270px│
│   ── Auto tab REMOVED from bottom panel               │      │
│   ── Auto Explain lives in the permanent right dock   │      │
└──────────────────────────────────────────────────────────────┘
```

### Vertical space allocation (1280×800 window, approximate)

| Zone | Height | % of content area |
|------|--------|-------------------|
| TopBarView | 44px | — |
| **Notes (hero)** | **~392px** | **~52%** |
| Resize handle | 5px | — |
| **Transcript** | **~209px** | **~28%** |
| Bottom Panel + CC | ~150px | ~20% |

Both Notes and Transcript share the full width of the center column (minus the Auto dock on the right).

### What changes

| Aspect | Before | After |
|--------|--------|-------|
| Notes position | Right column, 300px | **Top-left, hero, full center width** |
| Notes width | Fixed 200–500px (resizable) | Full width minus 280px Auto dock |
| Notes height | Depends on Transcript | ~52% of content area (resizable: 40–65%) |
| Transcript position | Top, left of Notes | **Below Notes, smaller** |
| Transcript height | ~75% of content area | ~28% of content area (resizable: 20–45%) |
| Bottom Panel | 4 tabs (Auto tab #4) | 3 tabs (Auto tab removed) |
| Auto Explain | Tab #4, hidden | **Permanent right dock, always visible** |

### File changes needed

| File | Change |
|------|--------|
| `LiveTabView.swift` | **Complete rewrite** — replace HStack with VStack of Notes above Transcript. Replace `notesWidth` resizable divider with a vertical resizable divider between Notes and Transcript. Add right-side Auto dock column. |
| `BottomPanelView.swift` | Remove the Auto tab (`autoTabBtn`). Remove `auto` case from `bodyContent`. Bottom panel shrinks to 3 tabs. |
| `AppViewModel.swift` | Replace `notesWidth: CGFloat` with `notesHeightRatio: CGFloat` (range 0.4–0.65). Add `autoDockWidth: CGFloat` (default 280). Remove `bottomTab = "auto"` references if safe. Remove `autoExplainNew` and `autoExplainStreaming` as bottom-tab triggers (they now drive the dock). |
| `AutoExplainCardView.swift` | Minor — wrap to fit inside a 280px column instead of full-width bottom panel. Remove the border/shadow for inline dock appearance, or keep card style with new background. |
| *(New file)* `AutoDockView.swift` | New container that wraps AutoExplainCardView inside a fixed-height vertical strip with idle/streaming/complete/collapsed states. Always rendered. |

### Auto Dock (right column, always visible)

A permanent vertical dock on the right side of the center content area:
- **280px wide**, spans the full height of Notes + Transcript areas
- **States:**
  - *Idle:* Shows purple "AUTO" badge + "Watching for unfamiliar terms…" with a subtle pulsing icon
  - *Streaming:* Shows the live Auto Explain card with streaming tokens
  - *Complete:* Shows the finished card with Save to Knowledge button
  - *Dismissed:* Collapses to a 32px-wide purple "AUTO" pill on the right edge — tap to re-expand
- A thin gray border separates it from the Notes/Transcript area
- The dock is **scrollable internally** if card content exceeds its height
- When dismissed, the Notes/Transcript area expands to reclaim the 280px

### Vertical resize handle

A horizontal bar (5px tall, draggable) between Notes and Transcript:
- Currently: `Rectangle().fill(Color(hex: "E8E8E8")).frame(height: 5)` — exists as a divider
- **New behavior:** Make it draggable to resize Notes vs. Transcript vertical split
- Range: Notes 40–65% of available height, Transcript the remainder
- Same drag gesture pattern as the current horizontal divider

### Pros (from student perspective)

| Pro | Why |
|-----|-----|
| **Notes = hero, top-left** | Student's most valuable asset during and after lecture is front and center. Reading order: Notes first, then Transcript if needed. |
| **Transcript always accessible** | Scroll down or resize handle up to see more transcript. It's not hidden, just deprioritized. |
| **Auto Explain always visible** | No need to click tabs. The term definition appears in the right column automatically. |
| **Natural lecture flow** | Notes are AI-generated during the lecture — seeing them update in real-time in the hero position is the best feedback loop. |
| **Bottom panel clean** | 3 tabs instead of 4 = less visual noise. Auto is no longer competing for attention. |

### Cons (from student perspective)

| Con | Why | Mitigation |
|-----|-----|------------|
| **No side-by-side Notes + Transcript** | User can't scan both simultaneously in the same horizontal view. Options B addresses this. | Can quickly scroll up/down — Notes are concise, Transcript is reference. |
| **Right column adds width** | 280px for Auto dock + 200px sidebar = 480px of fixed-width columns. On a 1280px window, center content is only 800px wide — tight for Notes. | Auto dock collapses to 32px pill when dismissed. Or: make Auto dock width dynamic (expand only when active). |
| **Transcript may feel too small** | At ~209px height (~28%), only ~5–6 lines of transcript are visible. | Resize handle lets the user grow it. Or: show only the most recent/largest blocks and let the user expand. |
| **Bottom tab count change** | Auto tab removal changes user habit. | Toast on first launch: "Auto Explain moved to the right dock →" |

---

## 3. Option B — "Corner Flip" (Notes Top-Left, Transcript Right)

### Layout

```
┌──────────────────────────────────────────────────────────────┐
│ TopBarView                                                     │
├──────┬───────────────────────────────┬───────────────────────┤
│      │                               │                       │
│ Side │  NOTES (left, wider, hero)    │  TRANSCRIPT           │
│ bar  │  ~60–65% of center width      │  (right, smaller)     │
│ 200px│  top-left corner, full height │  ~30–35% of center   │
│      │  above bottom panel           │  width, full height   │
│      │                               │                       │
│      ├───────────────────────────────┤                       │
│      │  AUTO EXPLAIN BAR (fixed      │                       │
│      │  strip, 80px)                 │                       │
│      │  spans full width of Notes    │                       │
│      │  column                       │                       │
├──────┴───────────────────────────────┴───────────────────────┤
│ Bottom Panel (Current | Saved | Searched | Auto)     │ CC   │
│                                                      │ 270px│
│   ── Auto tab MOVED to position #1 (default active)   │      │
│   ── All 4 tabs preserved                             │      │
└──────────────────────────────────────────────────────────────┘
```

### Horizontal space allocation (1280×800 window)

| Zone | Width | % |
|------|-------|---|
| Sidebar | 200px | — |
| **Notes (left, hero)** | **~580px** | **~60%** |
| Auto Explain bar | same 580px (below Notes) | — |
| **Transcript (right, smaller)** | **~290px** | **~30%** |
| Resizable divider | 4px | — |
| *(no right dock — Auto uses bottom tab + bar)* |

### Vertical space allocation

| Zone | Height | % of content area |
|------|--------|-------------------|
| TopBarView | 44px | — |
| **Notes** | **~452px** | **~60%** |
| **Auto Explain bar (80px fixed)** | **80px** | **~11%** |
| Bottom Panel + CC | ~224px | ~29% |

Notes gets ~60% of vertical space. Within Notes' column space (~580px wide), it has plenty of room for concept maps and slide sections.

### What changes

| Aspect | Before | After |
|--------|--------|-------|
| Notes position | Right column, 300px | **Top-left, hero, ~60% width, full height** |
| Notes width | 300px (200–500 resizable) | 580px (~60% of center, 50–70% resizable) |
| Transcript position | Top, left of Notes | **Right of Notes, smaller, ~30% width** |
| Transcript width | ~80% of center | ~30% of center (resizable: 25–45%) |
| Horizontal split | Transcript (big) \| Notes (small) | **Notes (big) \| Transcript (small)** |
| Auto Explain | Tab #4, hidden | **Dual presence:** fixed 80px bar below Notes + Auto tab as default active in bottom panel |
| Bottom panel | 4 tabs (Auto #4) | 4 tabs (Auto moves to **position #1**, default) |

### File changes needed

| File | Change |
|------|--------|
| `LiveTabView.swift` | **Rewrite** — flip the HStack: Notes on left, Transcript on right. Swap the divider draggable to resize from Notes side. Remove `notesWidth`, add `notesRatio: CGFloat` (0.5–0.7). Add the Auto Explain bar between Notes and Bottom Panel. |
| `BottomPanelView.swift` | No structural changes — keep all 4 tabs. Change default `bottomTab` to `"auto"` during live lectures. Tab order: Auto → Current → Saved → Searched. |
| `AppViewModel.swift` | Replace `notesWidth` with `notesRatio: CGFloat` (default 0.6, range 0.5–0.7). Add `autoBarVisible: Bool` (default true for the fixed bar). |
| *(New file)* `AutoExplainBarView.swift` | New 80px fixed strip below Notes. Shows AUTO badge + term name + preview. Tap opens Auto tab in bottom panel. Collapsible to 24px pill. |
| `AutoExplainCardView.swift` | No changes — still renders inside bottom panel's Auto tab. |

### Auto Explain Bar (new: always-visible strip below Notes)

An 80px horizontal bar that sits between Notes and the Bottom Panel:
- Spans the full width of the Notes column (not the Transcript column)
- **States:**
  - *Idle:* Purple "AUTO" badge + "Auto-explain active — watching for unfamiliar terms…" with subtle pulse
  - *Active:* Shows detected term name + first line of professional explanation (streaming)
  - *Complete:* Shows term name + first 60 characters of explanation + "View full →" button
  - *Collapsed:* 24px-tall stripe showing just "AUTO" pill — tap to re-expand
- Clicking anywhere on the bar opens the **Auto tab** in the bottom panel (scrolls to the full card)
- Has a dismiss "✕" that collapses it to the pill state

### Transcript right column

- Smaller: ~290px wide by default (25–45% resizable range)
- Shows same content as today: sealed blocks, active block, interim text
- Selection popup works the same way
- The narrower width means block text may wrap more, but that's acceptable for a reference panel

### Notes left column

- Hero position: top-left, ~580px wide
- Full-height (minus Auto bar and bottom panel)
- Shows all existing content: NoteBlocks, Concept Map tree, slide sections
- Slide headers and concept nodes now have more horizontal room — less text wrapping
- The plus-button for adding notes is more accessible (top-left corner)

### Pros (from student perspective)

| Pro | Why |
|-----|-----|
| **Notes = hero, top-left** | Fulfills Founder's requirement perfectly. Notes is visually dominant: bigger, wider, top-left. |
| **Side-by-side Notes + Transcript** | User can reference both simultaneously — scan transcript on the right while reading notes on the left. Better than Option A for power users. |
| **All 4 bottom tabs preserved** | Zero feature removal. No retraining needed for existing users. |
| **Auto Explain bar is always visible** | Glanceable strip below Notes shows what's happening. Tapping opens the full card in the bottom panel. |
| **Transcript still accessible** | Right column, smaller but always present. The user can widen it with the resize handle if needed. |

### Cons (from student perspective)

| Con | Why | Mitigation |
|-----|-----|------------|
| **Transcript may feel squeezed** | At 30% width (~290px), long blocks wrap significantly. May need to scroll more. | Resize handle lets the user drag wider. Or: use a smaller font size in transcript (11px instead of 13px). |
| **Auto bar adds visual noise** | A permanent 80px strip consumes vertical space even when idle. | Collapsed state (24px pill) can be the default; only expand when content is present. |
| **Notes + Transcript + Auto + Bottom = 4 zones** | More visual zones than today's 3 (Transcript + Notes + Bottom). | Each zone has a clear visual hierarchy: Notes (dominant) > Transcript (supporting) > Auto (thin strip) > Bottom (actions). |
| **Bottom panel default changes** | Auto tab becomes default instead of Current. Users expecting Current need to click. | Teach with the bar: clicking the bar opens Auto tab. After using Auto, the tab stays on whatever the user last selected. |

---

## 4. Comparison Matrix

| Criterion | Option A (Vertical Stack) | Option B (Corner Flip) |
|-----------|:---:|:---:|
| **"左上notes"** (Notes top-left, hero) | ✅ **Yes** — top-left, ~52% vertical | ✅ **Yes** — top-left, ~60% width + full height |
| **"Transcript变小，且放下面"** (Transcript below, smaller) | ✅ **Below Notes, ~28% vert** | ✅ **Right of Notes, ~30% width** |
| Side-by-side Notes + Transcript | ❌ No (vertical stack) | ✅ **Yes** (horizontal split, Notes on left) |
| Notes width | Full center width (~800px) | ~60% of center (~580px) |
| Transcript readability | Horizontal full width — easy reading | Narrow (~290px) — more text wrapping |
| Auto Explain home | Permanent right dock (280px) | 80px bar below Notes + tab #1 in bottom panel |
| Bottom tabs preserved | ❌ Auto tab removed (3 tabs) | ✅ **All 4 tabs preserved** |
| Feature retention | ✅ All features preserved, Auto relocated | ✅ All features preserved |
| Implementation effort | Medium–High (new dock, new vertical resize, change bottom panel) | Medium (flip divider, new bar, change bottom panel tab order) |
| Learning curve | Low (simple stack layout) | Low–Medium (transcript moved to right side) |
| Best for... | Students who prioritize Notes above all and rarely need transcript reference | Power users who want side-by-side reference but with Notes as primary |

---

## 5. Transcript Rendering Considerations (Both Options)

When the transcript is smaller (whether below or to the right), the UX needs tuning:

| Concern | Mitigation |
|---------|-----------|
| Too few lines visible | Show only the most recent sealed blocks (last 5–8) + the active block. Older blocks are accessible by scrolling up. |
| Text too small to read | Keep 13px font size. Option B's narrow column can use 12px with tighter line height. |
| Selection + popup still works | The `NSTextView.didChangeSelectionNotification` monitor is unaffected — it operates on the text object, regardless of frame size. |
| Interim text visible | The interim text strip below the last block still works. |
| Scroll freezing | The "Resume" frozen-scroll banner is unaffected. |

---

## 6. Auto Explain — Two Approaches

### Option A's approach: Permanent right dock

```
┌────────────────┐
│ NOTES          │
│ (hero, top)    │
│                │
├────────────────┤ Auto Dock (280px, full height)
│ TRANSCRIPT     │  ┌──────────────────┐
│ (below)        │  │ AUTO             │
│                │  │ • Badge + term   │
│                │  │ • Explanation or │
│                │  │   idle state     │
│                │  │ • ✕ dismiss      │
│                │  └──────────────────┘
└────────────────┘
```

- **Always rendered** — never disappears entirely
- When no term detected: "Watching for unfamiliar terms…" with pulse animation
- When streaming: real-time token display
- When complete: full card + Save to Knowledge button
- Dismiss collapses to 32px width pill

### Option B's approach: Fixed bar + default bottom tab

```
┌───────────────────────────────┬──────────┐
│ NOTES                         │ TRANSCRIPT│
│ (hero, left)                  │ (right)   │
│                               │           │
├───────────────────────────────┤           │
│ AUTO │ [term] │ explanation…  │  ✕        │  ← 80px bar
├───────────────────────────────┴──────────┤
│ Auto (default) │ Current │ Saved │ Searched│      │ CC │
│ ┌─ Full AutoExplainCardView ─────────┐   │      │    │
│ │ PRO: ... INTU: ...                 │   │      │    │
│ └────────────────────────────────────┘   │      └────┘
└──────────────────────────────────────────┘
```

- The 80px bar is always visible but can collapse to 24px
- When bar is clicked, bottom panel shows the full Auto tab content
- Auto tab is the **default active tab** during live lectures (was tab #4)

---

## 7. Recommendations Per User Persona

| Persona | Best Option | Reasoning |
|---------|:-----------:|-----------|
| **New student** (first time using Grasp) | **Option A** | Simple vertical stack. "What you see is what matters most." Lowest cognitive load. |
| **Power user** (multiple lectures, heavy note-taking) | **Option B** | Side-by-side reference. All tabs preserved. Familiar bottom panel. |
| **International lecture** (needs translation reference) | **Option B** | Seeing transcript + notes simultaneously helps language comprehension. |
| **Concept-map heavy user** (v1.1 feature) | **Option A** | Full-width concept tree rendering. The tree gets maximum horizontal space. |

---

## 8. Next Steps

1. Founder reviews Options A and B and selects a direction (or hybrid).
2. PM writes detailed per-view spec for the chosen option, including exact frame sizes, resize ranges, and state transitions.
3. Engineer implements in `wt/<slug>` branch.
4. QA verifies against this document's layout diagrams and risk mitigations.

---

*This document was written in response to Founder's requirements: "左上notes" and "Transcript变小，且放下面", with all existing features preserved.*
