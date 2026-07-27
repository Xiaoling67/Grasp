import Foundation

extension DatabaseService {
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
}
