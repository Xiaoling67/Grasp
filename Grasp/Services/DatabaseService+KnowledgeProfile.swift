import Foundation

extension DatabaseService {
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
