import SwiftUI

struct FeedbackView: View {
    @State private var model: FeedbackViewModel
    private let onRetell: () -> Void
    private let onDone: () -> Void

    init(
        assessment: Assessment,
        onRetell: @escaping () -> Void,
        onDone: @escaping () -> Void
    ) {
        _model = State(initialValue: FeedbackViewModel(assessment: assessment))
        self.onRetell = onRetell
        self.onDone = onDone
    }

    var body: some View {
        ScrollViewReader { scroll in
            ScrollView {
                VStack(alignment: .leading, spacing: Space.section) {
                    header
                    whatChanged
                    note
                    locatedFindings(scrollingWith: scroll)
                    absences
                    tryAgain
                    everythingElse
                    transcript
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
            }
            .screenPadding()
            .padding(.bottom, Space.s)
        }
        .sensoryFeedback(.selection, trigger: model.highlighted)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("How you told it")
                .textStyle(.screenTitle)
                .foregroundStyle(Ink.primary)
            Text(subtitle)
                .textStyle(.meta)
                .foregroundStyle(Color.paper.opacity(0.42))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var subtitle: String {
        let transcript = model.assessment.timeline.transcript
        var parts = [model.assessment.comparison.story.title]
        if model.assessment.progress != nil { parts.append("second telling") }
        parts.append("\(transcript.words.count) words")
        parts.append(transcript.duration.secondsLabel)
        return parts.joined(separator: " · ")
    }

    /// Shown from the second telling on. The verdict is computed, never written, so it
    /// can say the attempt missed.
    @ViewBuilder
    private var whatChanged: some View {
        if let progress = model.assessment.progress {
            VStack(alignment: .leading, spacing: Space.m) {
                Text("You were asked").eyebrowStyle(.eyebrowSmall)
                Text(progress.challenge)
                    .textStyle(.body)
                    .foregroundStyle(Color.paper.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)

                Text(progress.verdict.label)
                    .textStyle(.verdict)
                    .foregroundStyle(progress.verdict.tint)

                HStack(spacing: Space.s) {
                    Text(progress.focus.title)
                        .textStyle(.categoryLabel)
                        .textCase(.uppercase)
                        .foregroundStyle(Ink.tertiary)
                    Spacer()
                    Pill(text: progress.before.label)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Ink.quaternary)
                    Pill(text: progress.after.label, isStrong: progress.after == .strong)
                }
            }
            .padding(Space.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface(Surface.emberWash, border: Surface.emberEdge)
        }
    }

    private var note: some View {
        Text(model.feedback?.note ?? "There wasn't enough in that one for me to say much about how you told it.")
            .textStyle(.narrative)
            .foregroundStyle(Color.paper.opacity(0.92))
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Every claim points at the words it came from. Without that the feedback is an
    /// opinion; with it, the reader can go and check.
    @ViewBuilder
    private func locatedFindings(scrollingWith scroll: ScrollViewProxy) -> some View {
        if !model.located.isEmpty {
            VStack(alignment: .leading, spacing: Space.md) {
                SectionHeading(title: "Where")
                ForEach(model.located) { item in
                    Button {
                        model.reveal(item.evidence.at)
                        withAnimation {
                            scroll.scrollTo(
                                item.evidence.at.flatMap { model.passage(covering: $0)?.start },
                                anchor: .center
                            )
                        }
                    } label: {
                        findingCard(item)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Shows this moment in the transcript below")
                }
            }
        }
    }

    private func findingCard(_ item: FeedbackViewModel.Detail) -> some View {
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
        .cardSurface(Surface.finding, radius: Radius.finding)
    }

    /// Absences have no moment to point at, so they are listed rather than located. Showing
    /// them under "Where" with a 0:00 beside them claimed they happened. The dashed edge is
    /// the distinction, and it must not be softened into looking like the cards above.
    @ViewBuilder
    private var absences: some View {
        if !model.absences.isEmpty {
            VStack(alignment: .leading, spacing: Space.md) {
                SectionHeading(
                    title: "What didn't come through",
                    note: "No timestamps — these are absences."
                )
                ForEach(model.absences) { item in
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
        }
    }

    /// Always present. The way back into the loop must not depend on there having been
    /// something wrong.
    private var tryAgain: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionHeading(title: "Try again")
            Text(model.feedback?.challenge ?? "Tell it again, and give it a bit more room this time.")
                .textStyle(.body)
                .foregroundStyle(Ink.primary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Tell it again", action: onRetell)
                .buttonStyle(EmberButtonStyle(height: 52, radius: 15))
                .padding(.top, Space.xxs)
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

    private var everythingElse: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeading(title: "Everything else")
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
                    .padding(.horizontal, Space.l)
                }
            }
            .cardSurface(Surface.finding)
        }
    }

    @ViewBuilder
    private var transcript: some View {
        if !model.passages.isEmpty {
            VStack(alignment: .leading, spacing: Space.md) {
                SectionHeading(title: "What you said")
                ForEach(model.passages) { passage in
                    TranscriptLine(at: passage.start.timestampLabel, text: passage.text)
                        .padding(.vertical, Space.xs)
                        .padding(.horizontal, Space.s)
                        .background(
                            model.highlighted == passage.start ? Surface.emberPill : .clear,
                            in: .rect(cornerRadius: Radius.pill)
                        )
                        .animation(.easeOut(duration: 0.25), value: model.highlighted)
                        .id(passage.start)
                }
            }
        }
    }
}
