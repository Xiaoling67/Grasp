import Foundation

final class DeepSeekService {
    static let shared = DeepSeekService()
    private let key = Secrets.deepseekApiKey
    private let url = URL(string: "https://api.deepseek.com/chat/completions")!

    // MARK: - AI Search (streaming, max_tokens=200)

    func streamSearch(query: String, context: [Block], subject: String, customKnowledge: String = "", onToken: @escaping (String) -> Void) async throws -> String {
        let ctx = context.map { $0.textEn }.joined(separator: "\n\n")
        let subjectLabel = subject.isEmpty ? "this subject" : subject
        let system = "You generate instant study cards for students in live university lectures. Be precise, grounded in the lecture, and speak directly to a confused student who just heard this term for the first time."
        let knownTermsList = MemoryService.shared.getKnownTerms()
        let knownTermsBlock = knownTermsList.isEmpty ? "" : "\nKnown terms (the student already understands these — don't waste time explaining them from scratch):\n\(knownTermsList.sorted().joined(separator: ", "))\n"
        let customKnowledgeBlock = customKnowledge.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : "\nStudent-provided existing knowledge:\n\(customKnowledge)\n"
        let prompt = """
        Course: \(subject.isEmpty ? "Unknown" : subject)

        What the professor has been explaining:
        \(ctx.isEmpty ? "(lecture just started, no transcript yet)" : ctx)
        \(knownTermsBlock)
        \(customKnowledgeBlock)
        The student just highlighted: "\(query)"

        Write exactly 2 sentences separated by " | ". No markdown, no labels, no headers.

        Sentence 1 (≤ 50 words): Define "\(query)" as it applies in this lecture. Start with the term itself. If "\(query)" doesn't appear in the transcript, give the standard \(subjectLabel) definition.
        Sentence 2 (≤ 25 words): A concrete everyday analogy that requires zero prior knowledge of \(subjectLabel). No jargon.

        Never mention the professor, the lecture, the transcript, or the speaker. Speak as a knowledgeable friend.
        """
        return try await stream(system: system, prompt: prompt, maxTokens: 200, onToken: onToken)
    }

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

    // MARK: - Auto Explain: detect one unfamiliar term (max_tokens=60)

    func detectUnfamiliarTerm(text: String, subject: String, knownTerms: Set<String>, customKnowledge: String = "") async -> (term: String, confidence: Double)? {
        let system = "You identify the single most unfamiliar technical term in a university lecture transcript for a student new to the subject."
        let knownList = knownTerms.isEmpty ? "" : "\nAlready explained — skip these: \(knownTerms.prefix(20).joined(separator: ", "))"
        let customKnowledgeBlock = customKnowledge.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : "\nStudent-provided existing knowledge — skip terms the student says they already know:\n\(customKnowledge)"
        let prompt = """
        Lecture subject: \(subject.isEmpty ? "unknown" : subject)
        What the professor just said: "\(text)"\(knownList)
        \(customKnowledgeBlock)

        Find the ONE term a new student is most likely confused by — technical jargon, abbreviations, formulas, or domain-specific concepts only. Ignore everyday words.
        Output ONLY JSON: {"term": "WACC", "confidence": 0.82}
        If no unfamiliar term, or all terms already explained: {"term": null}
        """
        guard let raw = try? await call(system: system, prompt: prompt, maxTokens: 60),
              let p = parseJSON(raw),
              let term = p["term"] as? String, !term.isEmpty,
              let conf = p["confidence"] as? Double else { return nil }
        return (term, conf)
    }

    // MARK: - Domain Keywords (PRD P1-4, max_tokens=150)

    func generateKeywords(subject: String) async -> [String] {
        let system = "You are a specialist in university course terminology. Output only what is asked."
        let prompt = """
        List 20 technical terms and proper nouns that will appear in a university lecture on "\(subject)".
        Prioritize: abbreviations, formulas, researcher/model names, domain jargon, and multi-word phrases that are hard for speech recognition.
        Focus on terms that sound unusual when spoken aloud.
        Output ONLY a JSON array of strings. No explanation, no markdown.
        Example: ["NPV","IRR","WACC","Modigliani-Miller","discounted cash flow"]
        """
        guard let raw = try? await call(system: system, prompt: prompt, maxTokens: 150) else { return [] }
        let clean = raw.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespaces)
        guard let s = clean.firstIndex(of: "["), let e = clean.lastIndex(of: "]"),
              let d = String(clean[s...e]).data(using: .utf8),
              let terms = try? JSONDecoder().decode([String].self, from: d) else { return [] }
        return terms
    }

    // MARK: - Slide Structure (max_tokens=800)

    func generateSlideStructure(slides: [[String: String]], subject: String) async -> [SlideItem] {
        let st = slides.enumerated().map { i, s in "=== SLIDE \(i+1) ===\n\(s["text"] ?? "(no text)")" }.joined(separator: "\n\n")
        let sc = subject.isEmpty ? "" : " on \"\(subject)\""
        let system = "You extract the academic outline from university lecture slides. Be precise about topics. Distinguish abstract concepts from specific vocabulary."
        let prompt = """
        Build the course outline for a university lecture\(sc) from \(slides.count) slides below.

        \(st)

        For each slide, output ONE JSON object:
        { "index": <0-based>, "title": "<3-6 word topic heading>", "concepts": ["<abstract idea or principle>", ...], "keywords": ["<specific term, formula, acronym, or name>", ...] }

        Rules:
        - title: what this slide teaches, 3-6 words (e.g. "Supply and Demand Curves")
        - concepts: 2-3 abstract ideas or frameworks (e.g. "price elasticity", "opportunity cost") — things you reason about
        - keywords: 3-5 specific terms to recognize when spoken (e.g. "PED", "WACC", "Nash Equilibrium") — things you name or recall
        - Do NOT put the same term in both concepts and keywords
        - If a slide has no text (image/diagram only): {"index": N, "title": "Visual: <topic>", "concepts": [], "keywords": []}
        - index is 0-based
        Output ONLY the JSON array. No markdown fences. No explanation.
        """
        guard let raw = try? await call(system: system, prompt: prompt, maxTokens: 800),
              let d = raw.trimmingCharacters(in: .whitespaces).data(using: .utf8),
              let items = try? JSONDecoder().decode([SlideItem].self, from: d) else {
            return slides.enumerated().map { SlideItem(index: $0, title: $1["title"] ?? "Slide \($0+1)", concepts: [], keywords: []) }
        }
        return items
    }

    // MARK: - Cold Call (max_tokens=300)

    func generateColdCallAnswer(question: String, context: [Block], slides: [SlideItem], recentNotes: [NoteBlock], subject: String) async -> ColdCallAnswer? {
        let tx = context.map { $0.textEn }.joined(separator: "\n\n")
        let st = slides.map { "- \($0.title)\($0.concepts.isEmpty ? "" : ": " + $0.concepts.joined(separator: ", "))" }.joined(separator: "\n")
        let notesText = recentNotes.isEmpty ? "(none)" : recentNotes.map { "- " + $0.displayText }.joined(separator: "\n")
        let subjectLabel = subject.isEmpty ? "this subject" : subject
        let system = "You help a student prepare a spoken answer to their professor's cold-call question. Your answer must be concise enough to say aloud in 30 seconds and grounded in what was taught today."
        let knownTermsList = MemoryService.shared.getKnownTerms()
        let knownTermsBlock = knownTermsList.isEmpty ? "" : "\nKnown terms (the student already understands these):\n\(knownTermsList.joined(separator: ", "))\n"
        let prompt = """
        Course: \(subject.isEmpty ? "Unknown" : subject)
        \(st.isEmpty ? "" : "Topics covered today:\n\(st)\n")
        Key points noted so far:
        \(notesText)

        Recent transcript (what the professor has been explaining):
        \(tx.isEmpty ? "(no transcript yet)" : tx)
        \(knownTermsBlock)
        The professor just asked: "\(question)"

        Generate a helpful spoken answer. Prioritize information from the transcript and notes above. If the transcript doesn't directly address the question, supplement with standard \(subjectLabel) knowledge — but prefer lecture content.

        Output ONLY this JSON (no markdown):
        {
          "questionType": "<one of: Concept Explanation | Applied Analysis | Opinion Expression | Recall>",
          "shortAnswer": "<2-3 sentences, ≤ 60 words, answer the question directly and confidently>",
          "supportingPoints": ["<specific point from today's lecture or notes>", "<specific point from today's lecture or notes>"]
        }
        """
        guard let raw = try? await call(system: system, prompt: prompt, maxTokens: 300),
              let p = parseJSON(raw), let sa = p["shortAnswer"] as? String else { return nil }
        return ColdCallAnswer(questionType: p["questionType"] as? String ?? "Concept Explanation", shortAnswer: sa, supportingPoints: p["supportingPoints"] as? [String] ?? [])
    }

    // MARK: - HTTP helpers

    private func call(system: String, prompt: String, maxTokens: Int) async throws -> String {
        var req = URLRequest(url: url); req.httpMethod = "POST"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 20
        let body: [String: Any] = [
            "model": "deepseek-chat",
            "messages": [["role": "system", "content": system], ["role": "user", "content": prompt]],
            "stream": false,
            "max_tokens": maxTokens
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: req)
        let j = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return ((j?["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any])?["content"] as? String ?? ""
    }

    private func stream(system: String, prompt: String, maxTokens: Int, onToken: @escaping (String) -> Void) async throws -> String {
        var req = URLRequest(url: url); req.httpMethod = "POST"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 8
        let body: [String: Any] = [
            "model": "deepseek-chat",
            "messages": [["role": "system", "content": system], ["role": "user", "content": prompt]],
            "stream": true,
            "max_tokens": maxTokens
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (bytes, _) = try await URLSession.shared.bytes(for: req)
        var full = "", buf = ""
        for try await byte in bytes {
            buf.append(String(bytes: [byte], encoding: .utf8) ?? "")
            while let r = buf.range(of: "\n") {
                let line = String(buf[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
                buf = String(buf[r.upperBound...])
                guard line.hasPrefix("data:"), line != "data: [DONE]" else { continue }
                if let d = line.dropFirst(5).trimmingCharacters(in: .whitespaces).data(using: .utf8),
                   let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                   let tok = ((j["choices"] as? [[String: Any]])?.first?["delta"] as? [String: Any])?["content"] as? String {
                    full += tok; onToken(tok)
                }
            }
        }
        return full
    }

    private func parseJSON(_ t: String) -> [String: Any]? {
        let c = t.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespaces)
        guard let s = c.firstIndex(of: "{"), let e = c.lastIndex(of: "}"),
              let d = String(c[s...e]).data(using: .utf8),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return nil }
        return j
    }
}
