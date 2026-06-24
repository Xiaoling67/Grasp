import Foundation

// MARK: - Knowledge Status
enum KnowledgeStatus: String, CaseIterable {
    case neverSeen  = "never_seen"
    case known      = "known"
    case lookedUp   = "looked_up"
    case dismissed  = "dismissed"
    case preventive = "preventive"

    var displayName: String {
        switch self {
        case .neverSeen:  return "Never Seen"
        case .known:      return "Known"
        case .lookedUp:   return "Looked Up"
        case .dismissed:  return "Dismissed"
        case .preventive: return "Preventive"
        }
    }
}

// MARK: - Knowledge Action
enum KnowledgeAction {
    case save
    case search
    case dismiss
    case autoExplain
    case markKnown
    case clearHistory
}

// MARK: - Knowledge Record
struct KnowledgeRecord: Identifiable {
    var id: String { concept }
    let concept: String
    let status: KnowledgeStatus
    let searchCount: Int
    let firstSeenAt: Int64?
    let lastInteractedAt: Int64?
    let source: String
}

// MARK: - MemoryService
final class MemoryService: @unchecked Sendable {
    static let shared = MemoryService()
    private let db = DatabaseService.shared
    private init() {}

    // MARK: - Public API

    /// Looks up a concept and returns its KnowledgeStatus.
    func checkConcept(_ term: String) -> KnowledgeStatus {
        let key = normalize(term)
        guard !key.isEmpty else { return .neverSeen }
        guard let row = db.getKnowledgeRecord(concept: key),
              let rawStatus = row["status"] as? String else {
            return .neverSeen
        }
        return KnowledgeStatus(rawValue: rawStatus) ?? .neverSeen
    }

    /// Records an interaction with a concept.
    func recordInteraction(concept: String, action: KnowledgeAction) {
        let key = normalize(concept)
        guard !key.isEmpty else { return }

        let now = db.now()
        let existing = db.getKnowledgeRecord(concept: key)

        switch action {
        case .save, .markKnown:
            let status = "known"
            let source = existing == nil ? "manual" : (existing?["source"] as? String ?? "auto")
            let searchCount = existing?["search_count"] as? Int64 ?? 0
            let firstSeenAt = existing?["first_seen_at"] as? Int64 ?? now
            db.saveKnowledgeRecord(
                concept: key, status: status,
                searchCount: Int(searchCount),
                firstSeenAt: firstSeenAt,
                lastInteractedAt: now,
                source: source
            )

        case .search:
            let currentStatus = existing.flatMap { $0["status"] as? String } ?? "never_seen"
            let currentSearchCount = existing.flatMap { $0["search_count"] as? Int64 }.map(Int.init) ?? 0
            let newSearchCount = currentSearchCount + 1
            let newStatus: String
            if currentStatus == "never_seen" || currentStatus == "dismissed" {
                newStatus = "looked_up"
            } else if newSearchCount >= 2 {
                newStatus = "preventive"
            } else {
                newStatus = currentStatus
            }
            let source = existing == nil ? "search" : (existing?["source"] as? String ?? "auto")
            let firstSeenAt = existing?["first_seen_at"] as? Int64 ?? now
            db.saveKnowledgeRecord(
                concept: key, status: newStatus,
                searchCount: newSearchCount,
                firstSeenAt: firstSeenAt,
                lastInteractedAt: now,
                source: source
            )

        case .dismiss:
            let status = "dismissed"
            let source = existing?["source"] as? String ?? "auto"
            let searchCount = existing?["search_count"] as? Int64 ?? 0
            let firstSeenAt = existing?["first_seen_at"] as? Int64 ?? now
            db.saveKnowledgeRecord(
                concept: key, status: status,
                searchCount: Int(searchCount),
                firstSeenAt: firstSeenAt,
                lastInteractedAt: now,
                source: source
            )

        case .autoExplain:
            // Only act if the concept has never been seen before
            guard existing == nil else { return }
            let source = "auto"
            db.saveKnowledgeRecord(
                concept: key, status: "looked_up",
                searchCount: 0,
                firstSeenAt: now,
                lastInteractedAt: now,
                source: source
            )

        case .clearHistory:
            db.clearAllKnowledgeRecords()
        }
    }

    /// Returns the set of concepts the student knows (status = 'known').
    func getKnownTerms() -> Set<String> {
        Set(db.getKnownTerms())
    }

    /// Returns all knowledge records for the editor view.
    func getAllRecords() -> [KnowledgeRecord] {
        db.getAllKnowledgeRecords().map { row in
            KnowledgeRecord(
                concept: row["concept"] as? String ?? "",
                status: KnowledgeStatus(rawValue: row["status"] as? String ?? "never_seen") ?? .neverSeen,
                searchCount: (row["search_count"] as? Int64).map(Int.init) ?? 0,
                firstSeenAt: row["first_seen_at"] as? Int64,
                lastInteractedAt: row["last_interacted_at"] as? Int64,
                source: row["source"] as? String ?? "auto"
            )
        }
    }

    /// Deletes a single concept record.
    func deleteRecord(concept: String) {
        let key = normalize(concept)
        guard !key.isEmpty else { return }
        db.deleteKnowledgeRecord(concept: key)
    }

    /// Adds a concept manually (from the editor). Validates and normalizes input.
    func addManualConcept(_ concept: String) {
        let key = normalize(concept)
        guard !key.isEmpty else { return }
        recordInteraction(concept: key, action: .markKnown)
    }

    // MARK: - Helpers

    private func normalize(_ term: String) -> String {
        term.lowercased().trimmingCharacters(in: .whitespaces)
    }
}
