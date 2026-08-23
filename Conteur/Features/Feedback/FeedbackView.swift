import SwiftUI

/// What the telling did, folded.
///
/// The headline, the one thing to do next, and a way back into the loop are the only things
/// open. Everything else is behind a row with a count on it — you can see there were three
/// moments worth hearing without being made to read them before you can retell.
struct FeedbackView: View {
    @State private var model: FeedbackViewModel
    /// Owned here rather than by the row, because tapping a finding has to be able to open it.
    @State private var isTranscriptOpen = false
    private let earnedLevel: FireLevel?
    private let onRetell: () -> Void
    private let onDone: () -> Void

    init(
        assessment: Assessment,
        earnedLevel: FireLevel? = nil,
        onRetell: @escaping () -> Void,
        onDone: @escaping () -> Void
    ) {
        _model = State(initialValue: FeedbackViewModel(assessment: assessment))
        self.earnedLevel = earnedLevel
        self.onRetell = onRetell
        self.onDone = onDone
    }

    var body: some View {
        // The reader is what lets a finding send you to the words it came from. A claim you
        // cannot go and hear is an opinion, so the transcript has to be reachable from it.
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Space.screen) {
                    meta
                    headline
                    tierAward
                    next
                    folds(proxy)
                }
                .screenPadding()
                .padding(.top, Space.l)
                .padding(.bottom, Space.section)
            }
            .scrollIndicators(.hidden)
        }
        .background(NightBackground())
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top) {
            HStack {
                Spacer()
                Button("Done", action: onDone)
                    .textStyle(.action)
                    .foregroundStyle(Color.ember)
                    .frame(minHeight: 44)
            }
            .screenPadding()
        }
        .sensoryFeedback(.selection, trigger: model.highlighted)
    }

    private var meta: some View {
        Text(model.subtitle)
            .textStyle(.meta)
            .foregroundStyle(Color.paper.opacity(0.42))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The verdict on a second telling, and the note on a first. One sentence either way —
    /// the point of the fold is that the top of this screen can be read in a breath.
    private var headline: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            if let progress = model.assessment.progress {
                Text(progress.verdict.label)
                    .textStyle(.statement)
                    .foregroundStyle(progress.verdict.tint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(model.note)
                .textStyle(.narrative)
                .foregroundStyle(Color.paper.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Only when this telling was the one that earned it. A level shown on every screen after
    /// it is won stops being an event.
    @ViewBuilder
    private var tierAward: some View {
        if let earnedLevel {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("You've reached").eyebrowStyle(.eyebrowSmall)
                Text(earnedLevel.label)
                    .textStyle(.verdict)
                    .foregroundStyle(Color.emberLight)
                Text("\(earnedLevel.requirement.capitalizedFirst). This telling was the one that did it.")
                    .textStyle(.secondary)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Space.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface(Surface.emberWash, border: Surface.emberEdge)
        }
    }

    /// Always present. The way back into the loop must not depend on there having been
    /// something wrong.
    private var next: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("Next").eyebrowStyle(.eyebrowSmall)
            Text(model.challenge)
                .textStyle(.body)
                .foregroundStyle(Ink.primary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Tell it again", action: onRetell)
                .buttonStyle(EmberButtonStyle(height: 52, radius: 15))
            Text("Same story. You won't read it again.")
                .textStyle(.meta)
                .foregroundStyle(Ink.tertiary)
                .frame(maxWidth: .infinity)
        }
        .padding(Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.ember.opacity(0.16), Color.emberEdge.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: Radius.card)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card)
                .strokeBorder(Color.ember.opacity(0.28), lineWidth: 1)
        }
    }

    private func folds(_ proxy: ScrollViewProxy) -> some View {
        VStack(spacing: Space.m) {
            if !model.located.isEmpty {
                FoldedRow(title: "Moments worth hearing", trailing: "\(model.located.count)") {
                    VStack(spacing: Space.sm) {
                        ForEach(model.located) { item in
                            findingCard(item, proxy)
                        }
                    }
                }
            }

            if !model.absences.isEmpty {
                FoldedRow(title: "What didn't come through", trailing: "\(model.absences.count)") {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        Text("No timestamps — these are absences.")
                            .textStyle(.secondary)
                            .foregroundStyle(Ink.tertiary)
                        ForEach(model.absences) { item in
                            absenceCard(item)
                        }
                    }
                }
            }

            FoldedRow(title: "All six ratings", trailing: model.strongLabel) {
                VStack(spacing: 0) {
                    ForEach(Array(model.bands.enumerated()), id: \.element.dimension) { index, assessment in
                        if index > 0 {
                            Rectangle().fill(Surface.dividerQuiet).frame(height: 1)
                        }
                        HStack {
                            Text(assessment.dimension.title)
                                .textStyle(.rowTitle)
                                .foregroundStyle(Ink.primary)
                            if assessment.dimension == model.feedback?.dimension {
                                Text("focus")
                                    .textStyle(.eyebrowSmall)
                                    .textCase(.lowercase)
                                    .foregroundStyle(Color.ember.opacity(0.7))
                            }
                            Spacer()
                            Pill(text: assessment.band.label, isStrong: assessment.band == .strong)
                        }
                        .padding(.vertical, 11)
                    }
                }
            }

            if !model.passages.isEmpty {
                FoldedRow(
                    title: "What you said",
                    trailing: model.spokenDuration,
                    openness: $isTranscriptOpen
                ) {
                    VStack(alignment: .leading, spacing: Space.md) {
                        ForEach(model.passages) { passage in
                            TranscriptLine(
                                at: passage.start.timestampLabel,
                                text: passage.text,
                                isHighlighted: passage.start == model.highlighted
                            )
                        }
                    }
                }
            }
        }
    }

    /// Every claim points at the words it came from. Without that the feedback is an
    /// opinion; with it, the reader can go and check.
    private func findingCard(_ item: FeedbackViewModel.Detail, _ proxy: ScrollViewProxy) -> some View {
        Button {
            reveal(item, using: proxy)
        } label: {
            findingBody(item)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows the words this came from")
    }

    /// Opens the transcript at the moment a finding is about. The fold has to be laid out
    /// before it can be scrolled to, which is why the scroll waits a beat.
    private func reveal(_ item: FeedbackViewModel.Detail, using proxy: ScrollViewProxy) {
        guard let at = item.evidence.at else { return }
        model.reveal(at)
        withAnimation(.easeInOut(duration: 0.25)) { isTranscriptOpen = true }

        guard let target = model.highlighted else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo(target, anchor: .center) }
        }
    }

    private func findingBody(_ item: FeedbackViewModel.Detail) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.s) {
                Text(item.evidence.at?.timestampLabel ?? "")
                    .textStyle(.timestamp)
                    .foregroundStyle(Color.ember)
                Text(item.dimension.title)
                    .textStyle(.categoryLabel)
                    .textCase(.uppercase)
                    .foregroundStyle(Ink.tertiary)
                Spacer()
            }
            if let quote = item.evidence.quote {
                QuotedWords(text: quote)
            }
            if let detail = item.observation ?? item.evidence.measure {
                Text(detail)
                    .textStyle(.secondary)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(Surface.card, radius: Radius.finding)
    }

    /// Absences have no moment to point at, so they are listed rather than located. The dashed
    /// edge is the distinction, and it must not be softened into looking like the cards above.
    private func absenceCard(_ item: FeedbackViewModel.Detail) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(item.dimension.title)
                .textStyle(.categoryLabel)
                .textCase(.uppercase)
                .foregroundStyle(Ink.tertiary)
            Text(item.observation ?? item.evidence.quote ?? "")
                .textStyle(.secondary)
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .absenceSurface()
    }
}
