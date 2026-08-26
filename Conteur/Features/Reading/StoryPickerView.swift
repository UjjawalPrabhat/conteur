import SwiftUI

struct StoryPickerView: View {
    let onChosen: (GuidedStory) -> Void

    private let stories: [GuidedStory]

    init(onChosen: @escaping (GuidedStory) -> Void) {
        self.onChosen = onChosen

        var rawStories = Genre.allCases.flatMap { StoryLibrary.stories(in: $0) }
        if rawStories.isEmpty {
            rawStories = StoryLibrary.all
        }
        self.stories = rawStories
    }

    private enum DragPhase: Equatable {
        case idle, scrolling, inserting, committed
    }

    @State private var dragPhase: DragPhase = .idle
    @State private var wheelOffset: CGFloat = 0
    @State private var lastWheelOffset: CGFloat = 0
    @State private var insertOffset: CGFloat = 0
    @State private var transitionProgress: CGFloat = 0

    private let insertionTravelDistance: CGFloat = 250
    private let insertAnimationDuration: Double = 0.4

    private var maxInsertOffset: CGFloat { 110 + cardHeight * 0.20 }

    let cardWidth: CGFloat = 172
    let cardHeight: CGFloat = 232
    let spacing: CGFloat = 40
    private var itemWidth: CGFloat { cardWidth + spacing }

    var body: some View {
        ZStack {
            StarsBackgroundView()

            wheel
                .zIndex(1)

            VStack(spacing: 0) {
                Text("Pick a Story") // should be bitcount
                    .textStyle(.bitcountPickerTitle)
                    .foregroundStyle(.white)
                    .padding(.top, 190)

                Color.clear
                    .frame(height: cardHeight * 1.7)

                VStack(spacing: 10) {
                    chevrons
                    
                    Spacer()
                    
                    slot
                        .zIndex(2)

                    Text("Drag down to pick the story")
                        .textStyle(.secondary)
                        .foregroundStyle(Color.white.opacity(0.85))
                        .padding(.top, 10)
                        .padding(.bottom, 48)
                        .opacity((dragPhase == .inserting || dragPhase == .committed) ? 0 : 1)
                        .zIndex(3)
                }
            }
            .zIndex(2)

            if transitionProgress > 0 {
                transitionOverlay
                    .ignoresSafeArea()
            }
        }
        .contentShape(Rectangle())
        .gesture(dragGesture)
    }

    @ViewBuilder
    private var wheel: some View {
        let spacingMultiplier: CGFloat = 1.15
        let verticalDrop: CGFloat = 10.7
        let fanTilt: Double = 22.0
        let sideShrink: CGFloat = 0.08      
        let count = stories.count

        if count > 0 {
            let centerVirtualIndex = Int(round(-wheelOffset / itemWidth))
            let visibleRange = (centerVirtualIndex - 3)...(centerVirtualIndex + 3)

            ZStack {
                ForEach(visibleRange, id: \.self) { virtualIndex in
                    let storyIndex = (virtualIndex % count + count) % count
                    let story = stories[storyIndex]
                    let posX = CGFloat(virtualIndex) * itemWidth + wheelOffset
                    let progress = posX / itemWidth
                    let isCenter = abs(progress) < 0.5
                    let isInserting = (dragPhase == .inserting || dragPhase == .committed)

                    storyCard(story: story, progress: progress, isInserting: isInserting)
                        .offset(
                            x: (isCenter && isInserting) ? 0 : (posX * spacingMultiplier),
                            y: (isCenter && isInserting) ? insertOffset : abs(progress) * verticalDrop
                        )
                        .rotationEffect(
                            .degrees(-progress * fanTilt)
                        )
                        .scaleEffect(
                            1 - min(1, abs(progress)) * sideShrink
                        )
                        .zIndex(100.0 - Double(abs(posX)))
                }
            }
            .frame(height: cardHeight)
        }
    }

    private func centeredStory(for offset: CGFloat) -> GuidedStory? {
        guard !stories.isEmpty else { return nil }
        let centerVirtualIndex = Int(round(-offset / itemWidth))
        let storyIndex = (centerVirtualIndex % stories.count + stories.count) % stories.count
        return stories[storyIndex]
    }

    private var chevrons: some View {
        VStack(spacing: -6) {
            Image(systemName: "chevron.down")
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(Color(hex: 0xDCE8F5).opacity(0.8))
            Image(systemName: "chevron.down")
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(Color(hex: 0xDCE8F5).opacity(0.8))
        }
        .opacity((dragPhase == .inserting || dragPhase == .committed) ? 0 : 1)
        .animation(.easeInOut(duration: 0.2), value: dragPhase == .inserting || dragPhase == .committed)
    }

    private var slot: some View {
        ZStack(alignment: .top) {
            let slotWidth = cardWidth + 24
            let slotHeight: CGFloat = 52
            let radius: CGFloat = 18
            let strokeWidth: CGFloat = 4
            let glow = Color(hex: 0xFF7A00)
            let pocketBg = Color(hex: 0x050C1A)

            VStack(spacing: 0) {
                LinearGradient(
                    stops: [
                        .init(color: pocketBg.opacity(0), location: 0),
                        .init(color: pocketBg.opacity(0.25), location: 0.35),
                        .init(color: pocketBg.opacity(0.85), location: 0.8),
                        .init(color: pocketBg, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: slotWidth - strokeWidth, height: slotHeight)

                Rectangle()
                    .fill(pocketBg)
                    .frame(width: slotWidth + 40, height: 400)
            }
            .frame(width: slotWidth, height: slotHeight, alignment: .top)

            RoundedRectangle(cornerRadius: radius)
                .fill(
                    LinearGradient(
                        colors: [Color.clear, glow.opacity(0.12)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: slotWidth - strokeWidth, height: slotHeight - strokeWidth / 2)
                .offset(y: strokeWidth / 4)

            Path { path in
                let halfStroke = strokeWidth / 2
                path.move(to: CGPoint(x: halfStroke, y: 0))
                path.addLine(to: CGPoint(x: halfStroke, y: slotHeight - radius))
                path.addQuadCurve(
                    to: CGPoint(x: radius, y: slotHeight - halfStroke),
                    control: CGPoint(x: halfStroke, y: slotHeight - halfStroke)
                )
                path.addLine(to: CGPoint(x: slotWidth - radius, y: slotHeight - halfStroke))
                path.addQuadCurve(
                    to: CGPoint(x: slotWidth - halfStroke, y: slotHeight - radius),
                    control: CGPoint(x: slotWidth - halfStroke, y: slotHeight - halfStroke)
                )
                path.addLine(to: CGPoint(x: slotWidth - halfStroke, y: 0))
            }
            .stroke(
                LinearGradient(
                    stops: [
                        .init(color: glow.opacity(0), location: 0),
                        .init(color: glow.opacity(0.4), location: 0.35),
                        .init(color: glow, location: 0.95)
                    ],
                    startPoint: .top, endPoint: .bottom
                ),
                style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
            )
            .shadow(color: glow.opacity(0.9), radius: 8)
            .frame(width: slotWidth, height: slotHeight)
        }
        .frame(width: cardWidth + 24, height: 52)
    }

    private var transitionOverlay: some View {
        GeometryReader { geometry in
            let finalSize = hypot(geometry.size.width, geometry.size.height) * 2
            RoundedRectangle(cornerRadius: 32 * (1 - transitionProgress))
                .fill(Color(hex: 0x050C1A))
                .frame(
                    width: cardWidth + transitionProgress * (finalSize - cardWidth),
                    height: cardHeight + transitionProgress * (finalSize - cardHeight)
                )
                .position(x: geometry.size.width / 2, y: geometry.size.height - 150)
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                guard dragPhase != .committed else { return }

                if dragPhase == .idle {
                    let dx = value.translation.width
                    let dy = value.translation.height

                    guard hypot(dx, dy) >= 8 else { return }

                    if dy > 0 && dy >= abs(dx) * 0.75 {
                        dragPhase = .inserting
                    } else {
                        dragPhase = .scrolling
                    }
                }

                switch dragPhase {
                case .inserting:
                    let newOffset = min(maxInsertOffset, max(0, value.translation.height))
                    insertOffset = newOffset

                    if newOffset >= maxInsertOffset {
                        commitInsertion()
                    }
                case .scrolling:
                    wheelOffset = lastWheelOffset + value.translation.width
                case .idle, .committed:
                    break
                }
            }
            .onEnded { value in
                switch dragPhase {
                case .inserting:
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        insertOffset = 0
                    }
                    dragPhase = .idle
                case .scrolling:
                    let velocity = value.velocity.width
                    let flickThreshold: CGFloat = 250
                    var targetOffset: CGFloat
                    
                    if abs(velocity) > flickThreshold {
                        let direction: CGFloat = velocity > 0 ? 1 : -1
                        let currentSnapped = -round(-lastWheelOffset / itemWidth) * itemWidth
                        targetOffset = currentSnapped + (direction * itemWidth)
                    } else {
                        targetOffset = -round(-wheelOffset / itemWidth) * itemWidth
                    }

                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                        wheelOffset = targetOffset
                        lastWheelOffset = targetOffset
                    }
                    dragPhase = .idle
                case .idle, .committed:
                    break
                }
            }
    }

    private func commitInsertion() {
        guard dragPhase != .committed else { return }
        dragPhase = .committed

        guard let chosen = centeredStory(for: wheelOffset) else {
            withAnimation(.spring) { insertOffset = 0 }
            dragPhase = .idle
            return
        }

        withAnimation(.easeIn(duration: insertAnimationDuration)) {
            insertOffset = insertionTravelDistance
            transitionProgress = 1.0
        } completion: {
            onChosen(chosen)
        }
    }

    private func storyCard(story: GuidedStory, progress: CGFloat, isInserting: Bool) -> some View {
        let absProgress = abs(progress)
        let t = min(1.0, max(0.0, 1.0 - absProgress * 2.0))
        let highlight = t * t * (3.0 - 2.0 * t) // smoothstep interpolation

        return ZStack {
            // Dark card content (visible when off-center)
            cardContent(story: story, isHighlighted: false)
                .opacity(1.0 - highlight)

            // Light card content (visible when centered)
            cardContent(story: story, isHighlighted: true)
                .opacity(highlight)
        }
        .frame(width: cardWidth, height: cardHeight)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(hex: 0x0C1236))

                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.white)
                    .opacity(highlight)
            }
        }
        .overlay {
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .stroke(
                        Color.white.opacity(0.12 * (1.0 - highlight)),
                        lineWidth: 1
                    )
                RoundedRectangle(cornerRadius: 22)
                    .stroke(
                        Color(hex: 0xFF7A00).opacity(highlight),
                        lineWidth: 1.0 + highlight * 2.5
                    )
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(hex: 0xD8E8FF).opacity(0.35 * highlight))
                .blur(radius: 24)
                .scaleEffect(1.0 + 0.08 * highlight)
                .opacity(isInserting ? 0 : 1)
        }
    }

    private func cardContent(story: GuidedStory, isHighlighted: Bool) -> some View {
        VStack {
            Text(story.title) // should be bitcount
                .textStyle(.bitcountCardTitle)
                .foregroundStyle(isHighlighted ? Color.black : Color.white)
                .multilineTextAlignment(.center)
                .padding(.top, 22)
                .padding(.horizontal, 14)

            Spacer()

            Text(synopsis(for: story))
                .textStyle(.secondary)
                .foregroundStyle(isHighlighted ? Color.black.opacity(0.85) : Color.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)

            Spacer()

            Text("\(story.wordCount) words")
                .textStyle(.stats)
                .foregroundStyle(isHighlighted ? Color.black.opacity(0.75) : Color.white.opacity(0.75))
                .padding(.bottom, 20)
        }
    }

    private func synopsis(for story: GuidedStory) -> String {
        "It's a \(story.genre.label.lowercased()) story about \(story.cast.count) characters."
    }
}
