import Foundation

extension DeepSeekService {
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
}
