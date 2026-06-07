# Grasp

A desktop AI lecture assistant for students that performs real-time transcription, translation, note generation, and search during class.

## Features

- **Live Transcription** — Word-by-word display via Deepgram Nova-3. Semantic blocking with scroll-freeze.
- **AI Notes** — Slide-aligned, incrementally generated. Editable with indentation levels.
- **Instant Search** — Select any term for a two-sentence explanation (definition + analogy) via DeepSeek.
- **Live Translation** — Subject-aware Chinese translation with Qwen-MT. Toggle on/off anytime.
- **Cold Call Detection** — Detects professor questions and generates context-grounded answers.
- **Export** — Download full lecture as `.docx` with transcript, notes, and search history.
- **Review** — Browse past lectures with four tabs: Transcript, Notes, Saved, Searches.

## Quick Start

```bash
brew install xcodegen
git clone https://github.com/Xiaoling67/Grasp.git
cd Grasp
cp Grasp/Services/Secrets.example.swift Grasp/Services/Secrets.swift
# Add your API keys to Secrets.swift
xcodegen generate && open Grasp.xcodeproj
```

> Requires macOS 14.0+, Xcode 16.0+, and microphone access.

## Shortcuts

| Keys | |
|------|--|
| `⌘ N` | New lecture |
| `⌘ ⇧ P` | Pause / resume |
| `⌘ ⇧ K` | Save as knowledge |
| `⌘ ⇧ L` | Save as language |
| `⌘ ⇧ E` | Search selection |
| `⌘ ⇧ X` | Export |
| `Esc` | Dismiss popup |

## Architecture

```
Services/     Deepgram (WebSocket) · DeepSeek (Chat) · Qwen-MT (Translation) · SQLite · AVAudioEngine
ViewModels/   Single source of truth via @MainActor ObservableObject
Views/        Layout · Transcript · Notes · Bottom · ColdCall · Pages · Modals
```

## License

Proprietary. All rights reserved.
