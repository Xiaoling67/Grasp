import Foundation

extension DeepSeekService {
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
}
