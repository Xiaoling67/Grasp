import Foundation
import SwiftUI

extension AppViewModel {
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

    func loadNotePreferences() {
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
}
