import SwiftUI

/// The spacing scale. Every gap in the app is one of these numbers.
enum Space {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 6
    static let s: CGFloat = 8
    static let sm: CGFloat = 10
    static let m: CGFloat = 12
    static let md: CGFloat = 14
    static let l: CGFloat = 16
    static let lg: CGFloat = 18
    static let xl: CGFloat = 22
    /// The screen margin. Everything that is not full-bleed sits inside this.
    static let screen: CGFloat = 26
    static let xxl: CGFloat = 34
    static let section: CGFloat = 44
}

/// Corner radii, by the size of the thing being rounded rather than by number.
enum Radius {
    static let pill: CGFloat = 6
    static let rating: CGFloat = 7
    static let callout: CGFloat = 14
    static let button: CGFloat = 16
    static let finding: CGFloat = 16
    static let card: CGFloat = 18
}

extension View {
    /// A card: the standard grouped surface. Rows inside it divide themselves.
    func cardSurface(
        _ fill: Color = Surface.card,
        border: Color = Surface.hairline,
        radius: CGFloat = Radius.card
    ) -> some View {
        background(fill, in: .rect(cornerRadius: radius))
            .overlay {
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(border, lineWidth: 1)
            }
            .clipShape(.rect(cornerRadius: radius))
    }

    /// An absence: same geometry, dashed edge. The dash is the whole point — it says this
    /// claim has no moment attached to it, where a solid card always does.
    func absenceSurface(radius: CGFloat = Radius.finding) -> some View {
        background(Surface.absence, in: .rect(cornerRadius: radius))
            .overlay {
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(
                        Surface.dashed,
                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                    )
            }
    }

    func screenPadding() -> some View {
        padding(.horizontal, Space.screen)
    }
}

/// The standard background: night, everywhere the fire is not.
struct NightBackground: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .nightTop, location: 0),
                .init(color: .nightHigh, location: 0.38),
                .init(color: .nightMid, location: 0.68),
                .init(color: .nightDeep, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
