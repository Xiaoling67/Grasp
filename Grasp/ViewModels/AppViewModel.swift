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

    // Notes (Spec 7.2: notesStore)
    @Published var noteBlocks = [NoteBlock](); @Published var slideStructure = [SlideItem]()

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
    @Published var notesWidth = 300.0

    private let db = DatabaseService.shared; private let ds = DeepSeekService.shared
    private let dg = DeepgramService.shared; private let au = AudioService.shared
    private let tr = QwenTranslationService.shared
    private var interimBuf = ""; private var lastCC: Date?; private var noteTask: Task<Void,Never>?
    private var searchCache = [String:(String,String)]()

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
        let b = LiveBlock(id: UUID().uuidString, blockIndex: liveBlocks.count, textEn: "", isSealed: false)
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
        noteTask?.cancel()
        noteTask = Task { try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            let rb = db.getRecentBlocks(lectureId: lid, beforeIndex: bi+1, limit: 3)
            let sl = db.getSlideStructure(lectureId: lid)
            let rn = Array(noteBlocks.suffix(3))
            if let e = await ds.generateNoteEntry(slides: sl, recent: rb, recentNotes: rn, subject: activeLectureSubject) {
                let t = sl.first(where: { $0.index == e.0 })?.title
                let n = db.saveNoteBlock(lectureId: lid, slideIndex: e.0, slideTitle: t, content: e.1, source: "ai", level: e.2)
                noteBlocks.append(n)
            }
        }
        // Auto-explain: runs fully in parallel, does not affect NoteAgent
        let capturedText = text; let capturedLid = lid
        Task { await autoExplain(text: capturedText, lectureId: capturedLid) }
        detectCC(text)
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
    func generateCCAnswer(q: String) async {
        guard let lid = activeLectureId else { return }
        coldCallPhase = .generating
        let ctx = db.getRecentBlocks(lectureId: lid, beforeIndex: 9999, limit: 15)
        let sl = db.getSlideStructure(lectureId: lid)
        let rn = Array(noteBlocks.suffix(10))
        if let a = await ds.generateColdCallAnswer(question: q, context: ctx, slides: sl, recentNotes: rn, subject: activeLectureSubject) {
            coldCallPhase = .answered(a)
        } else { coldCallPhase = nil }
    }
    func dismissCC() { coldCallPhase = nil }

    // MARK: - Auto Explain
    private func autoExplain(text: String, lectureId: String) async {
        guard let detected = await ds.detectUnfamiliarTerm(text: text, subject: activeLectureSubject, knownTerms: recentlyExplained) else { return }
        guard detected.confidence > 0.65 else { return }
        let key = detected.term.lowercased()
        guard !recentlyExplained.contains(key) else { return }
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
            db.saveSearch(id: rid, lectureId: lectureId, query: detected.term, resultPro: pro, resultSimple: intu)
            sessionSearches.insert(r, at: 0)
        } catch { autoExplainStreaming = false }
    }

    func dismissAutoExplain() { autoExplainResult = nil; autoExplainNew = false; autoExplainTokens = "" }
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
    }
    func closeTab(id: String) { tabs.removeAll { $0.id == id }; if activeTabId == id { activeTabId = tabs.last?.id } }

    // MARK: - Toast
    func showToast(_ m: String, type: String = "info") { toastMessage = m; toastType = type
        Task { try? await Task.sleep(nanoseconds: 3_000_000_000); toastMessage = nil } }

    // MARK: - Reset
    private func resetLive() { liveBlocks = []; activeBlockId = nil; interimText = ""; interimBuf = ""
        noteBlocks = []; slideStructure = []; activeCard = nil; bottomTab = "current"
        sessionSaves = []; sessionSearches = []; coldCallPhase = nil; lastCC = nil; searchCache.removeAll() }

    // Debug
    @Published var deepgramStatus = ""; @Published var transcriptsReceived = 0
}
