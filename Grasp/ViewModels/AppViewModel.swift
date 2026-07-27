import Foundation; import SwiftUI

@MainActor final class AppViewModel: ObservableObject {
    // Navigation (Spec 7.2: appStore)
    @Published var page: AppPage = .home
    @Published var tabs = [TabItem](); @Published var activeTabId: String? = nil
    @Published var sidebarVisible = true; @Published var pastExpanded = false
    @Published var pastLectures = [Lecture]()

    // Live lecture (Spec 7.2: lectureStore)
    @Published var isRecording = false; @Published var isPaused = false
    @Published var activeLectureId: String? = nil; @Published var activeLectureName: String? = nil
    @Published var activeLectureMode = "standard"; @Published var activeLectureSubject = ""
    @Published var liveBlocks = [LiveBlock](); @Published var activeBlockId: String? = nil
    @Published var interimText = ""; @Published var isScrollFrozen = false
    @Published var selectedBlockId: String? = nil
    @Published var showFullTranscript = false
    @Published var displayFontSize = "medium"
    @Published var showTranslation = true
    @Published var hoverFreezeEnabled = true
    @Published var highlightedBlockIds = Set<String>()
    @Published var deepgramStatus = "disconnected"

    // Notes (Spec 7.2: notesStore) — flat rich-text list, no concept map
    @Published var noteBlocks = [NoteBlock](); @Published var slideStructure = [SlideItem]()
    @Published var newNoteRequest = 0
    @Published var aiNotesStatus = "Ready"
    @Published var noteStyleGuide = AppViewModel.defaultNoteStyleGuide
    @Published var aiNoteDetailLevel = "balanced"
    @Published var aiNoteFramework = ""

    // Cold call (Spec 7.2: coldCallStore)
    @Published var coldCallPhase: ColdCallPhase? = nil

    // Bottom panel (Spec 7.2: lectureStore)
    @Published var activeCard: ActiveCardState? = nil; @Published var bottomTab = "current"
    @Published var searchStreaming = false; @Published var streamingTokens = ""
    @Published var sessionSaves = [SavedCard](); @Published var sessionSearches = [SearchResultState]()

    // Auto Explain
    @Published var autoExplainResult: SearchResultState? = nil
    @Published var autoExplainStreaming = false
    @Published var autoExplainTokens = ""
    @Published var autoExplainNew = false
    @Published var autoExplainKnowledge = ""
    private var recentlyExplained = Set<String>()

    // Modals & Toast
    @Published var showNewLectureModal = false; @Published var showExportModal = false
    @Published var showOnboarding = false; @Published var onboardingChecked = false
    @Published var toastMessage: String? = nil; @Published var toastType = "info"

    // Layout — v1.1-r2: all dividers movable; each column's top/bottom split is independent
    @Published var notesWidth = 400.0
    @Published var leftColumnRatio: CGFloat = 0.55  // Transcript vs Auto Explain, range 0.30-0.80
    @Published var rightColumnRatio: CGFloat = 0.55 // Notes vs Save/Search, range 0.30-0.80

    private let db = DatabaseService.shared; private let ds = DeepSeekService.shared
    private let dg = DeepgramService.shared; private let au = AudioService.shared
    private let tr = QwenTranslationService.shared
    private var interimBuf = ""; private var lastCC: Date?; private var noteTask: Task<Void,Never>?
    private var noteAgentBusy = false
    private struct PendingNoteRequest { let lectureId: String; let blockIndex: Int; let text: String }
    private var pendingNoteRequest: PendingNoteRequest?
    private var activityToken: NSObjectProtocol?
    private var autoExplainBusy = false
    private var searchCache = [String:(String,String)]()

    init() { loadPast(); checkOnboarding(); loadNotePreferences() }

    // MARK: - Onboarding (Spec 17)
    func checkOnboarding() {
        onboardingChecked = true
        showOnboarding = db.getSetting(key: "onboardingComplete") != "true"
    }
    func completeOnboarding(_ mode: String) {
        db.setSetting(key: "mode", value: mode); db.setSetting(key: "onboardingComplete", value: "true")
        showOnboarding = false
    }

    // MARK: - Start/Stop (Spec 3.1)
    func loadPast() { pastLectures = db.getLectures() }

    func startLecture(name: String?, mode: String, subject: String?, slideURL: URL? = nil) async {
        au.stopCapture(); dg.disconnect()
        resetLive(); showNewLectureModal = false
        let lid = db.startLecture(name: name, mode: mode, subject: subject)
        activeLectureId = lid; activeLectureName = name; activeLectureMode = mode; activeLectureSubject = subject ?? ""
        isRecording = true; isPaused = false
        // Prevent App Nap from throttling the keep-alive timer / websocket while the window
        // is backgrounded or occluded — without this, Deepgram's connection silently drops
        // a few minutes after the app loses focus.
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled, .suddenTerminationDisabled],
            reason: "Recording live lecture"
        )

        // Parse slides in parallel — does not block recording start
        if let url = slideURL {
            Task {
                let pages = SlideParserService.parse(url: url)
                guard !pages.isEmpty else {
                    showToast("Could not read slides.", type: "error")
                    return
                }
                let slides = await ds.generateSlideStructure(slides: pages, subject: activeLectureSubject)
                db.saveSlideStructure(lectureId: lid, structure: slides)
                self.slideStructure = slides
            }
        }

        let tab = TabItem(id: "live", type: .live, lectureId: lid, label: name ?? "Live Lecture")
        tabs = [tab] + tabs; activeTabId = "live"
        if !(await AudioService.requestPermission()) {
            showToast("Microphone access denied. Please allow it in System Settings → Privacy → Microphone.", type: "error")
            isRecording = false; endActivity(); return
        }
        do {
            try au.startCapture { [weak self] d, _ in self?.dg.sendAudio(d) }
        } catch { showToast("Microphone failed to start.", type: "error"); isRecording = false; endActivity(); return }
        dg.onFinal = { [weak self] in self?.handleFinal($0) }
        dg.onInterim = { [weak self] in self?.handleInterim($0) }
        dg.onEnd = { [weak self] in self?.handleEnd() }
        dg.onStatus = { [weak self] in self?.deepgramStatus = $0 }
        // Connect immediately. Keyword generation must not block live transcription.
        dg.connect(sr: au.sampleRate)
    }

    func stopLecture() async {
        au.stopCapture(); dg.disconnect()
        if let b = activeBlock, !b.textEn.trimmingCharacters(in: .whitespaces).isEmpty { seal(b.textEn) }
        // Drop any merged backlog now — otherwise it would spawn a follow-up note task
        // right as we're finishing the session, after the summary has already been written.
        pendingNoteRequest = nil
        if let task = noteTask { await task.value }
        if let lid = activeLectureId {
            await appendLectureSummary(lectureId: lid)
            db.stopLecture(id: lid)
        }
        isRecording = false
        aiNotesStatus = "Ready"
        coldCallPhase = nil
        searchCache.removeAll(); loadPast()
        endActivity()
    }

    private func endActivity() {
        if let token = activityToken { ProcessInfo.processInfo.endActivity(token); activityToken = nil }
    }

    func togglePause() { isPaused.toggle() }

    // MARK: - Transcript (Spec 10.1, 10.3)
    private var activeBlock: LiveBlock? { activeBlockId.flatMap { id in liveBlocks.first { $0.id == id } } }

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

    private func seal(_ text: String) {
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

    // MARK: - Cold Call (Spec 6.10, 3.4)
    private let ccPatterns: [NSRegularExpression] = [
        try! NSRegularExpression(pattern: #"\bwho (knows|can tell|can explain|can answer|wants to)\b"#, options: .caseInsensitive),
        try! NSRegularExpression(pattern: #"\bcan (anyone|someone|somebody) (tell|explain|answer|describe|name|give)\b"#, options: .caseInsensitive),
        try! NSRegularExpression(pattern: #"\bdoes anyone (know|remember|recall|have)\b"#, options: .caseInsensitive),
        try! NSRegularExpression(pattern: #"\banyone (know|want to|care to)\b"#, options: .caseInsensitive),
        try! NSRegularExpression(pattern: #"\blet's hear from\b"#, options: .caseInsensitive),
        try! NSRegularExpression(pattern: #"\bwhat do you think\b"#, options: .caseInsensitive),
    ]
    private func detectCC(_ t: String) {
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
    private var ccDismissTimer: Timer?

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

    private func runNoteRequest(_ request: PendingNoteRequest) {
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

    private func appendLectureSummary(lectureId: String) async {
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

    // MARK: - Auto Explain
    private func autoExplain(text: String, lectureId: String) async {
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

    func setAutoExplainKnowledge(_ knowledge: String) {
        autoExplainKnowledge = knowledge
        db.setSetting(key: "autoExplainKnowledge", value: knowledge)
    }

    func setDisplayFontSize(_ size: String) {
        guard ["small", "medium", "large"].contains(size) else { return }
        displayFontSize = size
        db.setSetting(key: "displayFontSize", value: size)
    }

    func setShowTranslation(_ enabled: Bool) {
        showTranslation = enabled
        db.setSetting(key: "showTranslation", value: enabled ? "true" : "false")
    }

    func setHoverFreezeEnabled(_ enabled: Bool) {
        hoverFreezeEnabled = enabled
        if !enabled { isScrollFrozen = false }
        db.setSetting(key: "hoverFreezeEnabled", value: enabled ? "true" : "false")
    }

    var transcriptEnglishFontSize: CGFloat {
        switch displayFontSize {
        case "small": return 12
        case "large": return 15
        default: return 13
        }
    }

    var transcriptTranslationFontSize: CGFloat {
        max(11, transcriptEnglishFontSize - 1)
    }

    var shouldShowTranslation: Bool {
        showTranslation && !showFullTranscript
    }

    func detailLabel(for level: String? = nil) -> String {
        switch level ?? aiNoteDetailLevel {
        case "concise": return "Concise"
        case "detailed": return "Detailed"
        default: return "Balanced"
        }
    }

    private func loadNotePreferences() {
        noteStyleGuide = db.getSetting(key: "noteStyleGuide") ?? Self.defaultNoteStyleGuide
        let detail = db.getSetting(key: "aiNoteDetailLevel") ?? "balanced"
        aiNoteDetailLevel = ["concise", "balanced", "detailed"].contains(detail) ? detail : "balanced"
        aiNoteFramework = db.getSetting(key: "aiNoteFramework") ?? ""
        autoExplainKnowledge = db.getSetting(key: "autoExplainKnowledge") ?? ""
        let fontSize = db.getSetting(key: "displayFontSize") ?? "medium"
        displayFontSize = ["small", "medium", "large"].contains(fontSize) ? fontSize : "medium"
        showTranslation = db.getSetting(key: "showTranslation") != "false"
        hoverFreezeEnabled = db.getSetting(key: "hoverFreezeEnabled") != "false"
    }

    private var notePromptStyleGuide: String {
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

    private static let defaultNoteStyleGuide = "Student note style: compact Apple Notes-style numbered notes. Prefer one to three useful lines, concrete terms, formulas, examples, and compact tables only when they help."

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

    private static func knowledgeTerms(from text: String) -> Set<String> {
        Set(text
            .lowercased()
            .components(separatedBy: CharacterSet(charactersIn: ",;，；\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 2 })
    }
    func handleCommandN() {
        if isRecording, activeTabId == "live", activeLectureId != nil {
            newNoteRequest += 1
        } else {
            showNewLectureModal = true
        }
    }

    // MARK: - Tabs (Spec 7.2: appStore)
    func openPastLecture(id: String, name: String?) {
        if let ex = tabs.first(where: { $0.lectureId == id }) { activeTabId = ex.id; return }
        let t = TabItem(id: "past-\(id)", type: .past, lectureId: id, label: name ?? "Untitled")
        tabs.append(t); activeTabId = t.id
        slideStructure = db.getSlideStructure(lectureId: id)
        noteBlocks = db.getNoteBlocks(lectureId: id)
    }
    func closeTab(id: String) { tabs.removeAll { $0.id == id }; if activeTabId == id { activeTabId = tabs.last?.id } }

    // MARK: - Toast
    func showToast(_ m: String, type: String = "info") { toastMessage = m; toastType = type
        Task { try? await Task.sleep(nanoseconds: 3_000_000_000); toastMessage = nil } }

    // MARK: - Reset
    private func resetLive() { liveBlocks = []; activeBlockId = nil; interimText = ""; interimBuf = ""
        noteBlocks = []; slideStructure = []; activeCard = nil; bottomTab = "current"
        sessionSaves = []; sessionSearches = []; coldCallPhase = nil; lastCC = nil; searchCache.removeAll()
        pendingNoteRequest = nil; noteAgentBusy = false
        autoExplainResult = nil; autoExplainStreaming = false; autoExplainTokens = ""
        autoExplainNew = false; recentlyExplained.removeAll(); autoExplainBusy = false }

    /// Holds the most recent text selection from the transcript, for keyboard shortcuts.
    static var lastSelectedText: String = ""

    // MARK: - Toggle & Focus (v1.1 keyboard shortcuts)

    /// ⌘⇧F — Toggle full transcript view (hide/show translation columns)
    func toggleFullTranscript() { showFullTranscript.toggle() }

    /// ⌘⇧N — Focus notes panel (sets bottomTab to "current" to avoid hiding notes)
    func focusNotesPanel() {
        // Scroll notes view into focus — switching bottom tab off "auto" if needed
        if bottomTab == "auto" { bottomTab = "current" }
        showToast("Notes panel focused", type: "info")
    }

    /// ⌘⇧A — Focus auto-explain panel
    func focusAutoExplain() {
        bottomTab = "auto"
        autoExplainNew = false
    }

    /// ⌘⇧C — Dismiss cold call
    func handleColdCallShortcut() {
        if coldCallPhase != nil { dismissCC() }
    }
}
