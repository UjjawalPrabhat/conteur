import AVFoundation

protocol Transcribing: Sendable {
    /// The format buffers must be delivered in. Throws rather than returning nil so
    /// the reason reaches the speaker instead of being guessed at by the caller.
    func preferredAudioFormat() async throws -> AVAudioFormat

    /// Yields the cumulative transcript each time more words are finalized.
    ///
    /// Conformers must populate word-level timings — every downstream finding is
    /// anchored to them, so a conformer that only returns text is not substitutable.
    func transcribe(_ audio: AsyncStream<AudioChunk>) -> AsyncThrowingStream<Transcript, Error>
}
