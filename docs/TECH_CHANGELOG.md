# Tech Changelog

## v1.0.1 (2026-06-23)

### Changes
- Inter font added to Copy Bundle Resources via project.yml pre-build script
- InterFont.swift: updated bundle path (removed `subdirectory: "Resources"`)
- handleSaveAction: moved SaveDraft creation into async translation callback
- handleInterim: added `interimText = t` assignment
- seal(): added `interimText = ""` reset

## v1.0 (2026-06-23)

Initial release — current production state.

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

### Database Schema (6 tables + 1 KV store)
- lectures, blocks, note_blocks, saves, searches, lecture_slides, settings

### Known Technical Debt
| Issue | Impact | Severity |
|-------|--------|----------|
| Inter.ttc not in app bundle | All custom fonts → system font fallback | HIGH |
| Translation race in handleSaveAction | Translation never reaches save card | HIGH |
| DatabaseService no thread safety | Potential crash (concurrent prepare/step/finalize) | HIGH |
| @Published written from URLSession background | Data race on streamingTokens, autoExplainTokens | MEDIUM |
| DeepgramService.pending unsynchronized | Data race (audio thread vs main thread) | MEDIUM |
| DeepSeek byte-by-byte UTF-8 decoding | Multi-byte chars lost across TCP segments | MEDIUM |
| interimText never populated | Dead UI code | LOW |
| Export blocks main thread | UI freeze on large lectures | LOW |
| No WebSocket reconnection | Silent transcription loss on network drop | LOW |
