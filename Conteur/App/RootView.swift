import SwiftUI

struct RootView: View {
    @State private var isShowingSplash = true

    var body: some View {
//        TabView {
//            Tab("Tell", systemImage: "waveform") {
//                TellFlowView()
//            }
//            Tab("Retellings", systemImage: "arrow.counterclockwise") {
//                HistoryView()
//            }
//            Tab("Progress", systemImage: "chart.bar") {
//                ProgressCoachView()
//            }
//        }
//        .tint(Color.ember)
//        // The app is a fire at night. There is no light variant of that, so the appearance
//        // is pinned rather than left to follow the system into a palette it has no colours for.
//        .preferredColorScheme(.dark)
//        .tabBarMinimizeBehavior(.onScrollDown)
        ZStack {
            TellFlowView()
                .task { await RecordingCleanup.removeStrandedRecordings() }

            if isShowingSplash {
                SplashScreenView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.6)) {
                    isShowingSplash = false
                }
            }
        }
    }
}

#Preview {
    RootView()
}
