import SwiftData
import SwiftUI

/// Owns the loop: tell it, hear how you told it, tell it again, see what changed —
/// and a way back out at every step.
struct TellFlowView: View {
    private enum Stage: Equatable {
        case telling
        case feedback
        case retelling
        case comparison
    }

    @Environment(\.modelContext) private var context

    @State private var stage: Stage = .telling
    @State private var group = UUID()
    @State private var first: Assessment?
    @State private var second: Assessment?
    @State private var isTelling = false

    var body: some View {
        content
            // The tab bar is a distraction while somebody is mid-story, so it goes
            // away for the telling and comes back afterwards.
            .toolbar(isTelling ? .hidden : .automatic, for: .tabBar)
    }

    @ViewBuilder
    private var content: some View {
        switch stage {
        case .telling:
            session(challenge: nil, attempt: 1) { assessment in
                first = assessment
                stage = .feedback
            }

        case .feedback:
            if let first {
                FeedbackView(
                    assessment: first,
                    onRetell: { stage = .retelling },
                    onDone: { restart() }
                )
            }

        case .retelling:
            session(challenge: first?.feedback?.challenge, attempt: 2) { assessment in
                second = assessment
                stage = .comparison
            }

        case .comparison:
            if let first, let second {
                ComparisonView(first: first, second: second) { restart() }
            }
        }
    }

    private func session(
        challenge: String?,
        attempt: Int,
        onFinish: @escaping (Assessment) -> Void
    ) -> some View {
        let store = SwiftDataRetellingStore(context: context)

        return SessionView(
            challenge: challenge,
            baseline: store.baseline(),
            history: first?.focus.flatMap { store.lastBand(for: $0) },
            isTelling: $isTelling
        ) { assessment in
            try? store.save(assessment, attempt: attempt, group: group, isBenchmark: false)
            onFinish(assessment)
        }
        // A fresh identity per attempt so the session screen starts clean rather than
        // reusing the previous attempt's view model.
        .id(attempt)
    }

    private func restart() {
        first = nil
        second = nil
        group = UUID()
        isTelling = false
        stage = .telling
    }
}
