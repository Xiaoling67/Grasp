import Foundation

extension DeepSeekService {
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
}
