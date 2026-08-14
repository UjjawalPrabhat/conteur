import Accelerate
import AVFoundation

actor AudioCapture {
    enum Failure: Error, LocalizedError {
        case permissionDenied
        case formatUnavailable

        var errorDescription: String? {
            switch self {
            case .permissionDenied: "Conteur needs microphone access to hear your story."
            case .formatUnavailable: "This iPhone's microphone format can't be converted for analysis."
            }
        }
    }

    private let engine = AVAudioEngine()
    private let fanout = AudioFanout()

    /// Register before starting. Every consumer receives every chunk.
    func chunks() -> AsyncStream<AudioChunk> {
        fanout.register()
    }

    func start(convertingTo target: AVAudioFormat) async throws {
        guard await AVAudioApplication.requestRecordPermission() else {
            throw Failure.permissionDenied
        }

        try AudioSessionController.activate(.listening)

        let input = engine.inputNode
        let source = input.outputFormat(forBus: 0)
        guard let pipeline = ConversionPipeline(from: source, to: target) else {
            throw Failure.formatUnavailable
        }

        let fanout = fanout
        input.installTap(onBus: 0, bufferSize: 4096, format: source) { buffer, time in
            guard let converted = pipeline.convert(buffer) else { return }
            fanout.yield(
                AudioChunk(
                    buffer: converted,
                    start: pipeline.elapsed(upTo: time),
                    level: buffer.peakAmplitude
                )
            )
        }

        engine.prepare()
        try engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        fanout.finish()
        AudioSessionController.deactivate()
    }
}

/// Duplicates chunks to every consumer. The tap writes from a realtime thread while
/// consumers register from the actor, so the registry is locked. Buffers are large
/// enough (~85ms) that lock contention cannot starve the audio thread.
private final class AudioFanout: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [UUID: AsyncStream<AudioChunk>.Continuation] = [:]

    func register() -> AsyncStream<AudioChunk> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<AudioChunk>.makeStream()
        lock.withLock { continuations[id] = continuation }
        continuation.onTermination = { [weak self] _ in
            guard let self else { return }
            lock.withLock { continuations[id] = nil }
        }
        return stream
    }

    func yield(_ chunk: AudioChunk) {
        let targets = lock.withLock { Array(continuations.values) }
        for target in targets { target.yield(chunk) }
    }

    func finish() {
        let targets = lock.withLock {
            defer { continuations.removeAll() }
            return Array(continuations.values)
        }
        for target in targets { target.finish() }
    }
}

/// Converter state is touched only from the audio tap, which AVAudioEngine invokes
/// serially on a single realtime thread.
private final class ConversionPipeline: @unchecked Sendable {
    private let converter: AVAudioConverter
    private let target: AVAudioFormat
    private var pendingInput: AVAudioPCMBuffer?
    private var origin: AVAudioFramePosition?

    init?(from source: AVAudioFormat, to target: AVAudioFormat) {
        guard let converter = AVAudioConverter(from: source, to: target) else { return nil }
        self.converter = converter
        self.target = target
    }

    /// Seconds since the first tap callback, so timings share an origin with the transcript.
    func elapsed(upTo time: AVAudioTime) -> TimeInterval {
        let origin = origin ?? {
            self.origin = time.sampleTime
            return time.sampleTime
        }()
        return Double(time.sampleTime - origin) / time.sampleRate
    }

    func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        let ratio = target.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1024
        guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else {
            return nil
        }

        // The converter asks for input repeatedly until told there is no more, so the
        // buffer is offered once and then withdrawn to end this conversion pass.
        pendingInput = buffer
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { [self] _, outStatus in
            guard let input = pendingInput else {
                outStatus.pointee = .noDataNow
                return nil
            }
            pendingInput = nil
            outStatus.pointee = .haveData
            return input
        }

        guard status != .error, output.frameLength > 0 else { return nil }
        return output
    }
}

extension AVAudioPCMBuffer {
    var peakAmplitude: Float {
        guard let channel = floatChannelData?[0] else { return 0 }
        var peak: Float = 0
        vDSP_maxmgv(channel, 1, &peak, vDSP_Length(frameLength))
        return peak
    }
}
