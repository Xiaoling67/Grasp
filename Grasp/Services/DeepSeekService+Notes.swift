import Foundation

extension DeepSeekService {
    // MARK: - AI Notes

    func generateNoteEntry(slides: [SlideItem], recent: [Block], recentNotes: [NoteBlock], subject: String, styleGuide: String, detailLevel: String) async -> (Int, String)? {
        guard !recent.isEmpty else { return nil }
        let currentBlock = recent.last?.textEn ?? ""
        let priorContext = recent.dropLast().map { $0.textEn }.joined(separator: "\n\n")
        let sc = subject.isEmpty ? "" : "on \"\(subject)\""
        let detailPolicy = noteDetailPolicy(detailLevel)
        let system = "You are a senior AI lecture note-taker inside a polished Mac notes app. Your job is to create notes that a top student would actually keep: accurate, compact, structured, and easy to review. You skip filler, transitions, vague restatements, and anything already noted."

        let recentNotesText = recentNotes.isEmpty ? "(none yet)" :
            recentNotes.map { "- " + $0.displayText }.joined(separator: "\n")

        let prompt: String
        if !slides.isEmpty {
            let st = slides.map { "Slide \($0.index) — \"\($0.title)\"\($0.concepts.isEmpty ? "" : ": " + $0.concepts.joined(separator: ", "))" }.joined(separator: "\n")
            let vi = slides.map { String($0.index) }.joined(separator: ", ")
            prompt = """
            Lecture \(sc).

            Slide structure:
            \(st)

            Recent transcript context (use only to resolve pronouns, continuity, and topic):
            \(priorContext.isEmpty ? "(none)" : priorContext)

            Current sealed block to mine for NEW notes:
            \(currentBlock)

            Notes already taken (do NOT duplicate these):
            \(recentNotesText)

            Student's learned note style:
            \(styleGuide)

            User-selected detail level:
            \(detailPolicy)

            Extract the most important new fact, definition, framework, formula, causal mechanism, comparison, professor-emphasized point, or exam-worthy distinction from the CURRENT sealed block.

            If the content is transitional ("moving on", "as I mentioned", "okay so", "next slide"), filler, or already covered in the notes above, output: {"skip": true}

            Otherwise output a JSON object (no markdown):
            { "slideIndex": <one of: \(vi)>, "content": "<Apple Notes-style outline>", "confidence": <0.0-1.0> }

            Use at most three outline depths:
            1. Main idea, definition, or claim
            1.1 Short explanation or mechanism
            • Concrete example, formula, number, or exception only if present

            Follow the user-selected detail level exactly. No markdown headings. Do not use `1.1.1` or hollow bullets.
            If the content is a comparison, classification, variables, or data, include a compact markdown-style table after the numbered line.
            If the professor signals importance ("remember", "key", "exam", "important", "the point is", "notice"), include an "Exam cue:" or "Key point:" phrase in the note.
            Use precise nouns and numbers from the professor. Do not write generic lines like "This is important" or "The professor explains".
            Use recent transcript context only to understand the current block; do not create a note solely from older context.
            slideIndex = which slide the professor is currently discussing
            confidence = how likely this note is useful and non-duplicative; use <0.55 for weak/filler content.
            """
        } else {
            prompt = """
            Lecture \(sc).

            Recent transcript context (use only to resolve pronouns, continuity, and topic):
            \(priorContext.isEmpty ? "(none)" : priorContext)

            Current sealed block to mine for NEW notes:
            \(currentBlock)

            Notes already taken (do NOT duplicate these):
            \(recentNotesText)

            Student's learned note style:
            \(styleGuide)

            User-selected detail level:
            \(detailPolicy)

            Extract the most important new fact, definition, framework, formula, causal mechanism, comparison, professor-emphasized point, or exam-worthy distinction from the CURRENT sealed block.

            If the content is transitional, filler, or already covered in the notes above, output: {"skip": true}

            Otherwise output a JSON object (no markdown):
            { "slideIndex": 0, "content": "<Apple Notes-style outline>", "confidence": <0.0-1.0> }

            Use at most three outline depths:
            1. Main idea, definition, or claim
            1.1 Short explanation or mechanism
            • Concrete example, formula, number, or exception only if present

            Follow the user-selected detail level exactly. No markdown headings. Do not use `1.1.1` or hollow bullets.
            If the content is a comparison, classification, variables, or data, include a compact markdown-style table after the numbered line.
            If the professor signals importance ("remember", "key", "exam", "important", "the point is", "notice"), include an "Exam cue:" or "Key point:" phrase in the note.
            Use precise nouns and numbers from the professor. Do not write generic lines like "This is important" or "The professor explains".
            Use recent transcript context only to understand the current block; do not create a note solely from older context.
            confidence = how likely this note is useful and non-duplicative; use <0.55 for weak/filler content.
            """
        }
        guard let raw = try? await call(system: system, prompt: prompt, maxTokens: detailLevel == "detailed" ? 360 : 240) else { return nil }
        // Handle skip signal — proper JSON parse to avoid false positives from content text
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if let s = trimmed.firstIndex(of: "{"), let e = trimmed.lastIndex(of: "}"),
           let d = String(trimmed[s...e]).data(using: .utf8),
           let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
           let skip = j["skip"] as? Bool, skip { return nil }
        guard let p = parseJSON(raw), let c = p["content"] as? String, !c.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        if let confidence = p["confidence"] as? Double, confidence < 0.55 { return nil }
        var si = p["slideIndex"] as? Int ?? 0
        if !slides.isEmpty { let v = slides.map(\.index); if !v.contains(si) { si = v.last ?? 0 } }
        let content = c
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (si, content)
    }

    func generateLectureSummary(blocks: [Block], notes: [NoteBlock], subject: String, styleGuide: String, detailLevel: String) async -> String? {
        guard !blocks.isEmpty || !notes.isEmpty else { return nil }
        let transcript = blocks.suffix(18).map { $0.textEn }.joined(separator: "\n\n")
        let noteText = notes.map(\.displayText).joined(separator: "\n\n")
        let detailPolicy = summaryDetailPolicy(detailLevel)
        let system = "You are a world-class study-note editor. You turn live rough notes into a concise Apple Notes-style closing summary without losing exam-worthy details."
        let prompt = """
        Course: \(subject.isEmpty ? "Unknown" : subject)

        Existing notes:
        \(noteText.isEmpty ? "(none)" : noteText)

        Student's learned note style:
        \(styleGuide)

        User-selected summary detail:
        \(detailPolicy)

        Recent transcript:
        \(transcript.isEmpty ? "(none)" : transcript)

        Write a final section to append at the end of the student's note document.
        Output plain text only. No JSON. No markdown fences.

        Format exactly:
        Summary
        1. <core idea or takeaway>
        1.1 <mechanism / why it matters>
        • <example, number, formula, or exam cue if present>

        Key Terms
        | Term | Meaning | Why it matters |
        | --- | --- | --- |
        | ... | ... | ... |

        Rules:
        - Follow the user-selected summary detail exactly.
        - Include the table only if at least two real terms are present.
        - Do not duplicate notes verbatim.
        - Prefer concrete details from the lecture over generic study advice.
        """
        guard let raw = try? await call(system: system, prompt: prompt, maxTokens: detailLevel == "detailed" ? 760 : 520) else { return nil }
        let cleaned = raw
            .replacingOccurrences(of: "```markdown", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private func noteDetailPolicy(_ level: String) -> String {
        switch level {
        case "concise":
            return "Concise: output 1 line only, about 12-20 words. Use only `1.`. No table unless the professor gives explicit numbers or a direct comparison."
        case "detailed":
            return "Detailed: output 3-6 lines when useful, about 45-90 words total. Use `1.` for level 1, `1.1` for level 2, and `•` for level 3 examples, formulas, exceptions, and exam cues. Include compact tables for comparisons/data."
        default:
            return "Balanced: output 1-3 lines, about 22-45 words total. Use `1.` for level 1 and `1.1` for level 2; use `•` only for a concrete example, number, formula, or exam cue. Use tables only for clear comparisons/data."
        }
    }

    private func summaryDetailPolicy(_ level: String) -> String {
        switch level {
        case "concise":
            return "Concise: 2-3 numbered takeaways total, no table unless essential."
        case "detailed":
            return "Detailed: 5-7 numbered takeaways total, include mechanisms/examples when available, and include a Key Terms table when real terms are present."
        default:
            return "Balanced: 3-5 numbered takeaways total, include a compact Key Terms table when at least two real terms are present."
        }
    }
}
