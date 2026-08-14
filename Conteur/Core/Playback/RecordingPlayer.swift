import AVFoundation

protocol Playing: Sendable {
    /// Plays from a moment in the recording, so a finding can be heard rather than
    /// taken on trust. Returns how much audio remains from that point.
    @discardableResult
    func play(_ url: URL, from time: TimeInterval) async throws -> TimeInterval
    func stop() async
}

actor RecordingPlayer: Playing {
    private var player: AVAudioPlayer?

    @discardableResult
    func play(_ url: URL, from time: TimeInterval) async throws -> TimeInterval {
        try AudioSessionController.activate(.speaking)

        let player = try player(for: url)
        player.currentTime = min(time, player.duration)
        player.play()
        return max(0, player.duration - player.currentTime)
    }

    func stop() {
        player?.stop()
        player = nil
        AudioSessionController.deactivate()
    }

    private func player(for url: URL) throws -> AVAudioPlayer {
        if let player, player.url == url { return player }
        let player = try AVAudioPlayer(contentsOf: url)
        player.prepareToPlay()
        self.player = player
        return player
    }
}
