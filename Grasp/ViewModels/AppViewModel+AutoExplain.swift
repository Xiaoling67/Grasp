import Foundation

extension AppViewModel {
    // MARK: - Auto Explain
    func autoExplain(text: String, lectureId: String) async {
        let customKnownTerms = Self.knowledgeTerms(from: autoExplainKnowledge)
        guard let detected = await ds.detectUnfamiliarTerm(text: text, subject: activeLectureSubject, knownTerms: recentlyExplained.union(customKnownTerms), customKnowledge: autoExplainKnowledge) else { return }
        guard detected.confidence > 0.65 else { return }
        let key = detected.term.lowercased()
        guard !recentlyExplained.contains(key) else { return }
        guard !customKnownTerms.contains(key) else { return }

        // Check Knowledge Profile before showing explanation
        let status = MemoryService.shared.checkConcept(detected.term)
        switch status {
        case .known:
            return  // skip entirely, student knows this
        case .lookedUp:
            // Show a brief reminder — "You've seen this before" card
            guard activeLectureId == lectureId else { return }
            let rid = UUID().uuidString
            let r = SearchResultState(id: rid, query: detected.term,
                                      professional: "You've seen this before: \(detected.term)",
                                      intuition: "You previously looked this up. Here's a quick refresher if needed.")
            autoExplainResult = r; autoExplainStreaming = false
            autoExplainNew = (bottomTab != "auto")
            MemoryService.shared.recordInteraction(concept: detected.term, action: .autoExplain)
            return
        case .preventive, .neverSeen, .dismissed:
            break  // proceed to full explanation
        }

        recentlyExplained.insert(key)
        if recentlyExplained.count > 60, let old = recentlyExplained.first { recentlyExplained.remove(old) }

        guard activeLectureId == lectureId else { return }
        let rid = UUID().uuidString
        autoExplainStreaming = true; autoExplainTokens = ""
        let ctx = db.getRecentBlocks(lectureId: lectureId, beforeIndex: 9999, limit: 10)
        do {
            let full = try await ds.streamSearch(query: detected.term, context: ctx, subject: activeLectureSubject, customKnowledge: autoExplainKnowledge) { _ in }
            guard activeLectureId == lectureId else { return }
            let parts = full.components(separatedBy: " | ")
            let pro = parts.first?.trimmingCharacters(in: .whitespaces) ?? full
            let intu = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
            let r = SearchResultState(id: rid, query: detected.term, professional: pro, intuition: intu)
            autoExplainResult = r; autoExplainStreaming = false
            autoExplainNew = (bottomTab != "auto")
            MemoryService.shared.recordInteraction(concept: detected.term, action: .autoExplain)
        } catch {
            if activeLectureId == lectureId { autoExplainStreaming = false }
        }
    }

    func dismissAutoExplain() {
        if let term = autoExplainResult?.query {
            MemoryService.shared.recordInteraction(concept: term, action: .dismiss)
        }
        autoExplainResult = nil; autoExplainNew = false; autoExplainTokens = ""
    }

    func setAutoExplainKnowledge(_ knowledge: String) {
        autoExplainKnowledge = knowledge
        db.setSetting(key: "autoExplainKnowledge", value: knowledge)
    }

    private static func knowledgeTerms(from text: String) -> Set<String> {
        Set(text
            .lowercased()
            .components(separatedBy: CharacterSet(charactersIn: ",;，；\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 2 })
    }
}
