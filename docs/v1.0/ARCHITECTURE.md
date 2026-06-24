# Grasp — Architecture Document v1.0

> Version: 1.0 (2026-06-23)
> Platform: macOS 14.0+ | Swift 5.9 | SwiftUI + AppKit interop

---

## 1. Project Structure

```
Grasp/
├── GraspApp.swift                  # @main entry point, RootView, MainContent
├── Models/Models.swift             # All data structs + UI state enums
├── ViewModels/AppViewModel.swift   # Single @MainActor state container (335 lines)
├── Services/
│   ├── DatabaseService.swift       # SQLite persistence (singleton)
│   ├── DeepSeekService.swift       # DeepSeek Chat API (singleton)
│   ├── DeepgramService.swift       # Deepgram Nova-3 WebSocket (singleton)
│   ├── AudioService.swift          # AVAudioEngine capture (singleton)
│   └── QwenTranslationService.swift # Qwen-MT + DeepSeek fallback (singleton)
├── Views/
│   ├── Layout/
│   │   ├── TopBarView.swift        # Title bar, tabs, record controls
│   │   ├── SidebarView.swift       # 200px left nav (Home/Saved/Search/Past)
│   │   └── LiveTabView.swift       # Transcript + Notes + Bottom layout
│   ├── Transcript/
│   │   ├── TranscriptPanelView.swift  # Scrollable block list + selection monitor
│   │   └── SelectionPopupView.swift   # Glassmorphism K/L/Search/Notes popup
│   ├── Notes/NotesPanelView.swift     # Editable note list with slide sections
│   ├── Bottom/
│   │   ├── BottomPanelView.swift      # 4-tab bottom bar + Cold Call column
│   │   ├── SearchCardView.swift       # Streaming search result card
│   │   ├── SaveCardView.swift         # Knowledge/Language save card
│   │   └── AutoExplainCardView.swift  # Auto-explain result card
│   ├── ColdCall/ColdCallCardView.swift  # 3-phase cold call card
│   ├── Pages/
│   │   ├── HomeView.swift              # Landing page with Start Recording
│   │   ├── SettingsView.swift          # Default mode, display prefs
│   │   ├── PastLectureView.swift       # 4-tab lecture review
│   │   ├── SavedItemsView.swift        # All saves grid with filter
│   │   └── SearchHistoryView.swift     # All searches with expand/collapse
│   ├── Modals/
│   │   ├── NewLectureModalView.swift   # Name/Subject/Slides → Start
│   │   ├── ExportModalView.swift       # RTF export with toggles
│   │   └── OnboardingModalView.swift   # 3-step first-launch flow
│   ├── ToastView.swift                 # Bottom-center pill notification
│   ├── InterFont.swift                 # Inter TTC font registration
│   └── Color+Hex.swift                 # Hex color initializer
├── Resources/Inter.ttc              # Inter font (13MB, currently unbundled)
├── Info.plist                       # Bundle metadata, mic permission
└── Grasp.entitlements               # Sandbox entitlements (audio, network, files)
```

---

## 2. App Entry Point & View Hierarchy

```
GraspApp (@main)
 └─ WindowGroup { RootView() }
     └─ RootView
         ├─ TopBarView (title bar + tabs + record controls)
         ├─ HStack
         │   ├─ SidebarView (200px, conditionally visible)
         │   └─ MainContent
         │       ├─ [if activeTab] → LiveTabView | PastLectureView
         │       └─ [if no tab] → HomeView | SettingsView | SavedItemsView | SearchHistoryView
         │           └─ LiveTabView
         │               ├─ TranscriptPanelView + NotesPanelView (resizable divider)
         │               └─ BottomPanelView + ColdCallCardView
         ├─ NewLectureModalView (conditional overlay)
         ├─ ExportModalView (conditional overlay)
         ├─ OnboardingModalView (conditional overlay)
         └─ ToastView (conditional overlay)
```

**Window spec:**
- Default size: 1280×800
- Minimum size: 960×640
- Hidden title bar
- Single instance, single window

---

## 3. ViewModel Architecture

### AppViewModel (@MainActor, ObservableObject)

A single 335-line class managing ALL application state:

| Domain | Property | Type |
|--------|----------|------|
| Navigation | `page` | `AppPage` |
| Navigation | `tabs`, `activeTabId` | `[TabItem]`, `String?` |
| Navigation | `sidebarVisible`, `pastExpanded` | `Bool` |
| Lecture | `isRecording`, `isPaused` | `Bool` |
| Lecture | `activeLectureId`, `activeLectureName` | `String?` |
| Lecture | `activeLectureMode`, `activeLectureSubject` | `String` |
| Transcript | `liveBlocks`, `activeBlockId` | `[LiveBlock]`, `String?` |
| Transcript | `interimText` (never populated) | `String` |
| Notes | `noteBlocks`, `slideStructure` | `[NoteBlock]`, `[SlideItem]` |
| Bottom | `activeCard`, `bottomTab` | `ActiveCardState?`, `String` |
| Bottom | `searchStreaming`, `streamingTokens` | `Bool`, `String` |
| Bottom | `sessionSaves`, `sessionSearches` | `[SavedCard]`, `[SearchResultState]` |
| Cold Call | `coldCallPhase` | `ColdCallPhase?` |
| Auto Explain | `autoExplainResult`, `autoExplainStreaming` | `SearchResultState?`, `Bool` |
| Auto Explain | `autoExplainTokens`, `autoExplainNew` | `String`, `Bool` |
| UI | `showNewLectureModal`, `showExportModal` | `Bool` |
| UI | `showOnboarding`, `onboardingChecked` | `Bool` |
| UI | `toastMessage`, `toastType` | `String?`, `String` |
| Layout | `notesWidth` | `CGFloat` |
| Debug | `deepgramStatus`, `transcriptsReceived` | `String`, `Int` |

### Key Methods

| Method | Trigger | What it does |
|--------|---------|-------------|
| `startLecture()` | User taps "Start Recording" | Creates DB record, requests mic, starts AVAudioEngine tap, connects Deepgram WebSocket, generates domain keywords |
| `stopLecture()` | User taps ■ | Stops capture, disconnects WebSocket, seals last block, stops DB timer |
| `handleInterim()` | Deepgram interim result | Word-diff against interimBuf, appends new words to active block |
| `handleFinal()` | Deepgram final result | Appends remaining words, seals at 100-word limit |
| `handleEnd()` | Deepgram UtteranceEnd | Seals block if ≥ 50 words |
| `seal()` | Internal | Marks block sealed, saves to DB, triggers translation + note generation + auto-explain + cold call detection |
| `triggerSearch()` | User taps "Search" | Sends query + context to DeepSeek stream, caches result |
| `handleSaveAction()` | User taps K/L | Creates SaveDraft, shows save card (known bug: translation lost) |
| `autoExplain()` | Automatic after seal | Detects unfamiliar term, streams explanation, saves to session |
| `generateCCAnswer()` | User taps "Generate Answer" | Sends question + context to DeepSeek, transitions to answered phase |

---

## 4. Services Layer

### 4.1 AudioService

```
AVAudioEngine.inputNode
  └─ installTap(onBus: 0, bufferSize: sampleRate×0.1)
       └─ floatChannelData → PCM16 conversion → Data callback
            └─ DeepgramService.sendAudio()
```

- Sample rate: device default (~44.1kHz or 48kHz)
- Buffer: 100ms chunks
- Converts Float32 interleaved → Int16 PCM via manual channel averaging
- Runs on audio render thread (real-time priority)

### 4.2 DeepgramService

```
WebSocket wss://api.deepgram.com/v1/listen
  └─ Auth via protocols: ["token", apiKey]
  └─ Query params: nova-3, en-US, linear16, interim_results=true,
       punctuate=true, smart_format=true, utterance_end_ms=2000
  └─ Optional: keyterm params (up to 20 domain keywords)
  
  Events:
    ├─ Results (is_final=false) → onInterim callback
    ├─ Results (is_final=true)  → onFinal callback
    ├─ UtteranceEnd              → onEnd callback
    └─ WebSocket open/close      → isConnected flag + pending buffer flush
```

**Known issue:** `pending` audio buffer is accessed from audio thread (sendAudio) and main thread (didOpenWithProtocol) without synchronization.

### 4.3 DeepSeekService

```
REST POST https://api.deepseek.com/chat/completions
  ├─ model: deepseek-chat
  ├─ Auth: Bearer token (Secrets.deepseekApiKey)
  └─ Timeout: 20s (non-streaming) / 8s (streaming)

Endpoints:
  ├─ streamSearch()      — streaming, max_tokens=200
  ├─ generateNoteEntry() — non-streaming, max_tokens=120
  ├─ detectUnfamiliarTerm() — non-streaming, max_tokens=60
  ├─ generateKeywords()  — non-streaming, max_tokens=150
  ├─ generateSlideStructure() — non-streaming, max_tokens=800
  └─ generateColdCallAnswer() — non-streaming, max_tokens=300
```

**Known issue:** `stream()` decodes SSE byte-by-byte, breaking multi-byte UTF-8 characters across TCP segments.

### 4.4 DatabaseService

```
SQLite via raw C API (sqlite3_open → prepare → step → finalize)
Storage path: ~/Library/Application Support/Grasp/grasp.db

Tables:
  lectures        — id, name, subject, mode, started_at, ended_at, duration
  blocks          — id, lecture_id, block_index, text_en, text_zh, is_final, started_at, created_at
  note_blocks     — id, lecture_id, slide_index, slide_title, content, source, level, sort_order, created_at
  saves           — id, lecture_id, block_id, type, original, translation, note, created_at
  searches        — id, lecture_id, block_id, query, result_pro, result_simple, note, saved, engaged, dismissed_at, created_at
  lecture_slides  — lecture_id, structure (JSON), created_at
  settings        — key, value (KV store)
```

**Known issue:** No thread safety. `sqlite3_open` in single-thread mode. Multiple Tasks call prepare/step/finalize concurrently.

### 4.5 QwenTranslationService

```
Primary:   POST https://dashscope-us.aliyuncs.com/compatible-mode/v1/chat/completions
           model: qwen-mt-flash, translation_options: [source_lang: auto, target_lang: Chinese]
Fallback:  POST https://api.deepseek.com/chat/completions
           model: deepseek-chat, system prompt for academic translation
```

---

## 5. Data Models

### Persisted (SQLite rows)

| Struct | Source Table | Key Fields |
|--------|-------------|------------|
| `Lecture` | lectures | id, name?, subject?, mode, startedAt, endedAt?, duration?, saveCount?, searchCount? |
| `Block` | blocks | id, lectureId, blockIndex, textEn, textZh?, isFinal, startedAt, createdAt? |
| `NoteBlock` | note_blocks | id, lectureId, slideIndex, slideTitle?, content, source("ai"|"user"), level(0|1|2), sortOrder, createdAt? |
| `SavedCard` | saves | id, lectureId?, blockId?, type("knowledge"|"language"), original, translation?, note?, createdAt? |
| `SearchResult` | searches | id, lectureId?, blockId?, query, resultPro, resultSimple, note?, saved, createdAt? |
| `SlideItem` | lecture_slides (JSON) | index, title, concepts, keywords |

### Transient (UI state only)

| Struct | Purpose |
|--------|---------|
| `LiveBlock` | In-progress transcription block (not yet sealed) |
| `TabItem` | Open tab (live or past lecture) |
| `SaveDraft` | In-flight save operation before confirmation |
| `SearchResultState` | In-memory search result (mapped to DB SearchResult on save) |
| `ColdCallAnswer` | Generated cold call answer with supporting points |

---

## 6. Data Flows

### 6.1 Transcription Flow

```
Microphone → AudioService (AVAudioEngine tap, 100ms PCM16 chunks)
              → DeepgramService.sendAudio()
                → WebSocket to Deepgram Nova-3
                  ← WebSocket messages (interim/final/UtteranceEnd)
                    → AppViewModel.handleInterim()  [word-diff → liveBlocks[i].textEn]
                    → AppViewModel.handleFinal()    [append + check 100-word seal]
                    → AppViewModel.handleEnd()      [check 50-word minimum → seal]
                      → seal()
                        → db.saveBlock()
                        → [if international] Task { tr.translate() → db.setBlockTranslation() }
                        → noteTask { sleep 500ms → ds.generateNoteEntry() → db.saveNoteBlock() }
                        → Task { autoExplain() → ds.detectUnfamiliarTerm() → ds.streamSearch() }
                        → detectCC() → regex match → coldCallPhase = .detected
```

### 6.2 Search Flow

```
User selects text in transcript
  → NSEvent localMonitorForEvents (leftMouseUp)
    → window.firstResponder as? NSTextView → selectedRange()
  → SelectionPopupView (K/L/Search/Notes buttons)
    OR BlockView.contextMenu (Save K/L/AI Search/Copy to Notes)
  → AppViewModel.triggerSearch(query, blockIndex)
    → Check in-memory cache → hit: return cached
    → miss: DeepSeekService.streamSearch() (streaming)
      → streamingTokens += token (on URLSession background queue — data race risk)
      → On complete: split "|" → professional + intuition
      → db.saveSearch() → sessionSearches.insert → activeCard = .search
```

### 6.3 Note Generation Flow

```
seal() called
  → noteTask?.cancel()  [cancel previous pending note]
  → noteTask = Task {
      sleep 500ms
      db.getRecentBlocks(lectureId, beforeIndex: bi+1, limit: 3)
      db.getSlideStructure(lectureId)  [always empty — PDF never parsed]
      Array(noteBlocks.suffix(3))
      ds.generateNoteEntry(slides, recent, recentNotes, subject)
        → DeepSeek API call (non-streaming, max_tokens=120)
        → Parse JSON: { slideIndex, content, level } or { skip: true }
      db.saveNoteBlock()
      noteBlocks.append()
    }
```

### 6.4 Cold Call Flow

```
seal() → detectCC(text)
  → Match 7 regex patterns
  → If match: extractQ() → find sentence ending with "?"
  → 90s cooldown check
  → coldCallPhase = .detected(question)
  → User taps "Generate Answer"
    → ColdCallPhase = .generating
    → ds.generateColdCallAnswer(question, context, slides, notes, subject)
      → DeepSeek API call (non-streaming, max_tokens=300)
      → Parse JSON: { questionType, shortAnswer, supportingPoints }
    → ColdCallPhase = .answered(answer)
    → User can "Save to Notes" → saveCCToNotes()
```

---

## 7. Key Design Decisions

| Decision | Rationale | Trade-off |
|----------|-----------|-----------|
| Single AppViewModel | Simple state management, no cross-store coordination needed | 335-line monolith, hard to test |
| Singletons for all services | Easy access from anywhere, no DI setup | Tight coupling, can't mock for tests |
| SQLite via raw C API | Zero external dependencies, full control | No thread safety, verbose code |
| Deepgram Nova-3 | Best accuracy for academic lecture domain | $0.0043/min, requires internet |
| DeepSeek for all AI tasks | Single provider, consistent API | Vendor lock-in; Qwen only used for translation |
| Word-diff for interim text | Avoids re-rendering entire transcript on every interim | Fragile with ASR correction finals |
| 50-word seal minimum / 100-word maximum | Balances note granularity with block coherence | Seal boundaries are pause-based, not semantic |
| Inter font via CTFontManager | Custom typography without embedding in bundle | Font was unbundled (bug) |

---

## 8. Technical Debt & Known Issues

| Severity | Issue | Impact | Fix |
|----------|-------|--------|-----|
| HIGH | Inter.ttc not in bundle | All custom fonts silently fall back to system font | Add to Copy Bundle Resources |
| HIGH | Translation race in handleSaveAction | International mode translation never reaches save card | Move SaveDraft creation inside Task |
| HIGH | DatabaseService no thread safety | Potential crash on concurrent DB access from multiple Tasks | Add serial queue or actor |
| MEDIUM | @Published written from background queue | Data race on streamingTokens, autoExplainTokens | Wrap in MainActor.run |
| MEDIUM | DeepgramService.pending unsynchronized | Data race on audio thread vs main thread | Add lock or serial queue |
| MEDIUM | interimText never written | Dead code in TranscriptPanelView UI | Write in handleInterim |
| MEDIUM | 5 keyboard shortcuts unimplemented | README claims features that don't work | Add to GraspApp.commands |
| MEDIUM | PDF slides uploaded but never parsed | slideIndex always 0, notes not slide-aligned | Add PDFKit parsing |
| LOW | UTF-8 byte-by-byte SSE decoding | Multi-byte chars (Chinese) may be lost in stream | Buffer by line, not by byte |
| LOW | Export blocks main thread | UI freeze on large lecture exports | Move to background queue |
| LOW | No reconnection logic in DeepgramService | Network drops silently stop transcription | Add WebSocket reconnection |
| LOW | Settings toggles disconnected | Font size, show translation, hover freeze do nothing | Wire to actual behavior |

---

## 9. Dependencies

| Dependency | Purpose | Integration |
|-----------|---------|-------------|
| Deepgram Nova-3 | Speech-to-text | WebSocket API (API key) |
| DeepSeek Chat | AI notes, search, cold call, keywords | REST API (API key) |
| Qwen-MT Flash | Translation | REST API (API key) |
| libsqlite3.tbd | Local persistence | System library (Xcode SDK) |
| Inter font | UI typography | TTC file (Resources/) |
| AVAudioEngine | Microphone capture | System framework |
| PDFKit (unused) | Slide parsing | System framework (imported but not called) |

---

## 10. Build & Run

```bash
# Prerequisites
brew install xcodegen
# macOS 14.0+, Xcode 16.0+

# Setup
cd Grasp
cp Grasp/Services/Secrets.example.swift Grasp/Services/Secrets.swift
# Edit Secrets.swift with your API keys

# Build
xcodegen generate
xcodebuild -project Grasp.xcodeproj -scheme Grasp build

# Or open in Xcode
open Grasp.xcodeproj
```
