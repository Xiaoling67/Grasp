import Foundation

extension DatabaseService {
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
}
