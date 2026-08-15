import Foundation

/// How a face reads to somebody watching.
///
/// Deliberately a claim about what is conveyed, not about what is felt. Inferring
/// emotion from facial configuration does not hold up across people and contexts, but
/// a storyteller's concern is what an audience takes from them — and that is exactly
/// what these describe.
enum ConveyedImpression: String, Sendable, Hashable, CaseIterable {
    case flat
    case neutral
    case animated
    case warm
    case tense
    case sombre
    case surprised

    var label: String {
        switch self {
        case .flat: "reads as flat"
        case .neutral: "reads as neutral"
        case .animated: "reads as animated"
        case .warm: "reads as warm"
        case .tense: "reads as tense"
        case .sombre: "reads as sombre"
        case .surprised: "reads as surprised"
        }
    }
}

struct ExpressionReading: Sendable, Hashable {
    let impression: ConveyedImpression
    /// How much the face is doing overall, 0...1.
    let animation: Float

    static let still = ExpressionReading(impression: .flat, animation: 0)
}

/// Reads an impression from how far a face has moved off its own neutral.
///
/// Expects the departures produced by `ExpressionBaseline`, not raw coefficients.
/// Pure, so it is testable without a camera.
struct ExpressionReader: Sendable {
    /// Departures are small — natural expression moves a channel by a few hundredths,
    /// not by half. These thresholds are set against that scale, not against the raw
    /// 0...1 range.
    private static let noise: Float = 0.05
    private static let stillness: Float = 0.06
    /// Above this the face is doing a lot, even if none of it forms a named pattern.
    /// Below it, movement without a pattern is just an ordinary talking face.
    private static let busy: Float = 0.18

    func read(_ departure: ExpressionSample) -> ExpressionReading {
        let movement = Movement(departure)
        let animation = movement.overall

        guard animation >= Self.stillness else {
            return ExpressionReading(impression: .flat, animation: animation)
        }

        let candidates: [(ConveyedImpression, Float)] = [
            (.surprised, movement.surprise),
            (.warm, movement.warmth),
            (.sombre, movement.sombreness),
            (.tense, movement.tension),
        ]

        let strongest = candidates
            .filter { $0.1 >= Self.noise }
            .max { $0.1 < $1.1 }

        return ExpressionReading(
            impression: strongest?.0 ?? (animation >= Self.busy ? .animated : .neutral),
            animation: min(animation * 3, 1)
        )
    }

    private struct Movement {
        let browsRaised: Float
        let browsDrawn: Float
        let eyesWide: Float
        let squinting: Float
        let smiling: Float
        let frowning: Float
        let jawOpen: Float

        init(_ sample: ExpressionSample) {
            browsRaised = sample.value(.browInnerUp)
            browsDrawn = Self.mean(sample.value(.browDownLeft), sample.value(.browDownRight))
            eyesWide = Self.mean(sample.value(.eyeWideLeft), sample.value(.eyeWideRight))
            squinting = Self.mean(sample.value(.cheekSquintLeft), sample.value(.cheekSquintRight))
            smiling = Self.mean(sample.value(.mouthSmileLeft), sample.value(.mouthSmileRight))
            frowning = Self.mean(sample.value(.mouthFrownLeft), sample.value(.mouthFrownRight))
            jawOpen = sample.value(.jawOpen)
        }

        /// Excludes the jaw: speaking opens it continuously, so including it would
        /// measure whether somebody is talking rather than whether their face is doing
        /// anything.
        var overall: Float {
            [browsRaised, browsDrawn, eyesWide, squinting, smiling, frowning].max() ?? 0
        }

        /// Raised brows together with widened eyes are what make surprise legible. A
        /// geometric mean needs both present without demanding each clear the threshold
        /// alone, which `min` did.
        ///
        /// The jaw only amplifies a pattern that is already there. Speaking holds it open
        /// continuously — the same reason `overall` ignores it — so letting it carry the
        /// verdict alone labelled every talking face surprised.
        var surprise: Float {
            let core = Self.both(browsRaised, eyesWide)
            return core < ExpressionReader.noise ? 0 : core + jawOpen * 0.25
        }

        var warmth: Float {
            max(0, smiling - frowning)
        }

        /// A downturned mouth, or the raised-inner-brow over lowered-brow combination
        /// that carries a sombre expression without one.
        var sombreness: Float {
            max(0, frowning - smiling) + Self.both(browsRaised, browsDrawn) * 0.7
        }

        /// Driven by the lowered brow, tightened lids sharpening it.
        var tension: Float {
            browsDrawn + squinting * 0.4
        }

        private static func mean(_ left: Float, _ right: Float) -> Float {
            (left + right) / 2
        }

        /// Zero unless both are moving, but scales smoothly once they are.
        private static func both(_ left: Float, _ right: Float) -> Float {
            (left * right).squareRoot()
        }
    }
}
