import Foundation

extension AppViewModel {
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

    // MARK: - Reset
    func resetLive() { liveBlocks = []; activeBlockId = nil; interimText = ""; interimBuf = ""
        noteBlocks = []; slideStructure = []; activeCard = nil; bottomTab = "current"
        sessionSaves = []; sessionSearches = []; coldCallPhase = nil; lastCC = nil; searchCache.removeAll()
        pendingNoteRequest = nil; noteAgentBusy = false
        autoExplainResult = nil; autoExplainStreaming = false; autoExplainTokens = ""
        autoExplainNew = false; recentlyExplained.removeAll(); autoExplainBusy = false }
}
