# Student Knowledge Profile

**Feature:** SQLite table `student_knowledge` + Settings page editor + MemoryService.swift  
**Spec version:** 1.0  
**Author:** pm (DeepSeek)  
**Status:** Draft — ready for engineer implementation

---

## 1. Motivation

The app currently has no persistent memory of what a student knows. Auto Explain fires on every unfamiliar-looking term regardless of whether the student has already saved it, searched it, or dismissed it. Search has no awareness of the student's prior context. This spec introduces a **Knowledge Profile** — a persistent, editable record of concepts the student has encountered, searched, saved, or dismissed. It is the foundation for personalized Auto Explain and Search (Phase 2 wiring), but is built as an independent module in Phase 1.

**Founder decision (already made):** Placement is **Option A — Settings page** (see v1.1/SPEC.md for decision rationale). No other placement.

---

## 2. SQLite Table: `student_knowledge`

### 2.1 Schema

```sql
CREATE TABLE IF NOT EXISTS student_knowledge (
    concept            TEXT PRIMARY KEY,
    status             TEXT NOT NULL DEFAULT 'never_seen',
    search_count       INTEGER DEFAULT 0,
    first_seen_at      INTEGER,
    last_interacted_at INTEGER,
    source             TEXT DEFAULT 'auto'
);
```

### 2.2 Column Definitions

| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `concept` | TEXT (PK) | — | Normalized lowercased concept string (trimmed, no leading/trailing whitespace). Case-insensitive lookups always use `.lowercased()`. |
| `status` | TEXT | `'never_seen'` | One of `'known'`, `'looked_up'`, `'dismissed'`, `'preventive'`, `'never_seen'`. |
| `search_count` | INTEGER | 0 | Number of times the student has searched this concept. Incremented on each search, not on auto-explain. |
| `first_seen_at` | INTEGER | NULL | Unix millisecond timestamp of first recorded interaction with this concept. |
| `last_interacted_at` | INTEGER | NULL | Unix millisecond timestamp of most recent interaction (save, search, dismiss, auto-explain). |
| `source` | TEXT | `'auto'` | How the concept was added: `'auto'` (auto-explain detections), `'manual'` (user typed it in the Knowledge Profile editor), `'search'` (user searched the term). |

### 2.3 Status Definitions

| Status | Meaning | Auto Explain Action (Phase 2) |
|--------|---------|-------------------------------|
| `'known'` | Student previously saved this concept to Notes, or marked it as known in the Knowledge Profile editor. | **Skip** — do not show in Auto tab. |
| `'looked_up'` | Student has searched this concept at least once. Auto Explain has also shown it. | **Quick reminder** — single-line: "You've seen this before" + link to previous explanation if saved. |
| `'dismissed'` | Student dismissed an Auto Explain card for this concept during this session. | **Skip for this lecture session** — show again next time the app launches or a new lecture starts. |
| `'preventive'` | Student has searched the same term ≥ 2 times. | **Preventive** — next time the professor mentions this concept in a sealed block, Auto Explain fires automatically before the student needs to search again. |
| `'never_seen'` | Concept has never appeared in any student interaction. (This is the default — no row exists until first interaction.) | **Full explanation** — definition + analogy streamed to Auto tab. |

### 2.4 Migration

Add the table creation DDL to `DatabaseService.init()` alongside the existing `CREATE TABLE` statements. The `CREATE TABLE IF NOT EXISTS` guard makes this safe for existing databases.

---

## 3. MemoryService.swift — New File

### 3.1 File Location

`/Grasp/Services/MemoryService.swift`

### 3.2 Design Decisions

- **Standalone class** (not a protocol/interface) — simplicity over abstraction. No DI framework.
- **Wraps DatabaseService** — uses `db.query()`, `db.run()`, `db.row()`, `db.now()` for SQL access.
- **Thread-safe via `@unchecked Sendable`** — all DB access goes through DatabaseService's serialized SQLite3 calls.
- **Singleton** via `static let shared` — same pattern as `DatabaseService.shared` and `DeepSeekService.shared`.
- **No async/await** — all methods are synchronous. DB queries are fast local calls; callers are already on `@MainActor` (AppViewModel).

### 3.3 Public API

```swift
enum KnowledgeStatus: String {
    case neverSeen  = "never_seen"
    case known      = "known"
    case lookedUp   = "looked_up"
    case dismissed  = "dismissed"
    case preventive = "preventive"
}

final class MemoryService {
    static let shared = MemoryService()
    private let db = DatabaseService.shared
    private init() {}
}
```

#### `func checkConcept(_ term: String) -> KnowledgeStatus`

Looks up `term.lowercased()` in the `student_knowledge` table.

- If no row exists → return `.neverSeen`
- If row exists → return `KnowledgeStatus(rawValue: row.status) ?? .neverSeen`

Used by Auto Explain (Phase 2) to decide whether to show, skip, or collapse an explanation.

#### `func recordInteraction(concept: String, action: KnowledgeAction)`

The core write method. `KnowledgeAction` is an enum that encodes the type of interaction:

```swift
enum KnowledgeAction {
    case save            // student saved to Notes / marked as known
    case search          // student searched the term
    case dismiss         // student dismissed an auto-explain card
    case autoExplain     // auto-explain showed a card (not student-initiated)
    case markKnown       // manual "I know this" from editor
    case clearHistory    // delete all rows
}
```

Logic:

```
let key = concept.lowercased().trimmingCharacters(in: .whitespaces)
guard !key.isEmpty else { return }

let existing = row("SELECT * FROM student_knowledge WHERE concept=?", [key])
let now = db.now()

switch action {
case .save, .markKnown:
    // Upsert: set status='known', update last_interacted_at
    // If first_seen_at is NULL, set it to now
    // Keep existing search_count, source unchanged (source only set on insert)

case .search:
    // Upsert: increment search_count, set status:
    //   if current status is 'never_seen' or 'dismissed' → 'looked_up'
    //   if search_count+1 >= 2 → 'preventive'
    //   else keep existing status
    // Set last_interacted_at = now, first_seen_at if NULL
    // Set source = 'search' only on insert (first time)

case .dismiss:
    // Upsert: set status='dismissed', update last_interacted_at
    // Do NOT reset search_count

case .autoExplain:
    // Upsert: only if status is 'never_seen' (first detection)
    //   → set status='looked_up', first_seen_at, last_interacted_at
    // If already has a status, do nothing (don't overwrite known/looked_up/dismissed)

case .clearHistory:
    // DELETE FROM student_knowledge
}
```

Implementation notes:
- Use `INSERT OR REPLACE` with careful column selection, or separate `SELECT` + `UPDATE` / `INSERT` logic. Prefer the explicit read-then-write approach for clarity.
- `source` is set **only on INSERT** (first time a concept is recorded). Subsequent updates never change `source`.

#### `func getKnownTerms() -> Set<String>`

Returns the set of concepts where `status = 'known'`.

```sql
SELECT concept FROM student_knowledge WHERE status = 'known'
```

Used by:
- **Auto Explain:** pass as `knownTerms` to `DeepSeekService.detectUnfamiliarTerm(text:subject:knownTerms:)` so DeepSeek skips terms the student already knows.
- **Search (Phase 2):** inject into the DeepSeek Search prompt so the model knows what the student already understands.

#### `func getAllRecords() -> [KnowledgeRecord]`

Returns all rows for the Settings editor view.

```swift
struct KnowledgeRecord: Identifiable {
    var id: String { concept }
    let concept: String
    let status: KnowledgeStatus
    let searchCount: Int
    let firstSeenAt: Int64?
    let lastInteractedAt: Int64?
    let source: String
}
```

#### `func deleteRecord(concept: String)`

Deletes a single concept row from the table.

#### `func addManualConcept(_ concept: String)`

Validates non-empty, lowercases, trims. Calls `recordInteraction(concept:action: .markKnown)`.

### 3.4 SQL Queries (Reference)

**Check concept:**
```sql
SELECT status, search_count FROM student_knowledge WHERE concept = ?
```

**Upsert (generic):**
```sql
INSERT INTO student_knowledge(concept, status, search_count, first_seen_at, last_interacted_at, source)
VALUES (?, ?, ?, ?, ?, ?)
ON CONFLICT(concept) DO UPDATE SET
    status            = COALESCE(NULLIF(excluded.status, ''), student_knowledge.status),
    search_count      = excluded.search_count,
    last_interacted_at = excluded.last_interacted_at,
    first_seen_at     = COALESCE(student_knowledge.first_seen_at, excluded.first_seen_at)
```

(The engineer may choose a read-then-write approach instead of this ON CONFLICT formulation — either is acceptable as long as the logic in §3.3 is preserved.)

---

## 4. Settings Page — Knowledge Profile Editor

### 4.1 Placement

Add a "Knowledge Profile" row in `SettingsView.swift`, positioned after the Display section (after line 20, before the `Spacer()`).

### 4.2 Settings View Change

```swift
// Inside SettingsView body, after the Display VStack and before Spacer():
NavigationLink(destination: KnowledgeProfileView()) {
    HStack {
        Text("Knowledge Profile").font(.inter(size: 13)).foregroundColor(Color(hex: "0A0A0A"))
        Spacer()
        Text("\(knownCount) known").font(.inter(size: 11)).foregroundColor(Color(hex: "C0C0C0"))
    }
}
```

`knownCount` is loaded on appear: `MemoryService.shared.getKnownTerms().count`.

### 4.3 `KnowledgeProfileView.swift` — New File

File: `/Grasp/Views/Pages/KnowledgeProfileView.swift`

#### Layout (Bottom-to-Top)

```
┌──────────────────────────────────┐
│  Knowledge Profile       ← Back  │  <- Nav title
├──────────────────────────────────┤
│                                  │
│  [Add a concept...]     [+ Add]  │  <- TextField + button
│                                  │
│  ── Known (3) ──                 │  <- Section header with count
│  ？ WACC                    ✓   │  <- Row: concept, status badge, delete
│  ？ Photosynthesis           ✓   │     Badge: coloured pill (green=known,
│  ？ Covariance Matrix        ✓   │            blue=looked_up, grey=dismissed,
├──────────────────────────────────┤            orange=preventive)
│  ── Looked Up (2) ──            │
│  ✓ NPV                     ◷   │  <- ◷ = searched count badge
│  ✓ IRR                     ◷   │
├──────────────────────────────────┤
│  ── Dismissed (1) ──            │
│  ✕ CAP Theorem             ☐   │
├──────────────────────────────────┤
│  [ Clear All History ]          │  <- Destructive button at bottom
│                                  │
└──────────────────────────────────┘
```

#### Sections

The editor shows all records grouped by status in sections:

1. **Known** — `status = 'known'`
2. **Looked Up** — `status = 'looked_up'`
3. **Dismissed** — `status = 'dismissed'`
4. **Preventive** — `status = 'preventive'`

Each row shows:
- Concept name (displayed with original casing — store lowercased, display as stored or capitalize first letter)
- Status badge (coloured pill, ~20×16pt rounded rect with text)
- For looked_up/preventive: search count badge (`×2`, `×3`, etc.)
- Delete button (trash icon or "×") — calls `MemoryService.shared.deleteRecord(concept:)`

#### Add Concept

- Text field placeholder: "Type a concept you know…"
- "+ Add" button: validates non-empty → `MemoryService.shared.addManualConcept(...)` → refresh list
- Press Enter in text field triggers add
- Show inline validation (shorter than 2 chars → "Enter a concept name")

#### Clear All History

- Destructive button at bottom of last section
- Tapping triggers a confirmation alert: "Clear all knowledge history? This removes all concepts you've searched, saved, or dismissed."
- Confirmed → `MemoryService.shared.recordInteraction(concept: "", action: .clearHistory)` → refresh

### 4.4 `KnowledgeRecordRow.swift` — Optional Extraction

If the row styling is complex enough, extract a small subview `KnowledgeRecordRow`. Otherwise keep it inline.

### 4.5 Data Loading

On appear and after every mutation (add/delete/clear):
```swift
records = MemoryService.shared.getAllRecords()
knownCount = MemoryService.shared.getKnownTerms().count
```

---

## 5. Dependencies & Zero-Impact Guarantees

### 5.1 What Changes

| File | Change |
|------|--------|
| `Grasp/Services/DatabaseService.swift` | +1 `CREATE TABLE IF NOT EXISTS` line in `init()` |
| `Grasp/Services/MemoryService.swift` | **New file** (entire MemoryService) |
| `Grasp/Views/Pages/SettingsView.swift` | +1 NavigationLink row |
| `Grasp/Views/Pages/KnowledgeProfileView.swift` | **New file** (entire editor view) |

### 5.2 What Does NOT Change

- **No changes to** `DeepSeekService.swift`, `AppViewModel.swift`, `AutoExplainCardView.swift`, `SearchCardView.swift`, `SaveCardView.swift`, `BottomPanelView.swift`, or any other existing file beyond the four listed above.
- **No new dependencies** — MemoryService depends only on `DatabaseService` (already imported by all callers).
- **No new settings keys in the `settings` table** — all Knowledge Profile data lives in `student_knowledge`.
- **No new enums in Models.swift** — `KnowledgeStatus` and `KnowledgeAction` live inside MemoryService.swift.

### 5.3 No Wiring to Other Services (Phase 2)

Phase 1 delivers the table, the service, and the Settings editor. The wiring to Auto Explain and Search is explicitly deferred to Phase 2. This means:

- `detectUnfamiliarTerm` in DeepSeekService **still receives an empty `knownTerms` set**.
- `autoExplain()` in AppViewModel **does not call MemoryService**.
- `triggerSearch()` in AppViewModel **does not call MemoryService**.
- `handleSaveAction()` / `confirmSave()` **do not call MemoryService**.
- `dismissAutoExplain()` **does not call MemoryService**.

Phase 2 will add those calls. This spec only covers Phase 1.

---

## 6. Acceptance Criteria

### 6.1 SQLite Table

- [ ] `student_knowledge` table is created when the app launches (verify with `sqlite3 grasp.db ".schema student_knowledge"`)
- [ ] Table columns match §2.2 exactly
- [ ] Existing databases upgrade without data loss (the `IF NOT EXISTS` guard)

### 6.2 MemoryService

- [ ] `checkConcept("wacc")` on a fresh DB returns `.neverSeen`
- [ ] `recordInteraction(concept: "WACC", action: .save)` creates a row with `status='known'`
- [ ] `recordInteraction(concept: "NPV", action: .search)` creates a row with `status='looked_up'`, `search_count=1`
- [ ] `recordInteraction(concept: "NPV", action: .search)` again increments `search_count` to 2 and sets `status='preventive'`
- [ ] `recordInteraction(concept: "WACC", action: .dismiss)` sets `status='dismissed'`
- [ ] `recordInteraction(concept: "WACC", action: .save)` sets `status='known'` (wins over dismissed)
- [ ] `getKnownTerms()` returns `["wacc"]` after two steps above
- [ ] `addManualConcept("CAP Theorem")` creates a row with `source='manual'`
- [ ] `addManualConcept("")` is a no-op
- [ ] `deleteRecord(concept: "wacc")` removes the row
- [ ] `recordInteraction(concept: "", action: .clearHistory)` deletes all rows
- [ ] `getAllRecords()` returns correct array of `KnowledgeRecord` values

### 6.3 Settings UI

- [ ] Settings view shows "Knowledge Profile" row with known count
- [ ] Tapping the row navigates to `KnowledgeProfileView`
- [ ] All records grouped by status in correct sections
- [ ] Add concept text field + button works, validates empty input
- [ ] Delete button on each row removes the concept
- [ ] "Clear All History" shows confirmation alert and clears on confirm
- [ ] All edits persist across app restarts (verify by killing and relaunching)

### 6.4 No Regression

- [ ] Existing Settings rows (Default Mode, Display) still work
- [ ] Existing lecture/block/save/search/note operations unchanged
- [ ] Auto Explain, Search, Save, Dismiss all behave identically to current app

---

## 7. File Tree (Post-Implementation)

```
Grasp/
├── Services/
│   ├── DatabaseService.swift      ← +1 CREATE TABLE line
│   ├── MemoryService.swift        ← NEW
│   ├── DeepSeekService.swift      ← unchanged
│   ├── DeepgramService.swift      ← unchanged
│   ├── AudioService.swift         ← unchanged
│   └── QwenTranslationService.swift ← unchanged
├── Views/
│   └── Pages/
│       ├── SettingsView.swift     ← +1 NavigationLink row
│       ├── KnowledgeProfileView.swift ← NEW
│       ├── HomeView.swift         ← unchanged
│       ├── SavedItemsView.swift   ← unchanged
│       └── SearchHistoryView.swift ← unchanged
└── Models/
    └── Models.swift               ← unchanged
```

---

## 8. Future Work (Phase 2, Not in This Spec)

| Feature | When |
|---------|------|
| Auto Explain: check `MemoryService.shared.checkConcept()` before showing card | Next sprint |
| Search: inject `getKnownTerms()` into DeepSeek system prompt | Next sprint |
| Save (K): `MemoryService.shared.recordInteraction(concept: .save)` after `confirmSave()` where `type == "knowledge"` | Next sprint |
| Dismiss: `MemoryService.shared.recordInteraction(concept: .dismiss)` in `dismissAutoExplain()` | Next sprint |
| Preventive mode: detect `search_count >= 2` and fire Auto Explain preemptively | Next sprint |
| Knowledge Profile: show recent looked-up/dismissed concepts in a compact "Recently searched" section | TBD |
