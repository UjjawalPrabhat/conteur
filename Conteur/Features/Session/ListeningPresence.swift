import SwiftUI

/// A presence that listens. It breathes with the voice and settles at pauses, and it
/// never makes a sound while somebody is speaking — that silence is the whole point.
///
/// Deliberately abstract: a face that is almost right makes people self-conscious,
/// which is the opposite of what a storyteller needs.
struct ListeningPresence: View {
    var level: Float
    var isAttending: Bool
    var isAwake: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            Canvas { context, size in
                let centre = CGPoint(x: size.width / 2, y: size.height / 2)
                draw(in: context, centre: centre, radius: radius(for: size))
            }
            .opacity(isAwake ? 1 : 0.35)
            .animation(.easeInOut(duration: 0.6), value: isAwake)
            .drawingGroup()
            .id(context.date.timeIntervalSinceReferenceDate.rounded(.down))
        }
    }

    private func radius(for size: CGSize) -> CGFloat {
        let base = min(size.width, size.height) * 0.22
        // Attending draws slightly inward: the visual equivalent of leaning in.
        let attention: CGFloat = isAttending ? -0.06 : 0
        return base * (1 + CGFloat(level) * 0.35 + attention)
    }

    private func draw(in context: GraphicsContext, centre: CGPoint, radius: CGFloat) {
        for ring in stride(from: 3, through: 1, by: -1) {
            let scale = 1 + CGFloat(ring) * 0.28
            let circle = Path(
                ellipseIn: CGRect(
                    x: centre.x - radius * scale,
                    y: centre.y - radius * scale,
                    width: radius * scale * 2,
                    height: radius * scale * 2
                )
            )
            context.fill(circle, with: .color(.accentColor.opacity(0.06 * Double(ring))))
        }

        let core = Path(
            ellipseIn: CGRect(
                x: centre.x - radius,
                y: centre.y - radius,
                width: radius * 2,
                height: radius * 2
            )
        )
        context.fill(core, with: .color(.accentColor.opacity(isAttending ? 0.9 : 0.7)))
    }
}
