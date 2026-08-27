import SwiftUI

struct ReadingView: View {
    let story: GuidedStory
    let onBack: () -> Void
    let onFinished: () -> Void

    @State private var hasScrolled = false
    @State private var isAtBottom = false
    @AppStorage("readingFontSize") private var fontSize = 18.0
    private let minFontSize = 14.0
    private let maxFontSize = 30.0

    var body: some View {
        ZStack(alignment: .bottom) {
            // Dimmer stars specifically for the reading experience
            StarsBackgroundView(starsOpacity: 0.2)

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
                                    .foregroundStyle(Color(red: 237/255, green: 127/255, blue: 51/255).opacity(fontSize > minFontSize ? 1 : 0.3))
                                    .frame(width: 32, height: 32)
                            }
                            .disabled(fontSize <= minFontSize)

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
                                    .foregroundStyle(Color(red: 237/255, green: 127/255, blue: 51/255).opacity(fontSize < maxFontSize ? 1 : 0.3))
                                    .frame(width: 32, height: 32)
                            }
                            .disabled(fontSize >= maxFontSize)
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

            // Pinned floating button at bottom - smoothly appears on bottom scroll, disappears on scroll up
            VStack {
                Spacer()
                Button(action: onFinished) {
                    Text("Start Storytelling")
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
                        colors: [.clear, Color(hex: 0x050C1A).opacity(0.92), Color(hex: 0x050C1A)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 140)
                    .offset(y: 20)
                )
            }
            .ignoresSafeArea(edges: .bottom)
            .opacity(isAtBottom ? 1 : 0)
            .offset(y: isAtBottom ? 0 : 25)
            .animation(.easeInOut(duration: 0.35), value: isAtBottom)
            .allowsHitTesting(isAtBottom)
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .onPreferenceChange(ScrollBottomKey.self) { minY in
            let screenHeight = UIScreen.main.bounds.height
            let reached = minY < screenHeight + 50
            if reached != isAtBottom {
                withAnimation(.easeInOut(duration: 0.35)) {
                    isAtBottom = reached
                }
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

private struct ScrollBottomKey: PreferenceKey {
    static let defaultValue: CGFloat = .infinity
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
