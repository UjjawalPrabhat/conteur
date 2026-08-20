import SwiftUI

/// The telling. A fire, the words as they arrive, and one way to stop.
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
            if isUnusable {
                NightBackground()
                notEnough
            } else {
                // A second telling sits closer to the fire: same night, later hour.
                CampfireScene(isClose: challenge != nil)
                fireside
            }
        }
        .toolbar(.hidden, for: .navigationBar)
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

    // MARK: - At the fire

    private var fireside: some View {
        VStack(spacing: 0) {
            topBar
            Spacer(minLength: Space.xl)

            Text(invitation)
                .textStyle(.prompt)
                .foregroundStyle(Color.paper.opacity(0.82))
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.7), radius: 9, y: 2)
                .padding(.horizontal, Space.xxl)

            if let challenge, model.isListening {
                challengeCard(challenge)
                    .padding(.top, Space.xl)
                    .padding(.horizontal, Space.screen)
            }

            Spacer(minLength: Space.l)

            if model.isRunningOut {
                Callout(
                    text: "About \(Int(model.remaining.rounded())) seconds left — start drawing it to a close.",
                    isWarning: true
                )
                .screenPadding()
                .padding(.bottom, Space.md)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            transcript
            action
                .screenPadding()
                .padding(.top, Space.lg)
                .padding(.bottom, Space.xl)
        }
    }

    private var topBar: some View {
        HStack {
            if model.phase != .responding {
                BackButton(title: "Stories", tint: Ink.tertiary) {
                    Task {
                        await model.cancel()
                        onAbandon()
                    }
                }
            }
            Spacer()
            Text(clock)
                .textStyle(.timer)
                .monospacedDigit()
                .foregroundStyle(model.isRunningOut ? Color.ember : Ink.tertiary)
        }
        .screenPadding()
        .padding(.top, Space.s)
    }

    /// Counting up while there is room, and down once there is not. The switch is the
    /// warning — a number falling reads as a limit in a way an elapsed time never does.
    private var clock: String {
        let seconds = model.isRunningOut ? model.remaining : model.elapsed
        return "\(Int(seconds) / 60):\(String(format: "%02d", Int(seconds) % 60))"
    }

    private func challengeCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("Your challenge").eyebrowStyle(.eyebrowSmall, color: Color.ember.opacity(0.85))
            Text(text)
                .textStyle(.body)
                .foregroundStyle(Color(hex: 0xFAF0E4).opacity(0.88))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.md)
        .background(.ultraThinMaterial.opacity(0.5), in: .rect(cornerRadius: Radius.callout))
        .background(Color(hex: 0x100A06).opacity(0.55), in: .rect(cornerRadius: Radius.callout))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.callout)
                .strokeBorder(Color(hex: 0xFFC896).opacity(0.16), lineWidth: 1)
        }
    }

    /// Bottom-anchored, so the newest words sit where the eye already is.
    @ViewBuilder
    private var transcript: some View {
        if model.isListening, !model.heard.isEmpty {
            ScrollView {
                VStack {
                    Spacer(minLength: 0)
                    (Text(model.settled + (model.settled.isEmpty ? "" : " "))
                        .foregroundStyle(Ink.settled)
                     + Text(model.phrase)
                        .foregroundStyle(Color(hex: 0xFFF4E6).opacity(0.95))
                     + Text(" ▎")
                        .foregroundStyle(Color.ember))
                    .textStyle(.transcript)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 150, alignment: .bottom)
            }
            .frame(height: 150)
            .scrollIndicators(.hidden)
            .defaultScrollAnchor(.bottom)
            .shadow(color: .black.opacity(0.85), radius: 8, y: 2)
            .screenPadding()
        }
    }

    @ViewBuilder
    private var action: some View {
        switch model.phase {
        case .listening:
            Button("That's it") {
                Task { await model.end() }
            }
            .buttonStyle(FiresideButtonStyle())
        case .ready, .preparing, .reading:
            // The wait stays at the fire. A spinner on a blank screen would end the scene
            // at exactly the moment the app is deciding what to say about it.
            ProgressView()
                .tint(Color.ember)
                .frame(height: 54)
        case .responding, .failed, .tooShort, .unmatched:
            EmptyView()
        }
    }

    // MARK: - Nothing to judge

    private var isUnusable: Bool {
        switch model.phase {
        case .tooShort, .unmatched, .failed: true
        case .ready, .preparing, .listening, .reading, .responding: false
        }
    }

    /// No scores, no ratings, no findings. A short telling is not a weak one, and the screen
    /// has to say so without reading as a scolding.
    private var notEnough: some View {
        VStack(spacing: Space.xl) {
            Spacer()
            DimmedEmber()
            Text(invitation)
                .textStyle(.statement)
                .foregroundStyle(Ink.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.xxl)
            Text(explanation)
                .textStyle(.body)
                .foregroundStyle(Ink.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.xxl)
            Spacer()
            VStack(spacing: Space.m) {
                Button("Start again") { model.begin() }
                    .buttonStyle(EmberButtonStyle())
                Button("Back to stories") {
                    Task {
                        await model.cancel()
                        onAbandon()
                    }
                }
                .buttonStyle(OutlineButtonStyle())
            }
            .screenPadding()
            .padding(.bottom, Space.xl)
        }
    }

    private var explanation: String {
        switch model.phase {
        case .tooShort:
            "\(model.spokenWords) words in \(Int(model.spokenDuration.rounded())) seconds. "
            + "Nothing is scored — a short telling isn't a weak one, there's just nothing to point at."
        case .unmatched:
            "Nothing is scored. What you said didn't line up with the story, so there is nothing to measure it against."
        default:
            "Nothing is scored."
        }
    }

    private var invitation: String {
        switch model.phase {
        case .ready, .preparing: "One moment."
        case .listening: "I'm listening. Take your time."
        case .reading: "Thinking about how you told it."
        case .responding: ""
        case .tooShort:
            "There wasn't enough in that one for me to say much about how you told it."
        case .unmatched:
            "I heard you, but I couldn't line any of it up with \"\(story.title)\"."
        case .failed(let message): message
        }
    }
}
