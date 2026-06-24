import Foundation

// Spec 6.3: Qwen-MT Flash (US region) with DeepSeek fallback
final class QwenTranslationService {
    static let shared = QwenTranslationService()
    private let qk = Secrets.qwenApiKey, dk = Secrets.deepseekApiKey
    private let qURL = URL(string: "https://dashscope-us.aliyuncs.com/compatible-mode/v1/chat/completions")!
    private let dURL = URL(string: "https://api.deepseek.com/chat/completions")!

    func translate(text: String, subject: String?) async throws -> String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return "" }
        if let r = try? await qwen(t) { return r }
        return try await deepseek(t, subject: subject)
    }

    private func qwen(_ t: String) async throws -> String {
        var r = URLRequest(url: qURL); r.httpMethod = "POST"
        r.setValue("Bearer \(qk)", forHTTPHeaderField: "Authorization")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type"); r.timeoutInterval = 15
        let b: [String: Any] = ["model":"qwen-mt-flash", "messages":[["role":"user","content":t]], "translation_options":["source_lang":"auto","target_lang":"Chinese"]]
        r.httpBody = try JSONSerialization.data(withJSONObject: b)
        let (d, _) = try await URLSession.shared.data(for: r)
        let j = try JSONSerialization.jsonObject(with: d) as? [String: Any]
        return ((j?["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any])?["content"] as? String ?? ""
    }

    private func deepseek(_ t: String, subject: String?) async throws -> String {
        var r = URLRequest(url: dURL); r.httpMethod = "POST"
        r.setValue("Bearer \(dk)", forHTTPHeaderField: "Authorization")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type"); r.timeoutInterval = 15
        let sc = subject.map { " The lecture is about \"\($0)\" — preserve domain-specific terms consistently (e.g. keep English abbreviations like NPV, GDP, or translate them uniformly)." } ?? ""
        let b: [String: Any] = ["model":"deepseek-chat", "messages":[["role":"system","content":"You are a professional academic translator. Translate English university lecture speech to natural, fluent Simplified Chinese.\(sc) Preserve technical terms consistently. Return ONLY the translation — no notes, no explanations, no alternatives."], ["role":"user","content":t]], "stream":false, "max_tokens":1000]
        r.httpBody = try JSONSerialization.data(withJSONObject: b)
        let (d, _) = try await URLSession.shared.data(for: r)
        let j = try JSONSerialization.jsonObject(with: d) as? [String: Any]
        return ((j?["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any])?["content"] as? String ?? ""
    }
}
