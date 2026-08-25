import SwiftUI

struct StoryPickerView: View {
    let onChosen: (GuidedStory) -> Void

    private struct WheelItem: Identifiable {
        let id: String
        let story: GuidedStory
    }

    private let displayStories: [WheelItem]

    init(onChosen: @escaping (GuidedStory) -> Void) {
        self.onChosen = onChosen

        var stories = Genre.allCases.flatMap { StoryLibrary.stories(in: $0) }
        while stories.count < 5 && !stories.isEmpty {
            stories.append(contentsOf: stories)
        }
        self.displayStories = stories.enumerated().map { offset, story in
            WheelItem(id: "\(offset)-\(story.id)", story: story)
        }
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
                Text("Pick a Story")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
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
                        .font(.system(size: 14, design: .monospaced))
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

    private var wheel: some View {
        let spacingMultiplier: CGFloat = 1.15
        
        let verticalDrop: CGFloat = 10.7
        let fanTilt: Double = 22.0
        let sideShrink: CGFloat = 0.08      

        return ZStack {
            ForEach(Array(displayStories.enumerated()), id: \.element.id) { index, item in
                let posX = wrappedOffset(forIndex: index, offset: wheelOffset)
                let progress = posX / itemWidth
                let isCenter = abs(progress) < 0.5
                let isInserting = (dragPhase == .inserting || dragPhase == .committed)

                storyCard(story: item.story, isCenter: isCenter)
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
                    .zIndex(isCenter ? 10 : 5 - abs(progress))
            }
        }
        .frame(height: cardHeight)
    }
    
    private func wrappedOffset(forIndex index: Int, offset: CGFloat) -> CGFloat {
        let totalWidth = CGFloat(displayStories.count) * itemWidth
        guard totalWidth > 0 else { return 0 }
        let halfWidth = totalWidth / 2
        var pos = (CGFloat(index) * itemWidth + offset).truncatingRemainder(dividingBy: totalWidth)
        if pos > halfWidth { pos -= totalWidth }
        if pos < -halfWidth { pos += totalWidth }
        return pos
    }

    private func centeredStory(for offset: CGFloat) -> GuidedStory? {
        displayStories.indices
            .min { abs(wrappedOffset(forIndex: $0, offset: offset)) < abs(wrappedOffset(forIndex: $1, offset: offset)) }
            .map { displayStories[$0].story }
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
            .onEnded { _ in
                switch dragPhase {
                case .inserting:
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        insertOffset = 0
                    }
                    dragPhase = .idle
                case .scrolling:
                    let targetOffset = -round(-wheelOffset / itemWidth) * itemWidth
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
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

    private func storyCard(story: GuidedStory, isCenter: Bool) -> some View {
        let isBeingInserted = (dragPhase == .inserting || dragPhase == .committed)
        let showHighlight = isCenter && !isBeingInserted

        return VStack {
            Text(story.title)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(isCenter ? .black : .white)
                .multilineTextAlignment(.center)
                .padding(.top, 22)
                .padding(.horizontal, 14)

            Spacer()

            Text(synopsis(for: story))
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(isCenter ? .black : Color.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)

            Spacer()

            Text("\(story.wordCount) words")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(isCenter ? .black : Color.white.opacity(0.75))
                .padding(.bottom, 20)
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(isCenter ? Color.white : Color(hex: 0x0C1236))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    showHighlight ? Color(hex: 0xFF7A00) : Color.white.opacity(0.12),
                    lineWidth: showHighlight ? 3.5 : 1
                )
        )
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(showHighlight ? Color(hex: 0xD8E8FF).opacity(0.35) : Color.clear)
                .blur(radius: 28)
                .scaleEffect(1.08)
        )
        .animation(.easeInOut(duration: 0.15), value: showHighlight)
    }

    private func synopsis(for story: GuidedStory) -> String {
        "It's a \(story.genre.label.lowercased()) story about \(story.cast.count) characters."
    }
}
