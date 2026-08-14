import SwiftUI

struct SessionView: View {
    let challenge: String?
    let baseline: Baseline
    let history: Band?
    @Binding var isTelling: Bool
    let onFinish: (Assessment) -> Void

    @State private var model = SessionViewModel()

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack {
                if model.isListening {
                    SelfView(image: model.selfView, reading: model.reading)
                        .padding(.top, 12)
                        .transition(.opacity)
                }

                Spacer()
                ListeningPresence(
                    level: model.level,
                    isAttending: model.isAttending,
                    isAwake: model.isListening
                )
                .frame(height: 280)
                Spacer()

                Text(invitation)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 40)

                Spacer()
                action
                    .padding(.bottom, 48)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: model.phase)
        .task { model.prime(baseline: baseline, history: history) }
        .onChange(of: model.phase) { _, phase in
            isTelling = phase == .listening || phase == .reading
            if phase == .responding, let assessment = model.assessment {
                onFinish(assessment)
            }
        }
    }

    @ViewBuilder
    private var action: some View {
        switch model.phase {
        case .ready, .failed:
            Button("Tell me about it") { model.begin() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        case .preparing, .reading:
            ProgressView()
        case .listening:
            Button("That's it") {
                Task { await model.end() }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        case .responding:
            EmptyView()
        }
    }

    private var invitation: String {
        switch model.phase {
        case .ready:
            challenge ?? "Tell me about what you just read."
        case .preparing: "One moment."
        case .listening: "I'm listening. Take your time."
        case .reading: "Thinking about how you told it."
        case .responding: ""
        case .failed(let message): message
        }
    }
}
