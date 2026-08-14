import Foundation
import Testing

@testable import Conteur

/// The reader consumes departures from a speaker's neutral, not raw coefficients, so
/// the values here are deliberately small — that is the scale natural expression moves
/// on once rest is subtracted.
struct ExpressionReaderTests {
    private let reader = ExpressionReader()

    @Test func aFaceSittingAtRestReadsAsFlat() {
        #expect(reader.read(departure([:])).impression == .flat)
    }

    @Test func raisedBrowsWithWideEyesReadAsSurprise() {
        let reading = reader.read(departure([
            .browInnerUp: 0.16,
            .eyeWideLeft: 0.14,
            .eyeWideRight: 0.14,
            .jawOpen: 0.2,
        ]))

        #expect(reading.impression == .surprised)
    }

    @Test func aSmileReadsAsWarm() {
        #expect(reader.read(departure([.mouthSmileLeft: 0.14, .mouthSmileRight: 0.14])).impression == .warm)
    }

    @Test func aDownturnedMouthReadsAsSombre() {
        #expect(reader.read(departure([.mouthFrownLeft: 0.12, .mouthFrownRight: 0.12])).impression == .sombre)
    }

    @Test func aLoweredBrowReadsAsTense() {
        let reading = reader.read(departure([
            .browDownLeft: 0.12,
            .browDownRight: 0.12,
            .cheekSquintLeft: 0.1,
            .cheekSquintRight: 0.1,
        ]))

        #expect(reading.impression == .tense)
    }

    @Test func aSmileWinsOverATraceOfAFrown() {
        let reading = reader.read(departure([
            .mouthSmileLeft: 0.2,
            .mouthSmileRight: 0.2,
            .mouthFrownLeft: 0.04,
            .mouthFrownRight: 0.04,
        ]))

        #expect(reading.impression == .warm)
    }

    /// Speaking opens the jaw continuously. If the jaw counted toward overall movement,
    /// every speaker would read as animated for as long as they talked.
    @Test func anOpenJawAloneIsNotAnExpression() {
        let reading = reader.read(departure([.jawOpen: 0.6]))

        #expect(reading.impression == .flat)
    }

    @Test func movementWithoutAKnownPatternStillReadsAsAnimated() {
        let reading = reader.read(departure([.eyeWideLeft: 0.12, .eyeWideRight: 0.12]))

        #expect(reading.impression == .animated)
    }

    /// Raised brows without widened eyes is not surprise. `min` used to be strict enough
    /// to reject the real thing too, so the pattern now needs both present without
    /// demanding each clear the threshold alone.
    @Test func oneHalfOfTheSurprisePatternIsNotSurprise() {
        let reading = reader.read(departure([.browInnerUp: 0.2]))

        #expect(reading.impression != .surprised)
    }

    @Test func tinyMovementsAreRestingFaceNoise() {
        let reading = reader.read(departure([
            .mouthSmileLeft: 0.02,
            .mouthSmileRight: 0.02,
            .browInnerUp: 0.01,
        ]))

        #expect(reading.impression == .flat)
    }

    private func departure(_ coefficients: [ExpressionChannel: Float]) -> ExpressionSample {
        ExpressionSample(at: 0, coefficients: coefficients)
    }
}
