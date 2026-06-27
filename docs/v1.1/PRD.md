# Grasp — PRD v1.1

**Version:** 1.1
**Date:** 2026-06-27
**Platform:** macOS 14.0+ | Swift 5.9 | SwiftUI + AppKit
**Status:** In development
**Window:** Single-window app, default 1280×800, minimum 960×640

---

## Product Summary

Grasp is a next-generation AI note-taking assistant for live lectures and meetings.

### Core capabilities

1. **Real-Time AI Notes, Editable Anytime** — Notes generate in real time. User can edit any note at any moment during the lecture. AI never overwrites user edits. Once the user changes a note, Grasp marks it as manual and leaves it alone.

2. **Pre-Lecture Setup** — Upload materials (slides, PDFs) before the lecture. Tell Grasp the desired structure and detail level. AI uses this guidance from the start.

3. **Learning Memory** — Grasp remembers how and where the user edits notes over time. Learns conciseness level, structure preference, what gets kept vs deleted. Goal: minimize manual editing over time until notes match preferences by default.

4. **Smart Background & Explanations** — Based on user settings (per-lecture or global), Grasp surfaces background info and concept explanations during the lecture. Pulls from lecture history and knowledge profile.

---

## Change Log (v1.0 → v1.1)

| Area | v1.0 (shipped) | v1.1 (this PRD) |
|------|----------------|-----------------|
| **Layout** | Side-by-side (transcript \| notes) with bottom panel tabs | 2×2 grid layout — 4 quadrants (65/35 vertical, 55/45 horizontal). Bottom panel unchanged. |
| **AI Notes** | Flat per-seal notes, ≤25 words, level 0/1/2 | **Concept Map** — 15s rolling window, hierarchical concept tree with parent/child, rendered as indented outline. Dual render path: old lectures show flat notes. |
| **Auto Explain** | Stateless per block — no student memory | **Student Knowledge Profile** (SQLite) personalizes depth: known→skip, lookedUp→1-line reminder, neverSeen→full explanation. Results stay in bottom-left quadrant. |
| **Search & Save** | Selection popup. Search returns definition \| analogy. Save types: K/L. Caching: in-memory per session only. | Selection popup fixed (NotificationCenter). Search prompt injects known terms from profile. Saved terms auto-add to Knowledge Profile. |
| **Transcription** | Word-by-word display. Semantic blocking (50–100 words) via Deepgram UtteranceEnd. | Same + **PDF slide parsing** at lecture start anchors context. Optional **Qwen-MT translation** in International mode. |
| **Cold Call** | 7 regex patterns, 90s cooldown, 3-phase UI. Context: last 15 blocks + slides + last 10 notes. | Same + answers feed into Knowledge Profile. |
| **Keyboard shortcuts** | Documented in README but only `⌘N` wired up | All shortcuts implemented: `⌘⇧P`, `⌘⇧K`, `⌘⇧L`, `⌘⇧E`, `⌘⇧X`, plus `⌘N` |
| **Bug fixes** | None (shipped with known bugs) | 7 bugs fixed (see table below) |
| **Layout interactivity** | Static | Resizable vertical divider between columns; fixed 65/35 horizontal divider |

---

## 1. Transcription (with optional translation)

**Purpose:** Real-time capture of lecture audio into readable text blocks, with optional live translation for International mode.

**UI Placement:** Top-left quadrant of the 2×2 grid.

**UI Component:** `TranscriptPanelView` — fills entire top-left quadrant.

**Exact behavior:**
- **Engine:** Deepgram Nova-3 via WebSocket streaming.
- **Semantic blocking (Sealing):** Blocks seal on Deepgram `UtteranceEnd` event (~2s silence). Lower limit: 50 words. Upper limit: 100 words. Interim results update the active (unsealed) block in real time.
- **PDF slide parsing:** At lecture start, uploaded PDF's text content is parsed and injected as context into note/cold-call/explain prompts. Slides parsed once; parsed text cached for session duration.
- **Translation (International mode only):** Per sealed block, dispatches async Qwen-MT Flash translation (fallback: DeepSeek). Translations displayed inline alongside original text.
- **States:**
  - *Idle:* Empty area with placeholder "Waiting for transcription…"
  - *Streaming:* Words appear character-by-character in active (unsealed) block, grey background highlight on active block.
  - *Sealed:* Block moves to sealed list, background turns white. Each sealed block shows timestamp (mm:ss) left-aligned.

**Keyboard shortcuts:**
- `⌘⇧P` — Pause/Resume transcription
- `⌘⇧F` — Toggle full transcript view (hide/show translation columns)

---

## 2. AI Notes (Concept Map)

**Purpose:** Generate a structured, hierarchical concept map from the lecture in real time. Replaces v1.0's flat per-seal notes.

**UI Placement:** Top-right quadrant of the 2×2 grid.

**UI Component:** `NotesPanelView` — fills entire top-right quadrant.

**Exact behavior:**
- **Trigger:** Every 15 seconds of rolling window (not per seal event). Consolidates last N sealed blocks.
- **Engine:** DeepSeek returns a hierarchical concept tree with parent/child/sibling relationships.
- **Rendering:** Indented outline format. Depth indicated by indentation level (1 em per level). Each node shows concept name (bold) + 1-line summary beneath.
- **Dual render path:**
  - *New lectures:* Concept map outline.
  - *Old lectures (v1.0 data):* Flat notes as bullet list — no hierarchy, no indentation.
- **Interactions:** Click on any concept node → highlights corresponding transcript blocks. Right-click → "Add to Knowledge Profile."
- **Manual note editing:** User can add, edit, or delete individual note entries. Edits are persisted to SQLite and marked as `manual` (not overwritten by future auto-generation of that concept).

**Keyboard shortcuts:**
- `⌘N` — New lecture (creates new tab, starts transcription)
- `⌘⇧N` — Focus notes panel

---

## 3. Auto Explain

**Purpose:** Automatically detect and explain unfamiliar concepts as they appear in the lecture, personalized to the student's knowledge level.

**UI Placement:** Bottom-left quadrant of the 2×2 grid — **always visible, never removed from view hierarchy.**

**UI Component:** `AutoExplainBottomQuadrant` wrapper + `AutoExplainCardView` inside.

**Exact behavior:**
- **Trigger:** Per sealed block — one check per block.
- **Detection:** DeepSeek identifies exactly one unfamiliar term per block (confidence ≥ 0.65).
- **Student Knowledge Profile (SQLite):**
  - `known` (student already knows this) → skip, no output.
  - `lookedUp` (student has seen it before) → show 1-line reminder.
  - `neverSeen` → full explanation: definition + intuition/analogy (streamed).
- **States (bottom-left quadrant):**
  - *Idle:* Shows placeholder text: "Watching for unfamiliar terms…" in grey (`#C0C0C0`). Purple dot indicator (`#7C3AED`, 5px circle) absent.
  - *Loading:* Purple dot appears next to "AUTO EXPLAIN" header. Card area shows spinner.
  - *Streaming:* `AutoExplainCardView` visible — streaming explanation token-by-token.
  - *Complete:* Full explanation shown. Purple dot solid. User can hover → "Save to Notes" button appears.
- **Persistence:** Results stay in bottom-left quadrant, **never auto-enter notes.** User clicks "Save to Notes" manually to persist. Saved explanations respect Knowledge Profile (lookedUp status set).
- **Header:** "AUTO EXPLAIN" label (11pt semibold, `#5A5A5A`). Purple dot right-aligned when new content available.

**Keyboard shortcuts:**
- `⌘⇧A` — Focus auto-explain panel / jump to latest explanation

---

## 4. Search and Save

**Purpose:** Allow users to select any text and immediately search (AI definition + analogy) or save it (Knowledge or Language entry).

**UI Placement:** Bottom-right quadrant of the 2×2 grid (contextual — shows one view at a time via priority chain).

**UI Components:** `ContextualBottomQuadrant` wrapper, `SearchCardView`, `SaveCardView`, `ColdCallCardView`.

**Exact behavior:**
- **Trigger:** User selects any text (word/phrase/sentence) in the transcript or notes → selection popup appears.
- **Selection popup:** Fixed via `NotificationCenter` (replaces broken `NSEvent` monitor). 80ms debounce prevents flicker. Three buttons: **Search**, **Save as Knowledge (K)**, **Save as Language (L)** (L only visible in International mode).
- **Search action:**
  - DeepSeek returns exactly 1 definition + 1 intuition/analogy, separated by `|` delimiter.
  - Context: last 10 sealed blocks + known terms from Knowledge Profile (injected into prompt).
  - Streamed token-by-token in `SearchCardView`.
  - Cached per session (in-memory).
- **Save action:**
  - Save as Knowledge (K): saves to SQLite, auto-adds term to Knowledge Profile as `lookedUp`.
  - Save as Language (L): saves with async translation. Bug fixed: `SaveDraft` created after translation completes (not synchronously).
  - User can add optional short note per save.
- **Priority chain (bottom-right quadrant):**
  1. (highest) Cold call active → `ColdCallCardView`
  2. Save action → `SaveCardView`
  3. Search action → `SearchCardView`
  4. (empty) → Placeholder: "COLD CALL / SAVE / SEARCH — Activity appears here"
- **Transitions:**
  - *Cold call arrives while Save visible:* Cold call replaces Save. Save not lost — stored in `vm.activeCard`, reappears on cold call dismiss.
  - *User initiates Search while Cold Call visible:* Cold call stays. Search accessible via bottom panel "Searched" tab.
  - *Both Save and Search active:* Save wins. Search results in `vm.sessionSearches` + bottom panel.

**Keyboard shortcuts:**
- `⌘⇧K` — Save selected text as Knowledge
- `⌘⇧L` — Save selected text as Language (International mode only)
- `⌘⇧E` — Trigger Instant Search on selected text
- `Esc` — Dismiss selection popup / current card

---

## 5. Auto Answer Questions (Cold Call)

**Purpose:** Detect when a professor asks a question and generate a context-grounded answer in real time.

**UI Placement:** Bottom-right quadrant of the 2×2 grid — **highest priority** view.

**UI Component:** `ColdCallCardView` (phase: detected | generating | answered).

**Exact behavior:**
- **Detection:** 7 regex patterns (who knows, can anyone, does anyone, anybody, tell me, somebody, who here). Cooldown: 90s.
- **Answer generation:** DeepSeek using context from last 15 sealed blocks + uploaded slides + last 10 note entries + Knowledge Profile.
- **3-phase UI:**
  - *Phase 1 — Detected:* "Question detected" banner with speaker icon. Yellow badge. "Answering…" text. Duration: until first token arrives (~1–3s).
  - *Phase 2 — Generating:* Streaming answer token-by-token. Purple badge. "Generating…" pulse animation on speaker icon.
  - *Phase 3 — Answered:* Complete answer displayed in card. Green checkmark badge. Answer persists for 45s, then auto-dismisses. User can ✕ dismiss immediately.
- **Auto-dismiss:** 45s after answered state. On dismiss, falls through priority chain to save/search/empty.
- **Knowledge Profile integration:** Terms in the generated answer are checked against the profile. If the answer contains a `neverSeen` term, it triggers an Auto Explain automatically (bottom-left quadrant).

**Keyboard shortcuts:**
- `⌘⇧C` — Show/hide cold call card (if active)

---

## Layout — 2×2 Grid

### ASCII Diagram

```
┌────────────────────────────────────────────────────────┐
│ TopBarView  [unchanged]                                 │
├──────┬──────────────────────┬───────────────────────────┤
│      │                       │                           │
│ Side │  TRANSCRIPT           │  AI NOTES                 │
│ bar  │  (top-left)           │  (top-right)              │
│      │   • sealed blocks     │   • concept map outline  │
│      │   • active block      │   • flat notes (legacy)  │
│      │   • interim text      │   • add/edit/delete       │
│      │   • translation       │                           │
│      │                       │                           │
│      ├──────────────────────┼───────────────────────────┤
│      │  AUTO EXPLAIN         │  CONTEXTUAL               │
│      │  (bottom-left)        │  (bottom-right)           │
│      │  ★ always visible     │   priority chain:         │
│      │  ★ never hidden       │   1. Cold Call Card       │
│      │    behind a tab       │   2. Save Card             │
│      │                       │   3. Search Card           │
│      │                       │   4. Empty placeholder     │
├──────┴──────────────────────┴───────────────────────────┤
│ Bottom Panel (UNCHANGED — tabs + CC column)              │
└────────────────────────────────────────────────────────┘
```

### Dimensions

| Region | Ratio | Resizable? | Min/Max | Notes |
|--------|-------|------------|---------|-------|
| Top row (Transcript + Notes) | **65%** of window height | No — fixed | N/A | `geo.size.height * 0.65` |
| Bottom row (AutoExplain + Contextual) | **35%** of window height | No — fixed | N/A | `geo.size.height * 0.35` |
| Left column (Transcript + AutoExplain) | **55%** of window width | Yes — drag handle | Left min: 200px, Left max: 500px | `geo.size.width * 0.55` default |
| Right column (Notes + Contextual) | **45%** of window width | Yes — drag handle (linked) | Derived from left width | `geo.size.width - leftWidth - 1px` |

### Divider Specs

| Divider | Location | Thickness | Visual | Interaction |
|---------|----------|-----------|--------|-------------|
| Vertical | Between left/right columns, full height of both rows | 1px | Line fill `#E8E8E8` | Drag gesture → updates `vm.notesWidth`. Affects both rows simultaneously. |
| Horizontal | Between top/bottom rows | 5px | 1px `#E8E8E8` top line, 1px `#E8E8E8` bottom line, 3px `#F8F8F8` gap | Not resizable. Visual separator only. |

### Quadrant Behavior Summary

| Quadrant | View | Always visible? | Content |
|----------|------|-----------------|---------|
| Top-left | `TranscriptPanelView` | Yes | Sealed blocks + active block + interim text + translation inline |
| Top-right | `NotesPanelView` | Yes | Concept map outline (or flat notes for legacy lectures) |
| Bottom-left | `AutoExplainBottomQuadrant` | Yes — **never removed from hierarchy** | Idle placeholder OR `AutoExplainCardView`. Header always shows "AUTO EXPLAIN" |
| Bottom-right | `ContextualBottomQuadrant` | Yes — **always present in hierarchy** | One of: `ColdCallCardView` > `SaveCardView` > `SearchCardView` > empty placeholder |

### Window Resize Behavior

- Ratios scale proportionally — 65/35 and 55/45 are relative to current window dimensions.
- Minimum window: 960×640. Below this, left column may clip (min 200px enforced).

---

## Bug Fixes

| Bug | Fix |
|-----|-----|
| Inter font not bundled | Build script copies `Inter.ttc` to app bundle |
| Translation race in `handleSaveAction` | `SaveDraft` created after async translation completes (not synchronously) |
| `interimText` never populated | `handleInterim` sets `interimText = t` |
| Transcription duplication | Removed `interimText` concatenation in `BlockView` |
| Auto Explain polluting search history | Removed `db.saveSearch` from `autoExplain()` |
| Selection popup not appearing | Replaced `NSEvent` monitor with `NotificationCenter` |
| Selection popup flicker | Added 80ms debounce |
| Keyboard shortcuts not wired up | All 5 documented shortcuts (`⌘⇧P`, `⌘⇧K`, `⌘⇧L`, `⌘⇧E`, `⌘⇧X`) implemented |

---

## Known Issues

| Issue | Severity | Notes |
|-------|----------|-------|
| `DatabaseService` not thread-safe (no locking) | HIGH | Raw `sqlite3_open` — no WAL, no mutex, no serialization queue. Concurrent `Task` access can corrupt DB. |
| `@Published` vars written from `URLSession` background queue | MEDIUM | `streamingTokens`, `autoExplainTokens` written off main thread. Causes missed/delayed UI updates. |
| `DeepgramService.pending` array race (audio vs main thread) | MEDIUM | Concurrent reads/writes on `pending` array with no synchronization. |
| UTF-8 byte-by-byte SSE decoding | MEDIUM | Multi-byte characters (non-ASCII) lost during SSE streaming decode. |
| Export blocks main thread | LOW | `NSMutableAttributedString` build on main thread — freezes UI for lectures with large transcripts. |
| No WebSocket reconnection on network drop | LOW | Deepgram WebSocket disconnect does not auto-reconnect. User must manually restart transcription. |
| Settings toggles (font size, show translation, hover freeze) disconnected | LOW | UI controls exist but have no effect on the rendering. |
| No unit tests | — | Entire codebase has zero unit or UI tests. |

---

## Non-Goals (v1.1)

- No mobile app (iOS/Android)
- No cloud sync or user accounts
- No offline transcription
- No custom model fine-tuning
- No export formats beyond RTF
- No user-resizable horizontal divider (fixed 65/35)
- No bottom panel modification (kept exactly as v1.0)
- No removal of redundant bottom-panel tabs (Auto tab, Current tab — kept for now)
