# Bottom Panel Redesign — Layout Proposals

**Feature:** v1.1 UX — Auto Explain / Save / Search placement  
**Author:** PM Agent  
**Date:** 2026-06-24  
**Status:** Draft — awaiting Founder decision

---

## Current Layout (Problem Summary)

| Tab | Behavior | Pain Point |
|-----|----------|------------|
| **Current** | Shows active search/save results; empty otherwise | Dead tab most of the time |
| **Saved** | Stored notes & concepts | Passive — only visited on recall |
| **Searched** | Search history & results | Overlaps with Current and Saved |
| **Auto** | Auto Explain cards appear here | Hidden behind a tab; core feature lacks prominence |

**Structural issues:**
- Auto Explain (a core feature) competes with Save & Search for tab space.
- All three features overlap functionally (saved concepts should feed Auto Explain, search results can become notes), but the UX doesn't reflect this.
- The "Current" tab is a ghost tab — it only lights up during active interaction.
- Cold Call lives in a fixed-width right column, disconnected from the bottom panel.

---

## Proposal A: "Auto Hub" — Auto Explain Takes Center Stage

### Tab Structure (3 tabs)

| # | Tab | Contents |
|---|-----|----------|
| 1 | **Explain** | Auto Explain results. Prominent, always visible when auto-explain is enabled. Shows the most recent explanation by default; history accessible via a "▼" dropdown inline. |
| 2 | **Notes** | Merges **Saved** + **Searched**. Any saved concept or search result becomes a note here. Notes are sorted by recency, with a toggle to filter: *All / Saved / Searched*. |
| 3 | **Cold Call** | Moves Cold Call from the right-side column into the bottom panel as a proper tab. When active, shows the Cold Call question + answer + explanation. |

### Where Auto Explain results appear

- **Primary surface:** The **Explain** tab — always the first tab, selected by default when auto-explain triggers.
- **Secondary (contextual):** A compact floating mini-card overlays the reader area for 3 seconds when a new explanation arrives (dismissible), before settling into the Explain tab.

### Where Cold Call lives

- **Moved into the bottom panel** as its own tab (#3). This frees the right column for something else (e.g., a reading context sidebar, or removed for more reading space).
- Cold Call can optionally also appear as a slide-over panel triggered from the tab (similar to how Apple Maps handles search).

### Pros

| Pro | Detail |
|-----|--------|
| Auto Explain gets prominence | It's the first tab, always live, always visible |
| Eliminates dead tab | No "Current" tab — that was always a UX crutch |
| Merges Save + Search into one coherent "Notes" concept | Reduces tab count and matches user mental model ("I kept something") |
| Cold Call feels integrated | Belongs alongside other tools, not exiled to a column |
| Saved concepts become accessible in the same place as Auto Explain output | Enables the feedback loop Founder wants |

### Cons

| Con | Detail |
|-----|--------|
| Cold Call tab takes space | If Cold Call is rarely used, a dedicated tab is waste |
| Notes tab could get crowded | Merging Saved + Searched loses the distinction between "I saved this intentionally" vs "I searched for this once" |
| One more tab | We go from 4 to 3, not 4 to 2 — panel still has some complexity |
| Learning new muscle memory | Users who rely on "Saved" vs "Searched" separation will need to adjust |

---

## Proposal B: "Dual Mode" — Contextual vs. Persistent

### Tab Structure (2 permanent tabs + 1 contextual overlay)

| # | Tab | Contents |
|---|-----|----------|
| 1 | **Explain** | Always present. Shows Auto Explain's output. Includes a small "+" button to manually save any explanation as a note. |
| 2 | **Notes** | All persistent content: manually saved concepts, search results that were saved, Cold Call questions the user marked for review. |
| — | *(Contextual bar)* | A **collapsible drawer** (not a tab) at the bottom that appears **only when** the user selects text and triggers Save or Search. It slides up from the bottom, shows the action result, then auto-dismisses after 5s of inactivity (or stays pinned if user interacts). |

### Where Auto Explain results appear

- **Explain tab** — always present, always live. Auto Explain is treated as the default, always-on feature.
- The Explain tab has an inline "recents" strip showing the last 5 explanations in a horizontal scroll.

### Where Cold Call lives

- **Exploratory option A:** A small persistent button in the bottom-left of the reading area (like a quiz icon) that opens Cold Call as a **modal overlay** (not a tab, not a column).
- **Exploratory option B:** Cold Call results appear inside the **Notes** tab under a "Cold Call" filter section.

### Pros

| Pro | Detail |
|-----|--------|
| Only 2 permanent tabs | Minimalist — reduces cognitive load |
| Save/Search feel ephemeral, which they are | The contextual drawer matches the transient nature of "I searched something real quick" |
| Auto Explain is always first | Gets the prominence it deserves |
| Cold Call is unobtrusive | No permanent tab or column wasted; only appears when activated |

### Cons

| Con | Detail |
|-----|--------|
| Contextual drawer may be easy to miss | If users are used to explicit tabs, an auto-dismissing drawer could cause them to lose results |
| "Save" loses its dedicated home | If the user wants to browse all saved items, they go to Notes. If they want to see their save action feedback, it's in the drawer. Two places for one action. |
| Cold Call feels less discoverable | Hidden behind a button or inside a filtered section — users may forget it exists |
| Implementation complexity | The contextual drawer needs smart dismiss logic (auto vs pinned), plus animations to feel smooth |

---

## Proposal C: "Two-Column" — Split the Panel

### Tab Structure (2 tabs, split content)

| # | Tab | Contents |
|---|-----|----------|
| 1 | **Explain** | Auto Explain output. Full-width when selected. |
| 2 | **Actions** | A split view: left half shows **Save** results, right half shows **Search** results. Each half has its own scroll and its own compact header ("Saved" / "Searched"). |

**The panel layout dynamically adapts:**

| State | Layout |
|-------|--------|
| No active Action, Auto Explain running | Panel shows **Explain** tab exclusively (takes full width) |
| User saves text | A small badge/indicator appears on Explain tab ("1 new note"). The **Explain** tab remains the main surface. |
| User opens Actions tab | Panel splits: 70% Explain (still visible!) + 30% Actions side panel (vertical split within the same tab area). Or: Explain stays full-width, Actions is a bottom sheet? |

*(Let me be more precise here — see the two sub-options below.)*

### Option C1 — Horizontal split within the panel

| Explain (full width, always visible) |
|:------------------------------------|
| **[ Explain content ]** |
| Mini-actions bar: 💾 Save this | 🔍 Search this | 🎯 Cold Call |

The bottom **~20%** of the panel is a persistent **actions shelf** showing the most recent Save, Search, or Cold Call result as a compact card. Tapping it expands the shelf into a drawer.

### Option C2 — Vertical tabs with preview

| Tab | Behavior |
|-----|----------|
| **Explain** | Main surface. At the bottom of Explain content, a small row of chips: "Last saved: <summary>" and "Last searched: <term>". Tap to open a slide-up. |
| **History** | A single list with icons differentiating saved vs searched vs Cold Call. |

Where Cold Call lives: A **button** in the top-right of the panel header (🔔 icon). Tapping slides Cold Call in from the right, temporarily overlaying the right 40% of the panel width.

### Where Cold Call lives in C1

In the **actions shelf** at the bottom of the panel — Cold Call activity shows up there as a compact card alongside recent saves and searches.

### Pros

| Pro | Detail |
|-----|--------|
| Explain is always visible | In C1, it never gets buried — even when you Save or Search, Explain stays on screen |
| Save + Search remain separate | Proposal A's concern about losing the intentionality distinction is addressed |
| Dynamic, adaptive UI | Matches the varying interaction patterns (sometimes you're reading+explaining, sometimes you're saving) |
| Cold Call is contextual | Appears where relevant (action shelf or slide-over) |

### Cons

| Con | Detail |
|-----|--------|
| Layout is more complex | 2-axis split (tab switching + horizontal splits/shelves) may confuse users who expect simple tabs |
| Panel feels busy | Especially in C1, with Explain + actions shelf + Cold Call overlay, the bottom panel risks becoming crowded |
| C2's "History" tab is vague | "History" doesn't communicate Save vs Search clearly enough |
| More engineering effort | Custom split views, adaptive layouts, and smooth transitions are harder to build than straightforward tabs |

---

## Comparison Matrix

| Criterion | A: Auto Hub | B: Dual Mode | C1: Horizontal Split | C2: Vertical + Preview |
|-----------|:-----------:|:------------:|:--------------------:|:----------------------:|
| Auto Explain prominence | ★★★★★ | ★★★★★ | ★★★★★ | ★★★★☆ |
| Dead tabs eliminated | ★★★★★ (no "Current") | ★★★★★ (no "Current") | ★★★★☆ (Explain always visible) | ★★★★☆ |
| Save/Search clarity | ★★★☆☆ (merged) | ★★★☆☆ (drawer + notes) | ★★★★★ (separate, visible) | ★★★★☆ (chip preview) |
| Cold Call discoverability | ★★★★★ (dedicated tab) | ★★☆☆☆ (button/modal) | ★★★★☆ (in actions shelf) | ★★★☆☆ (bell icon) |
| Implementation effort | ★★★★★ (simple tabs) | ★★★☆☆ (drawer logic) | ★★☆☆☆ (split views) | ★★★☆☆ (slide overlay) |
| Minimalism / clean | ★★★★☆ | ★★★★★ | ★★★☆☆ | ★★★★☆ |
| Save↔Auto Explain feedback loop | ★★★★★ (same panel) | ★★★★☆ (save in one place) | ★★★★★ (Explain always on) | ★★★★☆ |

---

## Recommendation for Decision

**Do not make a final decision here.** This document surfaces three distinct philosophies:

1. **Tab-based consolidation** (Proposal A) — simplest, most predictable, best for users who want clear labeled spaces.
2. **Transient completion** (Proposal B) — most modern, best for users who want minimal UI, but risks discoverability.
3. **Visual fusion** (Proposal C) — keeps everything visible simultaneously, but adds complexity.

**Suggested next step:** Founder chooses one philosophy (A, B, or C), then we do a quick 3-participant prototype test (Figma or code prototype) before committing to implementation.

---

## Appendix: If "Current" Tab Stays

If Founder does NOT want to eliminate the Current tab:

| Scenario | Proposal A modification | Proposal B modification | Proposal C modification |
|----------|------------------------|------------------------|------------------------|
| Keep "Current" | Add 4th tab "Current" that shows real-time search/save activity → reverts to "no content" state when idle. Or show a subtle hint like "Select text to search or save". | The contextual drawer IS Current — just label it differently. | Current = Explain tab when idle, Explain + Actions shelf when active. No separate tab needed. |
| Keep "Current" + Cold Call column | A with 4 tabs. Cold Call stays in the right column. Less ambitious but safest incremental change. | Drop the Cold Call button idea; Cold Call stays in the right column. | Simplify C to just Explain + Notes tabs; everything else stays as-is. |
