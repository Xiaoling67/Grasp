import Foundation

// Spec 7.1-7.2: Data structures matching DB tables + state stores

struct Lecture: Identifiable {
    var id: String; var name: String?; var subject: String?; var mode: String
    var startedAt: Int64; var endedAt: Int64?; var duration: Int?
    var saveCount: Int?; var searchCount: Int?
}

struct Block: Identifiable {
    var id: String; var lectureId: String; var blockIndex: Int
    var textEn: String; var textZh: String?; var isFinal: Int
    var startedAt: Int64; var createdAt: Int64?
}

struct NoteBlock: Identifiable {
    var id: String; var lectureId: String; var slideIndex: Int; var slideTitle: String?
    var content: String; var source: String; var level: Int; var sortOrder: Int; var createdAt: Int64?
}

struct SavedCard: Identifiable {
    var id: String; var lectureId: String?; var blockId: String?; var type: String
    var original: String; var translation: String?; var note: String?
    var createdAt: Int64?; var lectureName: String?; var lectureSubject: String?; var lectureDate: Int64?
}

struct SearchResult: Identifiable {
    var id: String; var lectureId: String?; var blockId: String?; var query: String
    var resultPro: String; var resultSimple: String; var note: String?; var saved: Int
    var createdAt: Int64?; var lectureName: String?; var lectureSubject: String?; var lectureDate: Int64?
}

struct SlideItem: Codable { var index: Int; var title: String; var concepts: [String]; var keywords: [String] }

// UI state
struct LiveBlock: Identifiable { let id: String; var blockIndex: Int; var textEn: String; var textZh: String?; var isSealed: Bool; var createdAt: Int64? }
struct TabItem: Identifiable { var id: String; var type: TabType; var lectureId: String?; var label: String; enum TabType { case live, past } }
enum AppPage { case home, settings, saved, searched }
struct SaveDraft { var type: String; var original: String; var translation: String?; var lectureId: String? }
struct SearchResultState: Identifiable { var id: String; var query: String; var professional: String = ""; var intuition: String = ""; var error: String? = nil }
enum ActiveCardState { case search(SearchResultState); case save(SaveDraft) }
struct ColdCallAnswer { var questionType: String; var shortAnswer: String; var supportingPoints: [String] }
enum ColdCallPhase { case detected(String); case generating; case answered(ColdCallAnswer) }
