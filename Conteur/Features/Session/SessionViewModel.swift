import CoreGraphics
import Foundation
import FoundationModels
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
        case unmatched
        case failed(String)
    }

    /// Retelling a 350-word story should take about a minute: adults recall a third to a
    /// half of a narrative's length, at around 150 words a minute of narrative speech.
    /// Three minutes is generous room over that, and the comparison's reliability falls off
    /// well before the token budget would.
    static let maximumDuration: TimeInterval = 3 * 60
    /// The last stretch, where the speaker is told to start drawing to a close.
    static let warningDuration: TimeInterval = 30

    /// Below this there is nothing to say. Saying it anyway means inventing it.
    private static let minimumWords = 40
    private static let minimumDuration: TimeInterval = 20

    private(set) var phase: Phase = .ready
    private(set) var assessment: Assessment?

    /// Drives the listening presence. Smoothed, because the presence should breathe
    /// with the voice rather than twitch at every syllable.
    private(set) var level: Float = 0
    private(set) var elapsed: TimeInterval = 0

    /// What the transcriber actually heard. Shown when the retelling could not be matched,
    /// because the first thing worth knowing is whether the words arrived at all.
    var heard: String { transcript.text }

    /// The transcript split where the last clause ended: what has settled, and the phrase
    /// being spoken now. The telling screen dims the first and lights the second, so the
    /// words being said carry and the ones already said recede.
    var settled: String {
        String(transcript.words.prefix(upTo: phraseStart).map(\.text).joined(separator: " "))
    }

    var phrase: String {
        transcript.words[phraseStart...].map(\.text).joined(separator: " ")
    }

    private var phraseStart: Int {
        guard let last = transcript.words.lastIndex(where: \.endsClause) else { return 0 }
        return min(last + 1, transcript.words.count)
    }

    /// What a telling amounted to, for the screen that has to explain why it was too short
    /// without scoring it.
    var spokenWords: Int { transcript.words.count }
    var spokenDuration: TimeInterval { transcript.duration }

    var remaining: TimeInterval { max(0, Self.maximumDuration - elapsed) }
    var isRunningOut: Bool { phase == .listening && remaining <= Self.warningDuration }

    private let transcriber: any Transcribing
    private let comparer: any SourceComparing
    private let diagnosing: any Diagnosing
    private let composing: any FeedbackComposing
    private let speech: any Speaking

    private let audio = AudioCapture()
    private let delivery = DeliveryAnalyzer()
    private let prosody = ProsodyAnalyzer()

    private let story: GuidedStory
    private var baseline: Baseline = .none
    private var history: Band?
    /// The first telling, when this is the retell against a challenge.
    private var previous: Diagnosis?
    private var challenge: String?
    private let comparison = RetellingComparison()

    private var transcript = Transcript.empty
    private var frames: [ProsodyFrame] = []
    private var session: Task<Void, Never>?
    private var clock: Task<Void, Never>?
    /// Set when transcription failed mid-stream, so the analysis does not run over a partial
    /// transcript and overwrite the failure with a verdict about the speaker.
    private var didFail = false
    /// Set when the telling is walked away from, so the analysis is skipped rather than
    /// producing feedback nobody asked for.
    private var isAbandoned = false

    init(
        story: GuidedStory,
        transcriber: any Transcribing = SpeechTranscription(),
        comparer: any SourceComparing = StoryComparison(),
        diagnosing: any Diagnosing = RuleBasedDiagnosis(),
        composing: any FeedbackComposing = OnDeviceComposer(),
        speech: any Speaking = SystemSpeech()
    ) {
        self.transcriber = transcriber
        self.story = story
        self.comparer = comparer
        self.diagnosing = diagnosing
        self.composing = composing
        self.speech = speech
    }

    var isListening: Bool { phase == .listening }

    func prime(baseline: Baseline, history: Band?, previous: Diagnosis?, challenge: String?) {
        self.baseline = baseline
        self.history = history
        self.previous = previous
        self.challenge = challenge
    }

    func configureForPreview(phase: Phase, elapsed: TimeInterval = 0, words: [SpokenWord] = []) {
        self.phase = phase
        self.elapsed = elapsed
        if !words.isEmpty {
            self.transcript = Transcript(words: words)
        }
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

                try await audio.start(convertingTo: format)
                phase = .listening
                startClock()

                await withTaskGroup { group in
                    group.addTask { [weak self] in await self?.readTranscript(from: speech) }
                    group.addTask { [weak self] in await self?.readProsody(from: sound) }
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
        clock?.cancel()
        clock = nil
        Task { await audio.stop() }
    }

    /// Drives the clock and the hard cap on their own timer rather than off the prosody
    /// stream. Hanging both on incoming frames meant a stretch of silence froze the display,
    /// and a prosody stream that yielded nothing at all left the cap unable to fire — so the
    /// turn could run indefinitely past the limit that exists to protect the token budget.
    private func startClock() {
        clock?.cancel()
        clock = Task { [weak self] in
            let started = ContinuousClock.now
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled, let self else { return }
                elapsed = started.duration(to: .now).timeInterval
                if elapsed >= Self.maximumDuration, phase == .listening {
                    endCapture()
                    return
                }
            }
        }
    }

    /// Walks away from the telling: closes the microphone and produces no feedback.
    /// Without this the view could be dismissed while capture was still running.
    func cancel() async {
        isAbandoned = true
        endCapture()
        await session?.value
        isAbandoned = false
        phase = .ready
    }

    // MARK: - Consumers

    private func readTranscript(from chunks: AsyncStream<AudioChunk>) async {
        do {
            for try await update in transcriber.transcribe(chunks) {
                transcript = update
            }
        } catch {
            fail(error.localizedDescription)
        }
    }

    private func readProsody(from chunks: AsyncStream<AudioChunk>) async {
        for await frame in prosody.frames(from: chunks) {
            frames.append(frame)
            observe(loudness: frame.loudness)
        }
    }

    // MARK: - Presence

    /// Smoothed, so the listening presence breathes with the voice rather than twitching at
    /// every syllable. The clock and the time limit are deliberately not driven from here —
    /// see `startClock()`.
    private func observe(loudness: Float) {
        level += (min(loudness * 6, 1) - level) * 0.3
    }

    // MARK: - Analysis

    /// Records a failure so it survives the rest of the turn. The transcription consumer runs
    /// inside the same task group as the analysis, so without this the analysis would run
    /// afterwards regardless and overwrite the failure — reporting a broken recogniser as the
    /// speaker not having said enough.
    private func fail(_ reason: String) {
        didFail = true
        phase = .failed(reason)
    }

    private func respond() async throws {
        guard !isAbandoned else {
            phase = .ready
            return
        }
        // Transcription broke mid-stream. Whatever arrived before that is not a retelling,
        // and analysing it would blame the speaker for the recogniser.
        guard !didFail else { return }

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

        let timeline = FeatureTimeline(
            transcript: transcript,
            delivery: delivery.analyze(transcript),
            prosody: frames
        )
        // One comparison against the story, in one model session. The whole map-reduce
        // existed only because structure had to be inferred with nothing to compare to.
        //
        // A thrown error is reported rather than degraded into an empty comparison: those
        // look identical downstream, and "nothing matched" would be blamed on the speaker.
        let source: SourceComparison
        do {
            source = try await comparer.compare(transcript, with: story)
        } catch {
            // A guardrail refusal is not something the speaker did, and "Detected content
            // likely to be unsafe" is not something to show somebody who just retold a story
            // about a bereavement.
            phase = .failed(
                error.isGuardrailRefusal
                    ? "I couldn't work through that one. Try telling it again."
                    : error.localizedDescription
            )
            return
        }
        // Nothing recognisable at all — not an event, not a character. Scoring it would
        // mean guessing whether they told a different story or the matching simply failed.
        // Recognising the cast but none of the events is a finding, not an unknown.
        guard source.recognisedSomething else {
            phase = .unmatched
            return
        }
        let diagnosis = diagnosing.diagnose(
            DiagnosticInput(timeline: timeline, comparison: source),
            against: baseline
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
            comparison: source,
            diagnosis: diagnosis,
            feedback: feedback,
            progress: progress
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
        elapsed = 0
        isAbandoned = false
        didFail = false
        assessment = nil
        level = 0
    }
}
