# Concept Map — Feature Spec v1.1

> **Feature:** 15s rolling window Concept Map replacing per-seal flat note generation
> **Target release:** v1.1
> **Status:** Spec draft
> **Author:** PM (cos agent)
> **Dependencies:** PDF slide parsing ✅ (spec-pdf-slides.md), DeepSeekService ✅, DatabaseService ✅, NotesPanelView ✅

---

## 1. Problem Statement

### Current behavior (v1.0)

Every time a transcript block is sealed (`seal()` fires), `AppViewModel` debounces 500ms then calls `DeepSeekService.generateNoteEntry()`. That method:

1. Collects the last **3 sealed blocks** + last **3 notes**
2. Sends them to DeepSeek with a prompt that extracts "the ONE most important new fact"
3. DeepSeek returns a **single flat JSON entry** (`{slideIndex, content, level}`)
4. The entry is saved to `note_blocks` table and appended to `vm.noteBlocks`

**Result:** A flat list of ~25-word entries with level 0/1/2 indentation. No structural relationships between concepts. Each note is an independent leaf — there is no parent/child tree, no grouping, and no way to understand how concepts relate to each other.

### What's wrong with this

| Problem | Impact |
|---------|--------|
| **No structure** | Students see a flat list, not a hierarchical understanding. A core thesis and its supporting points are indistinguishable in the list beyond `level`. |
| **No concept relationships** | Notes like "Supply curve slopes downward" and "Demand curve slopes downward" exist as independent rows. A human learner needs to see them as children of "Supply and Demand" with "Equilibrium price" as a derived sibling. |
| **Per-seal bottleneck** | Each seal produces exactly one note or skip. Multi-block explanations (e.g., a professor building a concept across 5 sealed blocks) are fractured into independent entries or missed entirely. |
| **No state persistence** | DeepSeek receives only the last 3 blocks + 3 notes each call. It has no awareness of the overall concept map being built. It cannot "deepen" an existing concept — only add new leaves. |
| **Duplicate information** | The same concept referenced across multiple sealed blocks can generate duplicate notes. The model has no memory of what it's already said. |

### Why a 15s rolling window fixes this

- **Windowed batches** capture multi-block concept development as a single coherent unit
- **Full Concept Map context** passed each cycle lets DeepSeek make intelligent decisions: add a new concept, deepen an existing one, or skip filler
- **Hierarchical structure** with parent/child relationships lets students understand how ideas connect
- **Single source of truth** — the Concept Map IS the note, not a parallel system

---

## 2. Data Model

### New model: `ConceptNode`

Add to `/Users/catherineuspan/grasp/Grasp/Models/Models.swift`:

```swift
struct ConceptNode: Identifiable, Codable {
    var id: String
    var concept: String                  // short concept name
    var parentId: String?                // nil = root-level concept
    var level: Int                       // 0 = core thesis, 1 = key point, 2 = detail
    var content: String                  // the explanation/definition (≤ 60 words)
    var slideIndex: Int                  // which slide this belongs to
    var lectureId: String                // which lecture
    var createdAt: Int64                 // epoch ms
    var updatedAt: Int64                 // epoch ms — updated when deepened
    var children: [ConceptNode]?         // sub-concepts (populated at render time, not stored)
}
```

### Additional state in `AppViewModel`

```swift
// Replace the flat noteBlocks pattern in the live lecture context.
// noteBlocks is KEPT for past lecture backward compatibility (see §8 Migration).
// The timer will manage conceptMap separately.

@Published var conceptMap: [ConceptNode] = []     // flat array for storage/DB
@Published var conceptMapRoots: [ConceptNode] = [] // computed: top-level nodes with children populated
```

### New DB table

Add to `DatabaseService.init()` schema:

```sql
CREATE TABLE IF NOT EXISTS concept_map(
    id TEXT PRIMARY KEY,
    lecture_id TEXT NOT NULL,
    concept TEXT NOT NULL,
    parent_id TEXT,
    level INTEGER DEFAULT 0,
    content TEXT DEFAULT '',
    slide_index INTEGER DEFAULT 0,
    created_at INTEGER,
    updated_at INTEGER,
    FOREIGN KEY (lecture_id) REFERENCES lectures(id)
);
CREATE INDEX IF NOT EXISTS idx_concept_map_lecture ON concept_map(lecture_id);
```

### New DB methods in `DatabaseService`

```swift
func saveConceptMap(lectureId: String, nodes: [ConceptNode])
    // DELETE all existing nodes for this lecture_id, then INSERT all nodes.
    // Transaction-wrapped: ensures atomic replacement on each 15s update.

func loadConceptMap(lectureId: String) -> [ConceptNode]
    // SELECT * FROM concept_map WHERE lecture_id=? ORDER BY slide_index ASC, level ASC

func deleteConceptMap(lectureId: String)
    // DELETE FROM concept_map WHERE lecture_id=?
```

**Why DELETE + INSERT instead of UPSERT per node?** Because DeepSeek returns a full updated Concept Map each cycle, not individual node diffs. The map can reorganize — nodes can be reparented, removed, or merged. A full replace is simpler and safer. The 15s cadence means at most 4 writes per minute per lecture — trivial load.

---

## 3. Timer Logic

### Architecture: Timer alongside existing `seal()`

**Critical design rule:** `seal()` keeps ALL its current behavior **except** triggering `generateNoteEntry()`. The 15s timer is a new, independent subsystem.

### What `seal()` continues to do

| Behavior | Keep? |
|----------|-------|
| Save block to DB (`db.saveBlock`) | ✅ Yes |
| Mark `liveBlocks[i].isSealed = true` | ✅ Yes |
| Trigger translation (international mode) | ✅ Yes |
| Trigger auto-explain (`autoExplain()`) | ✅ Yes |
| Detect cold call (`detectCC()`) | ✅ Yes |
| Cancel + fire `generateNoteEntry()` | ❌ **Remove** — debounce block and the `noteTask` assignment |

### What replaces it

A **15-second repeating timer** that:

1. Collects ALL sealed blocks that arrived in the last 15-second window
2. Retrieves the existing Concept Map from DB
3. Retrieves slide structure from `vm.slideStructure`
4. Calls DeepSeek with the window text + existing map + slides
5. DeepSeek returns a full updated Concept Map
6. Saves the result to DB (DELETE + INSERT)
7. Updates `vm.conceptMap` and `vm.conceptMapRoots` (triggers UI refresh)

### Timer lifecycle

```
startLecture()
    ├── 15 ⏲️ ← timer starts when lecture recording starts
    │
    ├── 15s fire #1 → collect blocks, call DeepSeek, update map
    ├── 15s fire #2 → collect new blocks since last fire, etc.
    ├── ...
    │
    ├── stopLecture()
    │     ├── Seal final block (existing behavior)
    │     └── Cancel timer → fire one FINAL update with remaining blocks
    │
    └── Timer never fires again for this lecture
```

### Timer state variables in `AppViewModel`

```swift
private var conceptMapTimer: Timer?
private var lastConceptMapFire: Date = .distantPast
```

### `startLecture()` additions

```swift
// After existing setup, start the 15s timer:
startConceptMapTimer()

private func startConceptMapTimer() {
    conceptMapTimer?.invalidate()
    lastConceptMapFire = Date()
    conceptMapTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
        Task { [weak self] in await self?.fireConceptMapUpdate() }
    }
}
```

### `stopLecture()` additions

```swift
func stopLecture() async {
    // Existing: seal final block, stop recording, etc.
    // NEW: fire one last concept map update with remaining blocks
    await fireConceptMapUpdate()
    conceptMapTimer?.invalidate()
    conceptMapTimer = nil
    // ... existing cleanup
}
```

### `fireConceptMapUpdate()` logic

```swift
@MainActor
private func fireConceptMapUpdate() async {
    guard let lid = activeLectureId else { return }

    // 1. Collect sealed blocks since last fire
    let since = lastConceptMapFire
    lastConceptMapFire = Date()
    
    // Get all blocks sealed in this window
    let windowBlocks = db.getRecentBlocks(lectureId: lid, since: since)
    
    // 2. Skip if no new content
    guard !windowBlocks.isEmpty else { return }
    
    // 3. Get existing Concept Map
    let existingMap = db.loadConceptMap(lectureId: lid)
    
    // 4. Get slide structure
    let slides = slideStructure
    
    // 5. Call DeepSeek
    let windowText = windowBlocks.map { $0.textEn }.joined(separator: "\n\n")
    guard let updatedNodes = await ds.generateConceptMapUpdate(
        windowText: windowText,
        existingMap: existingMap,
        slides: slides,
        subject: activeLectureSubject
    ) else { return }
    
    // 6. Save to DB
    db.saveConceptMap(lectureId: lid, nodes: updatedNodes)
    
    // 7. Update in-memory state
    conceptMap = updatedNodes
    conceptMapRoots = buildConceptTree(from: updatedNodes)
}
```

### New DB helper: `getRecentBlocks(since:)`

```swift
func getRecentBlocks(lectureId: String, since: Date) -> [Block] {
    let ms = Int64(since.timeIntervalSince1970 * 1000)
    return query("""
        SELECT * FROM blocks 
        WHERE lecture_id=? AND created_at>? AND is_final=1 
        ORDER BY block_index ASC
    """, [lectureId, ms]).map { /* map to Block */ }
}
```

---

## 4. Prompt Design

### New method on `DeepSeekService`

```swift
func generateConceptMapUpdate(
    windowText: String,
    existingMap: [ConceptNode],
    slides: [SlideItem],
    subject: String
) async -> [ConceptNode]?
```

### System prompt

```
You are building a structured concept map from a live university lecture.
You receive new transcript text every 15 seconds.

Your job: update the existing Concept Map by adding new concepts,
deepening existing ones, or skipping transitional/filler content.

RULES:
1. Return the COMPLETE updated Concept Map (existing nodes + new nodes), not a diff.
2. Assign each concept a unique ID (UUID format). KEEP existing node IDs unchanged.
3. parentId of nil means root-level. Use existing node IDs as parentId values.
4. level 0 = core thesis of the lecture (at most 2-3 total)
   level 1 = key supporting point (default)
   level 2 = specific detail, example, or sub-point
5. content should be 10-60 words — a clear explanation, not just a label.
6. slideIndex: which slide number this concept belongs to (0-based). Use -1 if no slide.
7. For transitional content ("let's move on", "as I said before", "next slide"), 
   do NOT add new nodes — but DO update any existing nodes if relevant.
8. If the new transcript deepens an existing concept, update that node's content
   (keep the same id) rather than creating a duplicate.
9. If multiple nodes would have the same concept name, merge them into one node.
10. Maintain a clean hierarchy: root concepts are broad topics, children are 
    specific points that support the parent.
```

### User prompt

```
Subject: {subject}

== SLIDE STRUCTURE ==
{slides.map { "Slide \($0.index): \($0.title)" }.joined("\n")}

== EXISTING CONCEPT MAP ==
{JSON representation of existingMap}

== NEW TRANSCRIPT (last 15 seconds) ==
{windowText}

Output ONLY valid JSON — a single object with these fields:
{
  "nodes": [
    {
      "id": "<existing or new UUID>",
      "concept": "<short concept name, 1-5 words>",
      "parentId": "<existing node id or null>",
      "level": <0|1|2>,
      "content": "<explanation, 10-60 words>",
      "slideIndex": <int>
    }
  ]
}

No markdown fences, no explanation, no other text. Return the COMPLETE updated map.
```

### Prompt design rationale

| Design choice | Why |
|---------------|-----|
| **Return full map, not a diff** | Simplifies server-side logic. No merge conflicts. Atomic replacement in DB. |
| **Keep existing IDs** | Prevents orphaned parentId references. UI doesn't need to rebuild tree on every update — only recalculate `conceptMapRoots`. |
| **`slideIndex: -1` allowed** | Some concepts (e.g., "course overview") may span slides or come from professor digressions. |
| **Deepen vs add vs skip** | The model decides per concept. This enables intelligent map evolution rather than linear growth. |
| **10-60 word content** | Longer than current 25-word limit because concepts need explanation, not just a label. Current per-seal notes were constrained by frequency (one per seal). With a 15s window, each entry can be more substantive. |

### Backend parsing

```swift
guard let raw = try? await call(system: system, prompt: prompt, maxTokens: 1500),
      let data = raw.trimmingCharacters(in: .whitespaces).data(using: .utf8),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let nodesArray = json["nodes"] as? [[String: Any]]
else { return nil }

let decoder = JSONDecoder()
// ... parse each node, validate fields, fall back to existingMap on parse failure
```

---

## 5. UI Changes

### NotesPanelView: From flat list to tree render

**Current (v1.0):** Renders `ForEach(vm.noteBlocks)` or grouped by `slideSection(_:)` with flat notes.

**New (v1.1):** Render the Concept Map as an indented outline.

```swift
struct NotesPanelView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            
            if vm.conceptMapRoots.isEmpty && vm.slideStructure.isEmpty {
                // Case 1: No slides, no concepts yet
                Text("AI notes will appear here…")
                    .font(.inter(size: 12)).foregroundColor(Color(hex: "C0C0C0"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity).padding(.top, 20)
            } else if vm.conceptMapRoots.isEmpty {
                // Case 2: Slides loaded, but lecture hasn't produced concepts yet
                slideSkeleton  // Show slide headers with "Waiting for lecture…"
            } else {
                // Case 3: Concept Map available
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if vm.slideStructure.isEmpty {
                            // No slide grouping — flat tree
                            ForEach(vm.conceptMapRoots) { node in
                                conceptNodeView(node, depth: 0)
                            }
                        } else {
                            // Grouped by slide
                            ForEach(vm.slideStructure, id: \.index) { slide in
                                conceptSlideSection(slide)
                            }
                        }
                        Color.clear.frame(height: 80)
                    }
                }
            }
        }
        // ...
    }
}
```

### Tree node renderer

```swift
@ViewBuilder
func conceptNodeView(_ node: ConceptNode, depth: Int) -> some View {
    VStack(alignment: .leading, spacing: 0) {
        ConceptNodeRow(node: node, depth: depth)
        
        // Recursively render children
        if let children = node.children, !children.isEmpty {
            ForEach(children) { child in
                conceptNodeView(child, depth: depth + 1)
            }
        }
    }
}
```

### ConceptNodeRow

```swift
struct ConceptNodeRow: View {
    let node: ConceptNode
    let depth: Int
    
    var bullet: String {
        switch node.level {
        case 0: return "▸"
        case 1: return "•"
        case 2: return "◦"
        default: return "•"
        }
    }
    
    var bulletColor: Color {
        switch node.level {
        case 0: return Color(hex: "1A5FD4")        // blue for core theses
        case 1: return Color(hex: "9A9A9A")        // gray for key points
        case 2: return Color(hex: "CCCCCC")        // light gray for details
        default: return Color(hex: "CCCCCC")
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            // Depth indent
            Spacer().frame(width: CGFloat(depth) * 18)
            
            // Bullet
            Text(bullet)
                .font(.inter(size: depth == 0 ? 11 : 13))
                .foregroundColor(bulletColor)
                .frame(width: 14)
                .padding(.top, 3)
            
            // Content
            VStack(alignment: .leading, spacing: 1) {
                Text(node.concept)
                    .font(.inter(size: 13, weight: depth <= 1 ? .semibold : .regular))
                    .foregroundColor(Color(hex: "0A0A0A"))
                
                Text(node.content)
                    .font(.inter(size: 11))
                    .foregroundColor(Color(hex: "7A7A7A"))
                    .lineLimit(3)
            }
            .padding(.vertical, 3)
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
    }
}
```

### Slide-grouped view

```swift
func conceptSlideSection(_ slide: SlideItem) -> some View {
    let slideNodes = vm.conceptMapRoots
        .filter { $0.slideIndex == slide.index }
        .flatMap { flattenNode($0) }
    
    return VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 6) {
            Text(slide.title.uppercased())
                .font(.inter(size: 10, weight: .semibold))
                .foregroundColor(Color(hex: "C0C0C0"))
                .tracking(0.3)
            Spacer()
        }
        .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 4)
        
        if slideNodes.isEmpty {
            Text("Waiting for lecture…")
                .font(.inter(size: 12)).foregroundColor(Color(hex: "E0E0E0"))
                .padding(.horizontal, 18).padding(.vertical, 4)
        } else {
            ForEach(slideNodes.filter { $0.parentId == nil }) { root in
                conceptNodeView(root, depth: 0)
            }
        }
    }
}

/// Flatten a tree of ConceptNodes into a single array (for filtering by slideIndex)
func flattenNode(_ node: ConceptNode) -> [ConceptNode] {
    var result = [node]
    if let children = node.children {
        for child in children {
            result.append(contentsOf: flattenNode(child))
        }
    }
    return result
}
```

### Display states

| State | What user sees | Condition |
|-------|----------------|-----------|
| No slides, no lecture started | `"AI notes will appear here…"` | `conceptMapRoots.isEmpty && slideStructure.isEmpty` |
| Slides loaded, lecture running but no concepts yet | Slide headers with `"Waiting for lecture…"` under each | `conceptMapRoots.isEmpty && !slideStructure.isEmpty` |
| First 15s fire complete | Some slide headers now have indented concept trees | `!conceptMapRoots.isEmpty` |
| Lecture ended | Final Concept Map visible, fully populated | Same as above, no timer |
| Past lecture (no concept map) | Flat note list (see §8 Migration) | Loads `noteBlocks` instead of `conceptMap` |

### Note: Editable notes

The v1.0 had editable notes (inline editing, add, delete, indent). In v1.1, **the Concept Map is AI-generated and not directly editable in the tree.** Users can still:

- **Copy** content to clipboard (right-click → Copy)
- **Save** individual concepts as Knowledge/Language card (right-click → Save)
- **Add free-form notes** via the "+" button (these appear as a separate section below the Concept Map, or appended to the bottom of each slide section as `NoteBlock` rows)

This keeps the Concept Map authoritative as AI output while preserving user agency.

---

## 6. Tree Rendering: `buildConceptTree()`

```swift
func buildConceptTree(from nodes: [ConceptNode]) -> [ConceptNode] {
    let nodeMap = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
    var roots = [ConceptNode]()
    
    for node in nodes {
        var mutableNode = node
        // Populate children from flat array
        let children = nodes.filter { $0.parentId == node.id }
        mutableNode.children = children.isEmpty ? nil : children
        
        if node.parentId == nil || nodeMap[node.parentId!] == nil {
            roots.append(mutableNode)
        }
    }
    
    return roots.sorted { $0.slideIndex < $1.slideIndex || ($0.slideIndex == $1.slideIndex && $0.level < $1.level) }
}
```

Called whenever `conceptMap` is updated:

```swift
// After db.saveConceptMap(...)
conceptMap = updatedNodes
conceptMapRoots = buildConceptTree(from: updatedNodes)
```

---

## 7. Acceptance Criteria

### 7.1 Timer behavior

| # | Criterion | How to verify |
|---|-----------|---------------|
| 1 | Timer starts when `startLecture()` is called and recording begins | Check `conceptMapTimer` is non-nil and `lastConceptMapFire` is set |
| 2 | Timer fires every 15 seconds (±1s) during recording | Log `fireConceptMapUpdate` calls — should show ~4 calls per minute |
| 3 | Timer does NOT fire when `isPaused == true` | Pause → wait 20s → no calls to `fireConceptMapUpdate` |
| 4 | Timer fires one final update on `stopLecture()` | Stop → one more call with remaining blocks |
| 5 | Timer is invalidated on `stopLecture()` | `conceptMapTimer` is nil after stop |

### 7.2 Concept Map generation

| # | Criterion | How to verify |
|---|-----------|---------------|
| 6 | Empty window (no new blocks since last fire) → no API call | `getRecentBlocks` returns empty → guard returns early |
| 7 | First 15s → DeepSeek returns ≥1 concept node | First fire produces valid JSON with `nodes` array |
| 8 | Subsequent 15s → DeepSeek returns existing nodes + new nodes | `existingMap` parameter contains previous nodes; response includes their IDs unchanged |
| 9 | Transitional content → no new nodes added, existing nodes preserved | Fire with filler text → response contains same node IDs as `existingMap` |
| 10 | DeepSeek deepens existing concept → content updated, ID unchanged | Fire with content about previously noted concept → same `id`, different `content` |
| 11 | DeepSeek returns malformed JSON → fallback: keep existing map | Return nil → `conceptMap` and DB unchanged |
| 12 | DeepSeek network failure → keep existing map, retry next cycle | Network error → return nil → no data loss |
| 13 | Map never exceeds reasonable node count | With a 60-min lecture → ~240 fires max → ~50-200 nodes total |

### 7.3 UI rendering

| # | Criterion | How to verify |
|---|-----------|---------------|
| 14 | Slide headers group concept nodes correctly | Nodes with `slideIndex: 0` render under slide 0 header |
| 15 | Tree indentation: each child level indents 18px deeper | Depth 0 = 0px indent, depth 1 = 18px, depth 2 = 36px |
| 16 | Core thesis (level 0) renders with blue bullet, semibold text | Visual check |
| 17 | Detail (level 2) renders with light gray bullet, regular text | Visual check |
| 18 | Empty state shows "AI notes will appear here…" | Before first 15s fire with no slides |
| 19 | Slides loaded but no concepts → "Waiting for lecture…" per slide | After slides loaded, before first 15s fire |
| 20 | Nodes update in-place without animation disruption | After timing fire, UI updates smoothly |
| 21 | "+" button on slide headers creates user notes below concept tree | User note appears outside the Concept Map tree |

### 7.4 seal() unchanged behavior

| # | Criterion | How to verify |
|---|-----------|---------------|
| 22 | `seal()` still saves blocks to DB | Block appears in `blocks` table after seal |
| 23 | `seal()` still triggers translation (international mode) | `text_zh` populated in DB |
| 24 | `seal()` still triggers auto-explain | `autoExplainResult` appears in Auto tab |
| 25 | `seal()` still detects cold calls | `coldCallPhase` transitions to `.detected` |
| 26 | `seal()` no longer triggers `generateNoteEntry()` | No calls to `saveNoteBlock` from `seal()` path |
| 27 | `noteTask` cancellation and assignment removed from `seal()` | Code review confirms removal |

---

## 8. Migration Plan: How Existing Lectures Still Render

### The constraint

After v1.1 is deployed, old lectures (recorded with v1.0) have `note_blocks` entries but NO `concept_map` entries. We cannot regenerate the Concept Map for old lectures (too expensive, and the original transcript context is no longer available in the same temporal window).

### Strategy: Dual render path

```swift
// In NotesPanelView

var body: some View {
    VStack(spacing: 0) {
        header
        if vm.isPastLecture {
            // Old lecture → render flat note blocks (v1.0 style)
            legacyNotesView
        } else if liveLectureView {
            // Live lecture → render Concept Map (v1.1 style)
            conceptMapView
        }
    }
}
```

### How to detect past vs live

In `AppViewModel`:

```swift
var isPastLecture: Bool {
    // Past lectures have no concept map but may have noteBlocks
    // Live lectures have concept map (even if empty)
    conceptMap.isEmpty && !noteBlocks.isEmpty && activeTabId?.hasPrefix("past-") == true
}

var liveLectureView: Bool {
    // Live lecture or recently ended lecture with concept map
    !conceptMap.isEmpty
}
```

Alternatively, simpler: **check the DB at load time**.

```swift
// In openPastLecture():
let existingConceptMap = db.loadConceptMap(lectureId: id)
if existingConceptMap.isEmpty {
    // v1.0 lecture → load flat notes
    noteBlocks = db.getNoteBlocks(lectureId: id)
    conceptMap = []
} else {
    // v1.1 lecture → load concept map
    conceptMap = existingConceptMap
    conceptMapRoots = buildConceptTree(from: existingConceptMap)
    noteBlocks = []  // still loadable on demand if user wants to see raw notes
}
```

### What users see

| Scenario | v1.0 lecture opened in v1.1 | v1.1 lecture opened in v1.1 |
|----------|-----------------------------|-----------------------------|
| Notes panel | Flat list with level indentation (identical to v1.0) | Concept Map tree with slide grouping |
| Editability | Fully editable (v1.0 behavior) | Concept Map read-only, "+" for user notes |
| Search/Cold call context | Uses `noteBlocks` | Uses `conceptMap` (flat array) |
| Export | `.docx` includes flat notes | `.docx` includes Concept Map as indented outline |

### Code preconditions in NotesPanelView

The existing `slideSection(_:)` and `rowFor(_:)` methods are kept for the legacy path. New methods (`conceptSlideSection`, `conceptNodeView`) are added for the v1.1 path. Both paths coexist until v2.0 when the legacy path may be removed.

---

## 9. Detailed Implementation Checklist

### Models.swift
- [ ] Add `ConceptNode` struct with all fields + Codable conformance
- [ ] Add `ConceptNode.children: [ConceptNode]?` (optional — populated at render time)

### DatabaseService.swift
- [ ] Add `concept_map` table to `init()` schema
- [ ] Add `saveConceptMap(lectureId:, nodes:)` — DELETE + INSERT in transaction
- [ ] Add `loadConceptMap(lectureId:)` → `[ConceptNode]`
- [ ] Add `deleteConceptMap(lectureId:)`
- [ ] Add `getRecentBlocks(lectureId:, since:)` for window queries

### DeepSeekService.swift
- [ ] Add `generateConceptMapUpdate(windowText:, existingMap:, slides:, subject:)` method
- [ ] Add system prompt for Concept Map generation
- [ ] Add user prompt with window text + existing map + slides
- [ ] Set `maxTokens: 1500` (larger than current 120 due to full map output)
- [ ] Implement JSON parsing with fallback to existing map on failure

### AppViewModel.swift
- [ ] Add `@Published var conceptMap: [ConceptNode] = []`
- [ ] Add `@Published var conceptMapRoots: [ConceptNode] = []`
- [ ] Add `private var conceptMapTimer: Timer?`
- [ ] Add `private var lastConceptMapFire: Date = .distantPast`
- [ ] Add `private func startConceptMapTimer()`
- [ ] Add `@MainActor private func fireConceptMapUpdate() async`
- [ ] Add `func buildConceptTree(from:) -> [ConceptNode]`
- [ ] Modify `startLecture()`: call `startConceptMapTimer()`
- [ ] Modify `stopLecture()`: fire final update, invalidate timer
- [ ] Modify `seal()`: **REMOVE** noteTask cancellation + `generateNoteEntry()` call
- [ ] Keep all other seal() behavior (DB save, translation, auto-explain, CC detection)
- [ ] Modify `openPastLecture()`: load concept map if exists, else fall back to noteBlocks
- [ ] Modify `resetLive()`: also reset `conceptMap`, `conceptMapRoots`, timer
- [ ] Add computed var `isPastLecture` or equivalent

### NotesPanelView.swift
- [ ] Add `ConceptNodeRow` struct
- [ ] Add `conceptNodeView(_:depth:)` recursive renderer
- [ ] Add `conceptSlideSection(_:)` slide-grouped renderer
- [ ] Add `flattenNode(_:)` helper
- [ ] Modify `body`: branch on concept map vs legacy notes availability
- [ ] Keep legacy `slideSection(_:)` and `rowFor(_:)` for backward compat
- [ ] Update header count: show concept count rather than note count
- [ ] Add right-click → Copy/Save context menu on node rows

### xcodegen (project.yml)
- [ ] No new files added unless a separate ConceptNodeRow.swift is preferred over inline in NotesPanelView

---

## 10. Cost Analysis

| Metric | v1.0 (per-seal) | v1.1 (15s window) |
|--------|-----------------|-------------------|
| API calls per 60-min lecture | ~60-120 (one per seal) | ~240 (4 per minute × 60) |
| Tokens per call (input) | ~300 (3 blocks + 3 notes) | ~800-1500 (window text + full map JSON + slides) |
| Tokens per call (output) | ~50 (single JSON entry) | ~200-500 (full map JSON) |
| Estimated cost per lecture | ~$0.04 | ~$0.12-0.20 |
| Monthly cost (100 lectures) | ~$4 | ~$12-20 |

**Mitigation:** The `maxTokens: 1500` is a ceiling. Actual output tokens grow as the map grows, but most calls return ~300-800 tokens. If costs are a concern, consider:
- Reducing `maxTokens` to 1000 (maps over ~150 nodes are unusual for a single lecture)
- Adding a cache check: if window text matches previous window (lecture paused), skip the call
- Firing every 20s instead of 15s (180 calls vs 240 per hour — 25% cost reduction)

---

## 11. Open Questions

| Question | Decision needed | Who decides |
|----------|----------------|-------------|
| Should user-created notes be mixed into the Concept Map tree or rendered as a separate section below? | Separate section — keeps AI output authoritative | PM + Founder |
| Should the "+" button per slide create a user note or a suggestion to the AI to add a node? | User note (separate from Concept Map) | PM + Founder |
| When a past v1.0 lecture is opened, should we attempt one-time Concept Map generation from existing blocks? | No — too expensive, blocks lack temporal window context | PM |
| Should we animate node additions/removals when the map updates? | No — SwiftUI with `LazyVStack` handles it smoothly enough without custom transitions | PM + Engineer |
| Concept Map persistence: should it export to the `.docx` export format? | Yes — as an indented outline replacing the flat notes section | PM + Founder |

---

## 12. Future Considerations (v1.2+)

- **Click a concept node → trigger Search** on hover/click for instant explanation
- **Drag and drop** to reparent nodes (manual reorg by student)
- **Concept Map export** as standalone Markdown outline
- **Cross-lecture Concept Map** — merge maps from related lectures
- **Concept highlighting** — highlight transcript words that match concept names
- **Collapsible subtrees** — fold/unfold children to manage visual density
