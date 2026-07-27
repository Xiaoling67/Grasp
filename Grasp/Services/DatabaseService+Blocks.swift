import Foundation

extension DatabaseService {
    // Blocks
    func saveBlock(lectureId: String, blockIndex: Int, textEn: String, textZh: String?) -> String {
        let id = uid()
        let ts = now()
        run("INSERT INTO blocks(id,lecture_id,block_index,text_en,text_zh,is_final,started_at,created_at) VALUES(?,?,?,?,?,1,?,?)", [id, lectureId, blockIndex, textEn, textZh, ts, ts])
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
}
