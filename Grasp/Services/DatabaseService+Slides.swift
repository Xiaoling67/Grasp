import Foundation

extension DatabaseService {
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
}
