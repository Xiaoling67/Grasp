import Foundation

extension AppViewModel {
    // MARK: - Transcript (Spec 10.1, 10.3)
    var activeBlock: LiveBlock? { activeBlockId.flatMap { id in liveBlocks.first { $0.id == id } } }

    func handleInterim(_ t: String) {
        guard isRecording, !isPaused else { return }
        interimText = t
        let pw = interimBuf.split(separator: " "), cw = t.split(separator: " ")
        if cw.count > pw.count {
            let nw = cw.dropFirst(pw.count).joined(separator: " ")
            if activeBlockId == nil { newBlock() }
            if let i = liveBlocks.firstIndex(where: { $0.id == activeBlockId }) { liveBlocks[i].textEn += (liveBlocks[i].textEn.isEmpty ? "" : " ") + nw }
            interimBuf = t.trimmingCharacters(in: .whitespaces)
        }
    }

    func handleFinal(_ t: String) {
        guard isRecording, !isPaused else { return }
        let ft = t.trimmingCharacters(in: .whitespaces); guard !ft.isEmpty else { return }
        let pw = interimBuf.split(separator: " "), fw = ft.split(separator: " ")
        let tw = fw.dropFirst(pw.count).joined(separator: " ")
        interimBuf = ""
        if activeBlockId == nil { newBlock() }
        guard let i = liveBlocks.firstIndex(where: { $0.id == activeBlockId }) else { return }
        if !tw.isEmpty { liveBlocks[i].textEn += (liveBlocks[i].textEn.isEmpty ? "" : " ") + tw }
        // PRD P0-2: force seal at 100-word upper limit
        let wordCount = liveBlocks[i].textEn.split(separator: " ").count
        if wordCount >= 100 { seal(liveBlocks[i].textEn) }
    }

    func handleEnd() {
        guard isRecording, !isPaused, let b = activeBlock, !b.textEn.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        // PRD P0-2: only seal if block has reached 50-word lower limit
        let wordCount = b.textEn.split(separator: " ").count
        guard wordCount >= 50 else { return }
        seal(b.textEn)
    }

    private func newBlock() {
        let b = LiveBlock(id: UUID().uuidString, blockIndex: liveBlocks.count, textEn: "", isSealed: false, createdAt: Int64(Date().timeIntervalSince1970 * 1000))
        liveBlocks.append(b); activeBlockId = b.id
    }

    func seal(_ text: String) {
        guard let lid = activeLectureId, let i = liveBlocks.firstIndex(where: { $0.id == activeBlockId }) else { return }
        liveBlocks[i].isSealed = true; liveBlocks[i].textEn = text
        let bi = liveBlocks[i].blockIndex; activeBlockId = nil
        interimText = ""
        db.saveBlock(lectureId: lid, blockIndex: bi, textEn: text, textZh: nil)
        detectCC(text)

        if activeLectureMode == "international" {
            Task { let zh = try? await tr.translate(text: text, subject: activeLectureSubject.isEmpty ? nil : activeLectureSubject)
                if let zh, !zh.isEmpty, let j = liveBlocks.firstIndex(where: { $0.blockIndex == bi }) { liveBlocks[j].textZh = zh }
                db.setBlockTranslation(lectureId: lid, blockIndex: bi, textZh: zh ?? "")
            }
        }
        // Auto-explain: runs fully in parallel, does not affect NoteAgent
        let capturedText = text; let capturedLid = lid
        if !autoExplainBusy {
            autoExplainBusy = true
            Task {
                await autoExplain(text: capturedText, lectureId: capturedLid)
                await MainActor.run { self.autoExplainBusy = false }
            }
        }

        let request = PendingNoteRequest(lectureId: lid, blockIndex: bi, text: text)
        guard !noteAgentBusy else {
            // Real-time notes must not fall further and further behind: instead of a
            // growing FIFO, merge into the single pending slot so the worst-case lag stays
            // capped at "current request + one follow-up," and nothing said in between is
            // silently dropped.
            if let pending = pendingNoteRequest {
                pendingNoteRequest = PendingNoteRequest(lectureId: lid, blockIndex: bi, text: pending.text + "\n\n" + text)
            } else {
                pendingNoteRequest = request
            }
            aiNotesStatus = "Catching up..."
            return
        }
        runNoteRequest(request)
    }
}
