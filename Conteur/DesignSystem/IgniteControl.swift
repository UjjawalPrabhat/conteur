import CoreHaptics
import SwiftUI

/// Press and hold to start the telling.
///
/// A button would end the reading with a tap, which is the same gesture as scrolling past it.
/// Holding costs something, and it is the last thing between reading a story and being asked
/// to tell it back — the one moment in the app that should feel deliberate.
///
/// The fill and the haptic both rise from the bottom, so the fire reads as catching rather
/// than as a progress bar filling up.
struct IgniteControl: View {
    let onIgnite: () -> Void

    /// Long enough to be a decision, short enough not to be a chore.
    private static let duration: TimeInterval = 1.1

    @State private var isHolding = false
    @State private var filled: CGFloat = 0
    @State private var haptics = IgniteHaptics()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.button)
                .fill(Color(hex: 0x140C08).opacity(0.5))

            // Rising from the bottom edge, not left to right.
            GeometryReader { proxy in
                Color.ember.opacity(0.9)
                    .frame(height: proxy.size.height * filled)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .clipShape(.rect(cornerRadius: Radius.button))

            Text(isHolding ? "Keep holding…" : "Hold to light the fire")
                .textStyle(.actionQuiet)
                .foregroundStyle(filled > 0.55 ? Color.onEmber : Color(hex: 0xF7EADA))
                .animation(.easeInOut(duration: 0.2), value: filled > 0.55)
        }
        .frame(height: 54)
        .overlay {
            RoundedRectangle(cornerRadius: Radius.button)
                .strokeBorder(Color(hex: 0xFFD6AA).opacity(0.28), lineWidth: 1)
        }
        .contentShape(.rect)
        .gesture(hold)
        // A hold is not operable under VoiceOver or Switch Control, and every session has to
        // pass through this control. The action is invisible to everyone else and is the only
        // thing keeping the app usable for those who cannot hold a gesture.
        .accessibilityElement()
        .accessibilityLabel("Light the fire and begin telling")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { complete() }
        .onDisappear { haptics.stop() }
    }

    private var hold: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !isHolding else { return }
                begin()
            }
            .onEnded { _ in
                // Released before the top: the fire goes out rather than half-starting.
                guard filled < 1 else { return }
                abandon()
            }
    }

    private func begin() {
        isHolding = true
        haptics.rise(over: Self.duration)
        withAnimation(.linear(duration: Self.duration)) { filled = 1 }
        // The gesture cannot tell us the hold completed, only that it has not ended, so the
        // finish is timed alongside the animation it belongs to.
        Task {
            try? await Task.sleep(for: .seconds(Self.duration))
            guard isHolding else { return }
            complete()
        }
    }

    private func abandon() {
        isHolding = false
        haptics.stop()
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.28)) { filled = 0 }
    }

    private func complete() {
        isHolding = false
        haptics.catchFire()
        onIgnite()
    }
}

/// The hold's haptic: a continuous rumble climbing in intensity, then the catch.
///
/// `UIImpactFeedbackGenerator` can only fire discrete taps, so a rising sensation has to be a
/// continuous CoreHaptics event with an intensity curve. A ramp is the whole point — the
/// feeling should arrive from underneath and build, the way the fill does.
@MainActor
@Observable
final class IgniteHaptics {
    private var engine: CHHapticEngine?
    private var player: CHHapticPatternPlayer?

    /// Silently inert where haptics are unavailable. A missing engine is not worth reporting:
    /// the control still works, it just does not buzz.
    private func prepared() -> CHHapticEngine? {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return nil }
        if let engine { return engine }
        engine = try? CHHapticEngine()
        try? engine?.start()
        return engine
    }

    func rise(over duration: TimeInterval) {
        guard let engine = prepared() else { return }
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.25),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3),
            ],
            relativeTime: 0,
            duration: duration
        )
        let climb = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0, value: 0.2),
                .init(relativeTime: duration * 0.6, value: 0.7),
                .init(relativeTime: duration, value: 1),
            ],
            relativeTime: 0
        )

        player = try? engine.makePlayer(with: CHHapticPattern(events: [event], parameterCurves: [climb]))
        try? player?.start(atTime: CHHapticTimeImmediate)
    }

    /// The moment it takes. Sharper and harder than anything in the ramp, so the hand knows
    /// the hold is over without looking.
    func catchFire() {
        stop()
        guard let engine = prepared() else { return }
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8),
            ],
            relativeTime: 0
        )
        try? engine.makePlayer(with: CHHapticPattern(events: [event], parameterCurves: []))
            .start(atTime: CHHapticTimeImmediate)
    }

    func stop() {
        try? player?.stop(atTime: CHHapticTimeImmediate)
        player = nil
    }
}
