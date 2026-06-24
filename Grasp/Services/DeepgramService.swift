import Foundation

// Spec 6.1: Deepgram nova-3 WebSocket streaming
final class DeepgramService: NSObject {
    static let shared = DeepgramService()
    private let key = Secrets.deepgramApiKey
    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    private var timer: Timer?
    private var pending = [Data]()
    private(set) var isConnected = false
    var onFinal: ((String) -> Void)?; var onInterim: ((String) -> Void)?; var onEnd: (() -> Void)?; var onStatus: ((String) -> Void)?

    func connect(sr: Double, keywords: [String] = []) {
        isConnected = false; pending.removeAll()
        var c = URLComponents(); c.scheme = "wss"; c.host = "api.deepgram.com"; c.path = "/v1/listen"
        var items: [URLQueryItem] = [
            URLQueryItem(name: "model", value: "nova-3"),
            URLQueryItem(name: "language", value: "en-US"),
            URLQueryItem(name: "encoding", value: "linear16"),
            URLQueryItem(name: "sample_rate", value: String(Int(sr))),
            URLQueryItem(name: "channels", value: "1"),
            URLQueryItem(name: "interim_results", value: "true"),
            URLQueryItem(name: "punctuate", value: "true"),
            URLQueryItem(name: "smart_format", value: "true"),
            URLQueryItem(name: "filler_words", value: "false"),
            URLQueryItem(name: "utterance_end_ms", value: "2000"),
        ]
        // PRD P1-4: inject domain keywords to improve terminology recognition
        for kw in keywords.prefix(20) { items.append(URLQueryItem(name: "keyterm", value: kw)) }
        c.queryItems = items
        guard let u = c.url else { return }
        let s = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        session = s; task = s.webSocketTask(with: u, protocols: ["token", key])
        task?.resume()
        onStatus?("connecting")
    }

    func sendAudio(_ d: Data) {
        if isConnected { task?.send(.data(d)) { _ in } }
        else if pending.count < 20 { pending.append(d) }
    }

    func disconnect() {
        timer?.invalidate(); timer = nil; isConnected = false
        task?.send(.string(#"{"type":"CloseStream"}"#)) { _ in }
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil; session?.invalidateAndCancel(); session = nil
    }

    private func keepAlive() {
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.task?.send(.string(#"{"type":"KeepAlive"}"#)) { _ in }
        }
    }

    private func recv() {
        task?.receive { [weak self] r in
            guard let self, self.isConnected else { return }
            switch r {
            case .success(let m):
                if case .string(let t) = m { self.handle(t) }
                self.recv()
            case .failure: self.isConnected = false; self.timer?.invalidate()
            }
        }
    }

    private func handle(_ t: String) {
        guard let d = t.data(using: .utf8), let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return }
        let type = j["type"] as? String ?? ""
        if type == "UtteranceEnd" { onEnd?(); return }
        guard type == "Results", let ch = j["channel"] as? [String: Any],
              let alts = ch["alternatives"] as? [[String: Any]],
              let tr = alts.first?["transcript"] as? String, !tr.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        if j["is_final"] as? Bool ?? false { onFinal?(tr) } else { onInterim?(tr) }
    }
}

extension DeepgramService: URLSessionWebSocketDelegate {
    func urlSession(_ s: URLSession, webSocketTask t: URLSessionWebSocketTask, didOpenWithProtocol p: String?) {
        isConnected = true; keepAlive(); recv()
        onStatus?("connected")
        for d in pending { t.send(.data(d)) { _ in } }
        pending.removeAll()
    }
    func urlSession(_ s: URLSession, webSocketTask t: URLSessionWebSocketTask, didCloseWith c: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        isConnected = false; timer?.invalidate()
    }
}
