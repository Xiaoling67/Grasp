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
    var recentlyExplained = Set<String>()

    // Modals & Toast
    @Published var showNewLectureModal = false; @Published var showExportModal = false
    @Published var showOnboarding = false; @Published var onboardingChecked = false
    @Published var toastMessage: String? = nil; @Published var toastType = "info"

    // Layout — v1.1-r2: all dividers movable; each column's top/bottom split is independent
    @Published var notesWidth = 400.0
    @Published var leftColumnRatio: CGFloat = 0.55  // Transcript vs Auto Explain, range 0.30-0.80
    @Published var rightColumnRatio: CGFloat = 0.55 // Notes vs Save/Search, range 0.30-0.80

    // Shared services + cross-cutting state. Kept internal (not private) so the
    // per-concern extensions in AppViewModel+*.swift can use them — Swift extensions
    // in other files can't see `private` members of the primary declaration.
    let db = DatabaseService.shared; let ds = DeepSeekService.shared
    let dg = DeepgramService.shared; let au = AudioService.shared
    let tr = QwenTranslationService.shared
    var interimBuf = ""; var lastCC: Date?; var noteTask: Task<Void,Never>?
    var noteAgentBusy = false
    struct PendingNoteRequest { let lectureId: String; let blockIndex: Int; let text: String }
    var pendingNoteRequest: PendingNoteRequest?
    var activityToken: NSObjectProtocol?
    var autoExplainBusy = false
    var searchCache = [String:(String,String)]()
    let ccPatterns: [NSRegularExpression] = [
        try! NSRegularExpression(pattern: #"\bwho (knows|can tell|can explain|can answer|wants to)\b"#, options: .caseInsensitive),
        try! NSRegularExpression(pattern: #"\bcan (anyone|someone|somebody) (tell|explain|answer|describe|name|give)\b"#, options: .caseInsensitive),
        try! NSRegularExpression(pattern: #"\bdoes anyone (know|remember|recall|have)\b"#, options: .caseInsensitive),
        try! NSRegularExpression(pattern: #"\banyone (know|want to|care to)\b"#, options: .caseInsensitive),
        try! NSRegularExpression(pattern: #"\blet's hear from\b"#, options: .caseInsensitive),
        try! NSRegularExpression(pattern: #"\bwhat do you think\b"#, options: .caseInsensitive),
    ]
    var ccDismissTimer: Timer?

    /// Holds the most recent text selection from the transcript, for keyboard shortcuts.
    static var lastSelectedText: String = ""

    init() { loadPast(); checkOnboarding(); loadNotePreferences() }
}
