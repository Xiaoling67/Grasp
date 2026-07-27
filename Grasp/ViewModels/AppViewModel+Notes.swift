import Foundation

extension AppViewModel {
    func runNoteRequest(_ request: PendingNoteRequest) {
        noteAgentBusy = true
        let capturedLid = request.lectureId
        let capturedBlockIndex = request.blockIndex
        let capturedText = request.text
        // Snapshot state at the moment the request actually starts (not when it was queued)
        // so a merged follow-up request sees the freshest notes/context.
        let capturedSubject = activeLectureSubject
        let capturedSlides = slideStructure
        let capturedRecentNotes = Array(noteBlocks.suffix(20))
        let capturedStyleGuide = notePromptStyleGuide
        let capturedDetailLevel = aiNoteDetailLevel
        let capturedRecentTranscript = liveBlocks
            .filter { $0.isSealed && !$0.textEn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .suffix(4)
            .map {
                Block(
                    id: $0.id,
                    lectureId: capturedLid,
                    blockIndex: $0.blockIndex,
                    textEn: $0.textEn,
                    textZh: $0.textZh,
                    isFinal: 1,
                    startedAt: $0.createdAt ?? Int64(Date().timeIntervalSince1970 * 1000),
                    createdAt: $0.createdAt
                )
            }
        aiNotesStatus = "Writing..."
        noteTask = Task { [weak self] in
            let block = Block(
                id: UUID().uuidString,
                lectureId: capturedLid,
                blockIndex: capturedBlockIndex,
                textEn: capturedText,
                textZh: nil,
                isFinal: 1,
                startedAt: Int64(Date().timeIntervalSince1970 * 1000),
                createdAt: Int64(Date().timeIntervalSince1970 * 1000)
            )
            let noteContext = capturedRecentTranscript.isEmpty ? [block] : capturedRecentTranscript
            guard let (slideIndex, content) = await DeepSeekService.shared.generateNoteEntry(
                slides: capturedSlides,
                recent: noteContext,
                recentNotes: capturedRecentNotes,
                subject: capturedSubject,
                styleGuide: capturedStyleGuide,
                detailLevel: capturedDetailLevel
            ) else {
                await MainActor.run {
                    guard let self else { return }
                    if self.activeLectureId == capturedLid { self.aiNotesStatus = "Listening" }
                    self.finishNoteRequest()
                }
                return
            }
            await MainActor.run {
                guard let self else { return }
                defer { self.finishNoteRequest() }
                guard self.isRecording, self.activeLectureId == capturedLid else { return }
                guard !self.isDuplicateAINote(content) else {
                    self.aiNotesStatus = "Duplicate skipped"
                    return
                }
                let slideTitle = self.slideStructure.first(where: { $0.index == slideIndex })?.title
                let numberedContent = Self.renumberAINote(content, startingAt: self.nextAINoteNumber())
                let note = self.db.saveNoteBlock(
                    lectureId: capturedLid,
                    slideIndex: slideIndex,
                    slideTitle: slideTitle,
                    content: numberedContent,
                    source: "ai",
                    level: 0
                )
                self.noteBlocks.append(note)
                self.aiNotesStatus = "Updated"
            }
        }
    }

    private func finishNoteRequest() {
        noteAgentBusy = false
        guard let next = pendingNoteRequest else { return }
        pendingNoteRequest = nil
        guard next.lectureId == activeLectureId else { return }
        runNoteRequest(next)
    }

    func appendLectureSummary(lectureId: String) async {
        aiNotesStatus = "Summarizing..."
        let blocks = db.getRecentBlocks(lectureId: lectureId, beforeIndex: 9999, limit: 60)
        let notes = noteBlocks
        guard let summary = await ds.generateLectureSummary(blocks: blocks, notes: notes, subject: activeLectureSubject, styleGuide: notePromptStyleGuide, detailLevel: aiNoteDetailLevel) else {
            aiNotesStatus = "Ready"
            return
        }
        guard activeLectureId == lectureId else { return }
        let alreadyHasSummary = noteBlocks.contains { $0.displayText.localizedCaseInsensitiveContains("Summary") }
        guard !alreadyHasSummary else {
            aiNotesStatus = "Ready"
            return
        }
        let note = db.saveNoteBlock(
            lectureId: lectureId,
            slideIndex: noteBlocks.last?.slideIndex ?? 0,
            slideTitle: "Summary",
            content: "\n\n" + summary,
            source: "ai",
            level: 0
        )
        noteBlocks.append(note)
        aiNotesStatus = "Summary added"
    }

    // MARK: - Notes (Spec 10.3: handleCopyToNotes)
    func saveNoteBlockToDb(lectureId: String, slideIndex: Int, slideTitle: String?, content: String, source: String) -> NoteBlock {
        return db.saveNoteBlock(lectureId: lectureId, slideIndex: slideIndex, slideTitle: slideTitle, content: content, source: source, level: 0)
    }
    func handleCopyToNotes(text: String) {
        guard let lid = activeLectureId else { return }
        let last = noteBlocks.last
        let n = db.saveNoteBlock(lectureId: lid, slideIndex: last?.slideIndex ?? 0, slideTitle: last?.slideTitle, content: text, source: "user", level: 0)
        noteBlocks.append(n)
    }
    func updateNote(id: String, content: String, level: Int?) {
        if let lvl = level { db.updateNoteBlock(id: id, content: content, level: lvl) }
        else { db.updateNoteBlock(id: id, content: content, level: nil) }
    }
    func deleteNote(id: String) { db.deleteNoteBlock(id: id); noteBlocks.removeAll { $0.id == id } }

    func learnNoteStyle(from plainText: String) {
        let learned = Self.inferNoteStyleGuide(from: plainText)
        guard learned != noteStyleGuide else { return }
        noteStyleGuide = learned
        db.setSetting(key: "noteStyleGuide", value: learned)
        aiNotesStatus = "Style learned"
    }

    func setAINoteDetailLevel(_ level: String) {
        guard ["concise", "balanced", "detailed"].contains(level) else { return }
        aiNoteDetailLevel = level
        db.setSetting(key: "aiNoteDetailLevel", value: level)
        aiNotesStatus = detailLabel(for: level)
    }

    func setAINoteFramework(_ framework: String) {
        aiNoteFramework = framework
        db.setSetting(key: "aiNoteFramework", value: framework)
        aiNotesStatus = framework.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Ready" : "Framework saved"
    }

    var notePromptStyleGuide: String {
        let trimmed = aiNoteFramework.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return noteStyleGuide }
        return noteStyleGuide + "\nUser's preferred note framework:\n" + trimmed
    }

    private func nextAINoteNumber() -> Int {
        let pattern = #"^\s*(\d+)\.\s"#
        return noteBlocks
            .flatMap { $0.displayText.components(separatedBy: .newlines) }
            .compactMap { line -> Int? in
                guard let range = line.range(of: pattern, options: .regularExpression) else { return nil }
                return Int(line[range].trimmingCharacters(in: CharacterSet(charactersIn: " .")))
            }
            .max()
            .map { $0 + 1 } ?? 1
    }

    private static func renumberAINote(_ content: String, startingAt start: Int) -> String {
        var current = max(1, start) - 1
        return content.components(separatedBy: .newlines).map { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil {
                current += 1
                return line.replacingOccurrences(of: #"^\s*\d+\.\s"#, with: "\(current). ", options: .regularExpression)
            }
            if trimmed.range(of: #"^\d+\.\d+\s"#, options: .regularExpression) != nil {
                let parent = max(1, current)
                return line.replacingOccurrences(of: #"^\s*\d+\."#, with: "\(parent).", options: .regularExpression)
            }
            return line
        }.joined(separator: "\n")
    }

    private func isDuplicateAINote(_ content: String) -> Bool {
        let candidate = Self.normalizedNoteText(content)
        guard candidate.count > 24 else { return false }
        let candidateTokens = Set(candidate.split(separator: " ").map(String.init).filter { $0.count > 3 })
        for note in noteBlocks.suffix(12) {
            let existing = Self.normalizedNoteText(note.displayText)
            if existing.contains(candidate) || candidate.contains(existing), min(existing.count, candidate.count) > 24 {
                return true
            }
            let existingTokens = Set(existing.split(separator: " ").map(String.init).filter { $0.count > 3 })
            let union = candidateTokens.union(existingTokens)
            guard !union.isEmpty else { continue }
            let overlap = Double(candidateTokens.intersection(existingTokens).count) / Double(union.count)
            if overlap >= 0.72 { return true }
        }
        return false
    }

    static let defaultNoteStyleGuide = "Student note style: compact Apple Notes-style numbered notes. Prefer one to three useful lines, concrete terms, formulas, examples, and compact tables only when they help."

    private static func inferNoteStyleGuide(from text: String) -> String {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return defaultNoteStyleGuide }

        let wordCount = lines.reduce(0) { $0 + $1.split(separator: " ").count }
        let averageWords = Double(wordCount) / Double(max(lines.count, 1))
        let detail = averageWords <= 9 ? "very concise" : (averageWords <= 18 ? "balanced" : "detailed")
        let usesThirdDepth = text.contains("1.1.1")
        let usesTables = text.contains("| --- |") || text.contains("|---")
        let numberedLines = lines.filter { $0.range(of: #"^\d+(\.\d+)*\s"#, options: .regularExpression) != nil }.count
        let prefersNumbering = numberedLines >= max(2, lines.count / 4)

        var parts = ["Student note style: \(detail), Apple Notes-style"]
        parts.append(prefersNumbering ? "prefer numbered structure" : "use plain paragraphs unless structure clearly helps")
        parts.append(usesThirdDepth ? "allow 1.1.1 depth for examples/formulas" : "prefer 1. and 1.1; avoid third depth unless necessary")
        parts.append(usesTables ? "include compact tables for comparisons/data" : "avoid tables unless the transcript contains clear comparison/data")
        parts.append("preserve concrete terms, formulas, examples, and exam cues; never add filler")
        return parts.joined(separator: "; ") + "."
    }

    private static func normalizedNoteText(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
