import SwiftUI

/// The type scale, as roles rather than sizes.
///
/// Two families do all the work: the system serif — New York — carries the app's own voice
/// (titles, the narrative, the user's quoted words), and SF carries everything that is
/// interface. A screen that mixes them the other way round reads as a form rather than a
/// story, which is the whole distinction the design rests on.
///
/// Sizes are stored rather than baked into a `Font` so they can be scaled for the reader's
/// text size. The design specifies fixed points, which is right for a mockup and wrong for
/// a shipped app: at the largest accessibility sizes a fixed 13pt caption is unreadable, and
/// the whole point of the feedback is that somebody can read it.
struct TextRole {
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    /// Tracking as a fraction of the size, so it stays proportional once scaled.
    let trackingRatio: CGFloat
    /// Total line height as a multiple of the size, or zero to leave it alone.
    let lineHeightRatio: CGFloat
    /// The system style this scales alongside. Picking one per role is what keeps a caption
    /// growing like a caption and a title like a title.
    let scaling: Font.TextStyle

    fileprivate init(
        _ design: Font.Design,
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        tracking: CGFloat = 0,
        lineHeight: CGFloat = 0,
        scaling: Font.TextStyle
    ) {
        self.size = size
        self.weight = weight
        self.design = design
        trackingRatio = tracking
        lineHeightRatio = lineHeight
        self.scaling = scaling
    }
}

extension TextRole {
    // The app's voice.
    static let largeTitle = TextRole(.serif, 38, tracking: -0.015, lineHeight: 1.05, scaling: .largeTitle)
    static let screenTitle = TextRole(.serif, 34, tracking: -0.015, lineHeight: 1.1, scaling: .largeTitle)
    static let storyTitle = TextRole(.serif, 32, tracking: -0.015, lineHeight: 1.12, scaling: .title)
    static let detailTitle = TextRole(.serif, 30, tracking: -0.015, lineHeight: 1.12, scaling: .title)
    static let statement = TextRole(.serif, 28, lineHeight: 1.22, scaling: .title)
    static let sectionHeading = TextRole(.serif, 24, tracking: -0.01, scaling: .title2)
    static let prompt = TextRole(.serif, 23, tracking: -0.01, lineHeight: 1.25, scaling: .title2)
    static let verdict = TextRole(.serif, 21, lineHeight: 1.3, scaling: .title3)
    static let narrative = TextRole(.serif, 20, lineHeight: 1.58, scaling: .body)
    static let storyBody = TextRole(.serif, 19, lineHeight: 1.62, scaling: .body)
    static let summary = TextRole(.serif, 18, lineHeight: 1.55, scaling: .body)
    static let quote = TextRole(.serif, 17, lineHeight: 1.5, scaling: .body)
    static let excerpt = TextRole(.serif, 16, lineHeight: 1.5, scaling: .body)

    // Interface.
    static let rowTitle = TextRole(.default, 17, weight: .medium, tracking: -0.005, scaling: .body)
    static let action = TextRole(.default, 17, weight: .semibold, scaling: .body)
    static let actionQuiet = TextRole(.default, 17, weight: .medium, scaling: .body)
    static let transcript = TextRole(.default, 17, lineHeight: 1.55, scaling: .body)
    static let body = TextRole(.default, 16, lineHeight: 1.5, scaling: .body)
    static let secondary = TextRole(.default, 14, lineHeight: 1.45, scaling: .subheadline)
    static let meta = TextRole(.default, 13, tracking: 0.02, scaling: .footnote)
    static let categoryLabel = TextRole(.default, 12, tracking: 0.06, scaling: .caption)
    static let eyebrow = TextRole(.default, 12, weight: .semibold, tracking: 0.13, scaling: .caption)
    static let eyebrowSmall = TextRole(.default, 11, weight: .semibold, tracking: 0.14, scaling: .caption2)
    static let pillLabel = TextRole(.default, 12, weight: .medium, scaling: .caption)

    // Anything the user should be able to compare down a column.
    static let timestamp = TextRole(.monospaced, 12, weight: .semibold, tracking: 0.02, scaling: .caption)
    static let stats = TextRole(.monospaced, 12, weight: .medium, tracking: 0.02, scaling: .caption)
    static let timer = TextRole(.monospaced, 15, weight: .medium, tracking: 0.02, scaling: .subheadline)
}

extension View {
    func textStyle(_ role: TextRole) -> some View {
        modifier(ScaledText(role))
    }

    /// An all-caps label. Uppercasing is done here rather than in the copy so the strings
    /// stay readable where they are written, and so screen readers get sentence case.
    func eyebrowStyle(
        _ role: TextRole = .eyebrow,
        color: Color = Color.ember.opacity(0.75)
    ) -> some View {
        textStyle(role)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

private struct ScaledText: ViewModifier {
    private let role: TextRole
    @ScaledMetric private var size: CGFloat

    init(_ role: TextRole) {
        self.role = role
        _size = ScaledMetric(wrappedValue: role.size, relativeTo: role.scaling)
    }

    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: role.weight, design: role.design))
            .tracking(size * role.trackingRatio)
            // `lineSpacing` is the gap added between lines, where the design specifies total
            // line height as a multiple of the size. A line already occupies roughly 1.2× its
            // size, so that is what comes off.
            .lineSpacing(role.lineHeightRatio > 0 ? max(0, size * (role.lineHeightRatio - 1.2)) : 0)
    }
}
