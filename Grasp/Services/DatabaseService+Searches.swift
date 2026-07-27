import Foundation

extension DatabaseService {
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
}
