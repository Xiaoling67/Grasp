import Foundation
import SQLite3

final class DatabaseService {
    static let shared = DatabaseService()
    private var db: OpaquePointer?

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!.appendingPathComponent("Grasp")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("grasp.db").path
        guard sqlite3_open(path, &db) == SQLITE_OK else { fatalError("Cannot open DB") }
        exec("""
            CREATE TABLE IF NOT EXISTS lectures(id TEXT PRIMARY KEY, name TEXT, subject TEXT, mode TEXT DEFAULT 'standard', started_at INTEGER, ended_at INTEGER, duration INTEGER);
            CREATE TABLE IF NOT EXISTS blocks(id TEXT PRIMARY KEY, lecture_id TEXT, block_index INTEGER, text_en TEXT, text_zh TEXT, is_final INTEGER DEFAULT 1, started_at INTEGER, created_at INTEGER);
            CREATE TABLE IF NOT EXISTS note_blocks(id TEXT PRIMARY KEY, lecture_id TEXT, slide_index INTEGER DEFAULT 0, slide_title TEXT, content TEXT, source TEXT DEFAULT 'ai', level INTEGER DEFAULT 0, sort_order REAL DEFAULT 0, created_at INTEGER);
            CREATE TABLE IF NOT EXISTS saves(id TEXT PRIMARY KEY, lecture_id TEXT, block_id TEXT, type TEXT, original TEXT, translation TEXT, note TEXT, created_at INTEGER);
            CREATE TABLE IF NOT EXISTS searches(id TEXT PRIMARY KEY, lecture_id TEXT, block_id TEXT, query TEXT, result_pro TEXT, result_simple TEXT, note TEXT, saved INTEGER DEFAULT 0, created_at INTEGER);
            CREATE TABLE IF NOT EXISTS lecture_slides(lecture_id TEXT PRIMARY KEY, structure TEXT, created_at INTEGER);
            CREATE TABLE IF NOT EXISTS settings(key TEXT PRIMARY KEY, value TEXT);
            CREATE TABLE IF NOT EXISTS student_knowledge(concept TEXT PRIMARY KEY, status TEXT NOT NULL DEFAULT 'never_seen', search_count INTEGER DEFAULT 0, first_seen_at INTEGER, last_interacted_at INTEGER, source TEXT DEFAULT 'auto');
            CREATE TABLE IF NOT EXISTS concept_map(id TEXT PRIMARY KEY, lecture_id TEXT NOT NULL, concept TEXT NOT NULL, parent_id TEXT, level INTEGER DEFAULT 0, content TEXT DEFAULT '', slide_index INTEGER DEFAULT 0, created_at INTEGER, updated_at INTEGER, FOREIGN KEY (lecture_id) REFERENCES lectures(id));
            CREATE INDEX IF NOT EXISTS idx_concept_map_lecture ON concept_map(lecture_id);
        """)
        // PRD Section 9: implicit feedback columns (safe to run on existing DBs)
        exec("ALTER TABLE searches ADD COLUMN engaged INTEGER DEFAULT 0")
        exec("ALTER TABLE searches ADD COLUMN dismissed_at INTEGER")
    }

    deinit { if let db { sqlite3_close(db) } }

    private func exec(_ sql: String) { sqlite3_exec(db, sql, nil, nil, nil) }

    private func run(_ sql: String, _ args: [Any?] = []) {
        var s: OpaquePointer?; sqlite3_prepare_v2(db, sql, -1, &s, nil)
        bind(s, args); sqlite3_step(s); sqlite3_finalize(s)
    }

    private func query(_ sql: String, _ args: [Any?] = []) -> [[String: Any]] {
        var s: OpaquePointer?; sqlite3_prepare_v2(db, sql, -1, &s, nil)
        bind(s, args); var rows = [[String: Any]]()
        while sqlite3_step(s) == SQLITE_ROW {
            var row = [String: Any]()
            for i in 0..<sqlite3_column_count(s) {
                let n = String(cString: sqlite3_column_name(s, i))
                switch sqlite3_column_type(s, i) {
                case SQLITE_INTEGER: row[n] = sqlite3_column_int64(s, i)
                case SQLITE_TEXT:    row[n] = String(cString: sqlite3_column_text(s, i))
                default: break
                }
            }
            rows.append(row)
        }
        sqlite3_finalize(s); return rows
    }

    private func row(_ sql: String, _ args: [Any?] = []) -> [String: Any]? { query(sql, args).first }

    private func bind(_ s: OpaquePointer?, _ vals: [Any?]) {
        for (i, v) in vals.enumerated() {
            let idx = Int32(i + 1)
            switch v {
            case nil: sqlite3_bind_null(s, idx)
            case let x as Int:    sqlite3_bind_int64(s, idx, Int64(x))
            case let x as Int64:  sqlite3_bind_int64(s, idx, x)
            case let x as String: sqlite3_bind_text(s, idx, x, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            default: break
            }
        }
    }

    func now() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
    func uid() -> String { UUID().uuidString }

    // Lectures
    func startLecture(name: String?, mode: String, subject: String?) -> String {
        let id = uid()
        run("INSERT INTO lectures(id,name,subject,mode,started_at) VALUES(?,?,?,?,?)", [id, name, subject, mode, now()])
        return id
    }
    func stopLecture(id: String) {
        let n = now()
        if let r = row("SELECT started_at FROM lectures WHERE id=?", [id]), let s = r["started_at"] as? Int64 {
            run("UPDATE lectures SET ended_at=?,duration=? WHERE id=?", [n, Int((n-s)/1000), id])
        }
    }
    func updateLectureName(id: String, name: String) { run("UPDATE lectures SET name=? WHERE id=?", [name, id]) }
    func getLectures(limit: Int = 50) -> [Lecture] {
        query("SELECT l.*,COUNT(DISTINCT s.id) as sc,COUNT(DISTINCT sr.id) as src FROM lectures l LEFT JOIN saves s ON s.lecture_id=l.id LEFT JOIN searches sr ON sr.lecture_id=l.id GROUP BY l.id ORDER BY l.started_at DESC LIMIT ?", [limit]).map {
            Lecture(id: $0["id"] as? String ?? "", name: $0["name"] as? String, subject: $0["subject"] as? String,
                    mode: $0["mode"] as? String ?? "standard", startedAt: $0["started_at"] as? Int64 ?? 0,
                    endedAt: $0["ended_at"] as? Int64, duration: ($0["duration"] as? Int64).map(Int.init),
                    saveCount: ($0["sc"] as? Int64).map(Int.init), searchCount: ($0["src"] as? Int64).map(Int.init))
        }
    }
    func getLecture(id: String) -> Lecture? {
        row("SELECT * FROM lectures WHERE id=?", [id]).map {
            Lecture(id: $0["id"] as? String ?? "", name: $0["name"] as? String, subject: $0["subject"] as? String,
                    mode: $0["mode"] as? String ?? "standard", startedAt: $0["started_at"] as? Int64 ?? 0,
                    endedAt: $0["ended_at"] as? Int64, duration: ($0["duration"] as? Int64).map(Int.init))
        }
    }

    // Blocks
    func saveBlock(lectureId: String, blockIndex: Int, textEn: String, textZh: String?) -> String {
        let id = uid()
        run("INSERT INTO blocks(id,lecture_id,block_index,text_en,text_zh,is_final,started_at) VALUES(?,?,?,?,?,1,?)", [id, lectureId, blockIndex, textEn, textZh, now()])
        return id
    }
    func setBlockTranslation(lectureId: String, blockIndex: Int, textZh: String) {
        if let r = row("SELECT id FROM blocks WHERE lecture_id=? AND block_index=? ORDER BY created_at DESC LIMIT 1", [lectureId, blockIndex]),
           let rid = r["id"] as? String { run("UPDATE blocks SET text_zh=? WHERE id=?", [textZh, rid]) }
    }
    func getBlocks(lectureId: String) -> [Block] {
        query("SELECT * FROM blocks WHERE lecture_id=? ORDER BY block_index ASC", [lectureId]).map {
            Block(id: $0["id"] as? String ?? "", lectureId: $0["lecture_id"] as? String ?? "",
                  blockIndex: ($0["block_index"] as? Int64).map(Int.init) ?? 0, textEn: $0["text_en"] as? String ?? "",
                  textZh: $0["text_zh"] as? String, isFinal: ($0["is_final"] as? Int64).map(Int.init) ?? 1,
                  startedAt: $0["started_at"] as? Int64 ?? 0, createdAt: $0["created_at"] as? Int64)
        }
    }
    func getRecentBlocks(lectureId: String, beforeIndex: Int, limit: Int) -> [Block] {
        query("SELECT * FROM blocks WHERE lecture_id=? AND block_index<? AND is_final=1 ORDER BY block_index DESC LIMIT ?", [lectureId, beforeIndex, limit]).map {
            Block(id: $0["id"] as? String ?? "", lectureId: $0["lecture_id"] as? String ?? "",
                  blockIndex: ($0["block_index"] as? Int64).map(Int.init) ?? 0, textEn: $0["text_en"] as? String ?? "",
                  textZh: $0["text_zh"] as? String, isFinal: ($0["is_final"] as? Int64).map(Int.init) ?? 1,
                  startedAt: $0["started_at"] as? Int64 ?? 0, createdAt: $0["created_at"] as? Int64)
        }.reversed()
    }

    // MARK: - Concept Map (v1.1)

    func saveConceptMap(lectureId: String, nodes: [ConceptNode]) {
        let nowMs = now()
        run("DELETE FROM concept_map WHERE lecture_id=?", [lectureId])
        for n in nodes {
            run("INSERT INTO concept_map(id,lecture_id,concept,parent_id,level,content,slide_index,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?)",
                [n.id, lectureId, n.concept, n.parentId as Any?, n.level, n.content, n.slideIndex, n.createdAt, n.updatedAt])
        }
    }

    func loadConceptMap(lectureId: String) -> [ConceptNode] {
        query("SELECT * FROM concept_map WHERE lecture_id=? ORDER BY slide_index ASC, level ASC", [lectureId]).map {
            ConceptNode(id: $0["id"] as? String ?? "",
                        concept: $0["concept"] as? String ?? "",
                        parentId: $0["parent_id"] as? String,
                        level: ($0["level"] as? Int64).map(Int.init) ?? 0,
                        content: $0["content"] as? String ?? "",
                        slideIndex: ($0["slide_index"] as? Int64).map(Int.init) ?? 0,
                        lectureId: $0["lecture_id"] as? String ?? "",
                        createdAt: $0["created_at"] as? Int64 ?? 0,
                        updatedAt: $0["updated_at"] as? Int64 ?? 0)
        }
    }

    func deleteConceptMap(lectureId: String) {
        run("DELETE FROM concept_map WHERE lecture_id=?", [lectureId])
    }

    func getRecentBlocks(lectureId: String, since: Date) -> [Block] {
        let ms = Int64(since.timeIntervalSince1970 * 1000)
        return query("SELECT * FROM blocks WHERE lecture_id=? AND created_at>? AND is_final=1 ORDER BY block_index ASC", [lectureId, ms]).map {
            Block(id: $0["id"] as? String ?? "", lectureId: $0["lecture_id"] as? String ?? "",
                  blockIndex: ($0["block_index"] as? Int64).map(Int.init) ?? 0, textEn: $0["text_en"] as? String ?? "",
                  textZh: $0["text_zh"] as? String, isFinal: ($0["is_final"] as? Int64).map(Int.init) ?? 1,
                  startedAt: $0["started_at"] as? Int64 ?? 0, createdAt: $0["created_at"] as? Int64)
        }
    }

    // Saves
    func createSave(lectureId: String?, blockId: String?, type: String, original: String, translation: String?, note: String?) -> String {
        let id = uid()
        run("INSERT INTO saves(id,lecture_id,block_id,type,original,translation,note) VALUES(?,?,?,?,?,?,?)", [id, lectureId, blockId, type, original, translation, note])
        return id
    }
    func getSaves(lectureId: String) -> [SavedCard] {
        query("SELECT * FROM saves WHERE lecture_id=? ORDER BY created_at ASC", [lectureId]).map(mapSave)
    }
    func getAllSaves() -> [SavedCard] {
        query("SELECT s.*,l.name as ln,l.subject as ls,l.started_at as ld FROM saves s LEFT JOIN lectures l ON l.id=s.lecture_id ORDER BY s.created_at DESC").map(mapSave)
    }
    private func mapSave(_ r: [String: Any]) -> SavedCard {
        SavedCard(id: r["id"] as? String ?? "", lectureId: r["lecture_id"] as? String, blockId: r["block_id"] as? String,
                  type: r["type"] as? String ?? "knowledge", original: r["original"] as? String ?? "",
                  translation: r["translation"] as? String, note: r["note"] as? String,
                  createdAt: r["created_at"] as? Int64, lectureName: r["ln"] as? String,
                  lectureSubject: r["ls"] as? String, lectureDate: r["ld"] as? Int64)
    }

    // Searches
    func saveSearch(id: String, lectureId: String?, query: String, resultPro: String, resultSimple: String) {
        run("INSERT INTO searches(id,lecture_id,query,result_pro,result_simple) VALUES(?,?,?,?,?)", [id, lectureId, query, resultPro, resultSimple])
    }
    func saveSearchNote(id: String, note: String) { run("UPDATE searches SET note=? WHERE id=?", [note, id]) }
    func markSearchSaved(id: String) { run("UPDATE searches SET saved=1 WHERE id=?", [id]) }
    func markSearchEngaged(id: String) { run("UPDATE searches SET engaged=1 WHERE id=?", [id]) }
    func markSearchDismissed(id: String) { run("UPDATE searches SET dismissed_at=? WHERE id=?", [now(), id]) }
    func getSearches(lectureId: String) -> [SearchResult] {
        query("SELECT * FROM searches WHERE lecture_id=? ORDER BY created_at ASC", [lectureId]).map(mapSearch)
    }
    func getAllSearches() -> [SearchResult] {
        query("SELECT sr.*,l.name as ln,l.subject as ls,l.started_at as ld FROM searches sr LEFT JOIN lectures l ON l.id=sr.lecture_id ORDER BY sr.created_at DESC").map(mapSearch)
    }
    private func mapSearch(_ r: [String: Any]) -> SearchResult {
        SearchResult(id: r["id"] as? String ?? "", lectureId: r["lecture_id"] as? String, blockId: r["block_id"] as? String,
                     query: r["query"] as? String ?? "", resultPro: r["result_pro"] as? String ?? "",
                     resultSimple: r["result_simple"] as? String ?? "", note: r["note"] as? String,
                     saved: (r["saved"] as? Int64).map(Int.init) ?? 0, createdAt: r["created_at"] as? Int64,
                     lectureName: r["ln"] as? String, lectureSubject: r["ls"] as? String, lectureDate: r["ld"] as? Int64)
    }

    // Notes
    func saveNoteBlock(lectureId: String, slideIndex: Int, slideTitle: String?, content: String, source: String, level: Int) -> NoteBlock {
        let id = uid()
        let maxO = (row("SELECT MAX(sort_order) as m FROM note_blocks WHERE lecture_id=?", [lectureId])?["m"] as? Double) ?? 0
        let so = maxO + 1
        run("INSERT INTO note_blocks(id,lecture_id,slide_index,slide_title,content,source,level,sort_order) VALUES(?,?,?,?,?,?,?,?)", [id, lectureId, slideIndex, slideTitle, content, source, level, so])
        return NoteBlock(id: id, lectureId: lectureId, slideIndex: slideIndex, slideTitle: slideTitle, content: content, source: source, level: level, sortOrder: Int(so))
    }
    func updateNoteBlock(id: String, content: String, level: Int?) {
        if let lvl = level { run("UPDATE note_blocks SET content=?,level=?,source='user' WHERE id=?", [content, lvl, id]) }
        else { run("UPDATE note_blocks SET content=?,source='user' WHERE id=?", [content, id]) }
    }
    func deleteNoteBlock(id: String) { run("DELETE FROM note_blocks WHERE id=?", [id]) }
    func getNoteBlocks(lectureId: String) -> [NoteBlock] {
        query("SELECT * FROM note_blocks WHERE lecture_id=? ORDER BY sort_order ASC, created_at ASC", [lectureId]).map {
            NoteBlock(id: $0["id"] as? String ?? "", lectureId: $0["lecture_id"] as? String ?? "",
                      slideIndex: ($0["slide_index"] as? Int64).map(Int.init) ?? 0, slideTitle: $0["slide_title"] as? String,
                      content: $0["content"] as? String ?? "", source: $0["source"] as? String ?? "ai",
                      level: ($0["level"] as? Int64).map(Int.init) ?? 0,
                      sortOrder: ($0["sort_order"] as? Double).map(Int.init) ?? 0, createdAt: $0["created_at"] as? Int64)
        }
    }

    // Slides
    func saveSlideStructure(lectureId: String, structure: [SlideItem]) {
        let json = (try? JSONEncoder().encode(structure)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        run("INSERT INTO lecture_slides(lecture_id,structure) VALUES(?,?) ON CONFLICT(lecture_id) DO UPDATE SET structure=excluded.structure", [lectureId, json])
    }
    func getSlideStructure(lectureId: String) -> [SlideItem] {
        guard let r = row("SELECT structure FROM lecture_slides WHERE lecture_id=?", [lectureId]),
              let js = r["structure"] as? String, let d = js.data(using: .utf8),
              let items = try? JSONDecoder().decode([SlideItem].self, from: d) else { return [] }
        return items
    }

    // Settings
    func getSetting(key: String) -> String? { row("SELECT value FROM settings WHERE key=?", [key])?["value"] as? String }
    func setSetting(key: String, value: String) { run("INSERT INTO settings(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value", [key, value]) }

    // MARK: - Student Knowledge Profile
    func saveKnowledgeRecord(concept: String, status: String, searchCount: Int, firstSeenAt: Int64?, lastInteractedAt: Int64?, source: String) {
        run("""
            INSERT INTO student_knowledge(concept,status,search_count,first_seen_at,last_interacted_at,source)
            VALUES(?,?,?,?,?,?)
            ON CONFLICT(concept) DO UPDATE SET
                status=COALESCE(NULLIF(excluded.status,''),student_knowledge.status),
                search_count=excluded.search_count,
                last_interacted_at=excluded.last_interacted_at,
                first_seen_at=COALESCE(student_knowledge.first_seen_at,excluded.first_seen_at)
            """, [concept, status, searchCount, firstSeenAt as Any?, lastInteractedAt as Any?, source])
    }
    func getKnowledgeRecord(concept: String) -> [String: Any]? { row("SELECT * FROM student_knowledge WHERE concept=?", [concept]) }
    func getAllKnowledgeRecords() -> [[String: Any]] { query("SELECT * FROM student_knowledge ORDER BY last_interacted_at DESC") }
    func deleteKnowledgeRecord(concept: String) { run("DELETE FROM student_knowledge WHERE concept=?", [concept]) }
    func getKnownTerms() -> [String] { query("SELECT concept FROM student_knowledge WHERE status='known'").map { $0["concept"] as? String ?? "" }.filter { !$0.isEmpty } }
    func updateKnowledgeStatus(concept: String, status: String) { run("UPDATE student_knowledge SET status=?,last_interacted_at=? WHERE concept=?", [status, now(), concept]) }
    func clearAllKnowledgeRecords() { run("DELETE FROM student_knowledge") }
}
