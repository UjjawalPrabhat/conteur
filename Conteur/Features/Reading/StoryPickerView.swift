import SwiftUI

struct StoryPickerView: View {
    let onChosen: (GuidedStory) -> Void

    @State private var rawStories: [GuidedStory] = Genre.allCases.flatMap { StoryLibrary.stories(in: $0) }
    
    private var displayStories: [(String, GuidedStory)] {
        var stories = rawStories
        while stories.count < 5 && !stories.isEmpty {
            stories.append(contentsOf: stories)
        }
        return stories.enumerated().map { ("\($0.offset)-\($0.element.id)", $0.element) }
    }
    
    @State private var wheelOffset: CGFloat = 0
    @State private var lastWheelOffset: CGFloat = 0
    
    @State private var insertOffset: CGFloat = 0
    @State private var isInserting = false
    @State private var isScrolling = false
    @State private var transitionProgress: CGFloat = 0

    let cardWidth: CGFloat = 220
    let cardHeight: CGFloat = 320
    let spacing: CGFloat = 40
    private var itemWidth: CGFloat { cardWidth + spacing }

    var body: some View {
        ZStack {
            Color(hex: 0x050C1A).ignoresSafeArea()
            StarsView()
            
            VStack(spacing: 0) {
                Text("Pick a Story")
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.top, 80)
                
                Spacer(minLength: 40)
                
                // Wheel
                ZStack {
                    ForEach(Array(displayStories.enumerated()), id: \.element.0) { index, item in
                        let story = item.1
                        let totalWidth = CGFloat(displayStories.count) * itemWidth
                        let halfWidth = totalWidth / 2
                        
                        let rawPos = CGFloat(index) * itemWidth + wheelOffset
                        
                        let wrappedPos: CGFloat = {
                            var pos = rawPos.truncatingRemainder(dividingBy: totalWidth)
                            if pos > halfWidth { pos -= totalWidth }
                            if pos < -halfWidth { pos += totalWidth }
                            return pos
                        }()
                        
                        let progress = wrappedPos / itemWidth
                        let isCenter = abs(progress) < 0.5
                        
                        storyCard(story: story, progress: progress, isCenter: isCenter)
                            .offset(x: wrappedPos, y: (isCenter && isInserting) ? insertOffset : 0)
                            .rotation3DEffect(
                                .degrees(Double(-progress * 25)),
                                axis: (x: 0, y: 1, z: 0)
                            )
                            .scaleEffect(1 - min(1, abs(progress)) * 0.15)
                            .zIndex(1 - abs(progress))
                    }
                }
                .frame(height: cardHeight)
                
                Spacer(minLength: 40)
                
                VStack(spacing: 0) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(Color(hex: 0xF7EADA).opacity(0.6))
                        .opacity(isInserting ? 0 : 1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(Color(hex: 0xF7EADA).opacity(0.6))
                        .padding(.bottom, 20)
                        .opacity(isInserting ? 0 : 1)
                }
                
                // Slot
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: 0xFF8C00).opacity(0.6))
                        .blur(radius: 20)
                        .frame(width: cardWidth, height: 60)
                    
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: 0xFF8C00), lineWidth: 3)
                        .frame(width: cardWidth, height: 60)
                        
                    LinearGradient(
                        stops: [
                            .init(color: Color(hex: 0xFF8C00).opacity(0.8), location: 0),
                            .init(color: Color(hex: 0xFF8C00).opacity(1.0), location: 0.5),
                            .init(color: Color(hex: 0x050C1A), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: cardWidth, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .offset(y: 100)
                }
                
                Spacer(minLength: 40)
                
                Text("Drag down to pick the story")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.bottom, 40)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isInserting && !isScrolling {
                            if abs(value.translation.height) > abs(value.translation.width) && value.translation.height > 0 {
                                isInserting = true
                            } else {
                                isScrolling = true
                            }
                        }
                        
                        if isInserting {
                            insertOffset = max(0, value.translation.height)
                        } else if isScrolling {
                            wheelOffset = lastWheelOffset + value.translation.width
                        }
                    }
                    .onEnded { value in
                        if isInserting {
                            if insertOffset > 100 {
                                withAnimation(.easeIn(duration: 0.4)) {
                                    insertOffset = 250
                                    transitionProgress = 1.0
                                }
                                
                                let stories = displayStories
                                let totalWidth = CGFloat(stories.count) * itemWidth
                                let halfWidth = totalWidth / 2
                                var chosenStory = stories.first!.1
                                
                                for (index, item) in stories.enumerated() {
                                    let rawPos = CGFloat(index) * itemWidth + wheelOffset
                                    var wrappedPos = rawPos.truncatingRemainder(dividingBy: totalWidth)
                                    if wrappedPos > halfWidth { wrappedPos -= totalWidth }
                                    if wrappedPos < -halfWidth { wrappedPos += totalWidth }
                                    if abs(wrappedPos) < (itemWidth / 2) {
                                        chosenStory = item.1
                                        break
                                    }
                                }
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                                    onChosen(chosenStory)
                                }
                            } else {
                                withAnimation(.spring) {
                                    insertOffset = 0
                                }
                                isInserting = false
                            }
                        } else if isScrolling {
                            let rawIndex = round(-wheelOffset / itemWidth)
                            let targetOffset = -rawIndex * itemWidth
                            
                            withAnimation(.spring) {
                                wheelOffset = targetOffset
                                lastWheelOffset = targetOffset
                            }
                            isScrolling = false
                        }
                    }
            )
            
            if transitionProgress > 0 {
                RoundedRectangle(cornerRadius: 32 - transitionProgress * 32)
                    .fill(Color(hex: 0x050C1A))
                    .frame(
                        width: cardWidth + transitionProgress * 800,
                        height: cardHeight + transitionProgress * 1500
                    )
                    .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height - 150)
            }
        }
    }

    private func storyCard(story: GuidedStory, progress: CGFloat, isCenter: Bool) -> some View {
        VStack {
            Text(story.title)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(isCenter ? .black : .white)
                .multilineTextAlignment(.center)
                .padding(.top, 24)
                .padding(.horizontal, 16)
            
            Spacer()
            
            Text(synopsis(for: story))
                .font(.system(size: 16, design: .monospaced))
                .foregroundStyle(isCenter ? .black : .white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            
            Spacer()
            
            Text("\(story.wordCount) words")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(isCenter ? .black : .white)
                .padding(.bottom, 24)
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(isCenter ? Color.white : Color(hex: 0x0A0B1E))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isCenter ? Color(hex: 0xFF8C00) : Color.white.opacity(0.2), lineWidth: isCenter ? 4 : 1)
        )
        .shadow(color: isCenter ? Color(hex: 0xFF8C00).opacity(0.3) : .clear, radius: 20)
    }
    
    private func synopsis(for story: GuidedStory) -> String {
        return "It's a \(story.genre.label.lowercased()) story about \(story.cast.count) characters."
    }
}
