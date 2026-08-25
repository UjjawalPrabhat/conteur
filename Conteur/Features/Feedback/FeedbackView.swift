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
    
    // Accordion states
    @State private var isMomentsOpen = false
    @State private var isAbsencesOpen = false
    @State private var isRatingsOpen = false
    
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
                VStack(alignment: .leading, spacing: 24) {
                    meta
                    headline
                    tierAward
                    next
                    folds(proxy)
                }
                .padding(24)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
        }
        .background {
            ZStack {
                NightBackground()
                StarsView()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            Button(action: onDone) {
                Text("Pick Another Story")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(hex: 0xFF8C00))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .sensoryFeedback(.selection, trigger: model.highlighted)
    }

    private var meta: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.assessment.comparison.story.title)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            
            let words = model.assessment.timeline.transcript.words.count
            let duration = model.assessment.timeline.transcript.duration.secondsLabel
            Text("\(words) words (\(duration))")
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(Color.gray)
            
            let isSecond = model.assessment.progress != nil
            Text(isSecond ? "Second Telling" : "First Telling")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.9))
                .clipShape(Capsule())
                .padding(.top, 4)
        }
    }

    /// The verdict on a second telling, and the note on a first. One sentence either way —
    /// the point of the fold is that the top of this screen can be read in a breath.
    private var headline: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let progress = model.assessment.progress {
                Text(progress.verdict.label)
                    .textStyle(.statement)
                    .foregroundStyle(progress.verdict.tint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(model.note)
                .font(.system(size: 16, design: .monospaced))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                
            Text("What's to improve")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.top, 8)
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
        VStack(spacing: 20) {
            Text(model.challenge)
                .font(.system(size: 16, design: .monospaced))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Button(action: onRetell) {
                Text("Tell it again")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(hex: 0xFF8C00))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .shadow(color: Color.white.opacity(0.3), radius: 10)
            }
            
            Text("Same story. You won't read it again.")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color.gray)
        }
        .padding(24)
        .background(Color(hex: 0x0A1024))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white, lineWidth: 1)
        )
    }

    private func folds(_ proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 16) {
            if !model.located.isEmpty {
                FeedbackAccordionView(title: "Moments worth hearing", trailing: "\(model.located.count)", openness: nil) {
                    VStack(spacing: 12) {
                        ForEach(model.located) { item in
                            findingCard(item, proxy)
                        }
                    }
                    .padding(16)
                }
            }

            if !model.absences.isEmpty {
                FeedbackAccordionView(title: "What didn't come through", trailing: "\(model.absences.count)", openness: nil) {
                    VStack(spacing: 12) {
                        ForEach(model.absences) { item in
                            absenceCard(item)
                        }
                    }
                    .padding(16)
                }
            }

            FeedbackAccordionView(title: "All five ratings", trailing: model.strongLabel, openness: nil) {
                VStack(spacing: 16) {
                    ForEach(model.bands, id: \.dimension) { assessment in
                        HStack {
                            Text(assessment.dimension.title.capitalized)
                                .font(.system(size: 16, design: .monospaced))
                                .foregroundStyle(.white)
                            Spacer()
                            Text(assessment.band.label)
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(assessment.band == .strong ? Color(hex: 0xFF8C00) : Color.gray)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(20)
            }

            if !model.passages.isEmpty {
                FeedbackAccordionView(title: "What you said", trailing: model.spokenDuration, openness: $isTranscriptOpen) {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(model.passages) { passage in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(passage.start.timestampLabel)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color(hex: 0xFF8C00))
                                
                                HStack(alignment: .top, spacing: 12) {
                                    Rectangle()
                                        .fill(Color(hex: 0xFF8C00))
                                        .frame(width: 2)
                                    
                                    Text(passage.text)
                                        .font(.system(size: 14, design: .monospaced))
                                        .foregroundStyle(.gray)
                                        .lineSpacing(4)
                                }
                            }
                        }
                    }
                    .padding(16)
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(item.evidence.at?.timestampLabel ?? "")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(hex: 0xFF8C00))
                Text(item.dimension.title.capitalized)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.gray)
            }
            
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(Color(hex: 0xFF8C00))
                    .frame(width: 2)
                
                VStack(alignment: .leading, spacing: 8) {
                    if let quote = item.evidence.quote {
                        Text(quote)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    if let detail = item.observation ?? item.evidence.measure {
                        Text(detail)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(Color.gray)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        )
    }

    /// Absences have no moment to point at, so they are listed rather than located. The dashed
    /// edge is the distinction, and it must not be softened into looking like the cards above.
    private func absenceCard(_ item: FeedbackViewModel.Detail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.dimension.title.capitalized)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.gray)
            
            Text(item.observation ?? item.evidence.quote ?? "")
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(Color.gray)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                .foregroundColor(Color.gray.opacity(0.5))
        )
    }

    private func feedbackAccordion<Content: View>(
        title: String,
        trailing: String,
        isOpen: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isOpen.wrappedValue.toggle()
                }
            } label: {
                HStack {
                    Text(title)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(trailing)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.gray)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundStyle(.gray)
                        .rotationEffect(.degrees(isOpen.wrappedValue ? 90 : 0))
                }
                .padding(20)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpen.wrappedValue {
                content()
            }
        }
        .background(Color(hex: 0x0A1024))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white, lineWidth: 1)
        )
    }
}

struct FeedbackAccordionView<Content: View>: View {
    let title: String
    let trailing: String
    var openness: Binding<Bool>?
    @ViewBuilder var content: () -> Content

    @State private var isOpenLocally = false

    private var isOpenBinding: Binding<Bool> { openness ?? $isOpenLocally }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isOpenBinding.wrappedValue.toggle()
                }
            } label: {
                HStack {
                    Text(title)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(trailing)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.gray)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundStyle(.gray)
                        .rotationEffect(.degrees(isOpenBinding.wrappedValue ? 90 : 0))
                }
                .padding(20)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpenBinding.wrappedValue {
                content()
            }
        }
        .background(Color(hex: 0x0A1024))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white, lineWidth: 1)
        )
    }
}
