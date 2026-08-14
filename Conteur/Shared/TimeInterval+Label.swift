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
