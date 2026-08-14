import SwiftUI

/// The camera, shown back with how the face is currently reading.
///
/// Kept small and to one side on purpose: a full-screen mirror makes people
/// self-conscious, which is the opposite of what somebody telling a story needs.
struct SelfView: View {
    var image: CGImage?
    var reading: ExpressionReading

    var body: some View {
        VStack(spacing: 8) {
            preview
            Text(reading.impression.label)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.25), value: reading.impression)
        }
    }

    @ViewBuilder
    private var preview: some View {
        ZStack {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle().fill(.quaternary)
            }
        }
        .frame(width: 96, height: 128)
        .clipShape(.rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.tint.opacity(Double(reading.animation)), lineWidth: 2)
        }
        .animation(.easeOut(duration: 0.2), value: reading.animation)
    }
}
