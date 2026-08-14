import AVFoundation

/// A buffer handed off from the capture tap to its consumers.
///
/// `AVAudioPCMBuffer` is a mutable reference type, so it is not `Sendable` on its
/// own. The producer allocates a fresh buffer for every chunk and never touches it
/// again, and consumers only read, so ownership genuinely transfers.
struct AudioChunk: @unchecked Sendable {
    let buffer: AVAudioPCMBuffer
    let start: TimeInterval
    /// Peak amplitude, for level metering rather than analysis.
    let level: Float
}
