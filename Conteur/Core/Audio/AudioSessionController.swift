import AVFoundation

/// What the shared audio session is currently for.
enum AudioSessionRole: Sendable {
    case listening
    case speaking

    var category: AVAudioSession.Category {
        switch self {
        case .listening: .record
        case .speaking: .playback
        }
    }

    /// `.measurement` turns off the gain and EQ that would flatten the pitch and
    /// loudness the delivery signals are measured from — but it also pins output to the
    /// earpiece, so it must be cleared before anything is played back.
    var mode: AVAudioSession.Mode {
        switch self {
        case .listening: .measurement
        case .speaking: .spokenAudio
        }
    }
}

/// One place that owns the audio session.
///
/// Category and mode have to change together when moving between recording and
/// playback, and the failure is silent if it is ignored — audio simply comes out of the
/// wrong speaker. So this throws rather than letting callers use `try?`.
struct AudioSessionController: Sendable {
    static func activate(_ role: AudioSessionRole) throws {
        let session = AVAudioSession.sharedInstance()

        if session.category != role.category || session.mode != role.mode {
            // The output route is chosen when the session activates, so changing the
            // category underneath a live session leaves playback on whatever route
            // recording picked — the earpiece. It has to go down and come back up.
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            try session.setCategory(role.category, mode: role.mode)
        }

        try session.setActive(true)
    }

    static func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }
}
