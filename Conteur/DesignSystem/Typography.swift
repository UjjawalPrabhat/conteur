import SwiftUI

/// The type scale, as roles rather than sizes.
///
/// Two families do all the work: the system serif — New York — carries the app's own voice
/// (titles, the narrative, the user's quoted words), and SF carries everything that is
/// interface. A screen that mixes them the other way round reads as a form rather than a
/// story, which is the whole distinction the design rests on.
struct TextRole {
    let font: Font
    let tracking: CGFloat
    let lineSpacing: CGFloat

    fileprivate init(
        _ family: Family,
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        trackingEm: CGFloat = 0,
        lineHeight: CGFloat = 0
    ) {
        font = family.font(size: size, weight: weight)
        tracking = size * trackingEm
        // `lineSpacing` is the gap added between lines, where the design specifies total
        // line height as a multiple of the size. A line already occupies roughly 1.2× its
        // size, so that is what comes off.
        lineSpacing = lineHeight > 0 ? max(0, size * (lineHeight - 1.2)) : 0
    }

    fileprivate enum Family {
        case serif, ui, mono

        func font(size: CGFloat, weight: Font.Weight) -> Font {
            switch self {
            case .serif: .system(size: size, weight: weight, design: .serif)
            case .ui: .system(size: size, weight: weight)
            case .mono: .system(size: size, weight: weight, design: .monospaced)
            }
        }
    }
}

extension TextRole {
    // The app's voice.
    static let largeTitle = TextRole(.serif, 38, trackingEm: -0.015, lineHeight: 1.05)
    static let screenTitle = TextRole(.serif, 34, trackingEm: -0.015, lineHeight: 1.1)
    static let storyTitle = TextRole(.serif, 32, trackingEm: -0.015, lineHeight: 1.12)
    static let detailTitle = TextRole(.serif, 30, trackingEm: -0.015, lineHeight: 1.12)
    static let statement = TextRole(.serif, 28, lineHeight: 1.22)
    static let sectionHeading = TextRole(.serif, 24, trackingEm: -0.01)
    static let prompt = TextRole(.serif, 23, trackingEm: -0.01, lineHeight: 1.25)
    static let verdict = TextRole(.serif, 21, lineHeight: 1.3)
    static let narrative = TextRole(.serif, 20, lineHeight: 1.58)
    static let storyBody = TextRole(.serif, 19, lineHeight: 1.62)
    static let summary = TextRole(.serif, 18, lineHeight: 1.55)
    static let quote = TextRole(.serif, 17, lineHeight: 1.5)
    static let excerpt = TextRole(.serif, 16, lineHeight: 1.5)

    // Interface.
    static let rowTitle = TextRole(.ui, 17, weight: .medium, trackingEm: -0.005)
    static let action = TextRole(.ui, 17, weight: .semibold)
    static let actionQuiet = TextRole(.ui, 17, weight: .medium)
    static let transcript = TextRole(.ui, 17, lineHeight: 1.55)
    static let body = TextRole(.ui, 16, lineHeight: 1.5)
    static let secondary = TextRole(.ui, 14, lineHeight: 1.45)
    static let meta = TextRole(.ui, 13, trackingEm: 0.02)
    static let categoryLabel = TextRole(.ui, 12, trackingEm: 0.06)
    static let eyebrow = TextRole(.ui, 12, weight: .semibold, trackingEm: 0.13)
    static let eyebrowSmall = TextRole(.ui, 11, weight: .semibold, trackingEm: 0.14)
    static let pillLabel = TextRole(.ui, 12, weight: .medium)
    static let tabLabel = TextRole(.ui, 10, weight: .semibold)

    // Anything the user should be able to compare down a column.
    static let timestamp = TextRole(.mono, 12, weight: .semibold, trackingEm: 0.02)
    static let stats = TextRole(.mono, 12, weight: .medium, trackingEm: 0.02)
    static let timer = TextRole(.mono, 15, weight: .medium, trackingEm: 0.02)
}

extension View {
    func textStyle(_ role: TextRole) -> some View {
        font(role.font)
            .tracking(role.tracking)
            .lineSpacing(role.lineSpacing)
    }

    /// An all-caps label. Uppercasing is done here rather than in the copy so the strings
    /// stay readable where they are written.
    func eyebrowStyle(_ role: TextRole = .eyebrow, color: Color = Color.ember.opacity(0.75)) -> some View {
        textStyle(role)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}
