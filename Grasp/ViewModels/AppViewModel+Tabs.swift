import Foundation

extension AppViewModel {
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
}
