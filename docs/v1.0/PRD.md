# Grasp — Product Requirements Document

**Version:** 1.0 (current release)
**Date:** 2025-07-10
**Status:** Released
**Platform:** macOS 14.0+ only
**Tech Stack:** Swift 5.9, SwiftUI, AppKit interop, xcodegen (project.yml), DeepSeek API, Deepgram Nova-3, Qwen-MT Flash

---

## 1. Product Overview

Grasp is a native macOS desktop application for students attending live or recorded lectures. It provides real-time lecture transcription with word-by-word display, AI-generated study notes, contextual search, live translation (international mode), cold-call question assistance, automatic term explanation, and export/save functionality — all within a single-window SwiftUI interface.

**Core promise:** A student opens Grasp during a lecture, and the app captures the spoken content, generates structured notes, explains unfamiliar terms, and surfaces definitions on demand — all in real time.

---

## 2. Problem Statement

- Students in live lectures struggle to take comprehensive notes while also processing the speaker's words.
- Reviewing raw transcripts of lectures is inefficient — key concepts are not highlighted or summarised.
- Non-native speakers need live translation of lecture content.
- Students who are called on unexpectedly ("cold calls") benefit from real-time generated answers.
- Manually saving and organising study material from lectures is time-consuming and error-prone.

Grasp solves these problems by providing an integrated real-time transcription + AI toolbelt that runs natively on macOS.

---

## 3. Target Users

- University/college students attending lectures (live or recorded).
- Non-native English speakers attending English-language lectures (international mode).
- Self-learners watching recorded course videos.
- Any user who wants AI-assisted note-taking during spoken presentations.

---

## 4. Feature List (v1.0 Current State)

> **No features beyond those listed here exist in v1.0.** This document describes only what is implemented and shipped. Future improvements are out of scope.

### 4.1 Live Transcription

- **Engine:** Deepgram Nova-3 via WebSocket streaming.
- **Display:** Word-by-word display of live transcription in real time.
- **Semantic Blocking (Sealing):**
  - Blocks are sealed on Deepgram `UtteranceEnd` event (detected after ~2 seconds of silence).
  - **Lower limit:** 50 words per block.
  - **Upper limit:** 100 words per block.
  - Interim results update the active (unsealed) block in real time as words arrive.
  - Once sealed, a block is final and stored in the transcript.

### 4.2 AI Notes

- **Trigger:** Per seal event (each time a transcript block is sealed).
- **Debounce:** 500ms debounce on the backend before requesting generation.
- **Context sent to DeepSeek (per note generation):**
  - Last 3 sealed transcript blocks.
  - Last 3 existing note entries.
- **Output:** One note entry per generation, ≤25 words, with a **level** (0, 1, or 2) indicating importance/abstraction. Notes are flat — no hierarchy, no nesting, no threading.
- **Slide context:** PDF slides can be uploaded to the UI, but they are **never parsed** — `slide_index` is always 0 in generated notes. The file is present but unused by the note engine.

### 4.3 Instant Search

- **Trigger:** User selects any text (word, phrase, or sentence) in the transcript → a selection popup or right-click context menu appears → user chooses the search action.
- **Engine:** DeepSeek AI search with streaming response.
- **Response format:** Returns exactly **1 definition** and **1 intuition/analogy**, separated by the `|` delimiter.
- **Context window:** Only the last 10 sealed blocks of the current lecture session.
- **Caching:** In-memory cache per session only — no persistence across sessions.
- **Display:** Streamed token-by-token in the search results area.

### 4.4 Live Translation (International Mode Only)

- **Engine:** `QwenTranslationService` using Qwen-MT Flash as the primary model, with DeepSeek as a fallback if Qwen-MT is unavailable or fails.
- **Activation:** Only active when the user has selected **"international" mode** during onboarding or in Settings.
- **Trigger:** Per sealed transcript block, an async translation request is dispatched.
- **Display:** Translations shown alongside the original transcript text.
- **Known Bug — Translation Race on Save:** When saving a "Language" save (type L), `handleSaveAction` captures the `trans` variable as a value type. A `SaveDraft` is created synchronously with a nil translation because the async translation has not yet completed. The translated text never reaches `SaveCardView`.

### 4.5 Cold Call Detection

- **Purpose:** When a lecturer asks a question to the room ("cold call"), Grasp detects it and generates a suggested answer.
- **Detection:** 7 regex patterns:
  1. `who knows`
  2. `can anyone`
  3. `does anyone`
  4. `anybody`
  5. `tell me`
  6. `somebody`
  7. `who here`
- **Cooldown:** 90 seconds between cold call detections (prevents rapid re-triggering).
- **Answer Generation:** Uses DeepSeek, fed context from:
  - Last 15 sealed transcript blocks.
  - Uploaded slides (unparsed — `slide_index` always 0).
  - Last 10 note entries.
- **Phases — shown in UI as 3 states:**
  1. **Detected** — the UI shows that a cold call question was detected.
  2. **Generating** — the answer is being streamed from DeepSeek.
  3. **Answered** — the final answer is displayed.

### 4.6 Auto Explain

- **Trigger:** Per seal event (each sealed block triggers one check).
- **Detection:** DeepSeek determines if exactly one unfamiliar/uncommon term exists in the sealed block.
- **Confidence threshold:** 0.65 — DeepSeek must be at least 65% confident the term is unfamiliar to the student.
- **Output:** A streamed explanation consisting of a definition and an analogy, separated by `|`.
- **Display:** Shown in the **Auto** tab of the UI.
- **No student memory:** The system does not track which terms a specific student already knows. Every check is stateless per block.

### 4.7 Save

- **Trigger Methods:**
  1. Context menu (right-click on a sealed transcript block).
  2. Selection popup (after selecting text, showing actions for K/L/Search/Notes).
- **Types:**
  - **Knowledge (K):** Saves the selected content as domain knowledge. Available in all modes.
  - **Language (L):** Saves the selected content for language learning. **Only visible in international mode.**
- **Storage:** SQLite database (flat file on disk).
- **Quick Note:** User can add a short note to accompany each save.
- **Display:** Saved items appear in the Saved tab within the lecture view.

### 4.8 Export

- **UI:** `ExportModalView` — a modal sheet.
- **Workflow:**
  1. User selects a past lecture from a list.
  2. Toggles on/off what to include: **Transcript**, **AI Notes**, **Domain Knowledge**, **Language Saves**, **AI Searches**.
  3. Builds the document using `NSMutableAttributedString` (RTF format internally).
  4. Presents `NSSavePanel` for the user to choose a destination file path.
- **Output file:** RTF document (.rtf) containing the selected content.

### 4.9 Past Lecture Review

- **Access:** Open a past lecture as a new tab.
- **Layout:** 4 sub-tabs within the lecture view:
  1. **Transcript** — the full transcript from that lecture.
  2. **Notes** — AI notes generated during that lecture.
  3. **Saved** — all Knowledge and Language saves from that lecture.
  4. **Searches** — all Instant Search queries and results from that lecture.
- **Lecture rename:** The user can inline rename the lecture name (editable title field in the tab).

### 4.10 Onboarding

- **Steps (3-step wizard):**
  1. **Welcome** — splash screen introducing Grasp.
  2. **Choose Mode** — user selects **Standard** or **International** mode.
  3. **Done** — confirmation, app proceeds to main window.
- **Result:** Sets the default mode for the user profile.

### 4.11 Settings

- **Default Mode Picker:** Switch between Standard and International mode.
- **Target Language Text Field:** Enter the target language for translation (international mode).
- **Font Size Picker:** A UI control exists but is **disconnected** — changing it has no effect on the UI.
- **Show Translation Toggle:** A toggle exists but is **disconnected** — toggling it has no effect.
- **Hover to Freeze Toggle:** A toggle exists but is **disconnected** — toggling it has no effect.

### 4.12 Keyboard Shortcuts

- **Documented shortcuts (in README):**
  - `⌘⇧P` — Pause/Resume transcription
  - `⌘⇧K` — Save as Knowledge (K)
  - `⌘⇧L` — Save as Language (L)
  - `⌘⇧E` — Trigger Instant Search
  - `⌘⇧X` — Open Export
- **Actually implemented in code:** Only `⌘N` (New Lecture) is wired up. All five documented shortcuts above are **not implemented** — they are documented but non-functional.

---

## 5. User Flows

### 5.1 First Launch (Onboarding)

1. App starts → Onboarding sheet appears.
2. User sees Welcome screen → clicks Next.
3. User chooses Standard or International mode → clicks Next.
4. User sees Done screen → clicks Finish.
5. App shows main window with an empty lecture tab.

### 5.2 Starting a Lecture

1. User presses `⌘N` (New Lecture) or clicks New Lecture button.
2. Mic access prompt appears (if not already granted).
3. Transcription begins immediately — words appear in real time in the transcript area.
4. As blocks seal, AI Notes and Auto Explain run automatically.

### 5.3 During a Lecture — Instant Search

1. User selects text in the transcript with the mouse (word/phrase/sentence).
2. A selection popup appears with actions (including Search).
3. User clicks Search (or uses context menu).
4. AI search streams a result: definition + intuition/analogy.
5. Search appears in the Searches sub-tab.

### 5.4 During a Lecture — Save

1. User right-clicks a sealed block (or uses selection popup).
2. Chooses **Save as Knowledge** (K) or **Save as Language** (L, international mode only).
3. Optional: User adds a quick note.
4. Item saved to SQLite; appears in Saved sub-tab.

### 5.5 During a Lecture — Cold Call Detection

1. Lecturer says a phrase matching one of the 7 cold call patterns.
2. UI shows **Detected** badge.
3. DeepSeek generates an answer (context: last 15 blocks + slides + last 10 notes).
4. UI shows **Generating** while streaming.
5. Final answer displayed as **Answered**.

### 5.6 After a Lecture — Past Lecture Review

1. User opens past lecture from a list (sidebar or menu).
2. New tab opens with 4 sub-tabs: Transcript, Notes, Saved, Searches.
3. User can rename the lecture by clicking the title.

### 5.7 After a Lecture — Export

1. User triggers Export (`⌘⇧X` in docs, or menu item).
2. Export modal appears: select lecture + toggles for content types.
3. User clicks Export → `NSSavePanel` opens.
4. User chooses destination → RTF file is written.

---

## 6. Architecture Notes

### 6.1 Platform Constraints

- macOS 14.0+ (Sonoma minimum).
- Swift 5.9, SwiftUI, AppKit interop for text selection monitoring.
- xcodegen generates Xcode project from `project.yml`.
- Single-window app, default size 1280×800, minimum 960×640.

### 6.2 Data Storage

- SQLite database via raw `sqlite3_open` C API.
- One database file stored locally on disk.
- **Not thread-safe:** Raw `sqlite3_open` with no locking mechanism. Concurrent access from multiple `Task` objects can cause corruption or crashes.

### 6.3 External API Dependencies

- Deepgram Nova-3 (WebSocket transcription streaming)
- DeepSeek API (notes, search, cold call, auto explain)
- Qwen-MT Flash API (translation, primary engine)
- DeepSeek API (translation, fallback engine)

---

## 7. Known Issues

### 7.1 Missing Font Asset
**Issue:** The Inter font file (13MB `Inter.ttc`) is not bundled in the `.app` bundle during build. All custom font declarations silently fall back to the system San Francisco font. The UI appears in the wrong typeface.

### 7.2 Translation Race in handleSaveAction
**Issue:** When saving a Language (L) item, `handleSaveAction` captures the `trans` variable as a value type at the time of call. A `SaveDraft` is created synchronously with a nil translation value because the async Qwen/DeepSeek translation has not yet completed. The translated text is generated but never reaches `SaveCardView`.
- **Root cause:** Async translation is dispatched but the `SaveDraft` struct is created synchronously, capturing the stale value.

### 7.3 Dead Code — interimText Published Var
**Issue:** The `@Published var interimText` property is declared but never written to. It is dead code — the UI state it was intended to drive receives no updates.

### 7.4 DatabaseService Not Thread-Safe
**Issue:** `DatabaseService` uses raw `sqlite3_open` with no locking mechanism (no WAL mode, no mutex, no serialisation queue). When multiple `Task` objects access the database concurrently, this can cause crashes, data corruption, or undefined behaviour.

### 7.5 @Published Vars Updated Off Main Thread
**Issue:** `@Published var` properties (`streamingTokens`, `autoExplainTokens`) are written from `URLSession` background delegate queue (a non-main thread). SwiftUI's observation system expects `@Published` changes on the main thread. This causes missed UI updates or warnings/delays in rendering.

### 7.6 DeepgramService.pending Array Race
**Issue:** The `DeepgramService.pending` array is accessed from both the audio capture thread and the main thread without any synchronisation (no lock, no actor, no serial queue). This can cause data races, crashes on concurrent reads/writes, or lost interim results.

### 7.7 Keyboard Shortcuts Not Implemented
**Issue:** The README documents 5 keyboard shortcuts (`⌘⇧P`, `⌘⇧K`, `⌘⇧L`, `⌘⇧E`, `⌘⇧X`), but none are wired up in code. Only `⌘N` (New Lecture) is functional. Users who try the documented shortcuts will see no action.

---

## 8. Non-Goals (v1.0)

The following are explicitly **not** in scope for v1.0:

- No mobile app (iOS/Android).
- No web interface.
- No cloud sync or multi-device support.
- No user accounts or authentication (local-only app).
- No team/collaboration features.
- No offline transcription (requires persistent network for Deepgram API).
- No custom model fine-tuning.
- No student memory/personalisation (each session is stateless).
- No slide parsing (PDF uploads present but unused).
- No hierarchical/threaded notes.
- No export formats beyond RTF.

---

## 9. Appendices

### 9.1 File Structure (Relevant Paths)

```
grasp/
├── project.yml              # xcodegen project definition
├── README.md                # Documents keyboard shortcuts (including unimplemented ones)
└── docs/
    └── v1.0/
        └── PRD.md           # This document
```

### 9.2 API Summary Table

| Feature | API Used | Protocol | Mode |
|---|---|---|---|
| Transcription | Deepgram Nova-3 | WebSocket streaming | Always |
| AI Notes | DeepSeek | REST (server-sent events) | Always |
| Instant Search | DeepSeek | REST (streaming) | Always |
| Translation | Qwen-MT Flash (primary) / DeepSeek (fallback) | REST (async) | International only |
| Cold Call | DeepSeek | REST (streaming) | Always |
| Auto Explain | DeepSeek | REST (streaming) | Always |
