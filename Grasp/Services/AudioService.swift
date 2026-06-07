import AVFoundation

final class AudioService {
    static let shared = AudioService()
    private var engine: AVAudioEngine?
    private var onChunk: ((Data, Double) -> Void)?
    private(set) var sampleRate: Double = 44100

    static func requestPermission() async -> Bool {
        await withCheckedContinuation { c in AVCaptureDevice.requestAccess(for: .audio) { c.resume(returning: $0) } }
    }

    func startCapture(onChunk: @escaping (Data, Double) -> Void) throws {
        self.onChunk = onChunk
        let engine = AVAudioEngine()
        let node = engine.inputNode
        let fmt = node.outputFormat(forBus: 0)
        sampleRate = fmt.sampleRate
        let bs = AVAudioFrameCount(fmt.sampleRate * 0.1)

        node.installTap(onBus: 0, bufferSize: bs, format: fmt) { [weak self] buf, _ in
            guard let self, let ch = buf.floatChannelData else { return }
            let n = Int(buf.frameLength), nc = Int(buf.format.channelCount)
            guard n > 0 else { return }
            var pcm = [Int16](repeating: 0, count: n)
            for i in 0..<n {
                var s: Float = 0
                for c in 0..<nc { s += ch[c][i] }
                pcm[i] = Int16(max(-1, min(1, s / Float(nc))) * Float(Int16.max))
            }
            self.onChunk?(pcm.withUnsafeBytes { Data($0) }, self.sampleRate)
        }
        try engine.start()
        self.engine = engine
    }

    func stopCapture() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop(); engine = nil; onChunk = nil
    }
}
