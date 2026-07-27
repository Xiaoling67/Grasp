import Foundation

final class DeepSeekService {
    static let shared = DeepSeekService()
    // Internal (not private) so the per-prompt extensions in DeepSeekService+*.swift
    // can call the shared HTTP helpers below.
    let key = Secrets.deepseekApiKey
    let url = URL(string: "https://api.deepseek.com/chat/completions")!

    // MARK: - HTTP helpers

    func call(system: String, prompt: String, maxTokens: Int) async throws -> String {
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

    func stream(system: String, prompt: String, maxTokens: Int, onToken: @escaping (String) -> Void) async throws -> String {
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

    func parseJSON(_ t: String) -> [String: Any]? {
        let c = t.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespaces)
        guard let s = c.firstIndex(of: "{"), let e = c.lastIndex(of: "}"),
              let d = String(c[s...e]).data(using: .utf8),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return nil }
        return j
    }
}
