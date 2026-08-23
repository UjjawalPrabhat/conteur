import Foundation

extension TimeInterval {
    /// Minutes and seconds, matching how feedback refers to moments in the recording.
    var timestampLabel: String {
        let total = Int(rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    var secondsLabel: String {
        "\(Int(rounded()))s"
    }
}

extension Double {
    var percentLabel: String {
        formatted(.percent.precision(.fractionLength(0)))
    }
}

extension Float {
    /// How far a voice moved, in the unit pitch is heard in.
    var semitoneLabel: String {
        "\(formatted(.number.precision(.fractionLength(1)))) semitones"
    }
}

extension Duration {
    /// The same span as the seconds every other timing in the app is measured in.
    var timeInterval: TimeInterval {
        let (seconds, attoseconds) = components
        return TimeInterval(seconds) + TimeInterval(attoseconds) / 1e18
    }
}
