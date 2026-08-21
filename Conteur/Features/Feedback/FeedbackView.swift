import SwiftUI

struct FeedbackView: View {
    @State private var model: FeedbackViewModel
    private let assessment: Assessment
    private let hasPrevious: Bool
    private let onRetell: () -> Void
    private let onDone: () -> Void

    init(
        assessment: Assessment,
        hasPrevious: Bool = false,
        onRetell: @escaping () -> Void,
        onDone: @escaping () -> Void
    ) {
        _model = State(initialValue: FeedbackViewModel(assessment: assessment))
        self.assessment = assessment
        self.hasPrevious = hasPrevious
        self.onRetell = onRetell
        self.onDone = onDone
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scroll in
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        readingProgress
                        modeHeader
                        whatChanged
                        note
                        allFindings
                        deliverySignals
                        rawBeats
                        feedbackEvidence(scrollingWith: scroll)
                        challenge
                        bands
                        transcript
                    }
                    .padding()
                }
            }
            .navigationTitle("How you told it")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                }
            }
            .sensoryFeedback(.selection, trigger: model.highlighted)
        }
    }

    // MARK: - Reading progress

    @ViewBuilder
    private var readingProgress: some View {
        let progress = model.readingProgress
        if progress.previousSessions == 0 { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 6) {
                Text("Reading progress")
                    .font(.headline)
                Text("Session #\(progress.previousSessions) · continuation mode")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !progress.coveredComponents.isEmpty {
                    Text("Covered: \(progress.coveredComponents.map(\.rawValue).sorted().joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("Stakes established: \(progress.stakesEstablished ? "yes" : "no")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !progress.knownEntities.isEmpty {
                    Text("Known entities: \(progress.knownEntities.sorted().joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(.orange.opacity(0.08), in: .rect(cornerRadius: 12))
        )
    }

    // MARK: - What changed

    /// Shown from the second telling on. The verdict is computed, never written, so it
    /// can say the attempt missed.
    @ViewBuilder
    private var whatChanged: some View {
        if let progress = model.assessment.progress {
            VStack(alignment: .leading, spacing: 12) {
                Text("You were asked")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(progress.challenge)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Image(systemName: progress.verdict.symbol)
                    Text(progress.verdict.label)
                        .font(.headline)
                    Spacer()
                    Text("\(progress.before.label) → \(progress.after.label)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(progress.verdict.tint)

                ForEach(progress.resolved, id: \.identity) { finding in
                    changeRow(finding.observation, symbol: "checkmark")
                }
                ForEach(progress.persisted, id: \.identity) { finding in
                    changeRow(finding.observation, symbol: "arrow.turn.down.right")
                }
                ForEach(progress.introduced, id: \.identity) { finding in
                    changeRow(finding.observation, symbol: "exclamationmark")
                }
            }
            .padding()
            .background(progress.verdict.tint.opacity(0.1), in: .rect(cornerRadius: 12))
        }
    }

    private func changeRow(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Mode header

    private var modeHeader: some View {
        if assessment.mode == .standalone {
            return AnyView(
                Text("Standalone")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            )
        }

        return AnyView(EmptyView())
    }

    // MARK: - Composed note

    private var note: some View {
        Text(model.feedback?.note ?? "There wasn't enough in that one for me to say much about how you told it.")
            .font(.title3)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - All findings

    private var allFindings: some View {
        let findingsByDimension = model.allFindings
        if findingsByDimension.isEmpty {
            return AnyView(EmptyView())
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("All findings")
                    .font(.headline)

                ForEach(findingsByDimension.keys.sorted { $0.rawValue < $1.rawValue }, id: \.rawValue) { dimension in
                    let findings = findingsByDimension[dimension]!
                    FindingSection(dimension: dimension, findings: findings)
                }
            }
        )
    }

    // MARK: - Delivery signals

    private var deliverySignals: some View {
        let signals = model.deliverySignals
        guard signals.wordCount > 0 else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Text("Delivery signals")
                    .font(.headline)

                HStack(spacing: 16) {
                    signalItem("WPM", "\(Int(signals.wordsPerMinute))")
                    signalItem("Words", "\(signals.wordCount)")
                    signalItem("Duration", signals.duration.secondsLabel)
                }

                if !signals.filledPauses.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fillers (\(signals.filledPauses.count), rate \(signals.filledPauseRate.percentLabel))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(Array(signals.filledPauses.prefix(10).enumerated()), id: \.offset) { _, pause in
                            Text("\(pause.at.timestampLabel): \(pause.token)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !signals.restarts.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Restarts (\(signals.restarts.count))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(Array(signals.restarts.prefix(10).enumerated()), id: \.offset) { _, restart in
                            Text("\(restart.at.timestampLabel): \"\(restart.phrase)\"")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                let stalls = signals.pauses(of: .stall)
                if !stalls.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Stalls (\(stalls.count))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(Array(stalls.prefix(10).enumerated()), id: \.offset) { _, pause in
                            Text("\(pause.start.timestampLabel): \(pause.duration.secondsLabel)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding()
            .background(.quaternary.opacity(0.3), in: .rect(cornerRadius: 12))
        )
    }

    private func signalItem(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
                .monospacedDigit()
        }
    }

    // MARK: - Raw beats

    private var rawBeats: some View {
        let beats = model.beatDetails
        guard !beats.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Text("Raw beats")
                    .font(.headline)

                ForEach(Array(beats.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("\(item.beat.kind.rawValue) · \(item.beat.start.timestampLabel)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(item.beat.summary)
                                .font(.caption)
                        }
                        Text(item.text)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if !item.beat.entitiesIntroduced.isEmpty {
                            Text("Introduced: \(item.beat.entitiesIntroduced.joined(separator: ", "))")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                        if !item.beat.entitiesReferenced.isEmpty {
                            Text("Referenced: \(item.beat.entitiesReferenced.joined(separator: ", "))")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                        HStack(spacing: 8) {
                            if item.beat.statesStakes {
                                Text("stakes")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                            if item.beat.connectsCausally {
                                Text("causal")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(.quaternary.opacity(0.3), in: .rect(cornerRadius: 6))
                }
            }
        )
    }

    // MARK: - Evidence

    @ViewBuilder
    private func feedbackEvidence(scrollingWith scroll: ScrollViewProxy) -> some View {
        if let feedback = model.feedback, !feedback.evidence.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Feedback evidence")
                    .font(.headline)
                    .padding(.bottom, 8)

                ForEach(Array(feedback.evidence.enumerated()), id: \.offset) { _, item in
                    Button {
                        model.reveal(item.at)
                        withAnimation {
                            scroll.scrollTo(model.passage(covering: item.at)?.start, anchor: .center)
                        }
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(item.at.timestampLabel)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                if let quote = item.quote {
                                    Text(quote).multilineTextAlignment(.leading)
                                }
                                if let measure = item.measure {
                                    Text(measure)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "text.quote")
                                .foregroundStyle(.tint)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Challenge

    private var challenge: some View {
        let canRetry = hasPrevious || assessment.progress != nil
        return VStack(alignment: .leading, spacing: 8) {
            Text(canRetry ? "Try again" : "Next time")
                .font(.headline)
            Text(model.feedback?.challenge ?? "Tell it again, and give it a bit more room this time.")
                .fixedSize(horizontal: false, vertical: true)

            if canRetry {
                Button("Tell it again", action: onRetell)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(.tint.opacity(0.08), in: .rect(cornerRadius: 12))
    }

    // MARK: - Dimension bands (summary)

    private var bands: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dimension scores")
                .font(.headline)

            ForEach(model.bands, id: \.dimension) { assessment in
                HStack {
                    Text(assessment.dimension.title)
                    Spacer()
                    Text("\(assessment.band.label) (\(assessment.score.formatted(.number.precision(.fractionLength(2)))))")
                        .foregroundStyle(assessment.dimension == model.feedback?.dimension ? .primary : .secondary)
                }
                .font(.callout)
            }
        }
    }

    // MARK: - Transcript

    private var transcript: some View {
        let passages = model.passages
        if !passages.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("What you said")
                    .font(.headline)

                ForEach(passages) { passage in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(passage.start.timestampLabel)
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Text(passage.text)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .background(
                        model.highlighted == passage.start
                            ? AnyShapeStyle(.tint.opacity(0.14))
                            : AnyShapeStyle(.clear),
                        in: .rect(cornerRadius: 10)
                    )
                    .animation(.easeOut(duration: 0.25), value: model.highlighted)
                    .id(passage.start)
                }
            }
        }
        return AnyView(EmptyView())
    }
}

private struct FindingSection: View {
    let dimension: Dimension
    let findings: [Finding]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dimension.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(findings, id: \.self) { finding in
                FindingRow(finding: finding)
            }
        }
    }
}

private struct FindingRow: View {
    let finding: Finding

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(finding.observation)
                .font(.callout)
            Text("weight: \(finding.weight.formatted(.number.precision(.fractionLength(2)))) · magnitude: \(finding.magnitude.formatted(.number.precision(.fractionLength(2))))")
                .font(.caption2)
                .foregroundStyle(.secondary)
            ForEach(Array(finding.evidence.enumerated()), id: \.offset) { _, evidence in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(evidence.at.timestampLabel)
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    if let quote = evidence.quote {
                        Text(quote)
                    }
                    if let measure = evidence.measure {
                        Text(measure)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 6))
    }
}
