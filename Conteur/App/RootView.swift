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
        }
    }
}
