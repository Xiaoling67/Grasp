# Grasp — v1.0 → v1.1 Comparison

| # | Feature | Current v1 | Proposed v1.5 |
|---|---------|-----------|---------------|
| 1 | **AI Notes** | Triggered per `seal()` (transcript block sealed after speaker pause). **500ms debounce**. Sends last **3 blocks** + last **3 notes** to **DeepSeek**. Generates one entry (≤25 words) per call with **level 0/1/2**. Notes are flat, no hierarchical structure. **PDF slides** are uploaded but never parsed so `slide_index` is always **0**. | **15s rolling window** + **Concept Map**. Every **15s**, send buffer + existing **Concept Map** to **DeepSeek**. Output updates the **Concept Map** structure (hierarchical), not a flat entry. **PDF slides** parsed at lecture start. Cost: ~$0.04/lecture, same as current. |
|| 2 | **Auto Explain** | Exists. Per `seal()`, detects one unfamiliar **term** via **DeepSeek**. If **confidence > 0.65**, streams an explanation (definition + analogy split by `|`). Shows in **Auto tab**. No student memory — same experience for everyone. | **Concept-level detection**, not just single terms. DeepSeek analyzes each sealed block (and groups of 2–4 consecutive blocks) for **entire concepts** — including multi-sentence definitions, formulas, named frameworks, and extended explanations a professor might deliver across several blocks. Segments are scored by novelty/importance; each unfamiliar **concept** gets one explanation, not one per keyword. Results shown in **Auto tab** — student can "Save to Notes". |
| 3 | **Search** | Exists. User selects any text (word/phrase/sentence) in transcript → selection popup or right-click → **DeepSeek AI search** with streaming. Returns **1 definition** + **1 analogy**. Context: only last **10 blocks** of current lecture. No cross-lecture memory. No cache beyond current session. | Inject **Knowledge Profile** into prompt. Repeated searches on same term → trigger preventive **Auto Explain** next time. |
| 4 | **Save** | Context menu (right-click) or selection popup → K (Knowledge) / L (Language) / Notes. Saves to **SQLite**. International mode has async translation bug: translation never arrives to the save card. | Fix translation race bug (cos already fixed). Saved terms auto-update **Knowledge Profile** → **Auto Explain** skips them. |
| 5 | **Cold Call** | Per `seal()`, **7 regex patterns** match professor questions. **90s cooldown**. Generates answer from lecture context + notes via **DeepSeek**. Real-time, works during lecture. | Detection engine stays. Answer also updates **Concept Map** if new concepts introduced. |
| 6 | **Keyboard Shortcuts** | `README` documents **⌘⇧P** (pause), **⌘⇧K** (save K), **⌘⇧L** (save L), **⌘⇧E** (search), **⌘⇧X** (export). Only **⌘N** (new lecture) is actually implemented. | Implement all **5** documented shortcuts that are currently missing. |

---

## Auto Explain + Memory: Decision Tree

The flow below governs every sealed block entering Auto Explain. It replaces the vague "Knowledge Profile → decide explanation depth" description with a precise, testable state machine.

### Flow

```
sealed block(s) arrive (1 block, or 2–4 grouped blocks forming one concept)
       │
       ▼
┌─────────────────────────────┐
│  DeepSeek concept detection │  ← identifies candidate concept(s) in the block(s)
│  (see "Concept-level scope" │
│   below for what counts)    │
└──────────┬──────────────────┘
           │ candidate concept(s) found?
           ├── No  → do nothing (skip to next block)
           │
           ▼ Yes
┌──────────────────────────────┐
│  Look up concept in Memory  │
│  (SQLite: Knowledge Profile) │
└──────────┬───────────────────┘
           │
     ┌─────┴──────┬──────────────┬──────────────────┐
     ▼            ▼              ▼                  ▼
  Status:      Status:        Status:           Status:
  knownTerms  lookedUp        never_seen        searched_same_term
  (student     (student has   (completely         ≥ 2 times
   already      searched /    new concept)        (high-frequency
   saved it)    auto-explained                   search pattern)
                before)
     │            │              │                  │
     ▼            ▼              ▼                  ▼
  DON'T show   Show quick     Show full          PREVENTIVE —
  in Auto tab  1-line          explanation        next time
               reminder —     (definition +      professor mentions
  Still note   "You've seen   analogy,            this concept,
  it in        this before"   streamed to         Auto Explain
  Concept Map  + link to      Auto tab)          fires BEFORE
               previous                                            student needs
               explanation                          to search
               (if saved)                                       
     │            │              │                  │
     └─────┬──────┴──────┬──────┴──────┬───────────┘
           │             │             │
           ▼             ▼             ▼
   ┌─────────────────────────────────────────┐
   │  Student can interact with explanation: │
   │   • Dismiss (→ dismissed in Memory)     │
   │   • Save to Notes (→ moves to           │
   │     knownTerms, future auto-explains     │
   │     skip it)                             │
   │   • Search on same term again           │
   │     (→ increments search counter,        │
   │     may trigger preventive mode)         │
   └─────────────────────────────────────────┘
```

### Memory state definitions

| Status | Meaning | Auto Explain action | Concept Map action |
|--------|---------|-------------------|-------------------|
| `knownTerms` | Student previously saved this term to Notes, or marked it as known in Knowledge Profile | **Skip** — do not show in Auto tab | Still add node, mark "known" |
| `lookedUp` | Student has searched or auto-explained this concept at least once before | **Quick reminder** — single line ("You've seen this before") + link to previous full explanation if saved | Add node, mark "seen before" |
| `never_seen` | Concept has never appeared in any student interaction | **Full explanation** — definition + analogy streamed to Auto tab | Add node, mark "new" |
| `searched_same_term ≥ 2` | Student has manually searched the same term two or more times | **Preventive** — next time professor mentions this concept in a sealed block, Auto Explain fires automatically **before** the student needs to search again | Add/update node, mark "flagged preventive" |

### Concept-level detection scope (replaces "one term per block")

Auto Explain does NOT detect single keywords. It detects **concepts** — any of the following:

- **Single technical term** — e.g., "photosynthesis", "covariance matrix"
- **Named concept** — e.g., "Moore's Law", "Pareto efficiency"
- **Definition passage** — 1–3 sentences where the professor explicitly defines something
- **Formula / equation** — spoken math that introduces a new symbolic relationship
- **Named framework / theory** — e.g., "the CAP theorem", "Maslow's hierarchy of needs"
- **Extended explanation** — a multi-block segment (2–4 consecutive sealed blocks) where the professor builds up a concept across several utterances (e.g., "So first, we need to understand supply curves... Now, the demand side is similar... And where they intersect is the equilibrium price")
- **Comparison / contrast** — where the professor introduces a new concept by comparing it to something already known (detected via signals like "similar to X", "unlike Y", "in contrast to")

DeepSeek scores each detected concept by **novelty** (how likely the student hasn't encountered it before) and **centrality** (how important it is to understanding the current lecture). Only concepts above a combined novelty × centrality threshold produce an explanation.

### User interactions that update Memory

| Student action | Memory update |
|---|---|
| Dismisses an Auto Explain card | → concept added to `dismissed` list; same concept won't auto-explain again for this lecture |
| Saves an Auto Explain card to Notes | → concept moved to `knownTerms`; future auto-explains skip it |
| Searches the same concept again after seeing Auto Explain | → increment `search_count`; if ≥ 2, flag for preventive mode |
| Manually searches a concept (no prior Auto Explain) | → first search: add to `lookedUp`. Second search: increment → if ≥ 2, flag preventive. |
| Edits Knowledge Profile directly | → wholesale update of `knownTerms` / `lookedUp` / `dismissed` |

---

## Student Knowledge Profile — Placement Options

Founder has ruled out "onboarding-only" placement. The Knowledge Profile editor must be accessible anytime, easy to find, and not buried. Three placement proposals below — no final decision made; Founder picks one (or proposes a fourth).

### Option A: Settings page (recommended as default)

Place a "Knowledge Profile" row in the app's Settings screen. Tapping it opens the full profile editor.

| Pros | Cons |
|------|------|
| Follows iOS convention — user data settings live in Settings | Settings is 2 taps away from anywhere (menu → settings → profile), not instant |
| No new top-level UI element needed | Users may not think to look in Settings for something AI/personalised |
| Clean separation: profile is "config", not "content" during a lecture | One more Settings row competing for space with other Settings items |
| Easy to find for power users who already go to Settings | |

### Option B: Dedicated tab in the bottom tab bar

Add a 5th tab (e.g., a person icon) between the existing tabs. Tab opens the Knowledge Profile editor as its own full-screen view.

| Pros | Cons |
|------|------|
| One tap from anywhere in the app — maximum discoverability | Adds visual clutter to the tab bar (5 tabs is more crowded) |
| Signals that the Knowledge Profile is a **primary feature**, not a footnote | Takes up real estate that might be needed for other features later |
| Users can quickly check/edit their profile mid-lecture | May feel too prominent if the profile is something users rarely touch after initial setup |
| No navigation friction — always exactly one tap away | |

### Option C: Sidebar / slide-out drawer (lecture view only)

When in a live lecture, a "profile" icon (or avatar) in the top bar opens a drawer/sheet from the side with a quick editor. Outside a lecture, same icon opens the full profile page.

| Pros | Cons |
|------|------|
| Always accessible during the most relevant moment (lecture) | Sidebar/drawer adds UI complexity (swipe gesture, overlay management) |
| Doesn't compete with tab bar or Settings for space | Less discoverable than a tab — users must notice the icon first |
| Feels contextual: "your brain for this lecture" is attached to the lecture view | Outside-lecture flow (from home/dashboard) needs a separate path, creating inconsistency |
| Can show a lightweight inline editor (quick add/remove terms) without leaving the lecture | Students editing their profile mid-lecture may be distracted from the content |

|### Founder decision needed
|
|1. ~~Pick one placement (or propose a fourth).~~ **DECIDED: Option A (Settings page).**|
|2. (N/A — Option A has no secondary path)  ✓|
