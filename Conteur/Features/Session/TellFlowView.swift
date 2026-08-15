import SwiftData
import SwiftUI

/// Owns the loop: tell it, hear how you told it, tell it again, see what changed.
///
/// Every telling ends on the feedback screen — a second one simply shows what changed at
/// the top of it. That keeps the loop open past two attempts, and means no telling can
/// ever end without feedback.
struct TellFlowView: View {
    private enum Stage: Equatable {
        case telling
        case feedback
    }

    @Environment(\.modelContext) private var context

    @State private var stage: Stage = .telling
    @State private var group = UUID()
    @State private var attempt = 1
    @State private var previous: Assessment?
    @State private var current: Assessment?
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
            session

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

    private var session: some View {
        let store = SwiftDataRetellingStore(context: context)

        return SessionView(
            challenge: previous?.feedback?.challenge,
            baseline: store.baseline(),
            history: previous?.focus.flatMap { store.lastBand(for: $0) },
            previous: previous?.diagnosis,
            isTelling: $isTelling
        ) { assessment in
            try? store.save(assessment, attempt: attempt, group: group, isBenchmark: false)
            current = assessment
            stage = .feedback
        }
        // A fresh identity per attempt so the session screen starts clean rather than
        // reusing the previous attempt's view model.
        .id(attempt)
    }

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
        attempt = 1
        group = UUID()
        isTelling = false
        stage = .telling
    }
}
