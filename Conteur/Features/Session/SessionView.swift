import SwiftUI

struct SessionView: View {
    let story: GuidedStory
    let challenge: String?
    let baseline: Baseline
    let history: Band?
    let previous: Diagnosis?
    @Binding var isTelling: Bool
    let onFinish: (Assessment) -> Void

    @State private var model: SessionViewModel

    init(
        story: GuidedStory,
        challenge: String?,
        baseline: Baseline,
        history: Band?,
        previous: Diagnosis?,
        isTelling: Binding<Bool>,
        onFinish: @escaping (Assessment) -> Void
    ) {
        self.story = story
        self.challenge = challenge
        self.baseline = baseline
        self.history = history
        self.previous = previous
        _isTelling = isTelling
        self.onFinish = onFinish
        _model = State(initialValue: SessionViewModel(story: story))
    }


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

                if model.isRunningOut {
                    Text("About \(Int(model.remaining.rounded())) seconds left — start drawing it to a close.")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .monospacedDigit()
                        .padding(.top, 8)
                        .transition(.opacity)
                }

                Spacer()
                action
                    .padding(.bottom, 48)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: model.phase)
        .task { model.prime(baseline: baseline, history: history, previous: previous, challenge: challenge) }
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
        case .ready, .failed, .tooShort:
            Button(model.phase == .tooShort ? "Start again" : "Tell me about it") { model.begin() }
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
            challenge ?? "Tell me \"\(story.title)\" back, in your own words."
        case .preparing: "One moment."
        case .listening: "I'm listening. Take your time."
        case .reading: "Thinking about how you told it."
        case .responding: ""
        case .tooShort:
            "That was too short for me to say anything useful. Tell me a bit more of it."
        case .failed(let message): message
        }
    }
}
