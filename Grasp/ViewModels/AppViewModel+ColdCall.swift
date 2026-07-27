import Foundation

extension AppViewModel {
    // MARK: - Cold Call (Spec 6.10, 3.4)
    func detectCC(_ t: String) {
        let ns = t as NSString; let r = NSRange(location: 0, length: ns.length)
        guard ccPatterns.contains(where: { $0.firstMatch(in: t, range: r) != nil }) else { return }
        let q = extractQ(t)
        let now = Date()
        if let last = lastCC, now.timeIntervalSince(last) < 90 { return }
        lastCC = now; coldCallPhase = .detected(q)
    }
    private func extractQ(_ t: String) -> String {
        let ss = t.components(separatedBy: CharacterSet(charactersIn: ".!?")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        for s in ss where s.hasSuffix("?") && s.count < 150 { return s }
        return String((ss.last ?? t).prefix(120))
    }
    func dismissCC() { coldCallPhase = nil; ccDismissTimer?.invalidate(); ccDismissTimer = nil }

    func generateCCAnswer(q: String) async {
        guard let lid = activeLectureId else { return }
        coldCallPhase = .generating
        let ctx = db.getRecentBlocks(lectureId: lid, beforeIndex: 9999, limit: 15)
        let sl = db.getSlideStructure(lectureId: lid)
        let rn = Array(noteBlocks.suffix(10))
        if let a = await ds.generateColdCallAnswer(question: q, context: ctx, slides: sl, recentNotes: rn, subject: activeLectureSubject) {
            coldCallPhase = .answered(a)
            startCCAutoDismiss()
        } else { coldCallPhase = nil }
    }

    private func startCCAutoDismiss() {
        ccDismissTimer?.invalidate()
        ccDismissTimer = Timer.scheduledTimer(withTimeInterval: 45.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.dismissCC() }
        }
    }

    func saveCCToNotes(answer: ColdCallAnswer) {
        guard let lid = activeLectureId else { return }
        let last = noteBlocks.last
        let content = answer.shortAnswer
        let n = db.saveNoteBlock(lectureId: lid, slideIndex: last?.slideIndex ?? 0, slideTitle: last?.slideTitle, content: content, source: "user", level: 1)
        noteBlocks.append(n)
        for point in answer.supportingPoints {
            let p = db.saveNoteBlock(lectureId: lid, slideIndex: last?.slideIndex ?? 0, slideTitle: last?.slideTitle, content: point, source: "user", level: 2)
            noteBlocks.append(p)
        }
        coldCallPhase = nil
        showToast("Saved to notes.")
        // Extract key terms from cold call answer and add to Knowledge Profile
        let terms = answer.shortAnswer.split(separator: " ").filter { $0.count > 3 }
        for term in terms.prefix(3) {
            MemoryService.shared.recordInteraction(concept: String(term).lowercased(), action: .autoExplain)
        }
    }

    /// ⌘⇧C — Dismiss cold call
    func handleColdCallShortcut() {
        if coldCallPhase != nil { dismissCC() }
    }
}
