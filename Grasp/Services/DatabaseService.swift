import Foundation
import SQLite3

final class DatabaseService {
    static let shared = DatabaseService()
    var db: OpaquePointer?

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
            CREATE INDEX IF NOT EXISTS idx_blocks_lecture ON blocks(lecture_id);
        """)
        // PRD Section 9: implicit feedback columns (safe to run on existing DBs)
        exec("ALTER TABLE searches ADD COLUMN engaged INTEGER DEFAULT 0")
        exec("ALTER TABLE searches ADD COLUMN dismissed_at INTEGER")
    }

    deinit { if let db { sqlite3_close(db) } }

    // Internal (not private) SQLite helpers — shared by the per-table extensions in
    // DatabaseService+*.swift.
    func exec(_ sql: String) { sqlite3_exec(db, sql, nil, nil, nil) }

    func run(_ sql: String, _ args: [Any?] = []) {
        var s: OpaquePointer?; sqlite3_prepare_v2(db, sql, -1, &s, nil)
        bind(s, args); sqlite3_step(s); sqlite3_finalize(s)
    }

    func query(_ sql: String, _ args: [Any?] = []) -> [[String: Any]] {
        var s: OpaquePointer?; sqlite3_prepare_v2(db, sql, -1, &s, nil)
        bind(s, args); var rows = [[String: Any]]()
        while sqlite3_step(s) == SQLITE_ROW {
            var row = [String: Any]()
            for i in 0..<sqlite3_column_count(s) {
                let n = String(cString: sqlite3_column_name(s, i))
                switch sqlite3_column_type(s, i) {
                case SQLITE_INTEGER: row[n] = sqlite3_column_int64(s, i)
                case SQLITE_FLOAT:   row[n] = sqlite3_column_double(s, i)
                case SQLITE_TEXT:    row[n] = String(cString: sqlite3_column_text(s, i))
                default: break
                }
            }
            rows.append(row)
        }
        sqlite3_finalize(s); return rows
    }

    func row(_ sql: String, _ args: [Any?] = []) -> [String: Any]? { query(sql, args).first }

    func bind(_ s: OpaquePointer?, _ vals: [Any?]) {
        for (i, v) in vals.enumerated() {
            let idx = Int32(i + 1)
            switch v {
            case nil: sqlite3_bind_null(s, idx)
            case let x as Int:    sqlite3_bind_int64(s, idx, Int64(x))
            case let x as Int64:  sqlite3_bind_int64(s, idx, x)
            case let x as Double: sqlite3_bind_double(s, idx, x)
            case let x as String: sqlite3_bind_text(s, idx, x, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            default: break
            }
        }
    }

    func now() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
    func uid() -> String { UUID().uuidString }
}
