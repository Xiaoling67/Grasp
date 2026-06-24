# Tech Changelog

## v1.1 (2026-06-23)

### Features
- Concept Map: 15s rolling window replacing per-seal notes. New ConceptNode model, concept_map DB table, DeepSeekService.generateConceptMapUpdate() with full map replacement, 15s Timer in AppViewModel, tree UI in NotesPanelView with buildConceptTree/collectChildren helpers. Dual render path for v1.0 backward compat.
- Phase 2 wiring: Auto Explain checks MemoryService.checkConcept() before showing (known→skip, lookedUp→reminder, neverSeen→full). Search injects known terms into DeepSeek prompt. Save auto-adds to Profile. Dismiss tracked. Cold Call feeds into knowledge.
- Keyboard Shortcuts: added 5 new CommandMenu entries in GraspApp.swift with .disabled() guards
- AppViewModel: added `static var lastSelectedText` for shortcut access
- TranscriptPanelView: writes selection to `AppViewModel.lastSelectedText` in mouse-up handler
- SlideParserService.swift: new file, PDFKit-based text extraction
- startLecture(): parses PDF in parallel Task → DeepSeek generateSlideStructure → saveSlideStructure
- openPastLecture(): loads slideStructure from DB
- student_knowledge table: new SQLite table for persistent concept memory
- MemoryService.swift: new file, singleton wrapping knowledge CRUD
- KnowledgeProfileView.swift: new file, Settings page editor for knowledge profile
- SettingsView: added Knowledge Profile row

### Changed
- DatabaseService: added 7 knowledge CRUD methods + DDL for student_knowledge table
- project.yml: pre-build script for Inter font bundle

## v1.0.1 (2026-06-23)

### Changes
- Inter font added to Copy Bundle Resources via project.yml pre-build script
- InterFont.swift: updated bundle path (removed `subdirectory: "Resources"`)
- handleSaveAction: moved SaveDraft creation into async translation callback
- handleInterim: added `interimText = t` assignment
- seal(): added `interimText = ""` reset

## v1.0 (2026-06-23)

### Architecture
- Single `@MainActor AppViewModel` (335 lines) as single source of truth
- 5 singleton services: DatabaseService (SQLite), DeepSeekService (REST), DeepgramService (WebSocket), AudioService (AVAudioEngine), QwenTranslationService
- SwiftUI + AppKit interop (NSEvent monitor for text selection)
- Raw sqlite3 C API (no ORM)
- xcodegen for project generation (project.yml)

### Dependencies
| Dependency | Version/Type | Integration |
|-----------|-------------|-------------|
| Deepgram Nova-3 | WebSocket API | Speech-to-text |
| DeepSeek Chat | REST API (deepseek-chat) | AI notes, search, cold call, keywords |
| Qwen-MT Flash | REST API | Translation (primary) |
| libsqlite3.tbd | System library | Local persistence |
| Inter font | TTC (13MB, Resources/) | UI typography |
| AVAudioEngine | System framework | Microphone capture |

### Data Flow
- Audio: `AVAudioEngine tap (100ms PCM16) → Deepgram WebSocket → interim/final/UtteranceEnd → seal()`
- AI: `seal() → 500ms debounce → DeepSeek generateNoteEntry (non-streaming, max_tokens=120)`
- Search: `Selection popup → DeepSeek streamSearch (streaming, max_tokens=200)`
- Translation: `Qwen-MT Flash → [on failure] DeepSeek fallback`
- Cold Call: `7 regex patterns → DeepSeek generateColdCallAnswer (non-streaming, max_tokens=300)`
- Auto Explain: `seal() → DeepSeek detectUnfamiliarTerm → [if confidence>0.65] DeepSeek streamSearch`

### Database Schema (7 tables + 1 KV store)
- lectures, blocks, note_blocks, saves, searches, lecture_slides, student_knowledge, settings

### Known Technical Debt
| Issue | Impact | Severity |
|-------|--------|----------|
| DatabaseService no thread safety | Potential crash (concurrent prepare/step/finalize) | HIGH |
| @Published written from URLSession background | Data race on streamingTokens, autoExplainTokens | MEDIUM |
| DeepgramService.pending unsynchronized | Data race (audio thread vs main thread) | MEDIUM |
| DeepSeek byte-by-byte UTF-8 decoding | Multi-byte chars lost across TCP segments | MEDIUM |
| Export blocks main thread | UI freeze on large lectures | LOW |
| No WebSocket reconnection | Silent transcription loss on network drop | LOW |
