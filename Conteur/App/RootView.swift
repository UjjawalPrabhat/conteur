import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Tell", systemImage: "waveform") {
                TellFlowView()
            }
            Tab("Retellings", systemImage: "clock.arrow.circlepath") {
                HistoryView()
            }
            // On the experiment branch only: the model cannot be observed from the
            // simulator, so the measurement has to be reachable on the device.
            Tab("Model", systemImage: "chart.bar.doc.horizontal") {
                ModelEvaluationView()
            }
        }
        .task { await RecordingCleanup.removeStrandedRecordings() }
    }
}
