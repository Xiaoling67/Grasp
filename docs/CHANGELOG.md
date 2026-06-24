# Changelog

## v1.1 (2026-06-23)

### Features
- Concept Map: 15s rolling window replacing per-seal flat notes. Hierarchical tree structure with parent/child concept relationships. Slides-aligned. Tree UI in Notes panel.
- Knowledge Profile: persistent memory of known concepts via SQLite + MemoryService. Wired into Auto Explain (skips/reminds based on what student knows), Search (injects known terms into prompt), Save (auto-adds to profile), and Dismiss tracking.
- Keyboard Shortcuts: implemented all 5 missing shortcuts (⌘⇧P/K/L/E/X)
- PDF Slide Parsing: slides are now parsed at lecture start via PDFKit → DeepSeek → slide-aligned notes
- Cold Call answers now feed into Knowledge Profile

### Bug Fixes
- Inter font now bundled in .app — custom typography works correctly
- Translation race in handleSaveAction fixed — save card now receives translation in International mode
- interimText now populated in transcript UI (was dead code)

## v1.0.1 (2026-06-23)

### Bug Fixes
- Inter font now bundled in .app — custom typography works correctly
- Translation race in handleSaveAction fixed — save card now receives translation in International mode
- interimText now populated in transcript UI (was dead code)

## v1.0 (2026-06-23)

Initial release. Current production state of Grasp macOS app.

### Features
- Live Transcription via Deepgram Nova-3 (WebSocket streaming)
- AI Notes via DeepSeek (per-seal generation, flat structure)
- Instant Search via DeepSeek (streaming, selection-based)
- Live Translation via Qwen-MT + DeepSeek fallback
- Cold Call Detection (7 regex patterns, lecture-context answers)
- Save to Knowledge / Language (SQLite persistence)
- Export to RTF
- Past Lecture Review (4 tabs: Transcript, Notes, Saved, Searches)
- Onboarding (3-step: Welcome → Mode → Done)
- Settings (Default Mode, Display preferences)
- Keyboard Shortcuts: ⌘N (New Lecture) — others documented but not implemented

### Architecture
- Single `@MainActor AppViewModel` (335 lines) as single source of truth
- 5 singleton services: DatabaseService, DeepSeekService, DeepgramService, AudioService, QwenTranslationService
- SQLite via raw sqlite3 API (no ORM)
- SwiftUI + AppKit interop for text selection monitoring

### Known Issues (fixed in v1.0.1)
- Inter font not bundled in .app (all .inter() fonts fall back to system font)
- Translation race: handleSaveAction loses translation result in International mode
- interimText never populated in UI (cosmetic)
- 5 documented keyboard shortcuts not implemented
- PDF slides uploaded but never parsed (slideIndex always 0)
- No thread safety on DatabaseService
- No unit tests
- @Published properties written from URLSession background queue (data race risk)
- DeepgramService.pending array accessed from audio thread + main thread unsafely
