# Grasp

**Personalized Real-Time AI Note-Taking and Learning Assistant**

Grasp is a macOS app for real-time learning and knowledge work. It is designed for people who need to listen, understand, and take notes at the same time in information-dense live sessions such as lectures, meetings, trainings, interviews, and knowledge-sharing conversations.

Grasp is not a post-session summarizer. It is a real-time AI note-taking and learning workspace where the user and AI collaborate while the session is happening.

## Product Positioning

Grasp is the next-generation AI note app: not a tool that summarizes after the meeting, but a tool that helps the user and AI finish the note during the lecture or meeting, so there is little editing left afterward.

v1.3 updates the product positioning from a "macOS classroom AI assistant" to a broader **Personalized Real-Time AI Note-Taking and Learning Assistant**:

- It covers classrooms, meetings, trainings, interviews, and knowledge-sharing sessions.
- It keeps International Mode only as a language-accessibility scenario capability.
- It treats note-taking and learning as one workflow: capture what matters, structure it, edit it, and explain what the user does not understand.

## Why Grasp Is Not Another Granola

Granola and similar products focus on post-meeting summaries. They listen during the session and generate a recap after it ends.

That model has structural problems:

- **Information can be silently lost or rewritten.** The AI does not know which exact wording, example, or point the user wanted to preserve.
- **Users usually do not refine long AI summaries afterward.** If the recap is slightly wrong, the error often stays in the final note.
- **Similar meetings produce similar notes.** Without a predefined structure, the AI falls back to generic summary templates.
- **There is no memory.** Each generation is mostly stateless; the AI does not become meaningfully better at writing notes for this user.
- **The note is not finished during the session.** The user still needs to reread, reorganize, and repair it later.

Grasp is based on five principles:

1. **Real-time collaborative generation** - notes reflect the user's live intent, not only an after-the-fact reconstruction.
2. **Human + AI co-writing** - the user can guide structure, emphasize points, preserve original wording, and edit freely.
3. **Structure before generation** - notes are generated into slides or user-defined templates instead of a generic recap.
4. **Memory** - Grasp learns the user's note style, detail level, terminology, and known concepts over time.
5. **Session ends with a usable note** - the goal is to finish the note during the session, not create more cleanup work afterward.

## Target Users

Grasp is for anyone in a real-time, information-dense setting where listening, understanding, and note-taking compete for attention.

Primary users:

- Students in high-density STEM, business, law, or humanities courses.
- Professionals in meetings, internal trainings, knowledge-sharing sessions, product reviews, customer interviews, or investment discussions.
- International students or non-native speakers in English lectures or meetings.

Non-goals for v1.3:

- Not for passive recorded-video learning where users can pause and replay freely.
- Not for users who only want a post-session summary and do not care about the note-taking process.
- Not for multiplayer collaborative note-taking.
- Not for mobile, offline mode, or vector-database-based memory in this version.

## Core Capabilities

### I. AI Note-taking

| Capability | Status | Meaning |
|---|---|---|
| Real-Time AI Note Generation | Implemented | Sealed transcript blocks trigger AI note generation during the session. |
| Human + AI Collaborative Editing | Implemented | Users can edit notes during the session; AI does not overwrite user edits. |
| Structured Note Generation: Slide-driven | Implemented | Uploaded slides can guide note structure. |
| Structured Note Generation: Template-driven | v1.3 new | Users can handwrite, save, or upload a custom note structure; AI fills the right section. |
| Personalized Memory | Partially implemented, expanded in v1.3 | Current note style guide exists; v1.3 adds draft-vs-edit and inline-edit signals. |
| Human + AI Hybrid Notes | Product result | Final notes differ by user because structure, edits, memory, and AI output interact. |
| Inline AI Editing | v1.3 new | Select part of a note, ask AI to rewrite only that selection, then replace it if accepted. |

### II. AI Learning Assistant

| Capability | Status | Meaning |
|---|---|---|
| Proactive AI Explanation | Implemented | Auto Explain detects unfamiliar concepts and explains them during the live session. |
| Highlight-to-Explain | Implemented | Select text in the transcript and stream a definition + analogy. |
| Personalized Knowledge Profile | Implemented | Grasp tracks known concepts so it can skip explanations the user does not need. |

## v1.3 Scope

v1.3 does two things:

1. **Re-align the product narrative** from "classroom assistant" to "Personalized Real-Time AI Note-Taking and Learning Assistant" for real-time knowledge work.
2. **Add the two missing vision capabilities** from the product concept:
   - Template-driven Notes
   - Inline AI Editing

Existing v1.1-r3 capabilities such as real-time notes, Apple Notes-style editing, slide-driven notes, Auto Explain, Highlight-to-Explain, and Knowledge Profile remain the foundation.

## Template-Driven Notes

Problem: Many important sessions do not have slides. A VC pitch review, customer interview, product review, or internal training may still need structured notes, but the structure comes from the user's own framework.

v1.3 behavior:

- New Session offers `Upload Slides`, `Use a Template`, or `None` as mutually exclusive structure sources.
- Users can quickly type sections line by line, optionally with guidance.
- Example:

```text
Market: TAM/SAM/SOM, growth, market dynamics
Team: founder background, execution ability, hiring gaps
Product: core workflow, differentiation, adoption friction
Business Model: pricing, sales motion, margins
Competition: direct and indirect alternatives
```

- At session start, the Notes document immediately lays out all sections.
- Each AI-generated note is inserted under the best-matching section.
- If no section matches, the note goes to an `Other` section rather than being lost.
- P1 adds saved reusable templates and uploaded document-to-template parsing.

Data model direction:

```swift
struct TemplateSection: Codable {
    var index: Int
    var title: String
    var guidance: String
}
```

The template path reuses the existing slide-driven pipeline concept: define a structure first, then route live notes into that structure.

## Inline AI Editing

Problem: Today, users can edit the whole Notes document manually, but there is no AI editing interaction inside the Notes panel itself. Transcript selection has a popup, but note selection does not.

v1.3 behavior:

- Select at least 2 characters inside the live Notes document.
- An instant `Edit with AI` pill appears above the selection.
- Expanding it opens a card with:
  - selected text preview
  - Rewrite
  - Expand
  - Shorten
  - Clarify
  - Change tone
  - free-form instruction input
  - streaming output
  - Replace / Discard actions
- Replace only changes the original selected range.
- The rest of the document must remain byte-for-byte unchanged.
- After Replace, the new text stays selected so the user can continue editing.
- Every accepted replacement feeds `(selectedText, finalText, instruction)` into the style guide update logic.

This is not full-document regeneration. It is local, precise, user-approved AI editing.

## Personalized Memory

Current state:

- Grasp has a local `noteStyleGuide`.
- It is inferred from the final note text using heuristics such as detail level, outline depth, and table usage.
- It is saved locally and passed into future AI note and summary prompts.

v1.3 extension:

- Inline AI Editing creates high-quality edit pairs: selected text -> accepted replacement.
- These pairs are stronger signals than passive document analysis.
- Repeated terminology changes should become terminology preferences.
- Future notes should reflect the user's accepted edits over time.

## Current Live Workspace

The current app uses a four-quadrant live workspace:

```text
┌───────────────────────┬───────────────────────┐
│ Transcript             │ AI Notes              │
│ real-time STT          │ live editable document│
├───────────────────────┼───────────────────────┤
│ Auto Explain           │ Save / Search         │
│ proactive explanation  │ highlight workflows   │
└───────────────────────┴───────────────────────┘
```

Current workspace behavior:

- Vertical and horizontal dividers are draggable.
- Cursor changes to native resize arrows on divider hover.
- AI Notes uses one continuous `NSTextView` inside `NSScrollView`.
- Content surfaces are pure white.
- Grasp blue system:
  - Primary blue: `#2384E8`
  - Soft blue fill: `#EAF5FF`
  - Soft blue border: `#CFEAFF`

## Technical Architecture

| Layer | Technology |
|---|---|
| Platform | macOS 14+, Swift, SwiftUI, AppKit |
| Editor | Native `NSTextView` + `NSScrollView` |
| Audio capture | `AVAudioEngine` |
| STT | Deepgram Nova-3 |
| LLM | DeepSeek Chat |
| Translation | Qwen-MT with DeepSeek fallback |
| Storage | SQLite |
| Project generation | XcodeGen |

```text
Audio
  AVAudioEngine
  -> Deepgram WebSocket STT
  -> transcript blocks

Notes
  sealed transcript block
  -> DeepSeek generateNoteEntry
  -> quality / duplicate gate
  -> editable Notes document

Understanding
  transcript block or selected text
  -> concept detection / streaming explanation
  -> Auto Explain / Highlight-to-Explain / Knowledge Profile

v1.3 additions
  TemplateSection
  + structureType: none / slides / template
  + streamInlineEdit(selectedText, instruction, documentContext)
  + inline edit pairs for style memory
```

## v1.3 P0 Requirements

| Requirement | Acceptance |
|---|---|
| Handwritten templates | Generate `[TemplateSection]` locally without network calls. |
| Template sections appear at session start | Start Recording immediately inserts all section titles into Notes. |
| AI notes route into matching sections | Unmatched content goes to `Other`. |
| Notes selection shows `Edit with AI` | Appears within one frame, no debounce. |
| Inline edit card | Includes 5 actions, free-form input, streaming preview. |
| Replace only original selection | No other part of the document changes. |
| Inline edits update style guide | Accepted `(selectedText, finalText)` enters style learning. |

## v1.3 P1 Requirements

| Requirement | Acceptance |
|---|---|
| Save reusable templates | Local `templates` table and selectable saved templates. |
| Upload document as template | Parse PDF/Word/plain text into `TemplateSection` list. |
| Change tone presets | Formal, Casual, Concise-professional. |
| Terminology preference tracking | Repeated replacements influence future prompts. |
| README / root PRD rewrite | Product no longer reads as only a classroom assistant. |

## Quick Start

```bash
brew install xcodegen
git clone https://github.com/Xiaoling67/Grasp.git
cd Grasp
cp Grasp/Services/Secrets.example.swift Grasp/Services/Secrets.swift
# Add API keys to Secrets.swift
xcodegen generate
open Grasp.xcodeproj
```

Requirements:

- macOS 14.0+
- Xcode 16.0+
- Microphone permission
- API keys for enabled model providers

## Verification

Current v1.1-r3 behavior can be checked with:

```bash
bash scripts/verify-v1.1-r3.sh
```

The script verifies the current live workspace, AI Notes behavior, draggable panels, note formatting, settings persistence, duplicate gating, and macOS build success.

## Repository Structure

```text
Grasp/
  Services/       STT, LLM, translation, audio, database, memory
  ViewModels/     App state and product workflows
  Views/          Live workspace, Notes editor, transcript, modals, pages

docs/
  v1.3/           Product vision and next major requirements
  v1.1/           Current implementation details and QA records

scripts/
  verify-v1.1-r3.sh
```

## Product Documents

- `docs/v1.3/PRD.md` - the source of truth for the current product vision.
- `docs/v1.1/PRD.md` - implementation details for the current live workspace and Apple Notes-style editor.
- `docs/v1.1/SPEC.md` - supporting specs for existing capabilities.

## License

Proprietary. All rights reserved.
