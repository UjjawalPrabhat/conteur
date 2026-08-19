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
        case tooShort
        case failed(String)
    }

    /// Each chunk costs a model session, and the whole beat sheet has to fit one 4,096
    /// token budget at the reduce step. Ten minutes is about twenty chunks — enough for
    /// a full retelling, short enough that the analysis after you stop stays brief.
    static let maximumDuration: TimeInterval = 10 * 60
    /// The last stretch, where the speaker is told to start drawing to a close.
    static let warningDuration: TimeInterval = 60

    /// Below this there is nothing to say. Saying it anyway means inventing it.
    private static let minimumWords = 40
    private static let minimumDuration: TimeInterval = 20

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

    private(set) var elapsed: TimeInterval = 0

    var remaining: TimeInterval { max(0, Self.maximumDuration - elapsed) }
    var isRunningOut: Bool { phase == .listening && remaining <= Self.warningDuration }

    private let transcriber: any Transcribing
    private let narrative: any NarrativeAnalyzing
    private let diagnosing: any Diagnosing
    private let composing: any FeedbackComposing
    private let speech: any Speaking

    private let audio = AudioCapture()
    private let face = FaceCapture()
    private let delivery = DeliveryAnalyzer()
    private let prosody = ProsodyAnalyzer()
    private let expressivity = ExpressivityAnalyzer()
    private let reader = ExpressionReader()
    private var neutral = ExpressionBaseline()
    private let chunker = TranscriptChunker()

    private var baseline: Baseline = .none
    private var history: Band?
    /// The first telling, when this is the retell against a challenge.
    private var previous: Diagnosis?
    private var readingProgress: ReadingProgress = .none
    private var challenge: String?
    private let comparison = RetellingComparison()

    private var transcript = Transcript.empty
    private var frames: [ProsodyFrame] = []
    private var expressions: [ExpressionSample] = []
    private var beats: [Beat] = []
    private var labelledChunks = 0
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

    func prime(
        baseline: Baseline,
        history: Band?,
        previous: Diagnosis?,
        challenge: String?,
        readingProgress: ReadingProgress
    ) {
        self.baseline = baseline
        self.history = history
        self.previous = previous
        self.challenge = challenge
        self.readingProgress = readingProgress
    }

    func begin() {
        guard session == nil else { return }
        phase = .preparing
        reset()

        session = Task {
            do {
                let format = try await transcriber.preferredAudioFormat()
                let speech = await audio.chunks()
                let sound = await audio.chunks()
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
        endCapture()
        await session?.value
    }

    /// Stops the microphone without waiting for analysis, so it is safe to call from
    /// inside the session's own task when the time limit is reached.
    private func endCapture() {
        face.stop()
        Task { await audio.stop() }
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

    // MARK: - Presence

    /// A pause long enough to be deliberate is where a listener would settle and hold
    /// your gaze. Shorter gaps are the rhythm of speech and should not be reacted to.
    private static let attentionThreshold: TimeInterval = 0.4
    private static let quietLevel: Float = 0.02

    private func observe(loudness: Float, at time: TimeInterval) {
        level += (min(loudness * 6, 1) - level) * 0.3
        elapsed = time

        if time >= Self.maximumDuration, phase == .listening {
            endCapture()
        }

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
        // Analysing a handful of words does not produce weak feedback, it produces
        // invented feedback: the model fills the summary it is asked for, and every
        // dimension reports strong because no rule had anything to fire on.
        guard
            transcript.words.count >= Self.minimumWords,
            transcript.duration >= Self.minimumDuration
        else {
            phase = .tooShort
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

        let resolvedBeats = beats.resolveEntities()

        let narrativeReading = NarrativeReading(
            beats: resolvedBeats,
            arc: (try? await narrative.arc(from: resolvedBeats)) ?? NarrativeReading.empty.arc
        )
        let timeline = FeatureTimeline(
            transcript: transcript,
            delivery: delivery.analyze(transcript),
            prosody: frames,
            expressivity: expressivity.windows(from: expressions)
        )
        let diagnosis = diagnosing.diagnose(
            DiagnosticInput(
                timeline: timeline,
                narrative: narrativeReading,
                readingProgress: readingProgress
            ),
            against: baseline
        )
        let nextProgress = RuleBasedDiagnosis.readingProgress(
            from: narrativeReading,
            previous: readingProgress
        )
        let progress = previous.flatMap { first in
            challenge.flatMap { comparison.compare(first, with: diagnosis, challenge: $0) }
        }
        let feedback = await composing.compose(
            from: diagnosis,
            history: history,
            progress: progress
        )

        assessment = Assessment(
            recordedAt: .now,
            timeline: timeline,
            narrative: narrativeReading,
            diagnosis: diagnosis,
            feedback: feedback,
            progress: progress,
            readingProgress: nextProgress
        )

        phase = .responding
        if let feedback {
            // A failure to speak must not lose the written feedback, which is already
            // on screen by this point.
            try? await speech.speak(feedback.note)
        }
    }

    private func reset() {
        transcript = .empty
        frames = []
        expressions = []
        neutral = ExpressionBaseline()
        elapsed = 0
        beats = []
        labelledChunks = 0
        assessment = nil
        level = 0
        isAttending = false
        quietSince = nil
    }
}
