#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "PASS: $1"
}

require_pattern() {
  local pattern="$1"
  local path="$2"
  local label="$3"
  if rg -q "$pattern" "$path"; then
    pass "$label"
  else
    fail "$label"
  fi
}

reject_pattern() {
  local pattern="$1"
  local path="$2"
  local label="$3"
  if rg -q "$pattern" "$path"; then
    rg "$pattern" "$path" >&2
    fail "$label"
  else
    pass "$label"
  fi
}

reject_pattern "ConceptNode|conceptMap|buildConceptTree|flattenNode|collectChildren|conceptNodeView|conceptSlideSection" "Grasp" "No concept-map/tree implementation remains in app source"
reject_pattern "ColdCall|coldCall|COLD CALL|Cold Call|cold call|generateColdCallAnswer|ColdCallAnswer|ColdCallPhase" "Grasp" "Cold Call is removed from the current app source"
reject_pattern "level 0" "Grasp/Services/DeepSeekService.swift" "AI note generator no longer asks for DB hierarchy levels"
reject_pattern "100\\), 750|100\\.\\.\\.750" "Grasp/Views/Transcript/SelectionPopupView.swift" "Selection popup does not use hardcoded x bounds"

require_pattern "2384E8|EAF5FF|CFEAFF" "Grasp/Views/Color+Hex.swift" "Current Grasp blue system is centralized"
require_pattern "appBackground[[:space:]]*= Color\\(hex: \"FFFFFF\"\\)|warmCream[[:space:]]*= Color\\(hex: \"FFFFFF\"\\)|surfacePrimary[[:space:]]*= Color\\(hex: \"FFFFFF\"\\)" "Grasp/Views/Color+Hex.swift" "Live lecture content surfaces use pure white"
reject_pattern "F3FBF5|F7FCF8|DFF6EA|8FCEAA|ECFAF3|239B63|34C759|NSColor\\.systemGreen|Color\\.systemGreen" "Grasp/Views/Color+Hex.swift" "Green-tinted UI color values are removed from design tokens"
require_pattern "design: \\.rounded|graspRounded" "Grasp/Views/InterFont.swift" "UI uses rounded macOS typography"
require_pattern "PanelHeaderView|gearshape|PanelInfoSettingsPopover" "Grasp/Views/Layout/LiveTabView.swift" "Four-quadrant panels use unified headers with settings gears"
require_pattern "foregroundColor\\(\\.nearBlack\\)" "Grasp/Views/Layout/LiveTabView.swift" "Four-quadrant panel titles use near-black text"
require_pattern "VerticalDragHandle|resizeLeftRight|resizeUpDown|topRowRatio|notesWidth" "Grasp/Views/Layout/LiveTabView.swift" "Four live panels can be resized with vertical and horizontal drag handles"

require_pattern "generateNoteEntry" "Grasp/ViewModels/AppViewModel.swift" "Sealed transcript blocks trigger AI note generation"
require_pattern "source: \"ai\"" "Grasp/ViewModels/AppViewModel.swift" "AI-generated notes are marked with source=ai"
require_pattern "await task.value|noteTask.*value" "Grasp/ViewModels/AppViewModel.swift" "Stopping waits for the latest AI note task"
require_pattern "appendLectureSummary|generateLectureSummary" "Grasp/ViewModels/AppViewModel.swift" "Stopping appends a lecture summary"
require_pattern "aiNotesStatus" "Grasp/ViewModels/AppViewModel.swift" "AI Notes generation status is stored in app state"
require_pattern "noteStyleGuide|learnNoteStyle|inferNoteStyleGuide" "Grasp/ViewModels/AppViewModel.swift" "AI Notes learn local style from user edits"
require_pattern "db\\.setSetting\\(key: \"noteStyleGuide\"" "Grasp/ViewModels/AppViewModel.swift" "Learned note style is persisted locally"
require_pattern "aiNoteDetailLevel|setAINoteDetailLevel|detailLabel" "Grasp/ViewModels/AppViewModel.swift" "AI Notes expose a user-selected detail level"
require_pattern "db\\.setSetting\\(key: \"aiNoteDetailLevel\"" "Grasp/ViewModels/AppViewModel.swift" "AI Notes detail level is persisted locally"
require_pattern "aiNoteFramework|setAINoteFramework|notePromptStyleGuide" "Grasp/ViewModels/AppViewModel.swift" "AI Notes accept a user-defined note framework"
require_pattern "autoExplainKnowledge|setAutoExplainKnowledge|knowledgeTerms" "Grasp/ViewModels/AppViewModel.swift" "Auto Explain accepts user-provided existing knowledge"
require_pattern "displayFontSize|setDisplayFontSize|showTranslation|setShowTranslation|hoverFreezeEnabled|setHoverFreezeEnabled" "Grasp/ViewModels/AppViewModel.swift" "Display settings are stored in app state"
require_pattern "displayFontSize|showTranslation|hoverFreezeEnabled" "Grasp/ViewModels/AppViewModel.swift" "Display settings are loaded from local settings"
require_pattern "isDuplicateAINote|Duplicate skipped|normalizedNoteText" "Grasp/ViewModels/AppViewModel.swift" "AI Notes are locally duplicate-checked before save"
require_pattern "capturedRecentTranscript|suffix\\(4\\)|noteContext" "Grasp/ViewModels/AppViewModel.swift" "AI Notes use a rolling transcript context window"
require_pattern "aiNotesStatus" "Grasp/Views/Notes/NotesPanelView.swift" "Notes header displays AI Notes status"
require_pattern "learnNoteStyle" "Grasp/Views/Notes/NotesPanelView.swift" "Notes editor feeds user edits into style learning"
require_pattern "detailControl|Concise|Balanced|Detailed" "Grasp/Views/Notes/NotesPanelView.swift" "Notes panel exposes Concise/Balanced/Detailed AI detail controls"
require_pattern "AINotesSettingsPopover|Note framework|setAINoteFramework" "Grasp/Views/Notes/NotesPanelView.swift" "AI Notes settings expose detail and note framework controls"
reject_pattern "noteBlocks\\.count|systemName: \"plus\"" "Grasp/Views/Notes/NotesPanelView.swift" "AI Notes header no longer shows count or plus button"
require_pattern "pastelBlueStrong|lightBlueBorder|pastelPink|detailFill|detailBorder" "Grasp/Views/Notes/NotesPanelView.swift" "AI detail controls use color-matched pastel fills and borders"
reject_pattern "NSColor\\.systemGreen|Color\\.systemGreen" "Grasp/Views/Notes/NotesPanelView.swift" "Notes live toolbar no longer uses green accents"
require_pattern "bodyFont|headingFont|subheadingFont|NSColor\\.labelColor|notesHighlightPurple|notesHighlightPink|notesHighlightOrange|notesHighlightBlue" "Grasp/Views/Notes/NotesPanelView.swift" "AI Notes use black native typography with Apple Notes-style highlight colors"
require_pattern "textView\\.backgroundColor = \\.white|scrollView\\.backgroundColor = \\.white|textContainerInset = NSSize\\(width: 40, height: 28\\)|firstLineHeadIndent = 48|firstLineHeadIndent = 78" "Grasp/Views/Notes/NotesPanelView.swift" "AI Notes editor uses pure white background and reference-note spacing"
reject_pattern "Mint|notesHighlightMint|systemMint" "Grasp/Views/Notes/NotesPanelView.swift" "AI Notes highlight palette does not include mint"
reject_pattern "NSColor\\.systemYellow|Color\\.pastelYellow" "Grasp/Views/Notes/NotesPanelView.swift" "Notes live toolbar no longer uses yellow accents"
require_pattern "NotesDocumentEditorView" "Grasp/Views/Notes/NotesPanelView.swift" "Notes panel uses a single document editor"
require_pattern "NSScrollView" "Grasp/Views/Notes/NotesPanelView.swift" "Notes editor is backed by a native NSScrollView"
require_pattern "NotesDocumentFormatter" "Grasp/Views/Notes/NotesPanelView.swift" "Notes document formatting is centralized"
reject_pattern "struct NoteRow|NoteRichEditorView" "Grasp/Views/Notes/NotesPanelView.swift" "Notes panel no longer renders one NSTextView per note row"
require_pattern "formattingToolbar" "Grasp/Views/Notes/NotesPanelView.swift" "Notes panel exposes an Apple Notes-style formatting toolbar"
require_pattern "NotesEditorCommand" "Grasp/Views/Notes/NotesPanelView.swift" "Notes editor supports formatting commands"
require_pattern "insertListMarker|nextNumberedListIndex|toggleItalic|obliqueness" "Grasp/Views/Notes/NotesPanelView.swift" "Notes editor fixes numbered-list sequencing and italic fallback"
require_pattern "documentAttributes: \\[\\.documentType: NSAttributedString.DocumentType.html\\]" "Grasp/Views/Notes/NotesPanelView.swift" "Notes rich text is persisted as HTML"
require_pattern "photo|insertImage|allowedContentTypes = \\[\\.image\\]" "Grasp/Views/Notes/NotesPanelView.swift" "Notes editor exposes image insertion"
require_pattern "grasp-rtf-base64|NSAttributedString.DocumentType.rtf" "Grasp/Views/Notes/NotesPanelView.swift" "Notes with image attachments persist as RTF data"
require_pattern "richTextRTFPrefix|NSAttributedString.DocumentType.rtf" "Grasp/Models/Models.swift" "RTF note storage has readable text fallback"
require_pattern "Use at most three outline depths|1\\.1 Short explanation|• Concrete example" "Grasp/Services/DeepSeekService.swift" "AI notes use number, sub-number, and solid-bullet depths"
require_pattern "confidence|low-confidence|confident" "Grasp/Services/DeepSeekService.swift" "AI notes are quality-gated before append"
require_pattern "styleGuide|Student's learned note style" "Grasp/Services/DeepSeekService.swift" "AI Notes prompts receive the learned style guide"
require_pattern "noteDetailPolicy|summaryDetailPolicy|User-selected detail level|User-selected summary detail" "Grasp/Services/DeepSeekService.swift" "AI Notes prompts receive concrete detail-level policies"
require_pattern "12-20 words|22-45 words|45-90 words" "Grasp/Services/DeepSeekService.swift" "AI Notes detail levels define concrete word-count standards"
require_pattern "Student-provided existing knowledge|customKnowledge" "Grasp/Services/DeepSeekService.swift" "Auto Explain prompts receive user-provided existing knowledge"
require_pattern "Recent transcript context|Current sealed block|Use recent transcript context only" "Grasp/Services/DeepSeekService.swift" "AI Notes distinguish context from the current block"
require_pattern "Exam cue|Key point|professor signals importance" "Grasp/Services/DeepSeekService.swift" "AI Notes capture professor emphasis cues"
require_pattern "generateLectureSummary|Summary|Key Terms" "Grasp/Services/DeepSeekService.swift" "AI Notes can generate an end-of-lecture summary"
require_pattern "tablecells|Topic \\| Detail \\| Example" "Grasp/Views/Notes/NotesPanelView.swift" "Notes editor can insert a table template"
require_pattern "handleCommandN" "Grasp/ViewModels/AppViewModel.swift" "Command-N uses context-aware note/lecture behavior"
require_pattern "newNoteRequest" "Grasp/Views/Notes/NotesPanelView.swift" "Notes panel responds to command-created note requests"
require_pattern "topRowRatio" "Grasp/ViewModels/AppViewModel.swift" "Horizontal divider ratio is stored in app state"
require_pattern "transcriptEnglishFontSize|shouldShowTranslation|hoverFreezeEnabled|isScrollFrozen" "Grasp/Views/Transcript/TranscriptPanelView.swift" "Transcript panel applies display settings"
require_pattern "setDisplayFontSize|setShowTranslation|setHoverFreezeEnabled" "Grasp/Views/Pages/SettingsView.swift" "Settings page controls live display preferences"
require_pattern "SidebarRow|onHover|selected \\? Color\\.pastelBlue" "Grasp/Views/Layout/SidebarView.swift" "Sidebar rows expose hover and selected states"
require_pattern "SQLITE_FLOAT" "Grasp/Services/DatabaseService.swift" "SQLite REAL values are decoded"
require_pattern "sqlite3_bind_double" "Grasp/Services/DatabaseService.swift" "SQLite Double values are bound"

xcodebuild -project Grasp.xcodeproj -scheme Grasp build >/tmp/grasp-v1.1-r3-build.log
pass "xcodebuild Grasp scheme builds"

echo "All v1.1-r3 verification checks passed."
