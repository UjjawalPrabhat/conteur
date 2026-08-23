import Foundation

/// Rules that need only the recording. Unchanged by the story being known, because how
/// somebody speaks does not depend on what they are speaking about.
///
/// They share a floor: below this much speech there is not enough delivery to judge, and
/// finding no fault in forty words would otherwise be reported as strong delivery.
enum SpeechFloor {
    static let words = 50
}

/// A rate rather than a count, so a long retelling isn't penalised for being long.
struct FilledPauseRule: DiagnosticRule {
    private static let tolerated = 0.04

    let dimension = Dimension.delivery

    func canEvaluate(in input: DiagnosticInput) -> Bool { input.timeline.delivery.wordCount >= SpeechFloor.words }

    func findings(in input: DiagnosticInput) -> [Finding] {
        let signals = input.timeline.delivery
        let rate = signals.filledPauseRate
        guard rate > Self.tolerated else { return [] }

        return [
            Finding(
                dimension: dimension,
                subject: "fillers",
                observation: "\(signals.filledPauses.count) filled pauses across \(signals.wordCount) words",
                magnitude: rate,
                weight: 0.2,
                evidence: signals.filledPauses.prefix(3).map {
                    .at($0.at, quote: $0.token, measure: rate.percentLabel)
                }
            )
        ]
    }
}

struct StallRule: DiagnosticRule {
    private static let tolerated = 2

    let dimension = Dimension.delivery

    func canEvaluate(in input: DiagnosticInput) -> Bool { input.timeline.delivery.wordCount >= SpeechFloor.words }

    func findings(in input: DiagnosticInput) -> [Finding] {
        let stalls = input.timeline.delivery.pauses(of: .stall)
        guard stalls.count > Self.tolerated else { return [] }

        return [
            Finding(
                dimension: dimension,
                subject: "stalls",
                observation: "\(stalls.count) silences ran long enough for a listener to wonder whether you were coming back",
                magnitude: Double(stalls.count),
                weight: 0.25,
                evidence: stalls.prefix(3).map {
                    .at($0.start, measure: $0.duration.secondsLabel)
                }
            )
        ]
    }
}

/// Restarting a phrase is normal in speech; doing it often enough to notice is not.
///
/// Delivery, not coherence: this is repair fluency in the speed / breakdown / repair triad,
/// and it measures the sentence being rebuilt rather than the story failing to hold. Filed
/// under coherence it produced a challenge about following narrative threads for somebody
/// whose actual problem was starting sentences twice.
struct RestartRule: DiagnosticRule {
    private static let tolerated = 3

    let dimension = Dimension.delivery

    func canEvaluate(in input: DiagnosticInput) -> Bool { input.timeline.delivery.wordCount >= SpeechFloor.words }

    func findings(in input: DiagnosticInput) -> [Finding] {
        let restarts = input.timeline.delivery.restarts
        guard restarts.count > Self.tolerated else { return [] }

        return [
            Finding(
                dimension: dimension,
                subject: "restarts",
                observation: "\(restarts.count) sentences were restarted mid-phrase",
                magnitude: Double(restarts.count),
                weight: 0.2,
                evidence: restarts.prefix(3).map {
                    .at($0.at, quote: $0.phrase)
                }
            )
        ]
    }
}

/// A story told at one pitch.
///
/// Measured in semitones, which is how pitch is heard, so the same threshold means the same
/// thing for a low voice and a high one. Expressive narration typically runs three semitones
/// of spread or more; two is where a listener starts to hear one note.
struct MonotoneRule: DiagnosticRule {
    private static let minimumVariation: Float = 2

    let dimension = Dimension.engagement

    /// Pitch needs voiced audio, not beats — a short retelling can still be monotone.
    func canEvaluate(in input: DiagnosticInput) -> Bool {
        input.timeline.prosody.contains { $0.pitch != nil }
    }

    func findings(in input: DiagnosticInput) -> [Finding] {
        let variation = input.timeline.pitchVariationInSemitones
        guard variation > 0, variation < Self.minimumVariation else { return [] }

        return [
            Finding(
                dimension: dimension,
                subject: "pitch",
                observation: "the pitch of your voice barely moved across the whole retelling",
                // How far short of moving enough, so a voice that moved more reads better.
                magnitude: Double(Self.minimumVariation - variation),
                weight: 0.3,
                evidence: [
                    Evidence(at: nil, quote: nil, measure: variation.semitoneLabel)
                ]
            )
        ]
    }
}

/// The turning point told flat — as a thing that happened, with nothing to say why it
/// mattered.
///
/// This is Labov's *evaluation*: the clauses that tell a listener why the story was worth
/// telling. `StakesRule` already checks whether the story's point came through at all, but
/// Labov treated evaluation as distributed through a narrative and concentrated at its turn,
/// and the one place its absence is unambiguous is the climax. A retelling can land the
/// authored stakes in a closing sentence and still have narrated the turn itself as minutes.
///
/// Detected from four of Labov's own categories, all visible in a transcript with no model:
/// reported speech, intensifiers, comparators, and explicatives. Absence of every one of them
/// across the turning point is the finding; which of them a good telling used is not the app's
/// business.
struct UnevaluatedClimaxRule: DiagnosticRule {
    let dimension = Dimension.engagement

    /// Needs a located turning point and enough speech for its absence to mean something. A
    /// climax nobody reached is `OmittedEventRule`'s finding, not this one's.
    func canEvaluate(in input: DiagnosticInput) -> Bool {
        input.timeline.delivery.wordCount >= SpeechFloor.words
            && input.comparison.locatedClimax != nil
    }

    func findings(in input: DiagnosticInput) -> [Finding] {
        guard let climax = input.comparison.locatedClimax, let at = climax.at else { return [] }

        let span = input.comparison.span(of: climax, endingBy: input.timeline.duration)
        let spoken = input.timeline.words(in: span)
        guard !spoken.isEmpty, !EvaluativeDevice.appears(in: spoken) else { return [] }

        return [
            Finding(
                dimension: dimension,
                subject: "unevaluated-climax",
                observation: "the turning point went by as a thing that happened — nothing in it said why it mattered",
                magnitude: 1,
                weight: 0.25,
                evidence: [.at(at, quote: climax.quote)]
            )
        ]
    }
}

/// The words a teller uses to say that something mattered, rather than only that it happened.
///
/// Labov's four categories of evaluative device, reduced to the surface forms each one leaves
/// behind. Deliberately a coarse net: it answers "was there any evaluation here", never "was
/// the evaluation good", which is not a thing that can be measured.
enum EvaluativeDevice {
    /// Reported speech — the strongest marker of an engaging oral narrative, and the one a
    /// transcript shows most plainly.
    private static let reportedSpeech: Set<String> = [
        "said", "says", "asked", "asks", "told", "tells", "shouted", "whispered", "replied",
        "screamed", "cried", "goes",
    ]
    /// Intensifiers — degree, not fact.
    private static let intensifiers: Set<String> = [
        "very", "really", "so", "such", "totally", "completely", "absolutely", "utterly",
        "literally", "terribly", "awfully", "incredibly", "suddenly", "finally", "even",
    ]
    /// Comparators — what did not happen, or might have, set against what did.
    private static let comparators: Set<String> = [
        "never", "nothing", "nobody", "instead", "rather", "almost", "nearly", "would",
        "could", "should", "might", "worse", "better", "more", "less",
    ]
    /// Explicatives — the clauses that give a reason rather than an event.
    private static let explicatives: Set<String> = [
        "because", "since", "although", "though", "unless", "why", "meant",
    ]

    private static let all = reportedSpeech
        .union(intensifiers)
        .union(comparators)
        .union(explicatives)

    static func appears(in words: [SpokenWord]) -> Bool {
        words.contains { all.contains($0.normalized) }
    }
}

/// Speeding up through the moment that most deserves room.
struct RushedClimaxRule: DiagnosticRule {
    /// A fifth faster than the speaker's own average is enough to hear.
    private static let excess = 1.2

    let dimension = Dimension.delivery

    func canEvaluate(in input: DiagnosticInput) -> Bool {
        input.timeline.delivery.wordCount >= SpeechFloor.words
            && input.comparison.locatedClimax != nil
            && input.timeline.delivery.wordsPerMinute > 0
    }

    func findings(in input: DiagnosticInput) -> [Finding] {
        guard let climax = input.comparison.locatedClimax, let at = climax.at else { return [] }

        let average = input.timeline.delivery.wordsPerMinute
        let span = input.comparison.span(of: climax, endingBy: input.timeline.duration)
        let local = input.timeline.wordsPerMinute(in: span)
        guard average > 0, local > average * Self.excess else { return [] }

        return [
            Finding(
                dimension: dimension,
                subject: "climax-pace",
                observation: "you sped up to \(Int(local)) words a minute through the turning point, against \(Int(average)) across the rest",
                magnitude: local / average,
                weight: 0.25,
                evidence: [.at(at, quote: climax.quote, measure: "\(Int(local)) wpm")]
            )
        ]
    }
}
