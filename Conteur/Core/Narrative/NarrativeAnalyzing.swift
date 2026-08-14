protocol NarrativeAnalyzing: Sendable {
    /// Labels one chunk. Called per chunk during the retelling so only the reduce
    /// step remains when the speaker stops.
    func label(_ chunk: TranscriptChunk) async throws -> Beat

    /// Reduces the labelled beats to the shape of the whole retelling.
    func arc(from beats: [Beat]) async throws -> NarrativeArc
}
