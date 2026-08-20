import SwiftData
import SwiftUI

/// Owns the loop: pick a story, read it, tell it back, hear how you told it, tell it again.
///
/// Sits above the features rather than inside one. It drives Reading, Session and Feedback in
/// turn, and living in any of them would have made that feature the owner of its two siblings.
///
/// Every telling ends on the feedback screen — a second one simply shows what changed at
/// the top of it. That keeps the loop open past two attempts, and means no telling can ever
/// end without feedback.
struct TellFlowView: View {
    private enum Stage: Equatable {
        case choosing
        case reading
        case telling
        case feedback
    }

    @Environment(\.modelContext) private var context

    @State private var stage: Stage = .choosing
    @State private var story: GuidedStory?
    @State private var group = UUID()
    @State private var attempt = 1
    @State private var previous: Assessment?
    @State private var current: Assessment?
    @State private var isTelling = false

    var body: some View {
        NavigationStack {
            content
                // The feedback fades in rather than sliding. A push reads as going somewhere
                // else; this is the fire answering, and it should arrive where you are.
                .animation(.easeInOut(duration: 0.35), value: stage)
                .transition(.opacity)
        }
        // The tab bar is a distraction while somebody is mid-story, so it goes away for
        // the telling and comes back afterwards.
        .toolbar(isTelling ? .hidden : .automatic, for: .tabBar)
    }

    @ViewBuilder
    private var content: some View {
        switch stage {
        case .choosing:
            StoryPickerView { chosen in
                story = chosen
                stage = .reading
            }

        case .reading:
            if let story {
                ReadingView(
                    story: story,
                    onBack: { restart() },
                    onFinished: { stage = .telling }
                )
            }

        case .telling:
            if let story {
                session(story)
            }

        case .feedback:
            if let current {
                FeedbackView(
                    assessment: current,
                    onRetell: { retell() },
                    onDone: { restart() }
                )
            }
        }
    }

    private func session(_ story: GuidedStory) -> some View {
        let store = SwiftDataRetellingStore(context: context)

        return SessionView(
            story: story,
            challenge: previous?.feedback?.challenge,
            baseline: store.baseline(),
            history: previous?.focus.flatMap { store.lastBand(for: $0) },
            previous: previous?.diagnosis,
            isTelling: $isTelling,
            onAbandon: { restart() }
        ) { assessment in
            try? store.save(assessment, attempt: attempt, group: group, isBenchmark: false)
            current = assessment
            stage = .feedback
        }
        // A fresh identity per attempt so the session screen starts clean rather than
        // reusing the previous attempt's view model.
        .id(attempt)
    }

    /// The same story, told again against the challenge. The story is not shown a second
    /// time — the point is what they retained and how they told it, not re-reading.
    private func retell() {
        previous = current
        current = nil
        attempt += 1
        isTelling = false
        stage = .telling
    }

    private func restart() {
        previous = nil
        current = nil
        story = nil
        attempt = 1
        group = UUID()
        isTelling = false
        stage = .choosing
    }
}
