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
    @Published var highlightedBlockIds = Set<String>()

    // Notes (Spec 7.2: notesStore)
    @Published var noteBlocks = [NoteBlock](); @Published var slideStructure = [SlideItem]()
    @Published var conceptMap = [ConceptNode]()

    // Bottom panel (Spec 7.2: lectureStore)
    @Published var activeCard: ActiveCardState? = nil; @Published var bottomTab = "current"
    @Published var searchStreaming = false; @Published var streamingTokens = ""
    @Published var sessionSaves = [SavedCard](); @Published var sessionSearches = [SearchResultState]()

    // Cold call (Spec 7.2: coldCallStore)
    @Published var coldCallPhase: ColdCallPhase? = nil

    // Auto Explain
    @Published var autoExplainResult: SearchResultState? = nil
    @Published var autoExplainStreaming = false
    @Published var autoExplainTokens = ""
    @Published var autoExplainNew = false
    private var recentlyExplained = Set<String>()

    // Modals & Toast
    @Published var showNewLectureModal = false; @Published var showExportModal = false
    @Published var showOnboarding = false; @Published var onboardingChecked = false
    @Published var toastMessage: String? = nil; @Published var toastType = "info"

    // Layout
    @Published var notesWidth = 400.0

    private let db = DatabaseService.shared; private let ds = DeepSeekService.shared
    private let dg = DeepgramService.shared; private let au = AudioService.shared
    private let tr = QwenTranslationService.shared
    private var interimBuf = ""; private var lastCC: Date?; private var noteTask: Task<Void,Never>?
    private var searchCache = [String:(String,String)]()
    private var conceptMapTimer: Timer?
    private var lastConceptMapFire: Date = .distantPast

    init() { loadPast(); checkOnboarding() }

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
        resetLive(); showNewLectureModal = false
        let lid = db.startLecture(name: name, mode: mode, subject: subject)
        activeLectureId = lid; activeLectureName = name; activeLectureMode = mode; activeLectureSubject = subject ?? ""
        isRecording = true; isPaused = false

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

        startConceptMapTimer()

        let tab = TabItem(id: "live", type: .live, lectureId: lid, label: name ?? "Live Lecture")
        tabs = [tab] + tabs; activeTabId = "live"
        if !(await AudioService.requestPermission()) {
            showToast("Microphone access denied. Please allow it in System Settings → Privacy → Microphone.", type: "error")
            isRecording = false; return
        }
        do {
            try au.startCapture { [weak self] d, _ in self?.dg.sendAudio(d) }
        } catch { showToast("Microphone failed to start.", type: "error"); isRecording = false; return }
        dg.onFinal = { [weak self] in self?.handleFinal($0) }
        dg.onInterim = { [weak self] in self?.handleInterim($0) }
        dg.onEnd = { [weak self] in self?.handleEnd() }
        dg.onStatus = { [weak self] in self?.deepgramStatus = $0 }
        // PRD P1-4: generate domain keywords and inject into Deepgram for better terminology recognition
        let subject = activeLectureSubject
        let keywords = subject.isEmpty ? [] : await ds.generateKeywords(subject: subject)
        dg.connect(sr: au.sampleRate, keywords: keywords)
    }

    func stopLecture() async {
        isRecording = false; au.stopCapture(); dg.disconnect()
        if let b = activeBlock, !b.textEn.trimmingCharacters(in: .whitespaces).isEmpty { seal(b.textEn) }
        if let lid = activeLectureId { db.stopLecture(id: lid) }
        await fireConceptMapUpdate()
        conceptMapTimer?.invalidate()
        conceptMapTimer = nil
        noteTask?.cancel(); searchCache.removeAll(); coldCallPhase = nil; loadPast()
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

        if activeLectureMode == "international" {
            Task { let zh = try? await tr.translate(text: text, subject: activeLectureSubject.isEmpty ? nil : activeLectureSubject)
                if let zh, !zh.isEmpty, let j = liveBlocks.firstIndex(where: { $0.blockIndex == bi }) { liveBlocks[j].textZh = zh }
                db.setBlockTranslation(lectureId: lid, blockIndex: bi, textZh: zh ?? "")
            }
        }
        // Auto-explain: runs fully in parallel, does not affect NoteAgent
        let capturedText = text; let capturedLid = lid
        Task { await autoExplain(text: capturedText, lectureId: capturedLid) }
        detectCC(text)
    }

    // MARK: - Concept Map (v1.1)

    private func startConceptMapTimer() {
        conceptMapTimer?.invalidate()
        lastConceptMapFire = Date()
        conceptMapTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            Task { [weak self] in await self?.fireConceptMapUpdate() }
        }
    }

    @MainActor
    private func fireConceptMapUpdate() async {
        guard let lid = activeLectureId else { return }

        // 1. Collect sealed blocks since last fire
        let since = lastConceptMapFire
        lastConceptMapFire = Date()

        let windowBlocks = db.getRecentBlocks(lectureId: lid, since: since)

        // 2. Skip if no new content
        guard !windowBlocks.isEmpty else { return }

        // 3. Get existing Concept Map
        let existingMap = db.loadConceptMap(lectureId: lid)

        // 4. Get slide structure
        let slides = slideStructure

        // 5. Build window text
        let windowText = windowBlocks.map { $0.textEn }.joined(separator: "\n\n")

        // 6. Call DeepSeek
        guard let updatedNodes = await ds.generateConceptMapUpdate(
            windowText: windowText,
            existingMap: existingMap,
            slides: slides,
            subject: activeLectureSubject
        ) else { return }

        // 7. Preserve lectureId on all nodes
        let nodesWithLectureId = updatedNodes.map { n -> ConceptNode in
            var node = n
            // Only set lectureId if it's missing
            if node.lectureId.isEmpty {
                node.lectureId = lid
            }
            return node
        }

        // 8. Save to DB
        db.saveConceptMap(lectureId: lid, nodes: nodesWithLectureId)

        // 9. Update in-memory state
        conceptMap = nodesWithLectureId
    }

    // MARK: - Cold Call (Spec 6.10, 3.4)
    private let ccPatterns: [NSRegularExpression] = [
        try! NSRegularExpression(pattern: #"\bwho (knows|can tell|can explain|can answer|wants to)\b"#, options: .caseInsensitive),
        try! NSRegularExpression(pattern: #"\bcan (anyone|someone|somebody) (tell|explain|answer|describe|name|give)\b"#, options: .caseInsensitive),
        try! NSRegularExpression(pattern: #"\bdoes anyone (know|remember|recall|have)\b"#, options: .caseInsensitive),
        try! NSRegularExpression(pattern: #"\banybody (know|want to|care to)\b"#, options: .caseInsensitive),
        try! NSRegularExpression(pattern: #"\btell me (what|how|why|who|which)\b"#, options: .caseInsensitive),
        try! NSRegularExpression(pattern: #"\bsomebody (tell|explain|give) (me|us)\b"#, options: .caseInsensitive),
        try! NSRegularExpression(pattern: #"\bwho (here|in this class|in this room|among you)\b"#, options: .caseInsensitive),
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

    // MARK: - Auto Explain
    private func autoExplain(text: String, lectureId: String) async {
        guard let detected = await ds.detectUnfamiliarTerm(text: text, subject: activeLectureSubject, knownTerms: recentlyExplained) else { return }
        guard detected.confidence > 0.65 else { return }
        let key = detected.term.lowercased()
        guard !recentlyExplained.contains(key) else { return }

        // Check Knowledge Profile before showing explanation
        let status = MemoryService.shared.checkConcept(detected.term)
        switch status {
        case .known:
            return  // skip entirely, student knows this
        case .lookedUp:
            // Show a brief reminder — "You've seen this before" card
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

        let rid = UUID().uuidString
        autoExplainStreaming = true; autoExplainTokens = ""
        let ctx = db.getRecentBlocks(lectureId: lectureId, beforeIndex: 9999, limit: 10)
        do {
            let full = try await ds.streamSearch(query: detected.term, context: ctx, subject: activeLectureSubject) { [weak self] t in
                self?.autoExplainTokens += t
            }
            let parts = full.components(separatedBy: " | ")
            let pro = parts.first?.trimmingCharacters(in: .whitespaces) ?? full
            let intu = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
            let r = SearchResultState(id: rid, query: detected.term, professional: pro, intuition: intu)
            autoExplainResult = r; autoExplainStreaming = false
            autoExplainNew = (bottomTab != "auto")
            MemoryService.shared.recordInteraction(concept: detected.term, action: .autoExplain)
        } catch { autoExplainStreaming = false }
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
                    let full = try await ds.streamSearch(query: query, context: ctx, subject: subj) { [weak self] t in self?.streamingTokens += t }
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
    func handleCopyToNotes(text: String) {
        guard let lid = activeLectureId else { return }
        let last = noteBlocks.last
        let n = db.saveNoteBlock(lectureId: lid, slideIndex: last?.slideIndex ?? 0, slideTitle: last?.slideTitle, content: text, source: "user", level: last?.level ?? 1)
        noteBlocks.append(n)
    }
    func updateNote(id: String, content: String, level: Int?) { db.updateNoteBlock(id: id, content: content, level: level) }
    func deleteNote(id: String) { db.deleteNoteBlock(id: id); noteBlocks.removeAll { $0.id == id } }

    // MARK: - Tabs (Spec 7.2: appStore)
    func openPastLecture(id: String, name: String?) {
        if let ex = tabs.first(where: { $0.lectureId == id }) { activeTabId = ex.id; return }
        let t = TabItem(id: "past-\(id)", type: .past, lectureId: id, label: name ?? "Untitled")
        tabs.append(t); activeTabId = t.id
        slideStructure = db.getSlideStructure(lectureId: id)
        conceptMap = db.loadConceptMap(lectureId: id)
        noteBlocks = db.getNoteBlocks(lectureId: id)
    }
    func closeTab(id: String) { tabs.removeAll { $0.id == id }; if activeTabId == id { activeTabId = tabs.last?.id } }

    // MARK: - Toast
    func showToast(_ m: String, type: String = "info") { toastMessage = m; toastType = type
        Task { try? await Task.sleep(nanoseconds: 3_000_000_000); toastMessage = nil } }

    // MARK: - Reset
    private func resetLive() { liveBlocks = []; activeBlockId = nil; interimText = ""; interimBuf = ""
        noteBlocks = []; slideStructure = []; conceptMap = []; activeCard = nil; bottomTab = "current"
        sessionSaves = []; sessionSearches = []; coldCallPhase = nil; lastCC = nil; searchCache.removeAll() }

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

    // MARK: - Concept Node → Block Highlighting

    /// When a concept node is tapped, highlight transcript blocks that mention the concept.
    func highlightBlocksForConcept(_ node: ConceptNode) {
        let conceptWords = node.concept.lowercased().split(separator: " ").filter { $0.count > 2 }
        guard !conceptWords.isEmpty else { return }

        let matchingBlockIds = liveBlocks.filter { block in
            let text = block.textEn.lowercased()
            return conceptWords.contains(where: { text.contains($0) })
        }.map(\.id)

        highlightedBlockIds = Set(matchingBlockIds)

        // Auto-clear highlight after 3 seconds
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            highlightedBlockIds = []
        }
    }

    /// Right-click concept node → add to Knowledge Profile
    func addConceptToProfile(_ node: ConceptNode) {
        MemoryService.shared.recordInteraction(concept: node.concept, action: .markKnown)
        showToast("Added \"\(node.concept)\" to Knowledge Profile", type: "info")
    }

    // Debug
    @Published var deepgramStatus = ""; @Published var transcriptsReceived = 0
}
