import Foundation

extension DatabaseService {
    // Notes
    func saveNoteBlock(lectureId: String, slideIndex: Int, slideTitle: String?, content: String, source: String, level: Int) -> NoteBlock {
        let id = uid()
        let maxO = (row("SELECT MAX(sort_order) as m FROM note_blocks WHERE lecture_id=?", [lectureId])?["m"] as? Double) ?? 0
        let so = maxO + 1
        let ts = now()
        run("INSERT INTO note_blocks(id,lecture_id,slide_index,slide_title,content,source,level,sort_order,created_at) VALUES(?,?,?,?,?,?,?,?,?)", [id, lectureId, slideIndex, slideTitle, content, source, level, so, ts])
        return NoteBlock(id: id, lectureId: lectureId, slideIndex: slideIndex, slideTitle: slideTitle, content: content, source: source, level: level, sortOrder: Int(so), createdAt: ts)
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
}
