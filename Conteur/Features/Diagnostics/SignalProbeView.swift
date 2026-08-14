import SwiftUI

/// Measures what the on-device frameworks actually deliver, so the signal layer is
/// built on verified behaviour rather than assumed behaviour.
struct SignalProbeView: View {
    @State private var model = SignalProbeViewModel(transcriber: SpeechTranscription())

    var body: some View {
        NavigationStack {
            List {
                filledPauses
                pace
                pauses
                voice
                face
                restarts
                transcript
                failure
            }
            .navigationTitle("Signal probe")
            .safeAreaInset(edge: .bottom) { controls }
        }
    }

    private var signals: DeliverySignals { model.timeline.delivery }

    private var filledPauses: some View {
        Section("Filled pauses") {
            LabeledContent("Detected", value: "\(signals.filledPauses.count)")
            LabeledContent("Rate", value: percent(signals.filledPauseRate))
            ForEach(signals.filledPauses, id: \.at) { filled in
                LabeledContent(filled.token, value: seconds(filled.at)).monospaced()
            }
        }
    }

    private var pace: some View {
        Section("Pace") {
            LabeledContent("Words", value: "\(signals.wordCount)")
            LabeledContent("Duration", value: seconds(signals.duration))
            LabeledContent("Words per minute", value: number(signals.wordsPerMinute, places: 0))
        }
    }

    private var pauses: some View {
        Section("Pauses") {
            ForEach(PauseKind.allCases, id: \.self) { kind in
                LabeledContent(kind.rawValue.capitalized, value: "\(signals.pauses(of: kind).count)")
            }
        }
    }

    private var voice: some View {
        Section("Voice") {
            LabeledContent("Prosody frames", value: "\(model.timeline.prosody.count)")
            LabeledContent("Voiced frames", value: "\(model.timeline.prosody.count(where: { $0.pitch != nil }))")
            LabeledContent("Pitch variation", value: percent(Double(model.timeline.pitchVariation)))
            LabeledContent("Dynamic range", value: number(Double(model.timeline.dynamicRange), places: 1) + "×")
        }
    }

    private var face: some View {
        Section("Face") {
            if model.faceTrackingAvailable {
                LabeledContent("Windows", value: "\(model.timeline.expressivity.count)")
                ForEach(model.timeline.expressivity, id: \.start) { window in
                    LabeledContent(
                        seconds(window.start),
                        value: number(Double(window.variation), places: 3)
                    )
                    .monospaced()
                }
            } else {
                Text("Face tracking unavailable on this device.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var restarts: some View {
        if !signals.restarts.isEmpty {
            Section("Restarts") {
                ForEach(signals.restarts, id: \.at) { restart in
                    LabeledContent(restart.phrase, value: seconds(restart.at))
                }
            }
        }
    }

    private var transcript: some View {
        Section("Transcript") {
            Text(model.timeline.transcript.text.isEmpty ? "—" : model.timeline.transcript.text)
                .font(.callout)
        }
    }

    @ViewBuilder
    private var failure: some View {
        if case .failed(let message) = model.state {
            Section {
                Text(message).foregroundStyle(.red)
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            Text(status)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(model.isListening ? "Stop" : "Start listening") {
                Task {
                    if model.isListening {
                        await model.stop()
                    } else {
                        model.start()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.state == .preparing)
        }
        .padding()
        .background(.bar)
    }

    private var status: String {
        switch model.state {
        case .idle: "Read a line aloud with deliberate \"um\"s and see whether they survive."
        case .preparing: "Preparing the speech model…"
        case .listening: "Listening."
        case .finished: "Done."
        case .failed: "Failed."
        }
    }

    private func seconds(_ value: TimeInterval) -> String {
        number(value, places: 2) + "s"
    }

    private func number(_ value: Double, places: Int) -> String {
        value.formatted(.number.precision(.fractionLength(places)))
    }

    private func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(1)))
    }
}
