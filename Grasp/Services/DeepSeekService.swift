import Foundation

// Spec 6.2-6.8: deepseek-chat for search/notes/coldcall
final class DeepSeekService {
    static let shared = DeepSeekService()
    private let key = Secrets.deepseekApiKey
    private let url = URL(string: "https://api.deepseek.com/chat/completions")!

    // MARK: - AI Search (Spec 6.5, streaming, max_tokens=150)

    func streamSearch(query: String, context: [Block], subject: String, onToken: @escaping (String) -> Void) async throws -> String {
        let ctx = context.map { $0.textEn }.joined(separator: "\n\n")
        let prompt = """
        You are a concise study-card generator. A student highlighted a term during a university lecture and needs an instant explanation.

        Course: \(subject.isEmpty ? "Unknown" : subject)
        Recent lecture transcript (for context only):
        \(ctx.isEmpty ? "(no prior context)" : ctx)

        Term to explain: "\(query)"

        Rules:
        - Output exactly 2 sentences separated by " | ". No headers, no labels, no markdown.
        - NEVER start with "The professor", "In this lecture", "The transcript", "As mentioned", or any meta-reference to the lecture or speaker.
        - If the highlighted text is a phrase or concept rather than a single term, explain the core idea directly.

        Sentence 1 (max 50 words): A direct, self-contained definition of "\(query)" grounded in the lecture context. Start with the term itself or a direct statement about what it is.
        Sentence 2 (max 25 words): One concrete everyday analogy for someone with zero prior knowledge of \(subject.isEmpty ? "the subject" : subject). No jargon.
        """
        return try await stream(prompt: prompt, maxTokens: 150, onToken: onToken)
    }

    // MARK: - AI Notes (Spec 6.6, max_tokens=100)

    func generateNoteEntry(slides: [SlideItem], recent: [Block], subject: String) async -> (Int, String, Int)? {
        guard !recent.isEmpty else { return nil }
        let tx = recent.map { $0.textEn }.joined(separator: "\n\n")
        let sc = subject.isEmpty ? "" : "on \"\(subject)\""

        let prompt: String
        if !slides.isEmpty {
            let st = slides.map { "Slide \($0.index) — \"\($0.title)\"\($0.concepts.isEmpty ? "" : ": " + $0.concepts.joined(separator: ", "))" }.joined(separator: "\n")
            let vi = slides.map { String($0.index) }.joined(separator: ", ")
            prompt = """
            You are taking notes for a live university lecture \(sc).

            Course structure:
            \(st)

            Recent transcript:
            \(tx)

            Generate ONE concise note entry based on the most recent key point in the transcript.
            Output ONLY a JSON object (no markdown):
            { "slideIndex": <one of: \(vi)>, "content": "<concise phrase or sentence, under 20 words>", "level": <0, 1, or 2> }

            level 0 = main concept or key term (use sparingly, for truly top-level ideas)
            level 1 = supporting point or explanation (most notes should be level 1)
            level 2 = specific detail, example, or sub-point
            slideIndex must match which slide topic the professor is currently discussing.
            """
        } else {
            prompt = """
            You are taking notes for a live university lecture \(sc).

            Recent transcript:
            \(tx)

            Generate ONE concise note entry based on the most recent key point in the transcript.
            Output ONLY a JSON object (no markdown):
            { "slideIndex": 0, "content": "<concise phrase or sentence, under 20 words>", "level": <0, 1, or 2> }

            level 0 = main concept, level 1 = supporting point (default), level 2 = specific detail
            """
        }
        guard let raw = try? await call(prompt: prompt, maxTokens: 100),
              let p = parseJSON(raw), let c = p["content"] as? String, !c.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        var si = p["slideIndex"] as? Int ?? 0
        if !slides.isEmpty { let v = slides.map(\.index); if !v.contains(si) { si = v.last ?? 0 } }
        let lv = [0,1,2].contains(p["level"] as? Int ?? -1) ? p["level"] as! Int : 1
        return (si, c.trimmingCharacters(in: .whitespaces), lv)
    }

    // MARK: - Slide Structure (Spec 6.8, max_tokens=600)

    func generateSlideStructure(slides: [[String: String]], subject: String) async -> [SlideItem] {
        let st = slides.enumerated().map { i, s in "=== SLIDE \(i+1) ===\n\(s["text"] ?? "")" }.joined(separator: "\n\n")
        let sc = subject.isEmpty ? "" : "on \"\(subject)\""
        let prompt = """
        You are processing lecture slides for a university course \(sc).
        Extract a course structure from the \(slides.count) slides below (separated by === SLIDE N ===).

        \(st)

        Return a JSON array where each element is:
        { "index": <0-based>, "title": "<2-8 word topic>", "concepts": ["<concept>", ...], "keywords": ["<term>", ...] }

        Rules: index is 0-based. title is the main topic. 2-3 concepts. 3-5 keywords.
        Output ONLY the JSON array, no explanation, no markdown fences.
        """
        guard let raw = try? await call(prompt: prompt, maxTokens: 600),
              let d = raw.trimmingCharacters(in: .whitespaces).data(using: .utf8),
              let items = try? JSONDecoder().decode([SlideItem].self, from: d) else {
            return slides.enumerated().map { SlideItem(index: $0, title: $1["title"] ?? "Slide \($0+1)", concepts: [], keywords: []) }
        }
        return items
    }

    // MARK: - Cold Call (Spec 6.7, max_tokens=300)

    func generateColdCallAnswer(question: String, context: [Block], slides: [SlideItem], subject: String) async -> ColdCallAnswer? {
        let tx = context.map { $0.textEn }.joined(separator: "\n\n")
        let st = slides.map { "- \($0.title)\($0.concepts.isEmpty ? "" : ": " + $0.concepts.joined(separator: ", "))" }.joined(separator: "\n")
        let prompt = """
        You are a real-time study assistant helping a student answer a professor's cold-call question during a live university lecture.

        Course: \(subject.isEmpty ? "Unknown" : subject)
        \(st.isEmpty ? "" : "Course topics covered:\n\(st)\n")
        Recent transcript (chronological):
        \(tx.isEmpty ? "(no prior transcript)" : tx)

        The professor just asked: "\(question)"

        Based ONLY on what was discussed in the lecture transcript above, generate a helpful answer.
        Do NOT introduce knowledge beyond what was mentioned in the lecture.

        Output ONLY a JSON object (no markdown fences):
        {
          "questionType": "<one of: Concept Explanation | Applied Analysis | Opinion Expression | Recall>",
          "shortAnswer": "<2-3 sentences, max 60 words, directly answering the question>",
          "supportingPoints": ["<point referencing lecture content>", "<point referencing lecture content>"]
        }
        """
        guard let raw = try? await call(prompt: prompt, maxTokens: 300),
              let p = parseJSON(raw), let sa = p["shortAnswer"] as? String else { return nil }
        return ColdCallAnswer(questionType: p["questionType"] as? String ?? "Concept Explanation", shortAnswer: sa, supportingPoints: p["supportingPoints"] as? [String] ?? [])
    }

    // MARK: - HTTP helpers

    private func call(prompt: String, maxTokens: Int) async throws -> String {
        var req = URLRequest(url: url); req.httpMethod = "POST"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type"); req.timeoutInterval = 20
        let body: [String: Any] = ["model": "deepseek-chat", "messages": [["role":"system","content":"You are a university lecture assistant. Be concise and accurate."], ["role":"user","content":prompt]], "stream": false, "max_tokens": maxTokens]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: req)
        let j = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return ((j?["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any])?["content"] as? String ?? ""
    }

    private func stream(prompt: String, maxTokens: Int, onToken: @escaping (String) -> Void) async throws -> String {
        var req = URLRequest(url: url); req.httpMethod = "POST"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type"); req.timeoutInterval = 15
        let body: [String: Any] = ["model": "deepseek-chat", "messages": [["role":"system","content":"You are a university lecture assistant. Be concise and accurate."], ["role":"user","content":prompt]], "stream": true, "max_tokens": maxTokens]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (bytes, _) = try await URLSession.shared.bytes(for: req)
        var full = "", buf = ""
        for try await byte in bytes {
            buf.append(String(bytes: [byte], encoding: .utf8) ?? "")
            while let r = buf.range(of: "\n") {
                let line = String(buf[..<r.lowerBound]).trimmingCharacters(in: .whitespaces); buf = String(buf[r.upperBound...])
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
        guard let s = c.firstIndex(of: "{"), let e = c.lastIndex(of: "}"), let d = String(c[s...e]).data(using: .utf8),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return nil }
        return j
    }
}
