import SwiftUI

/// The fire the user tells their story to.
///
/// Deliberately not driven by the microphone. An ember that jumps per syllable reads as a
/// level meter, and the one rule the whole feel depends on is that the listener never
/// performs while somebody is speaking. It burns at its own pace and waits.
struct CampfireScene: View {
    /// The second telling moves the camera in: the fire fills the lower half and the horizon
    /// is gone, so the screen feels like a later hour of the same night.
    var isClose = false

    /// A fire that never stops moving is exactly what somebody who turns this on asked not to
    /// see. It still burns — the scene is the screen — but it holds still.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var layout: Layout { isClose ? .close : .wide }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let fire = CGPoint(x: size.width / 2, y: size.height * layout.fireBaseline)

            ZStack {
                layout.sky.ignoresSafeArea()
                StarField(ceiling: layout.starCeiling, isStill: reduceMotion)
                if layout.showsTreeline {
                    Treeline(top: size.height * 0.44, height: 130)
                }
                ground(in: size)
                lightPool(at: fire)
                FireGlow(
                    diameter: layout.glowDiameter,
                    strength: layout.glowStrength,
                    isStill: reduceMotion
                )
                    .position(fire)
                Logs(scale: layout.logScale).position(fire)
                Flames(scale: layout.flameScale, isStill: reduceMotion)
                    .position(x: fire.x, y: fire.y - layout.flameScale * 46)
                if !reduceMotion {
                    EmberDrift(rise: layout.emberRise)
                        .position(x: fire.x, y: fire.y - layout.flameScale * 60)
                }
                foregroundRim(in: size)
            }
            .ignoresSafeArea()
            // The whole scene is decoration. Announcing a treeline and five embers to
            // somebody using VoiceOver buries the one thing on this screen that matters.
            .accessibilityHidden(true)
        }
    }

    private func ground(in size: CGSize) -> some View {
        LinearGradient(
            colors: [.sceneGroundTop, .sceneGround, .sceneGroundDeep],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: size.height * (1 - layout.groundTop))
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    /// The pool of light the fire throws on the ground, which is what stops the fire looking
    /// like a sticker laid over a photograph.
    private func lightPool(at fire: CGPoint) -> some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [Color.ember.opacity(0.3), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 260
                )
            )
            .frame(width: 520, height: 200)
            .blur(radius: 14)
            .position(x: fire.x, y: fire.y + 30)
    }

    /// The user's own side of the fire circle: the near edge of the clearing, unlit.
    private func foregroundRim(in size: CGSize) -> some View {
        Ellipse()
            .fill(
                LinearGradient(
                    colors: [Color(hex: 0x0D0908), Color(hex: 0x050403)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: size.width * 1.7, height: 150)
            .overlay(alignment: .top) {
                Ellipse()
                    .stroke(Color.ember.opacity(0.1), lineWidth: 20)
                    .blur(radius: 14)
                    .frame(width: size.width * 1.7, height: 150)
            }
            .clipShape(Ellipse())
            .position(x: size.width / 2, y: size.height + 40)
    }
}

// MARK: - Layout

private extension CampfireScene {
    /// The two framings, as data. Every difference between the wide scene and the close one
    /// is a number here rather than a branch in the view.
    struct Layout {
        let sky: LinearGradient
        let starCeiling: CGFloat
        let showsTreeline: Bool
        let groundTop: CGFloat
        let fireBaseline: CGFloat
        let glowDiameter: CGFloat
        let glowStrength: Double
        let flameScale: CGFloat
        let logScale: CGFloat
        let emberRise: CGFloat

        static let wide = Layout(
            sky: LinearGradient(
                stops: [
                    .init(color: .sceneSkyTop, location: 0),
                    .init(color: .sceneSkyMid, location: 0.4),
                    .init(color: .sceneSkyLow, location: 0.66),
                    .init(color: Color(hex: 0x100C0A), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            ),
            starCeiling: 0.58,
            showsTreeline: true,
            groundTop: 0.55,
            fireBaseline: 0.78,
            glowDiameter: 420,
            glowStrength: 0.30,
            flameScale: 1,
            logScale: 1,
            emberRise: 220
        )

        static let close = Layout(
            sky: LinearGradient(
                stops: [
                    .init(color: Color(hex: 0x04070E), location: 0),
                    .init(color: Color(hex: 0x0A0C14), location: 0.34),
                    .init(color: Color(hex: 0x150E0A), location: 0.72),
                    .init(color: Color(hex: 0x1C1109), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            ),
            starCeiling: 0.38,
            showsTreeline: false,
            groundTop: 0.62,
            fireBaseline: 1.02,
            glowDiameter: 640,
            glowStrength: 0.34,
            flameScale: 2.15,
            logScale: 1.78,
            emberRise: 300
        )
    }
}

// MARK: - Sky

private struct StarField: View {
    let ceiling: CGFloat
    let isStill: Bool

    /// Fixed positions. Generated once from a constant seed, because a star field that
    /// reshuffles on every layout pass reads as noise rather than a sky.
    private static let stars: [Star] = {
        var seed: UInt64 = 0x5EED_1234
        func next() -> CGFloat {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat((seed >> 33) % 10_000) / 10_000
        }
        return (0..<44).map { _ in
            Star(x: next(), y: next(), size: 1.1 + next() * 0.5, dim: 0.4 + next() * 0.4)
        }
    }()

    struct Star {
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let dim: Double
    }

    @State private var bright = false

    var body: some View {
        GeometryReader { proxy in
            ForEach(Array(Self.stars.enumerated()), id: \.offset) { index, star in
                Circle()
                    .fill(Color.paper)
                    .frame(width: star.size, height: star.size)
                    .opacity(star.dim * (bright ? 1 : 0.5))
                    .position(
                        x: star.x * proxy.size.width,
                        y: star.y * proxy.size.height * ceiling
                    )
                    .animation(
                        isStill ? nil : .easeInOut(duration: 6 + Double(index % 4) * 0.5)
                            .repeatForever()
                            .delay(Double(index % 7) * 0.4),
                        value: bright
                    )
            }
        }
        .onAppear { bright = true }
    }
}

/// The far edge of the clearing. A silhouette, not trees — at this scale the shape of the
/// horizon is all that carries, and detail would only fight the fire for attention.
private struct Treeline: View {
    let top: CGFloat
    let height: CGFloat

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let width = proxy.size.width
                path.move(to: CGPoint(x: 0, y: top + height))
                path.addLine(to: CGPoint(x: 0, y: top + 24))
                var x: CGFloat = 0
                var index = 0
                while x < width {
                    let step = 18 + CGFloat(index % 3) * 11
                    let peak = top + CGFloat([0, 16, 6, 22, 10][index % 5])
                    path.addLine(to: CGPoint(x: x + step / 2, y: peak))
                    path.addLine(to: CGPoint(x: x + step, y: top + 20))
                    x += step
                    index += 1
                }
                path.addLine(to: CGPoint(x: width, y: top + height))
                path.closeSubpath()
            }
            .fill(Color.treeline)
            .opacity(0.95)
        }
    }
}

// MARK: - Fire

private struct FireGlow: View {
    let diameter: CGFloat
    let strength: Double
    let isStill: Bool

    @State private var lit = false

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    stops: [
                        .init(color: Color(hex: 0xFFB24D).opacity(strength), location: 0),
                        .init(color: Color.emberEdge.opacity(0.13), location: 0.46),
                        .init(color: .clear, location: 1),
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter / 2
                )
            )
            .frame(width: diameter, height: diameter)
            .blur(radius: 10)
            .opacity(lit ? 0.92 : 0.66)
            .scaleEffect(lit ? 1.05 : 0.97)
            .animation(isStill ? nil : .easeInOut(duration: 2.7).repeatForever(), value: lit)
            .onAppear { lit = true }
    }
}

private struct Logs: View {
    let scale: CGFloat

    var body: some View {
        ZStack {
            log(width: 112 * scale, height: 13 * scale).rotationEffect(.degrees(-13))
            log(width: 120 * scale, height: 13 * scale).rotationEffect(.degrees(11))
        }
    }

    private func log(width: CGFloat, height: CGFloat) -> some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [.logTop, .logBase],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: width, height: height)
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Color(hex: 0xFFBE78).opacity(0.35))
                    .frame(height: 1.5)
                    .padding(.horizontal, height)
            }
    }
}

/// Three flames, flickering at rates that share no common multiple. Synchronised flames
/// read as one animated object; desynchronised ones read as fire.
private struct Flames: View {
    let scale: CGFloat
    let isStill: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            Flame(
                size: CGSize(width: 86 * scale, height: 126 * scale),
                core: Color.flameCore,
                blur: 5 * scale,
                period: 1.7,
                isStill: isStill
            )
            Flame(
                size: CGSize(width: 44 * scale, height: 80 * scale),
                core: Color.flameHeart,
                blur: 2.5 * scale,
                period: 1.15,
                isStill: isStill,
                offBeat: true
            )
            Flame(
                size: CGSize(width: 18 * scale, height: 34 * scale),
                core: Color(hex: 0xFFFBF0),
                blur: 2 * scale,
                period: 0.9,
                isStill: isStill
            )
        }
        .frame(height: 126 * scale, alignment: .bottom)
    }
}

private struct Flame: View {
    let size: CGSize
    let core: Color
    let blur: CGFloat
    let period: Double
    let isStill: Bool
    /// Started half a period late, so this flame is falling while the one behind it rises.
    var offBeat = false

    @State private var high = false

    var body: some View {
        FlameShape()
            .fill(
                RadialGradient(
                    stops: [
                        .init(color: core, location: 0),
                        .init(color: Color.flameBody.opacity(0.8), location: 0.42),
                        .init(color: Color.emberEdge.opacity(0), location: 1),
                    ],
                    center: UnitPoint(x: 0.5, y: 0.74),
                    startRadius: 0,
                    endRadius: size.height * 0.72
                )
            )
            .frame(width: size.width, height: size.height)
            .blur(radius: blur)
            .scaleEffect(
                x: high ? 1.05 : 0.94,
                y: high ? 1.09 : 0.95,
                anchor: .bottom
            )
            .rotationEffect(.degrees(high ? 2.5 : -2.5), anchor: .bottom)
            .opacity(high ? 1 : 0.9)
            .animation(
                isStill ? nil : .easeInOut(duration: period)
                    .delay(offBeat ? period / 2 : 0)
                    .repeatForever(),
                value: high
            )
            .onAppear { high = true }
    }
}

/// An upward teardrop: a tall dome narrowing to a point, flatter at the base where it
/// meets the log.
private struct FlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control1: CGPoint(x: rect.minX - width * 0.06, y: rect.maxY - height * 0.32),
            control2: CGPoint(x: rect.minX + width * 0.2, y: rect.minY + height * 0.08)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.maxX - width * 0.2, y: rect.minY + height * 0.08),
            control2: CGPoint(x: rect.maxX + width * 0.06, y: rect.maxY - height * 0.32)
        )
        path.closeSubpath()
        return path
    }
}

private struct EmberDrift: View {
    let rise: CGFloat

    private static let embers: [(color: Color, size: CGFloat, drift: CGFloat, duration: Double, delay: Double)] = [
        (Color(hex: 0xFFC98A), 3.4, -22, 4.6, 0),
        (Color(hex: 0xFFB870), 2.5, 14, 5.8, 1.1),
        (Color(hex: 0xFFD9A8), 4.0, 26, 3.9, 2.0),
        (Color(hex: 0xFFC07A), 2.8, -9, 6.2, 2.7),
        (Color(hex: 0xFFCE92), 3.1, 19, 5.1, 3.4),
    ]

    var body: some View {
        ZStack {
            ForEach(Array(Self.embers.enumerated()), id: \.offset) { index, ember in
                Ember(
                    color: ember.color,
                    size: ember.size,
                    drift: ember.drift,
                    rise: rise,
                    duration: ember.duration,
                    delay: ember.delay
                )
            }
        }
    }
}

private struct Ember: View {
    let color: Color
    let size: CGFloat
    let drift: CGFloat
    let rise: CGFloat
    let duration: Double
    let delay: Double

    @State private var risen = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .scaleEffect(risen ? 0.35 : 1)
            .opacity(risen ? 0 : 0.9)
            .offset(x: risen ? drift : 0, y: risen ? -rise : 0)
            .animation(
                .linear(duration: duration).delay(delay).repeatForever(autoreverses: false),
                value: risen
            )
            .onAppear { risen = true }
    }
}
