import Foundation

extension DeepSeekService {
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
}
