import Foundation

extension AppViewModel {
    // MARK: - Search (Spec 6.5)
    func triggerSearch(query: String, blockIndex: Int, lectureId: String? = nil) {
        let lid = lectureId ?? activeLectureId; guard let lid else { return }
        let ck = "\(lid):\(query.lowercased().trimmingCharacters(in: .whitespaces))"
        if let cached = searchCache[ck] {
            let r = SearchResultState(id: UUID().uuidString, query: query, professional: cached.0, intuition: cached.1)
            sessionSearches.insert(r, at: 0); activeCard = .search(r); bottomTab = "current"; return
        }
        let rid = UUID().uuidString; searchStreaming = true; streamingTokens = ""
        let ctx = db.getRecentBlocks(lectureId: lid, beforeIndex: blockIndex, limit: 10)
        let subj = activeLectureSubject
        Task {
            var lastError: Error? = nil
            for attempt in 1...2 {
                do {
                    if attempt == 2 { streamingTokens = "" }
                    let full = try await ds.streamSearch(query: query, context: ctx, subject: subj) { _ in }
                    let parts = full.components(separatedBy: " | ")
                    let pro = parts.first?.trimmingCharacters(in: .whitespaces) ?? full
                    let intu = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
                    let r = SearchResultState(id: rid, query: query, professional: pro, intuition: intu)
                    sessionSearches.insert(r, at: 0); activeCard = .search(r); searchStreaming = false
                    searchCache[ck] = (pro, intu); db.saveSearch(id: rid, lectureId: lid, query: query, resultPro: pro, resultSimple: intu)
                    return
                } catch {
                    lastError = error
                }
            }
            var r = SearchResultState(id: rid, query: query); r.error = "Search failed. Check your connection."
            sessionSearches.insert(r, at: 0); activeCard = .search(r); searchStreaming = false
        }
        bottomTab = "current"
    }
}
