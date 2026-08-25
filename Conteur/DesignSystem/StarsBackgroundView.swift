//
//  StarsBackgroundView.swift
//  Conteur
//
//  Created by Daffa Yuranizar Arrifi on 26/08/26.
//

import SwiftUI

struct StarsBackgroundView: View {
    var backgroundColor: Color = Color(hex: 0x050C1A)

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()

            StarsView()
                .ignoresSafeArea()
        }
        .allowsHitTesting(false)
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

