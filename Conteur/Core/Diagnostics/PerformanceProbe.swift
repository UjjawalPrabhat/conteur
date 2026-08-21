import Foundation
import os.signpost

struct PerformanceProbe: Sendable {
    static let log = OSLog(subsystem: "com.daffa.conteur", category: "performance")

    static func startSession() {
        // Reserved for future session-level timing instrumentation.
    }

    static func markFrame(at time: Date = .now) {
        // Reserved for frame-drop monitoring via Instruments/Points of Interest.
        _ = time
    }

    static func sessionDuration() -> TimeInterval {
        // Reserved for session duration reporting.
        0
    }
}
