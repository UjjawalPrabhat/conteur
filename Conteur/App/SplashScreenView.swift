//
//  SplashScreenView.swift
//  Conteur
//
//  Created by Daffa Yuranizar Arrifi on 26/08/26.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var isVisible = false
    @State private var glowOpacity: Double = 0.0

    var body: some View {
        ZStack {
            StarsBackgroundView()

            VStack {
                Spacer()

                ZStack {
                    // Subtle ambient warm glow matching the ember theme
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.ember.opacity(0.18),
                                    Color.emberEdge.opacity(0.06),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 160
                            )
                        )
                        .frame(width: 320, height: 180)
                        .blur(radius: 20)
                        .opacity(glowOpacity)

                    Image("conteur-orange")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 243, height: 50)
                        .scaleEffect(isVisible ? 1.0 : 0.92)
                        .opacity(isVisible ? 1.0 : 0.0)
                }

                Spacer()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isVisible = true
                glowOpacity = 1.0
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
