import SwiftUI

struct ReadingView: View {
    let story: GuidedStory
    let onBack: () -> Void
    let onFinished: () -> Void

    @State private var hasScrolled = false
    @State private var hasReachedBottom = false
    @AppStorage("readingFontSize") private var fontSize = 18.0
    private let minFontSize = 14.0
    private let maxFontSize = 30.0

    var body: some View {
        ZStack(alignment: .bottom) {
            StarsBackgroundView()

            VStack(spacing: 0) {
                // Top Bar
                VStack(spacing: 8) {
                    ZStack {
                        Text(" ")
                            .textStyle(.navTitle)
                        
                        if hasScrolled {
                            Text(story.title)
                                .textStyle(.navTitle)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .transition(.opacity)
                        }
                    }
                    
                    HStack {
                        Button(action: onBack) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .bold))
                                Text("Pick a story")
                                    .textStyle(.navAction)
                            }
                            .foregroundStyle(Color(red: 237/255, green: 127/255, blue: 51/255))
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 0) {
                            Button(action: {
                                withAnimation {
                                    fontSize = max(minFontSize, fontSize - 1)
                                }
                            }) {
                                Image(systemName: "minus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color(red: 237/255, green: 127/255, blue: 51/255))
                                    .frame(width: 32, height: 32)
                            }
                            
                            Text("\(Int(fontSize))")
                                .textStyle(.stats)
                                .foregroundStyle(Color(red: 237/255, green: 127/255, blue: 51/255))
                                .frame(width: 44)
                            
                            Button(action: {
                                withAnimation {
                                    fontSize = min(maxFontSize, fontSize + 1)
                                }
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color(red: 237/255, green: 127/255, blue: 51/255))
                                    .frame(width: 32, height: 32)
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color(red: 237/255, green: 127/255, blue: 51/255).opacity(0.1))
                                .overlay(
                                    Capsule()
                                        .stroke(Color(red: 237/255, green: 127/255, blue: 51/255).opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 16)
                // We add a subtle gradient to the top bar so stars show through but text doesn't clash
                // Actually, if we use VStack, the scrollview clips exactly at the bottom of this bar!
                // So we don't need a background on the top bar to hide the text, the layout clips it automatically.

                // ScrollView
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        header
                        prose
                        
                        GeometryReader { proxy in
                            Color.clear
                                .preference(key: ScrollBottomKey.self, value: proxy.frame(in: .global).minY)
                        }
                        .frame(height: 1)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 150)
                }
                .scrollIndicators(.hidden)
            }

            // Pinned button at bottom
            VStack {
                Spacer()
                Button(action: onFinished) {
                    Text("Start Storytelling") // should be bitcount
                        .textStyle(.bitcountAction)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(red: 237/255, green: 127/255, blue: 51/255))
                        .clipShape(RoundedRectangle(cornerRadius: 32))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .background(
                    LinearGradient(
                        colors: [.clear, Color(red: 35/255, green: 38/255, blue: 65/255).opacity(0.9)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)
                    .offset(y: 20)
                )
            }
            .ignoresSafeArea(edges: .bottom)
            .opacity(hasReachedBottom ? 1 : 0)
            .animation(.easeInOut(duration: 0.3), value: hasReachedBottom)
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .onPreferenceChange(ScrollBottomKey.self) { minY in
            let screenHeight = UIScreen.main.bounds.height
            if minY < screenHeight + 50 {
                hasReachedBottom = true
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(story.title)
                .textStyle(.screenTitle)
                .foregroundStyle(.white)
            
            let words = story.prose.components(separatedBy: .whitespacesAndNewlines).count
            let seconds = Int(story.readingTime.rounded())
            Text("\(words) words (\(seconds) seconds)")
                .textStyle(.secondary)
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(hasScrolled ? 0 : 1)
        .background(
            GeometryReader { proxy in
                Color.clear.onChange(of: proxy.frame(in: .global).minY) { _, minY in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        // 80 is roughly the height of the top safe area + top bar
                        hasScrolled = minY < 80
                    }
                }
            }
        )
    }

    private var prose: some View {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(.inconsolata(.regular, size: fontSize))
                    .lineSpacing(4)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var paragraphs: [String] {
        story.prose
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}


struct ScrollBottomKey: PreferenceKey {
    static let defaultValue: CGFloat = .infinity
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
