# Grasp

**桌面 AI 讲座助手** — Real-time transcription, translation, notes, search, and cold call assistance during live lectures.

## Pain Points → Solutions

| Pain Point | Grasp |
|------------|-------|
| Can't keep up with lecture pace for note-taking | **AI Notes** — auto-generated, slide-aligned |
| Mid-lecture confusion requires looking things up | **Search** — select any term for instant explanation |
| Key quotes and insights lost after class | **Save** — bookmark knowledge & language cards |
| Professor's cold call questions affecting GPA | **Cold Call** — detect + generate context-grounded answers |
| Language barriers for international students | **Live Translation** — incremental, subject-aware |

## Modes

| Mode | Target | Features |
|------|--------|----------|
| **Standard** | Native English speakers | Live transcription · AI notes · AI search · Save |
| **International** | Non-native speakers | All above + live translation + language saves |

## Core Features

### Live Transcription

- Word-by-word rendering, target latency < 500ms
- Semantic blocks (50–100 words each) sealed by:
  - Sentence-ending punctuation + ≥ 500ms pause
  - Word count ≥ 100 (forced)
- Active block shows pulsing blue dot and "Transcribing…" indicator
- Blocks display English (13px Inter) and Chinese translation (12px) below
- Auto-scroll to bottom; manual scroll up freezes and shows preview strip
- Hover-to-freeze mode (configurable in Settings)

### AI Real-Time Notes

Pre-class: Upload slides → LLM extracts course outline (chapters + concepts + keywords).

During class:
- Incremental note generation — append operations, not full rewrite
- Each note block has `id`, `level` (0/1/2), `source` (ai/user)
- Notes are slide-aligned via embedding-based chapter matching
- Structured as `1.` (main) / `·` (supporting) / `○` (detail)
- Editable: click to edit, Enter to add new line, Tab to indent, Backspace to delete
- Organized by slide chapter with divider headers
- Fully preserved for post-class review

### Text Selection Actions

Two triggers: click block (selects all) or drag-select any fragment.

**Standard mode popup:**
```
[ Save ]  |  [ Search ]
```

**International mode popup:**
```
[ K ]  [ L ]  |  [ Search ]
```
K = Knowledge, L = Language

**AI Search** (⌘⇧E):
- Returns 2-part structured explanation via DeepSeek streaming
- Sentence 1 (≤ 50 words): Professional definition grounded in lecture context
- Sentence 2 (≤ 25 words): Everyday analogy, zero jargon
- Follow-up questions supported; results saveable
- Context: 10 semantic blocks preceding selection
- Session-level cache; 8s timeout with 1 retry

**Search Prompt (v2):**
```
You are a concise study-card generator. A student highlighted a term during a university lecture and needs an instant explanation.

Course: {subject}
Recent lecture transcript (for context only):
{context}

Term to explain: "{query}"

Rules:
- Output exactly 2 sentences separated by " | ". No headers, no labels, no markdown.
- NEVER start with "The professor", "In this lecture", "The transcript", "As mentioned", or any meta-reference to the lecture or speaker.
- If the highlighted text is a phrase or concept rather than a single term, explain the core idea directly.

Sentence 1 (max 50 words): A direct, self-contained definition of "{query}" grounded in the lecture context. Start with the term itself or a direct statement about what it is.
Sentence 2 (max 25 words): One concrete everyday analogy for someone with zero prior knowledge of {subject}. No jargon.
```

### Live Translation (International mode)

- Incremental, subject-aware (course subject passed to translation engine)
- Chinese text appears below English in real time
- Configurable target language (default: zh-CN)
- Toggle on/off in Settings

### Cold Call Detection

- 7 regex patterns detect professor questions in sealed blocks
- 90-second cooldown between triggers; 45-second auto-dismiss
- Answer generation: question type classification → lecture context retrieval → grounded answer
- Output: `questionType` (Concept/Analysis/Opinion/Recall) + `shortAnswer` (≤ 60 words) + `supportingPoints`

### Past Lecture Review

Open any past lecture as a tab with **4 sub-pages**:

| Tab | Content |
|-----|---------|
| Transcript | All semantic blocks with translations |
| Notes | Slide-organized notes with level indentation |
| Saved | Knowledge & Language cards, filterable by type |
| Searches | All AI search records |

Lecture names support inline renaming (click to edit).

### Export

Export as `.docx` via ⌘⇧X or sidebar button. Selectable content:
- Full Transcript · AI Notes · Knowledge Notes · Language Notes · AI Searches

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI (macOS 14.0+) |
| Database | SQLite3 (raw C API) |
| Speech-to-Text | Deepgram Nova-3 (WebSocket) |
| AI | DeepSeek Chat + Qwen-MT Flash |
| Font | Inter |

## Project Structure

```
Grasp/
├── Services/              # Backend
│   ├── DatabaseService.swift
│   ├── AudioService.swift
│   ├── DeepgramService.swift
│   ├── DeepSeekService.swift
│   └── QwenTranslationService.swift
├── Models/Models.swift    # Data structures
├── ViewModels/            # State management
├── Views/
│   ├── Layout/            # TopBar, Sidebar
│   ├── Transcript/        # Transcript panel, Selection popup
│   ├── Notes/             # AI notes (contentEditable-style)
│   ├── Bottom/            # Search card, Save card
│   ├── ColdCall/
│   ├── Pages/             # Home, Settings, PastLecture, Saved, SearchHistory
│   └── Modals/            # New Lecture, Export, Onboarding
└── Resources/Inter.ttc    # Font
```

## Setup

```bash
git clone https://github.com/catherineuspan/grasp.git
cd grasp

# Install dependencies
brew install xcodegen

# Configure API keys
cp Grasp/Services/Secrets.example.swift Grasp/Services/Secrets.swift
# Edit Secrets.swift with your keys:
#   - deepgramApiKey (Deepgram Nova-3)
#   - deepseekApiKey (DeepSeek Chat)
#   - qwenApiKey (Qwen-MT Flash)

# Build & run
xcodegen generate
open Grasp.xcodeproj   # Cmd+R to run
```

## Shortcuts

| Keys | Action |
|------|--------|
| `⌘ N` | New Lecture |
| `⌘ ⇧ P` | Pause / Resume |
| `⌘ ⇧ K` | Save as Knowledge |
| `⌘ ⇧ L` | Save as Language |
| `⌘ ⇧ E` | AI Search |
| `⌘ ⇧ X` | Export |
| `Esc` | Dismiss popup |

## Requirements

- macOS 14.0+
- Xcode 16.0+
- Microphone permission

## License

Proprietary. All rights reserved.
