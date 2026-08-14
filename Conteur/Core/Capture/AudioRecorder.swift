import AVFoundation

/// Writes captured audio to disk so the speaker can hear the moment a finding refers
/// to. A separate consumer of the chunk stream, which keeps capture itself unaware
/// that anything is being stored.
actor AudioRecorder {
    private var file: AVAudioFile?
    private var format: AVAudioFormat?

    func record(_ chunks: AsyncStream<AudioChunk>, to url: URL) async throws {
        for await chunk in chunks {
            guard let file = try openIfNeeded(at: url, matching: chunk.buffer.format) else { continue }
            try file.write(from: chunk.buffer)
        }
        file = nil
        format = nil
    }

    /// Returns nil rather than writing a buffer whose format differs from the one the
    /// file was opened with. `writeFromBuffer:` raises an Objective-C exception on a
    /// format mismatch instead of returning an error, so it cannot be caught — the
    /// mismatch has to be prevented rather than handled.
    private func openIfNeeded(at url: URL, matching format: AVAudioFormat) throws -> AVAudioFile? {
        if let file {
            return self.format == format ? file : nil
        }

        // The two-argument initializer derives its own standard processing format from
        // the settings, which then disagrees with the converter's output. Naming the
        // processing format explicitly keeps the file and the buffers in step.
        let file = try AVAudioFile(
            forWriting: url,
            settings: format.settings,
            commonFormat: format.commonFormat,
            interleaved: format.isInterleaved
        )
        self.file = file
        self.format = format
        return file
    }
}
