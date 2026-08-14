import CoreGraphics
import Foundation
import Observation

@MainActor
@Observable
final class SessionViewModel {
    enum Phase: Equatable {
        case ready
        case preparing
        case listening
        case reading
        case responding
        case failed(String)
    }

    private(set) var phase: Phase = .ready
    private(set) var assessment: Assessment?

    /// Drives the listening presence. Smoothed, because the presence should breathe
    /// with the voice rather than twitch at every syllable.
    private(set) var level: Float = 0
    /// True through a pause, when a listener would visibly hold your gaze.
    private(set) var isAttending = false

    /// The self-view and how the face is reading right now.
    private(set) var selfView: CGImage?
    private(set) var reading = ExpressionReading.still

    private let transcriber: any Transcribing
    private let narrative: any NarrativeAnalyzing
    private let diagnosing: any Diagnosing
    private let composing: any FeedbackComposing
    private let speech: any Speaking

    private let audio = AudioCapture()
    private let face = FaceCapture()
    private let recorder = AudioRecorder()
    private let delivery = DeliveryAnalyzer()
    private let prosody = ProsodyAnalyzer()
    private let expressivity = ExpressivityAnalyzer()
    private let reader = ExpressionReader()
    private var neutral = ExpressionBaseline()
    private let chunker = TranscriptChunker()

    private var baseline: Baseline = .none
    private var history: Band?

    private var transcript = Transcript.empty
    private var frames: [ProsodyFrame] = []
    private var expressions: [ExpressionSample] = []
    private var beats: [Beat] = []
    private var labelledChunks = 0
    private var recordingURL: URL?
    private var session: Task<Void, Never>?
    private var quietSince: TimeInterval?

    init(
        transcriber: any Transcribing = SpeechTranscription(),
        narrative: any NarrativeAnalyzing = OnDeviceNarrativeAnalyzer(),
        diagnosing: any Diagnosing = RuleBasedDiagnosis(),
        composing: any FeedbackComposing = OnDeviceComposer(),
        speech: any Speaking = SystemSpeech()
    ) {
        self.transcriber = transcriber
        self.narrative = narrative
        self.diagnosing = diagnosing
        self.composing = composing
        self.speech = speech
    }

    var isListening: Bool { phase == .listening }

    func prime(baseline: Baseline, history: Band?) {
        self.baseline = baseline
        self.history = history
    }

    func begin() {
        guard session == nil else { return }
        phase = .preparing
        reset()

        session = Task {
            do {
                let format = try await transcriber.preferredAudioFormat()
                let url = Self.newRecordingURL()
                recordingURL = url

                let speech = await audio.chunks()
                let sound = await audio.chunks()
                let stored = await audio.chunks()
                let faces = face.samples()
                let views = face.previewFrames()

                try await audio.start(convertingTo: format)
                face.start()
                phase = .listening

                await withTaskGroup { group in
                    group.addTask { [weak self] in await self?.readTranscript(from: speech) }
                    group.addTask { [weak self] in await self?.readProsody(from: sound) }
                    group.addTask { [weak self] in await self?.readExpressions(from: faces) }
                    group.addTask { [weak self] in await self?.showSelf(from: views) }
                    group.addTask { [weak self] in await self?.store(stored, at: url) }
                }

                try await respond()
            } catch {
                phase = .failed(error.localizedDescription)
            }
            session = nil
        }
    }

    /// Ends the turn. There is no stop button in the interface — this is called when
    /// the speaker trails off.
    func end() async {
        face.stop()
        await audio.stop()
        await session?.value
    }

    func silence() async {
        await speech.stop()
    }

    // MARK: - Consumers

    private func readTranscript(from chunks: AsyncStream<AudioChunk>) async {
        do {
            for try await update in transcriber.transcribe(chunks) {
                transcript = update
                await labelSettledChunks()
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func readProsody(from chunks: AsyncStream<AudioChunk>) async {
        for await frame in prosody.frames(from: chunks) {
            frames.append(frame)
            observe(loudness: frame.loudness, at: frame.at)
        }
    }

    private func readExpressions(from samples: AsyncStream<ExpressionSample>) async {
        for await sample in samples {
            expressions.append(sample)
            neutral.observe(sample)
            reading = reader.read(neutral.departure(from: sample))
        }
    }

    private func showSelf(from frames: AsyncStream<CameraFrame>) async {
        for await frame in frames {
            selfView = frame.image
        }
        selfView = nil
    }

    private func store(_ chunks: AsyncStream<AudioChunk>, at url: URL) async {
        try? await recorder.record(chunks, to: url)
    }

    // MARK: - Presence

    /// A pause long enough to be deliberate is where a listener would settle and hold
    /// your gaze. Shorter gaps are the rhythm of speech and should not be reacted to.
    private static let attentionThreshold: TimeInterval = 0.4
    private static let quietLevel: Float = 0.02

    private func observe(loudness: Float, at time: TimeInterval) {
        level += (min(loudness * 6, 1) - level) * 0.3

        guard loudness < Self.quietLevel else {
            quietSince = nil
            isAttending = false
            return
        }
        let since = quietSince ?? time
        quietSince = since
        isAttending = time - since >= Self.attentionThreshold
    }

    // MARK: - Analysis

    /// Labels every chunk except the one still being spoken, so most of the map step is
    /// already done by the time the speaker stops.
    private func labelSettledChunks() async {
        let chunks = chunker.chunks(of: transcript)
        guard chunks.count > labelledChunks + 1 else { return }

        for chunk in chunks[labelledChunks..<(chunks.count - 1)] {
            // Advance regardless of outcome: a chunk the model declines must not be
            // retried on every subsequent transcript update.
            labelledChunks += 1
            if let beat = try? await narrative.label(chunk) {
                beats.append(beat)
            }
        }
    }

    private func respond() async throws {
        guard let url = recordingURL, !transcript.words.isEmpty else {
            phase = .ready
            return
        }
        phase = .reading

        let chunks = chunker.chunks(of: transcript)
        for chunk in chunks.dropFirst(labelledChunks) {
            labelledChunks += 1
            if let beat = try? await narrative.label(chunk) {
                beats.append(beat)
            }
        }

        let narrativeReading = NarrativeReading(
            beats: beats,
            arc: (try? await narrative.arc(from: beats)) ?? NarrativeReading.empty.arc
        )
        let timeline = FeatureTimeline(
            transcript: transcript,
            delivery: delivery.analyze(transcript),
            prosody: frames,
            expressivity: expressivity.windows(from: expressions)
        )
        let diagnosis = diagnosing.diagnose(
            DiagnosticInput(timeline: timeline, narrative: narrativeReading),
            against: baseline
        )
        let feedback = await composing.compose(from: diagnosis, history: history)

        assessment = Assessment(
            recordedAt: .now,
            audio: url,
            timeline: timeline,
            narrative: narrativeReading,
            diagnosis: diagnosis,
            feedback: feedback
        )

        phase = .responding
        if let feedback {
            // A failure to speak must not lose the written feedback, which is already
            // on screen by this point.
            try? await speech.speak(feedback.note)
        }
    }

    private static func newRecordingURL() -> URL {
        URL.documentsDirectory.appending(path: "retelling-\(UUID().uuidString).caf")
    }

    private func reset() {
        transcript = .empty
        frames = []
        expressions = []
        neutral = ExpressionBaseline()
        beats = []
        labelledChunks = 0
        assessment = nil
        level = 0
        isAttending = false
        quietSince = nil
    }
}
