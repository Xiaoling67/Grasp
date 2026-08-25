import AVFoundation
import ScreenCaptureKit

final class AudioService: NSObject {
    static let shared = AudioService()
    private var engine: AVAudioEngine?
    private var stream: SCStream?
    private let streamQueue = DispatchQueue(label: "grasp.system-audio")
    private var onChunk: ((Data, Double) -> Void)?
    private(set) var sampleRate: Double = 44100
    private(set) var isSystemAudio = false

    enum CaptureError: Error {
        case noAudioSource
    }

    static func requestPermission() async -> Bool {
        await withCheckedContinuation { c in AVCaptureDevice.requestAccess(for: .audio) { c.resume(returning: $0) } }
    }

    func startCapture(onChunk: @escaping (Data, Double) -> Void) async throws {
        stopCapture()
        self.onChunk = onChunk
        if #available(macOS 13.0, *) {
            do {
                try await startSystemAudioCapture()
                return
            } catch {
                isSystemAudio = false
            }
        }
        guard await Self.requestPermission() else { throw CaptureError.noAudioSource }
        try startMicrophoneCapture()
    }

    private func startMicrophoneCapture(asFallback: Bool = true) throws {
        let engine = AVAudioEngine()
        let node = engine.inputNode
        let fmt = node.outputFormat(forBus: 0)
        if asFallback {
            sampleRate = fmt.sampleRate
            isSystemAudio = false
        } else if abs(fmt.sampleRate - sampleRate) > 1 {
            return
        }
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

    @available(macOS 13.0, *)
    private func startSystemAudioCapture() async throws {
        let content = try await SCShareableContent.current
        guard let display = content.displays.first else { throw CaptureError.noAudioSource }

        let config = SCStreamConfiguration()
        config.width = 2
        config.height = 2
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        let micRate = AVAudioEngine().inputNode.outputFormat(forBus: 0).sampleRate
        config.sampleRate = Int(micRate > 0 ? micRate : 48_000)
        config.channelCount = 1

        let stream = SCStream(
            filter: SCContentFilter(display: display, excludingWindows: []),
            configuration: config,
            delegate: nil
        )
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: streamQueue)
        try await stream.startCapture()
        sampleRate = Double(config.sampleRate)
        isSystemAudio = true
        self.stream = stream
        if await Self.requestPermission() {
            try? startMicrophoneCapture(asFallback: false)
        }
    }

    func stopCapture() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop(); engine = nil
        if let stream {
            Task { try? await stream.stopCapture() }
            self.stream = nil
        }
        onChunk = nil
        isSystemAudio = false
    }
}

@available(macOS 13.0, *)
extension AudioService: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, sampleBuffer.isValid, let onChunk else { return }

        var bufferList = AudioBufferList()
        var blockBuffer: CMBlockBuffer?
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: &bufferList,
            bufferListSize: MemoryLayout<AudioBufferList>.size,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        guard status == noErr else { return }

        let buffer = bufferList.mBuffers
        guard let data = buffer.mData else { return }
        let sampleCount = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
        guard sampleCount > 0 else { return }

        let samples = data.assumingMemoryBound(to: Float.self)
        var pcm = [Int16]()
        pcm.reserveCapacity(sampleCount)
        for i in 0..<sampleCount {
            pcm.append(Int16(max(-1, min(1, samples[i])) * Float(Int16.max)))
        }
        onChunk(pcm.withUnsafeBytes { Data($0) }, sampleRate)
        _ = blockBuffer
    }
}
