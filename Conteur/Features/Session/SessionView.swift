import SwiftUI

struct SessionView: View {
    let story: GuidedStory
    let challenge: String?
    let baseline: Baseline
    let history: Band?
    let previous: Diagnosis?
    @Binding var isTelling: Bool
    let onAbandon: () -> Void
    let onFinish: (Assessment) -> Void

    @State private var model: SessionViewModel

    init(
        story: GuidedStory,
        challenge: String?,
        baseline: Baseline,
        history: Band?,
        previous: Diagnosis?,
        isTelling: Binding<Bool>,
        onAbandon: @escaping () -> Void,
        onFinish: @escaping (Assessment) -> Void
    ) {
        self.story = story
        self.challenge = challenge
        self.baseline = baseline
        self.history = history
        self.previous = previous
        _isTelling = isTelling
        self.onAbandon = onAbandon
        self.onFinish = onFinish
        _model = State(initialValue: SessionViewModel(story: story))
    }


    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack {
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

                if let challenge, model.isListening {
                    Text(challenge)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.tint)
                        .padding(.horizontal, 40)
                        .padding(.top, 10)
                }

                if !model.heard.isEmpty, showsWhatWasHeard {
                    ScrollView {
                        Text(model.heard)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 160)
                    .padding(.horizontal, 28)
                    .padding(.top, 12)
                }

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
        .overlay(alignment: .topLeading) {
            if model.phase != .responding {
                Button("Stories", systemImage: "chevron.left") {
                    Task {
                        await model.cancel()
                        onAbandon()
                    }
                }
                .padding()
            }
        }
        .animation(.easeInOut(duration: 0.4), value: model.phase)
        .task {
            model.prime(baseline: baseline, history: history, previous: previous, challenge: challenge)
            // Getting to this screen — from the story, or from "tell it again" — is already
            // the decision to tell it, so there is nothing left to confirm.
            model.begin()
        }
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
        case .failed, .tooShort, .unmatched:
            Button("Start again") { model.begin() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        case .ready, .preparing, .reading:
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

    /// After a retelling that could not be used, what was heard is the only thing that
    /// explains why — whether the words arrived wrong or arrived and were not recognised.
    private var showsWhatWasHeard: Bool {
        switch model.phase {
        case .unmatched, .tooShort, .failed: true
        case .ready, .preparing, .listening, .reading, .responding: false
        }
    }

    private var invitation: String {
        switch model.phase {
        case .ready, .preparing: "One moment."
        case .listening: "I'm listening. Take your time."
        case .reading: "Thinking about how you told it."
        case .responding: ""
        case .tooShort:
            "That was too short for me to say anything useful. Tell me a bit more of it."
        case .unmatched:
            "I heard you, but I couldn't line any of it up with \"\(story.title)\"."
        case .failed(let message): message
        }
    }
}
