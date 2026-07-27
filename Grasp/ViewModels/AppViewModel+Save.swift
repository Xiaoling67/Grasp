import Foundation

extension AppViewModel {
    // MARK: - Save (Spec 10.3)
    func handleSaveAction(type: String, text: String) {
        guard let lid = activeLectureId else { return }
        let draft = SaveDraft(type: type, original: text, translation: nil, lectureId: lid)
        activeCard = .save(draft)
        bottomTab = "current"
        if activeLectureMode == "international" {
            Task {
                let trans = try? await tr.translate(text: text, subject: activeLectureSubject.isEmpty ? nil : activeLectureSubject)
                if let trans, !trans.isEmpty {
                    let updated = SaveDraft(type: type, original: text, translation: trans, lectureId: lid)
                    activeCard = .save(updated)
                }
            }
        }
    }
    func confirmSave(draft: SaveDraft, note: String?) {
        guard let lid = draft.lectureId ?? activeLectureId else { return }
        let sid = db.createSave(lectureId: lid, blockId: nil, type: draft.type, original: draft.original, translation: draft.translation, note: note)
        let card = SavedCard(id: sid, lectureId: lid, type: draft.type, original: draft.original, translation: draft.translation, note: note)
        sessionSaves.insert(card, at: 0)
        // Extract key terms from saved text and add to Knowledge Profile
        let words = draft.original.split(separator: " ").filter { $0.count > 3 }
        for word in words.prefix(5) {
            MemoryService.shared.recordInteraction(concept: String(word), action: .save)
        }
    }
}
