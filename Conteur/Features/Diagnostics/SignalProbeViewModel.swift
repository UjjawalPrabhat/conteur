import Foundation
import Observation

@MainActor
@Observable
final class SignalProbeViewModel {
    enum State: Equatable {
        case idle
        case preparing
        case listening
        case finished
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var timeline = FeatureTimeline.empty

    private let transcriber: any Transcribing
    private let audio = AudioCapture()
    private let delivery = DeliveryAnalyzer()
    private let prosody = ProsodyAnalyzer()
    private var session: Task<Void, Never>?

    private var transcript = Transcript.empty
    private var frames: [ProsodyFrame] = []

    init(transcriber: any Transcribing) {
        self.transcriber = transcriber
    }

    var isListening: Bool { state == .listening }

    func start() {
        guard session == nil else { return }
        state = .preparing
        reset()

        session = Task {
            do {
                let format = try await transcriber.preferredAudioFormat()
                let speech = await audio.chunks()
                let sound = await audio.chunks()

                try await audio.start(convertingTo: format)
                state = .listening

                await withTaskGroup { group in
                    group.addTask { [weak self] in await self?.consumeTranscript(of: speech) }
                    group.addTask { [weak self] in await self?.consumeProsody(of: sound) }
                }

                if case .failed = state {} else { state = .finished }
            } catch {
                state = .failed(error.localizedDescription)
            }
            session = nil
        }
    }

    func stop() async {
        await audio.stop()
        await session?.value
    }

    private func consumeTranscript(of chunks: AsyncStream<AudioChunk>) async {
        do {
            for try await update in transcriber.transcribe(chunks) {
                transcript = update
                rebuild()
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func consumeProsody(of chunks: AsyncStream<AudioChunk>) async {
        for await frame in prosody.frames(from: chunks) {
            frames.append(frame)
            rebuild()
        }
    }


    private func rebuild() {
        timeline = FeatureTimeline(
            transcript: transcript,
            delivery: delivery.analyze(transcript),
            prosody: frames,
        )
    }

    private func reset() {
        transcript = .empty
        frames = []
        timeline = .empty
    }
}
