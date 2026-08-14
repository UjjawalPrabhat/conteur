import AVFoundation
import Speech

struct SpeechTranscription: Transcribing {
    enum Failure: Error, LocalizedError {
        case languageUnsupported(Locale.Language)
        case formatUnavailable

        var errorDescription: String? {
            switch self {
            case .languageUnsupported(let language):
                let name = language.languageCode?.identifier ?? "this language"
                return "Conteur can't transcribe \(name) on this device yet."
            case .formatUnavailable:
                return "This iPhone's microphone can't be read by the speech model."
            }
        }
    }

    let locale: Locale

    init(locale: Locale = .current) {
        self.locale = locale
    }

    func preferredAudioFormat() async throws -> AVAudioFormat {
        let transcriber = SpeechTranscriber(
            locale: try await resolvedLocale(),
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: [.audioTimeRange]
        )
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        else { throw Failure.formatUnavailable }
        return format
    }

    func transcribe(_ audio: AsyncStream<AudioChunk>) -> AsyncThrowingStream<Transcript, Error> {
        AsyncThrowingStream { continuation in
            let work = Task {
                do {
                    let transcriber = SpeechTranscriber(
                        locale: try await resolvedLocale(),
                        transcriptionOptions: [],
                        reportingOptions: [],
                        attributeOptions: [.audioTimeRange]
                    )
                    try await installModel(for: transcriber)

                    let analyzer = SpeechAnalyzer(modules: [transcriber])
                    let feed = Task {
                        _ = try await analyzer.analyzeSequence(audio.map { AnalyzerInput(buffer: $0.buffer) })
                        try await analyzer.finalizeAndFinishThroughEndOfInput()
                    }

                    var words: [SpokenWord] = []
                    for try await result in transcriber.results {
                        words.append(contentsOf: result.text.spokenWords)
                        continuation.yield(Transcript(words: words))
                    }

                    try await feed.value
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in work.cancel() }
        }
    }

    /// Maps the device locale onto one the speech model actually ships.
    ///
    /// Region matters less than language here: a phone set to en_ID or en_SG has no
    /// dedicated model, but English transcription works fine. Preferring an
    /// already-installed match avoids a download the speaker didn't ask for.
    private func resolvedLocale() async throws -> Locale {
        let supported = await SpeechTranscriber.supportedLocales
        let wanted = locale.identifier(.bcp47)

        if let exact = supported.first(where: { $0.identifier(.bcp47) == wanted }) {
            return exact
        }

        guard let language = locale.language.languageCode else {
            throw Failure.languageUnsupported(locale.language)
        }
        let sameLanguage = supported.filter { $0.language.languageCode == language }
        guard !sameLanguage.isEmpty else {
            throw Failure.languageUnsupported(locale.language)
        }

        let installed = Set(await SpeechTranscriber.installedLocales.map { $0.identifier(.bcp47) })
        return sameLanguage.first { installed.contains($0.identifier(.bcp47)) } ?? sameLanguage[0]
    }

    private func installModel(for transcriber: SpeechTranscriber) async throws {
        switch await AssetInventory.status(forModules: [transcriber]) {
        case .installed:
            return
        case .unsupported:
            throw Failure.languageUnsupported(locale.language)
        case .supported, .downloading:
            try await install(for: transcriber)
        @unknown default:
            try await install(for: transcriber)
        }
    }

    private func install(for transcriber: SpeechTranscriber) async throws {
        let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber])
        try await request?.downloadAndInstall()
    }
}

private extension AttributedString {
    var spokenWords: [SpokenWord] {
        runs.compactMap { run in
            guard let range = run.audioTimeRange else { return nil }
            let text = String(self[run.range].characters)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return SpokenWord(text: text, start: range.start.seconds, end: range.end.seconds)
        }
    }
}
