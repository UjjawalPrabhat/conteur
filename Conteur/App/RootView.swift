import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Tell", systemImage: "waveform") {
                TellFlowView()
            }
            Tab("Retellings", systemImage: "arrow.counterclockwise") {
                HistoryView()
            }
            Tab("Progress", systemImage: "chart.bar") {
                ProgressCoachView()
            }
        }
        .tint(Color.ember)
        // The app is a fire at night. There is no light variant of that, so the appearance
        // is pinned rather than left to follow the system into a palette it has no colours for.
        .preferredColorScheme(.dark)
        .tabBarMinimizeBehavior(.onScrollDown)
        .task { await RecordingCleanup.removeStrandedRecordings() }
    }
}
