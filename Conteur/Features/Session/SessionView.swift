import SwiftUI
import SpriteKit

/// The telling. A fire, the words as they arrive, and one way to stop.
struct SessionView: View {
    let story: GuidedStory
    let challenge: String?
    /// Which attempt this is, so a telling too short to judge can still say where it sat.
    let attempt: Int
    /// Read when the telling starts rather than passed in. Both figures are database reads,
    /// and taking them as values meant fetching twice on every body evaluation of the screen
    /// above this one.
    let priming: () -> Priming
    let previous: Diagnosis?
    @Binding var isTelling: Bool
    let onAbandon: () -> Void
    let onFinish: (Assessment) -> Void

    @State private var model: SessionViewModel


    @State private var sessionScene: SessionScene = {
        let scene = SessionScene(size: CGSize(width: 604, height: 1136))
        scene.scaleMode = .aspectFill
        return scene
    }()
    init(
        story: GuidedStory,
        challenge: String?,
        attempt: Int,
        priming: @escaping () -> Priming,
        previous: Diagnosis?,
        isTelling: Binding<Bool>,
        onAbandon: @escaping () -> Void,
        onFinish: @escaping (Assessment) -> Void
    ) {
        self.story = story
        self.challenge = challenge
        self.attempt = attempt
        self.priming = priming
        self.previous = previous
        _isTelling = isTelling
        self.onAbandon = onAbandon
        self.onFinish = onFinish
        _model = State(initialValue: SessionViewModel(story: story))
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 37/255, green: 73/255, blue: 136/255),
                    Color(red: 35/255, green: 38/255, blue: 65/255)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            StarsView()
                .ignoresSafeArea()

            SpriteView(scene: sessionScene, options: [.allowsTransparency])
                .ignoresSafeArea()

            if isUnusable {
                notEnough
            } else {
                fireside
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .animation(.easeInOut(duration: 0.4), value: model.phase)
        .task {
            isTelling = true
            let priming = priming()
            model.prime(
                baseline: priming.baseline,
                history: priming.history,
                previous: previous,
                challenge: challenge
            )
            // Removed model.begin() to start in .ready state
        }
        .onChange(of: model.phase) { _, phase in
            isTelling = true
            sessionScene.setLit(shouldBeLit)
            if phase == .responding, let assessment = model.assessment {
                onFinish(assessment)
            }
        }
    }
    
    private var fireside: some View {
        VStack(spacing: 0) {
            Spacer()
            
            if model.phase == .ready || model.phase == .preparing {
                Text("Start\nstorytelling")
                    // We'll use VT323 or Courier to look pixelated. Actually, the mockup uses a pixel font.
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.bottom, 80)
            } else if model.phase == .listening || model.phase == .reading {
                VStack(spacing: 8) {
                    Text(clock)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("\(model.spokenWords) words")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }
                .padding(.bottom, 80)
            }
            
            Spacer()
            Spacer()
            Spacer()
            
            action
                .padding(.bottom, 60)
        }
    }

    private var clock: String {
        (model.isRunningOut ? model.remaining : model.elapsed).timestampLabel
    }

    @ViewBuilder
    private var action: some View {
        switch model.phase {
        case .ready, .failed, .tooShort, .preparing:
            HoldStartButton(onComplete: {
                model.begin()
            })
        case .listening:
            Button(action: {
                Task { await model.end() }
            }) {
                ZStack {
                    Circle()
                        .stroke(Color(red: 0.98, green: 0.95, blue: 0.85), lineWidth: 4)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(red: 0.38, green: 0.22, blue: 0.16))
                        .frame(width: 28, height: 28)
                }
                .frame(width: 72, height: 72)
            }
        case .reading, .responding, .unmatched:
            Text("Processing...")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(red: 0.38, green: 0.22, blue: 0.16))
                .padding(.horizontal, 24)
                .frame(height: 72)
                .background(Color(red: 0.98, green: 0.95, blue: 0.85))
                .clipShape(Capsule())
        }
    }

    // MARK: - Nothing to judge


    private var shouldBeLit: Bool {
        switch model.phase {
        case .ready, .tooShort, .unmatched, .preparing, .failed: return false
        default: return true
        }
    }

    private var isUnusable: Bool {
        switch model.phase {
        case .tooShort, .unmatched, .failed: true
        case .ready, .preparing, .listening, .reading, .responding: false
        }
    }

    /// No scores, no ratings, no findings. A short telling is not a weak one, and the screen
    /// has to say so without reading as a scolding.
    private var notEnough: some View {
        VStack(spacing: Space.xl) {
            Spacer()

            VStack(spacing: Space.m) {
                Text(tally)
                    .textStyle(.meta)
                    .foregroundStyle(Ink.tertiary)
                Text(invitation)
                    .textStyle(.statement)
                    .foregroundStyle(Ink.primary)
                    .multilineTextAlignment(.center)
                Text(explanation)
                    .textStyle(.body)
                    .foregroundStyle(Ink.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Space.xxl)

            // The challenge is not spent by a telling too short to judge, so it is still the
            // thing to do — saying so is what stops this screen reading as a dead end.
            if let challenge {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Still standing").eyebrowStyle(.eyebrowSmall)
                    Text(challenge)
                        .textStyle(.body)
                        .foregroundStyle(Ink.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Space.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardSurface(Surface.absence)
                .screenPadding()
            }

            Spacer()
            VStack(spacing: Space.m) {
                Button("Tell it again") { model.begin() }
                    .buttonStyle(EmberButtonStyle())
                Button("Back to stories") {
                    Task {
                        await model.cancel()
                        onAbandon()
                    }
                }
                .buttonStyle(OutlineButtonStyle())
            }
            .screenPadding()
            .padding(.bottom, Space.xl)
        }
    }

    /// What the telling amounted to, stated before the sentence about it, so the number is
    /// context rather than an accusation.
    private var tally: String {
        "\(model.spokenWords) words · \(model.spokenDuration.timestampLabel) · attempt \(attempt)"
    }

    private var explanation: String {
        switch model.phase {
        case .tooShort:
            "Nothing is scored. A short telling isn't a weak one — there's just nothing to point at."
        case .unmatched:
            "Nothing is scored. What you said didn't line up with the story, so there is nothing to measure it against."
        default:
            "Nothing is scored."
        }
    }

    private var invitation: String {
        switch model.phase {
        case .ready, .preparing: "One moment."
        case .listening: "I'm listening. Take your time."
        case .reading: "Thinking about how you told it."
        case .responding: ""
        case .tooShort:
            "There wasn't enough in that one for me to say much about how you told it."
        case .unmatched:
            "I heard you, but I couldn't line any of it up with \"\(story.title)\"."
        case .failed(let message): message
        }
    }
}

private struct Star: Identifiable {
    let id: Int
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let baseOpacity: Double
    let twinkleDuration: Double
    let twinkleDelay: Double
}

private let seededStars: [Star] = {
    var stars: [Star] = []
    var seed: UInt64 = 0xDEAD_BEEF_1234_5678
    func nextDouble() -> Double {
        seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double(seed >> 33) / Double(UInt64(1) << 31)
    }
    for i in 0..<150 {
        stars.append(Star(
            id: i,
            x: nextDouble(),
            y: nextDouble() * 0.8,
            size: 1.5 + nextDouble() * 1.3,
            baseOpacity: 0.5 + nextDouble() * 0.5,
            twinkleDuration: 1.5 + nextDouble() * 2.5,
            twinkleDelay: nextDouble() * 3.0
        ))
    }
    return stars
}()

private struct TwinklingStar: View {
    let star: Star
    @State private var bright = false

    var body: some View {
        GeometryReader { geo in
            Circle()
                .fill(Color.white.opacity(bright ? star.baseOpacity : star.baseOpacity * 0.4))
                .frame(width: star.size, height: star.size)
                .position(
                    x: star.x * geo.size.width,
                    y: star.y * geo.size.height
                )
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + star.twinkleDelay) {
                withAnimation(
                    .easeInOut(duration: star.twinkleDuration)
                    .repeatForever(autoreverses: true)
                ) {
                    bright = true
                }
            }
        }
    }
}

struct StarsView: View {
    var body: some View {
        GeometryReader { _ in
            ZStack {
                ForEach(seededStars) { star in
                    TwinklingStar(star: star)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

class SessionScene: SKScene {
    
    private var fireNode: SKSpriteNode!
    private var cloudsLeft: [SKSpriteNode] = []
    private var cloudsRight: [SKSpriteNode] = []
    private var litGround: SKSpriteNode!
    private var darkGround: SKSpriteNode!
    private var litRocks: [SKSpriteNode] = []
    private var darkRocks: [SKSpriteNode] = []
    
    override func didMove(to view: SKView) {
        self.backgroundColor = .clear
        self.anchorPoint = CGPoint(x: 0.5, y: 0.0)
        
        let cloud1 = SKSpriteNode(imageNamed: "cloud_01")
        cloud1.position = CGPoint(x: -150, y: 535)
        cloud1.setScale(0.75)
        cloud1.zPosition = 1.1
        addChild(cloud1)
        let cloudBack1 = SKSpriteNode(imageNamed: "cloud_back_01")
        cloudBack1.position = CGPoint(x: -200, y: 630)
        cloudBack1.setScale(0.75)
        cloudBack1.zPosition = 1
        addChild(cloudBack1)
        
        cloudsLeft.append(cloud1)
        cloudsLeft.append(cloudBack1)
        
        let cloud2 = SKSpriteNode(imageNamed: "cloud_02")
        cloud2.position = CGPoint(x: 130, y: 535)
        cloud2.setScale(0.75)
        cloud2.zPosition = 1.1
        addChild(cloud2)
        
        let cloudBack2 = SKSpriteNode(imageNamed: "cloud_back_02")
        cloudBack2.position = CGPoint(x: 160, y: 635)
        cloudBack2.setScale(0.75)
        cloudBack2.zPosition = 1
        addChild(cloudBack2)
        
        cloudsRight.append(cloud2)
        cloudsRight.append(cloudBack2)
        
        let outerGround = SKSpriteNode(imageNamed: "outer_ground")
        outerGround.position = CGPoint(x: 0, y: 220)
        outerGround.zPosition = 2
        addChild(outerGround)
        
        
        darkGround = SKSpriteNode(imageNamed: "ground_dark")
        darkGround.position = CGPoint(x: 0, y: 282)
        darkGround.zPosition = 3.1
        addChild(darkGround)
        
        litGround = SKSpriteNode(imageNamed: "ground")
        litGround.position = CGPoint(x: 0, y: 282)
        litGround.zPosition = 3
        addChild(litGround)
        
        
        // Helper to add rock pairs
        func addRock(name: String, unlitName: String, pos: CGPoint, z: CGFloat) {
            let dark = SKSpriteNode(imageNamed: unlitName)
            dark.position = pos
            dark.setScale(0.75)
            dark.zPosition = z
            dark.alpha = 1.0
            addChild(dark)
            darkRocks.append(dark)
            
            let lit = SKSpriteNode(imageNamed: name)
            lit.position = pos
            lit.setScale(0.75)
            lit.zPosition = z + 0.1
            lit.alpha = 0.0
            addChild(lit)
            litRocks.append(lit)
        }
        
        
        addRock(name: "rock_01", unlitName: "dark_rock_01", pos: CGPoint(x: -140, y: 274), z: 4.0)
        addRock(name: "rock_02", unlitName: "dark_rock_02", pos: CGPoint(x: -60, y: 250), z: 7.0)
        addRock(name: "rock_03", unlitName: "dark_rock_03", pos: CGPoint(x: 70, y: 260), z: 6.0)
        addRock(name: "rock_04", unlitName: "dark_rock_04", pos: CGPoint(x: 180, y: 280), z: 7.0)
        
        // Fire
        var fireTextures: [SKTexture] = []
        for i in 1...12 {
            let name = String(format: "campfire_%02d", i)
            fireTextures.append(SKTexture(imageNamed: name))
        }
        fireNode = SKSpriteNode(texture: fireTextures[0])
        fireNode.position = CGPoint(x: 0, y: 550)
        fireNode.setScale(1.1)
        fireNode.zPosition = 5
        fireNode.run(SKAction.repeatForever(SKAction.animate(with: fireTextures, timePerFrame: 0.15)))
        fireNode.alpha = 0.0
        addChild(fireNode)
        
        // Grass
        let grass01 = SKSpriteNode(imageNamed: "grass_01")
        grass01.position = CGPoint(x: -170, y: 185)
        grass01.zPosition = 7
        addChild(grass01)
        
        let grass02 = SKSpriteNode(imageNamed: "grass_02")
        grass02.position = CGPoint(x: 200, y: 155)
        grass02.zPosition = 7
        addChild(grass02)
    }
    
    func setLit(_ isLit: Bool) {
        let duration = 0.8
        if isLit {
            fireNode.run(SKAction.fadeIn(withDuration: duration))
            for dark in darkRocks { dark.run(SKAction.fadeOut(withDuration: duration)) }
            for lit in litRocks { lit.run(SKAction.fadeIn(withDuration: duration)) }
            
            darkGround.run(SKAction.fadeOut(withDuration: duration))
            
            litGround.run(SKAction.fadeIn(withDuration: duration))
            
            for cloud in cloudsLeft {
                cloud.run(SKAction.moveTo(x: -1000, duration: duration * 2.3))
            }
            for cloud in cloudsRight {
                cloud.run(SKAction.moveTo(x: 1000, duration: duration * 2.3))
            }
            
        } else {
            fireNode.run(SKAction.fadeOut(withDuration: duration))
            for dark in darkRocks { dark.run(SKAction.fadeIn(withDuration: duration)) }
            for lit in litRocks { lit.run(SKAction.fadeOut(withDuration: duration)) }
            
            darkGround.run(SKAction.fadeIn(withDuration: duration))
            litGround.run(SKAction.fadeOut(withDuration: duration))
        }
    }
}


struct HoldStartButton: View {
    let onComplete: () -> Void
    @State private var isHolding = false
    @State private var progress: CGFloat = 0

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(Color(red: 0.98, green: 0.95, blue: 0.85), lineWidth: 4)
                
                Circle()
                    .fill(Color(red: 0.38, green: 0.22, blue: 0.16))
                    .padding(6)
                
                // Fill animation while holding
                Circle()
                    .fill(Color.orange.opacity(0.8))
                    .padding(6)
                    .scaleEffect(progress)
                    .opacity(progress)
            }
            .frame(width: 72, height: 72)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isHolding {
                            isHolding = true
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation(.easeInOut(duration: 0.8)) {
                                progress = 1.0
                            }
                            Task {
                                try? await Task.sleep(for: .milliseconds(800))
                                if isHolding {
                                    isHolding = false
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                    onComplete()
                                }
                            }
                        }
                    }
                    .onEnded { _ in
                        if isHolding {
                            isHolding = false
                            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                            withAnimation(.easeOut(duration: 0.2)) {
                                progress = 0
                            }
                        }
                    }
            )
            
            Text("Hold to light the fire")
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(Color(red: 0.98, green: 0.95, blue: 0.85).opacity(0.8))
        }
    }
}
