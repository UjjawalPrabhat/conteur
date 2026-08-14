import Foundation

struct ExpressivityWindow: Sendable, Hashable {
    let start: TimeInterval
    let duration: TimeInterval
    /// Mean per-channel variation across the window. High means a moving face; near
    /// zero means a still one.
    let variation: Float

    var end: TimeInterval { start + duration }
}

/// Measures how much the face moves, never what it is thought to feel. Inferring
/// emotion from expression is contested; measuring variation is not.
struct ExpressivityAnalyzer: Sendable {
    /// Long enough to span a narrative beat rather than a single syllable.
    static let windowDuration: TimeInterval = 15

    func windows(from samples: [ExpressionSample]) -> [ExpressivityWindow] {
        guard let last = samples.last else { return [] }

        return stride(from: 0, through: last.at, by: Self.windowDuration).compactMap { start in
            let window = samples.filter { $0.at >= start && $0.at < start + Self.windowDuration }
            guard window.count > 1 else { return nil }
            return ExpressivityWindow(
                start: start,
                duration: Self.windowDuration,
                variation: meanChannelDeviation(in: window)
            )
        }
    }

    private func meanChannelDeviation(in samples: [ExpressionSample]) -> Float {
        let deviations = ExpressionChannel.allCases.map { channel in
            standardDeviation(of: samples.map { $0.value(channel) })
        }
        return deviations.reduce(0, +) / Float(deviations.count)
    }

    private func standardDeviation(of values: [Float]) -> Float {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Float(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Float(values.count)
        return sqrt(variance)
    }
}
