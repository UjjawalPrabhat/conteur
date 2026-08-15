import Foundation

/// Removes audio left behind by earlier versions, which wrote a `.caf` per retelling.
///
/// Nothing writes these any more — audio is transcribed as it arrives and discarded — but
/// an existing install still has them sitting in Documents, and "nothing is recorded" has
/// to be true of the device, not just of new code.
enum RecordingCleanup {
    /// Deliberately off the main thread and after the first frame. Enumerating the
    /// container during `App.init` sits directly on the launch path, and iOS kills an app
    /// that takes too long to show something.
    static func removeStrandedRecordings() async {
        await Task.detached(priority: .utility) {
            let documents = URL.documentsDirectory
            guard
                let files = try? FileManager.default.contentsOfDirectory(
                    at: documents,
                    includingPropertiesForKeys: nil
                )
            else { return }

            for file in files where file.lastPathComponent.hasPrefix("retelling-") {
                try? FileManager.default.removeItem(at: file)
            }
        }.value
    }
}
