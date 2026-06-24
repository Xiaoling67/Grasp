import Foundation

final class DeepSeekService {
    static let shared = DeepSeekService()
    private let key = Secrets.deepseekApiKey
    private let url = URL(string: "https://api.deepseek.com/chat/completions")!

    // MARK: - AI Search (streaming, max_tokens=200)

    func streamSearch(query: String, context: [Block], subject: String, onToken: @escaping (String) -> Void) async throws -> String {
        let ctx = context.map { $0.textEn }.joined(separator: "\n\n")
        let subjectLabel = subject.isEmpty ? "this subject" : subject
        let system = "You generate instant study cards for students in live university lectures. Be precise, grounded in the lecture, and speak directly to a confused student who just heard this term for the first time."
        let knownTermsList = MemoryService.shared.getKnownTerms()
        let knownTermsBlock = knownTermsList.isEmpty ? "" : "\nKnown terms (the student already understands these — don't waste time explaining them from scratch):\n\(knownTermsList.sorted().joined(separator: ", "))\n"
        let prompt = """
        Course: \(subject.isEmpty ? "Unknown" : subject)

        What the professor has been explaining:
        \(ctx.isEmpty ? "(lecture just started, no transcript yet)" : ctx)
        \(knownTermsBlock)
        The student just highlighted: "\(query)"

        Write exactly 2 sentences separated by " | ". No markdown, no labels, no headers.

        Sentence 1 (≤ 50 words): Define "\(query)" as it applies in this lecture. Start with the term itself. If "\(query)" doesn't appear in the transcript, give the standard \(subjectLabel) definition.
        Sentence 2 (≤ 25 words): A concrete everyday analogy that requires zero prior knowledge of \(subjectLabel). No jargon.

        Never mention the professor, the lecture, the transcript, or the speaker. Speak as a knowledgeable friend.
        """
        return try await stream(system: system, prompt: prompt, maxTokens: 200, onToken: onToken)
    }

    // MARK: - AI Notes (max_tokens=120)

    func generateNoteEntry(slides: [SlideItem], recent: [Block], recentNotes: [NoteBlock], subject: String) async -> (Int, String, Int)? {
        guard !recent.isEmpty else { return nil }
        let tx = recent.map { $0.textEn }.joined(separator: "\n\n")
        let sc = subject.isEmpty ? "" : "on \"\(subject)\""
        let system = "You are a silent, attentive note-taker at a live university lecture. You capture one key insight at a time in 25 words or fewer. You skip filler, transitions, and anything already noted."

        let recentNotesText = recentNotes.isEmpty ? "(none yet)" :
            recentNotes.map { "- " + $0.content }.joined(separator: "\n")

        let prompt: String
        if !slides.isEmpty {
            let st = slides.map { "Slide \($0.index) — \"\($0.title)\"\($0.concepts.isEmpty ? "" : ": " + $0.concepts.joined(separator: ", "))" }.joined(separator: "\n")
            let vi = slides.map { String($0.index) }.joined(separator: ", ")
            prompt = """
            Lecture \(sc).

            Slide structure:
            \(st)

            What the professor just said:
            \(tx)

            Notes already taken (do NOT duplicate these):
            \(recentNotesText)

            Extract the ONE most important new fact, definition, or concept from what the professor just said.

            If the content is transitional ("moving on", "as I mentioned", "okay so", "next slide"), filler, or already covered in the notes above, output: {"skip": true}

            Otherwise output a JSON object (no markdown):
            { "slideIndex": <one of: \(vi)>, "content": "<direct statement, ≤ 25 words>", "level": <0, 1, or 2> }

            level 0 = the single central thesis of this slide — use at most once per slide, only for the defining idea
            level 1 = a key supporting fact, definition, or explanation (default)
            level 2 = a specific example, number, formula, or sub-detail
            slideIndex = which slide the professor is currently discussing
            """
        } else {
            prompt = """
            Lecture \(sc).

            What the professor just said:
            \(tx)

            Notes already taken (do NOT duplicate these):
            \(recentNotesText)

            Extract the ONE most important new fact, definition, or concept from what the professor just said.

            If the content is transitional, filler, or already covered in the notes above, output: {"skip": true}

            Otherwise output a JSON object (no markdown):
            { "slideIndex": 0, "content": "<direct statement, ≤ 25 words>", "level": <0, 1, or 2> }

            level 0 = central thesis (use sparingly), level 1 = key point (default), level 2 = specific detail
            """
        }
        guard let raw = try? await call(system: system, prompt: prompt, maxTokens: 120) else { return nil }
        // Handle skip signal — proper JSON parse to avoid false positives from content text
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if let s = trimmed.firstIndex(of: "{"), let e = trimmed.lastIndex(of: "}"),
           let d = String(trimmed[s...e]).data(using: .utf8),
           let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
           let skip = j["skip"] as? Bool, skip { return nil }
        guard let p = parseJSON(raw), let c = p["content"] as? String, !c.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        var si = p["slideIndex"] as? Int ?? 0
        if !slides.isEmpty { let v = slides.map(\.index); if !v.contains(si) { si = v.last ?? 0 } }
        let lv = [0,1,2].contains(p["level"] as? Int ?? -1) ? p["level"] as! Int : 1
        return (si, c.trimmingCharacters(in: .whitespaces), lv)
    }

    // MARK: - Auto Explain: detect one unfamiliar term (max_tokens=60)

    func detectUnfamiliarTerm(text: String, subject: String, knownTerms: Set<String>) async -> (term: String, confidence: Double)? {
        let system = "You identify the single most unfamiliar technical term in a university lecture transcript for a student new to the subject."
        let knownList = knownTerms.isEmpty ? "" : "\nAlready explained — skip these: \(knownTerms.prefix(20).joined(separator: ", "))"
        let prompt = """
        Lecture subject: \(subject.isEmpty ? "unknown" : subject)
        What the professor just said: "\(text)"\(knownList)

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

    // MARK: - Concept Map Update (v1.1, max_tokens=1500)

    func generateConceptMapUpdate(windowText: String, existingMap: [ConceptNode], slides: [SlideItem], subject: String) async -> [ConceptNode]? {
        let slidesText = slides.isEmpty ? "(no slides loaded)" :
            slides.map { "Slide \($0.index): \($0.title)" }.joined(separator: "\n")
        let existingJSON: String
        if existingMap.isEmpty {
            existingJSON = "(empty)"
        } else if let d = try? JSONEncoder().encode(existingMap), let s = String(data: d, encoding: .utf8) {
            existingJSON = s
        } else {
            existingJSON = "(empty)"
        }
        let subjectLabel = subject.isEmpty ? "this subject" : subject
        let system = "You are building a structured concept map from a live university lecture.\nYou receive new transcript text every 15 seconds.\n\nYour job: update the existing Concept Map by adding new concepts,\ndeepening existing ones, or skipping transitional/filler content.\n\nRULES:\n1. Return the COMPLETE updated Concept Map (existing nodes + new nodes), not a diff.\n2. Assign each concept a unique ID (UUID format). KEEP existing node IDs unchanged.\n3. parentId of nil means root-level. Use existing node IDs as parentId values.\n4. level 0 = core thesis of the lecture (at most 2-3 total)\n   level 1 = key supporting point (default)\n   level 2 = specific detail, example, or sub-point\n5. content should be 10-60 words — a clear explanation, not just a label.\n6. slideIndex: which slide number this concept belongs to (0-based). Use -1 if no slide.\n7. For transitional content (\"let's move on\", \"as I said before\", \"next slide\"),\n   do NOT add new nodes — but DO update any existing nodes if relevant.\n8. If the new transcript deepens an existing concept, update that node's content\n   (keep the same id) rather than creating a duplicate.\n9. If multiple nodes would have the same concept name, merge them into one node.\n10. Maintain a clean hierarchy: root concepts are broad topics, children are\n    specific points that support the parent."

        let prompt = """
        Subject: \(subjectLabel)

        == SLIDE STRUCTURE ==
        \(slidesText)

        == EXISTING CONCEPT MAP ==
        \(existingJSON)

        == NEW TRANSCRIPT (last 15 seconds) ==
        \(windowText)

        Output ONLY valid JSON — a single object with these fields:
        {
          "nodes": [
            {
              "id": "<existing or new UUID>",
              "concept": "<short concept name, 1-5 words>",
              "parentId": "<existing node id or null>",
              "level": <0|1|2>,
              "content": "<explanation, 10-60 words>",
              "slideIndex": <int>
            }
          ]
        }

        No markdown fences, no explanation, no other text. Return the COMPLETE updated map.
        """
        guard let raw = try? await call(system: system, prompt: prompt, maxTokens: 1500) else { return nil }
        let cleaned = raw.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespaces)
        guard let s = cleaned.firstIndex(of: "{"),
              let e = cleaned.lastIndex(of: "}"),
              let data = String(cleaned[s...e]).data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let nodesArray = json["nodes"] as? [[String: Any]] else {
            // Parse failure — return existing map unchanged
            return existingMap
        }
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        // Build existing map lookup by id
        let existingById = Dictionary(uniqueKeysWithValues: existingMap.map { ($0.id, $0) })
        var parsedNodes = [ConceptNode]()
        for item in nodesArray {
            guard let id = item["id"] as? String, !id.isEmpty else { continue }
            let concept = item["concept"] as? String ?? ""
            guard !concept.isEmpty else { continue }
            let content = item["content"] as? String ?? ""
            let parentId = item["parentId"] as? String
            let level = [0, 1, 2].contains(item["level"] as? Int ?? -1) ? item["level"] as! Int : 1
            let slideIndex = item["slideIndex"] as? Int ?? -1
            // Preserve original createdAt if node existed before
            let createdAt = existingById[id]?.createdAt ?? nowMs
            let updatedAt = nowMs
            // Preserve lectureId
            let lectureId = existingById[id]?.lectureId ?? ""
            let node = ConceptNode(id: id, concept: concept, parentId: parentId, level: level, content: content, slideIndex: slideIndex, lectureId: lectureId, createdAt: createdAt, updatedAt: updatedAt)
            parsedNodes.append(node)
        }
        return parsedNodes.isEmpty ? existingMap : parsedNodes
    }

    // MARK: - Cold Call (max_tokens=300)

    func generateColdCallAnswer(question: String, context: [Block], slides: [SlideItem], recentNotes: [NoteBlock], subject: String) async -> ColdCallAnswer? {
        let tx = context.map { $0.textEn }.joined(separator: "\n\n")
        let st = slides.map { "- \($0.title)\($0.concepts.isEmpty ? "" : ": " + $0.concepts.joined(separator: ", "))" }.joined(separator: "\n")
        let notesText = recentNotes.isEmpty ? "(none)" : recentNotes.map { "- " + $0.content }.joined(separator: "\n")
        let subjectLabel = subject.isEmpty ? "this subject" : subject
        let system = "You help a student prepare a spoken answer to their professor's cold-call question. Your answer must be concise enough to say aloud in 30 seconds and grounded in what was taught today."
        let prompt = """
        Course: \(subject.isEmpty ? "Unknown" : subject)
        \(st.isEmpty ? "" : "Topics covered today:\n\(st)\n")
        Key points noted so far:
        \(notesText)

        Recent transcript (what the professor has been explaining):
        \(tx.isEmpty ? "(no transcript yet)" : tx)

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
