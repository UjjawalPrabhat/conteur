import AVFoundation

protocol Speaking: Sendable {
    func speak(_ text: String) async throws
}

actor SystemSpeech: Speaking {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) async throws {
        guard !text.isEmpty else { return }
        try AudioSessionController.activate(.speaking)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.warmestAvailableVoice
        // Slightly under the default: this is somebody responding to a story, not
        // reading a notification.
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        synthesizer.speak(utterance)
    }

    /// Enhanced and premium voices are downloaded by the user in Settings, so the best
    /// available one varies by device.
    private static var warmestAvailableVoice: AVSpeechSynthesisVoice? {
        let language = AVSpeechSynthesisVoice.currentLanguageCode()
        let candidates = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == language }

        return candidates.first { $0.quality == .premium }
            ?? candidates.first { $0.quality == .enhanced }
            ?? AVSpeechSynthesisVoice(language: language)
    }
}
