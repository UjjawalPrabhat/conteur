import Foundation
import Testing

@testable import Conteur

struct ExpressionBaselineTests {
    @Test func aFaceHeldStillHasNothingToReport() {
        var baseline = ExpressionBaseline()
        let resting = sample([.browInnerUp: 0.25])

        for _ in 0..<60 { baseline.observe(resting) }

        #expect(baseline.departure(from: resting).value(.browInnerUp) < 0.01)
    }

    /// The point of the baseline: a speaker whose brows rest high should not be read as
    /// permanently surprised.
    @Test func aNaturallyRaisedBrowSettlesIntoNeutral() {
        var high = ExpressionBaseline()
        var low = ExpressionBaseline()

        for _ in 0..<60 {
            high.observe(sample([.browInnerUp: 0.3]))
            low.observe(sample([.browInnerUp: 0.02]))
        }

        // Both then raise their brows by the same amount.
        let highDeparture = high.departure(from: sample([.browInnerUp: 0.45])).value(.browInnerUp)
        let lowDeparture = low.departure(from: sample([.browInnerUp: 0.17])).value(.browInnerUp)

        #expect(abs(highDeparture - lowDeparture) < 0.02)
    }

    @Test func movingOffRestIsReported() {
        var baseline = ExpressionBaseline()
        for _ in 0..<60 { baseline.observe(sample([.mouthSmileLeft: 0.05])) }

        let departure = baseline.departure(from: sample([.mouthSmileLeft: 0.4]))

        #expect(departure.value(.mouthSmileLeft) > 0.3)
    }

    /// Neutral must not creep up to meet a held expression, or a long smile would fade
    /// to flat while it was still on the speaker's face.
    @Test func aHeldExpressionIsNotAbsorbedIntoNeutral() {
        var baseline = ExpressionBaseline()
        for _ in 0..<20 { baseline.observe(sample([.mouthSmileLeft: 0.0])) }
        for _ in 0..<100 { baseline.observe(sample([.mouthSmileLeft: 0.5])) }

        #expect(baseline.departure(from: sample([.mouthSmileLeft: 0.5])).value(.mouthSmileLeft) > 0.4)
    }

    @Test func departuresAreNeverNegative() {
        var baseline = ExpressionBaseline()
        for _ in 0..<60 { baseline.observe(sample([.jawOpen: 0.4])) }

        #expect(baseline.departure(from: sample([.jawOpen: 0.0])).value(.jawOpen) == 0)
    }

    private func sample(_ coefficients: [ExpressionChannel: Float]) -> ExpressionSample {
        ExpressionSample(at: 0, coefficients: coefficients)
    }
}
