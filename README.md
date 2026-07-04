# Grasp

**Personalized Real-Time AI Note-Taking and Learning Assistant**

Grasp is a macOS AI workspace for information-dense live sessions such as lectures, meetings, trainings, interviews, and knowledge-sharing conversations. It combines live speech-to-text, AI note generation, proactive concept explanation, and personalized learning memory to help users listen, understand, and take notes at the same time.

Unlike post-session summarizers, Grasp works while the session is happening. The goal is not simply to produce a recap afterward, but to help the user and AI co-create a structured, editable note in real time.

## Why Grasp

Most AI note tools follow a post-session summary model: they record a meeting or lecture, then generate a polished recap after it ends. That approach is useful, but it has several limitations:

- Important wording, examples, or context can be silently compressed or lost.
- Users often do not spend time carefully editing long AI summaries after the session.
- Similar sessions tend to produce generic notes if the AI has no structure to follow.
- The AI usually does not learn the user's preferred note style or knowledge gaps.
- The final note still needs cleanup after the session.

Grasp takes a different approach:

- **Real-time collaboration:** notes are generated during the session, close to the moment the information appears.
- **Human-AI co-writing:** users can edit, guide, and refine notes while AI continues assisting.
- **Structure-first generation:** notes can follow slides or user-defined frameworks instead of generic summaries.
- **Learning support:** Grasp explains unfamiliar terms and adapts to what the user already knows.
- **Personalization:** accepted edits, note structure, detail level, and knowledge history become signals for future outputs.

## Core Features

### Real-Time Transcription

Grasp captures live audio and converts speech into a running transcript. The transcript is segmented into meaningful blocks so downstream AI features can operate on coherent units rather than isolated sentences.

### AI Notes

Grasp generates structured notes from live transcript blocks and inserts them into an editable note document. The Notes panel is designed as a continuous writing surface, closer to a native notes app than a chat feed.

### Human-AI Collaborative Editing

Users can freely edit AI-generated notes during the session. Grasp treats user edits as intentional and does not overwrite them with later AI output.

### Auto Explain

Grasp proactively detects unfamiliar or important concepts from the live session and generates short explanations. The goal is to reduce comprehension gaps while the user is still listening.

### Highlight-to-Explain

Users can select text from the transcript and ask Grasp for an immediate explanation. This supports fast clarification without leaving the live workspace.

### Personalized Learning Memory

Grasp keeps a local profile of the user's known concepts and note preferences. Over time, this helps the assistant skip what the user already understands and focus on what needs explanation.

### Template-Based Note Generation

For sessions without slides, users can provide a custom note framework such as a customer interview template, VC pitch evaluation structure, or product review checklist. Grasp uses that structure to organize live notes into the right sections.

### Review and Export

Past sessions can be reviewed with transcript, notes, saved items, and search history. Notes can be exported for later study or sharing.

## Product Experience

The main workspace is organized around live capture, note creation, explanation, and retrieval:

```text
┌───────────────────────┬───────────────────────┐
│ Transcript             │ AI Notes              │
│ live speech-to-text    │ editable live notes   │
├───────────────────────┼───────────────────────┤
│ Auto Explain           │ Save / Search         │
│ proactive explanation  │ saved context         │
└───────────────────────┴───────────────────────┘
```

The layout is built for focused live use:

- Resizable panels for different workflows.
- A continuous AI Notes editor.
- Selection-based actions for fast explanation and note creation.
- A restrained desktop interface designed for long working sessions.

## How It Works

1. Grasp captures live audio from the session.
2. Speech is converted into a real-time transcript.
3. Transcript text is segmented into meaningful blocks.
4. AI turns each block into structured notes.
5. Notes are inserted into the live editable document.
6. Auto Explain detects concepts the user may not understand.
7. User edits and preferences update local personalization signals.
8. The session ends with a usable note, not just raw transcript data.

## Architecture

Grasp is organized as a native macOS app with separate layers for capture, transcription, AI generation, editing, explanation, and local persistence.

```text
Audio Capture
  -> Speech-to-Text
  -> Transcript Blocks

Transcript Blocks
  -> AI Note Generation
  -> Structured Notes Editor

Transcript / Selection
  -> Concept Detection
  -> Auto Explain / Highlight-to-Explain

User Edits + Saved Concepts
  -> Personalization Memory
  -> Future Notes and Explanations
```

Core modules:

- **macOS client:** SwiftUI interface with AppKit-backed editing where native text behavior matters.
- **Speech-to-text layer:** live transcription pipeline for real-time capture.
- **LLM orchestration layer:** prompt workflows for notes, explanations, search, and editing.
- **Note generation engine:** converts transcript blocks into structured note entries.
- **Auto Explain engine:** detects and explains unfamiliar concepts.
- **Personalization layer:** stores knowledge profile and note style signals.
- **Local persistence:** saves lectures, transcript blocks, notes, searches, and settings.

## Tech Stack

| Area | Technology |
|---|---|
| Platform | macOS |
| UI | SwiftUI + AppKit |
| Editor | `NSTextView` + `NSScrollView` |
| Audio | `AVAudioEngine` |
| Speech-to-text | Deepgram Nova-3 |
| LLM | DeepSeek Chat |
| Translation | Qwen-MT with fallback support |
| Storage | SQLite |
| Project tooling | Xcode / XcodeGen |

## Setup

```bash
git clone https://github.com/Xiaoling67/Grasp.git
cd Grasp
cp Grasp/Services/Secrets.example.swift Grasp/Services/Secrets.swift
```

Add the required API keys to `Grasp/Services/Secrets.swift`, then generate and open the Xcode project:

```bash
xcodegen generate
open Grasp.xcodeproj
```

Requirements:

- macOS 14+
- Xcode
- XcodeGen
- API keys for the configured STT and LLM providers

## Roadmap

Planned directions include:

- More adaptive note style learning from user edits.
- Better template control for different learning and work scenarios.
- Inline AI editing inside the notes editor.
- Deeper knowledge profile and concept memory.
- Higher-quality export formats.
- Multimodal notes with tables, images, and richer structure.
- International learning support for non-native speakers.

## Project Status

Grasp is an active AI product prototype under development.

## Author

Built by [Xiaoling67](https://github.com/Xiaoling67) as an AI Builder project exploring real-time AI note-taking, personalized learning assistance, and human-AI collaborative knowledge work.
