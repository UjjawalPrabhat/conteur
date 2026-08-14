import Foundation

/// A speaker's own neutral face.
///
/// Resting coefficients differ from person to person — some faces sit with slightly
/// raised brows, others with a faint downturn — so absolute thresholds label one
/// speaker permanently tense and another permanently flat. Movement only means
/// anything as a departure from where a particular face rests.
struct ExpressionBaseline: Sendable {
    /// Falls quickly toward a lower reading, since the lowest values a channel visits
    /// are the resting ones.
    private static let settleRate: Float = 0.08
    /// Rises barely at all, so holding an expression does not get absorbed into
    /// neutral and disappear.
    private static let driftRate: Float = 0.002

    private var resting: [ExpressionChannel: Float] = [:]

    mutating func observe(_ sample: ExpressionSample) {
        for channel in ExpressionChannel.allCases {
            let value = sample.value(channel)
            guard let current = resting[channel] else {
                resting[channel] = value
                continue
            }
            let rate = value < current ? Self.settleRate : Self.driftRate
            resting[channel] = current + (value - current) * rate
        }
    }

    /// How far each channel currently sits above rest.
    func departure(from sample: ExpressionSample) -> ExpressionSample {
        ExpressionSample(
            at: sample.at,
            coefficients: ExpressionChannel.allCases.reduce(into: [:]) { partial, channel in
                partial[channel] = max(0, sample.value(channel) - (resting[channel] ?? 0))
            }
        )
    }
}
