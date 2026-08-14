import Foundation

/// The facial movements that carry narrative expression. A deliberately small
/// subset: the full 52-coefficient set is mostly mouth shapes driven by phonetics,
/// which say nothing about how a story is being told.
enum ExpressionChannel: String, Sendable, Hashable, CaseIterable {
    case browInnerUp
    case browDownLeft
    case browDownRight
    case eyeWideLeft
    case eyeWideRight
    case eyeBlinkLeft
    case eyeBlinkRight
    case mouthSmileLeft
    case mouthSmileRight
    case mouthFrownLeft
    case mouthFrownRight
    case jawOpen
    case cheekSquintLeft
    case cheekSquintRight
}

struct ExpressionSample: Sendable, Hashable {
    let at: TimeInterval
    let coefficients: [ExpressionChannel: Float]

    func value(_ channel: ExpressionChannel) -> Float {
        coefficients[channel] ?? 0
    }
}
