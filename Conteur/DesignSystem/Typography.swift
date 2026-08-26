import SwiftUI

/// Custom font family and weight definition for the design system typography.
enum TypographyFont: Sendable {
    case bitcount(BitcountWeight)
    case inconsolata(InconsolataWeight)

    var fontName: String {
        switch self {
        case .bitcount(let weight):
            return weight.rawValue
        case .inconsolata(let weight):
            return weight.rawValue
        }
    }
}

/// The type scale, as roles rather than sizes.
struct TextRole: Sendable {
    let font: TypographyFont
    let size: CGFloat
    /// Tracking as a fraction of the size, so it stays proportional once scaled.
    let trackingRatio: CGFloat
    /// Total line height as a multiple of the size, or zero to leave it alone.
    let lineHeightRatio: CGFloat
    /// The system style this scales alongside.
    let scaling: Font.TextStyle

    fileprivate init(
        _ font: TypographyFont,
        _ size: CGFloat,
        tracking: CGFloat = 0,
        lineHeight: CGFloat = 0,
        scaling: Font.TextStyle
    ) {
        self.font = font
        self.size = size
        self.trackingRatio = tracking
        self.lineHeightRatio = lineHeight
        self.scaling = scaling
    }
}

extension TextRole {
    // MARK: - Bitcount (Display & Story Voice - Always .regular)
    /// Large story picker title ("Pick a Story")
    static let bitcountPickerTitle = TextRole(.bitcount(.regular), 32, tracking: -0.015, lineHeight: 1.12, scaling: .title)
    /// Story card title in the picker
    static let bitcountCardTitle = TextRole(.bitcount(.regular), 20, tracking: -0.01, lineHeight: 1.15, scaling: .title3)
    /// Prominent action button ("Start Storytelling")
    static let bitcountAction = TextRole(.bitcount(.regular), 18, tracking: 0.01, scaling: .body)
    /// Badge or word count in Bitcount ("\(words) words")
    static let bitcountBadge = TextRole(.bitcount(.regular), 14, tracking: 0.02, scaling: .caption)
    /// Large titles / display
    static let largeTitle = TextRole(.bitcount(.regular), 38, tracking: -0.015, lineHeight: 1.05, scaling: .largeTitle)
    static let storyTitle = TextRole(.bitcount(.regular), 32, tracking: -0.015, lineHeight: 1.12, scaling: .title)
    static let detailTitle = TextRole(.bitcount(.regular), 30, tracking: -0.015, lineHeight: 1.12, scaling: .title)
    static let figure = TextRole(.bitcount(.regular), 30, tracking: -0.015, scaling: .title)

    // MARK: - Inconsolata (Interface, Content & Readouts)
    // Screen Titles & Large Headings
    static let screenTitle = TextRole(.inconsolata(.bold), 32, tracking: -0.015, lineHeight: 1.1, scaling: .largeTitle)
    static let screenTitleMedium = TextRole(.inconsolata(.bold), 28, tracking: -0.01, lineHeight: 1.15, scaling: .title)
    static let statement = TextRole(.inconsolata(.bold), 28, lineHeight: 1.22, scaling: .title)
    static let promptLarge = TextRole(.inconsolata(.bold), 32, lineHeight: 1.2, scaling: .title)
    static let sectionHeading = TextRole(.inconsolata(.bold), 24, tracking: -0.01, scaling: .title2)
    static let cardHeading = TextRole(.inconsolata(.bold), 18, tracking: -0.005, scaling: .headline)
    static let verdict = TextRole(.inconsolata(.bold), 21, lineHeight: 1.3, scaling: .title3)

    // Body & Prose
    static let narrative = TextRole(.inconsolata(.regular), 20, lineHeight: 1.58, scaling: .body)
    static let storyBody = TextRole(.inconsolata(.regular), 19, lineHeight: 1.62, scaling: .body)
    static let summary = TextRole(.inconsolata(.regular), 18, lineHeight: 1.55, scaling: .body)
    static let body = TextRole(.inconsolata(.regular), 16, lineHeight: 1.5, scaling: .body)
    static let bodyBold = TextRole(.inconsolata(.bold), 16, lineHeight: 1.4, scaling: .body)
    static let quote = TextRole(.inconsolata(.bold), 16, lineHeight: 1.5, scaling: .body)
    static let excerpt = TextRole(.inconsolata(.regular), 16, lineHeight: 1.5, scaling: .body)
    static let secondary = TextRole(.inconsolata(.regular), 14, lineHeight: 1.45, scaling: .subheadline)
    static let secondaryBold = TextRole(.inconsolata(.bold), 14, lineHeight: 1.4, scaling: .subheadline)
    static let transcript = TextRole(.inconsolata(.regular), 14, lineHeight: 1.55, scaling: .body)

    // Navigation & Actions
    static let navTitle = TextRole(.inconsolata(.regular), 16, scaling: .body)
    static let navAction = TextRole(.inconsolata(.regular), 16, scaling: .body)
    static let rowTitle = TextRole(.inconsolata(.bold), 16, tracking: -0.005, scaling: .body)
    static let actionLarge = TextRole(.inconsolata(.bold), 18, scaling: .body)
    static let action = TextRole(.inconsolata(.bold), 17, scaling: .body)
    static let actionQuiet = TextRole(.inconsolata(.medium), 17, scaling: .body)

    // Badges, Tags & Captions
    static let meta = TextRole(.inconsolata(.regular), 12, tracking: 0.02, scaling: .footnote)
    static let metaSmall = TextRole(.inconsolata(.regular), 13, tracking: 0.02, scaling: .footnote)
    static let caption = TextRole(.inconsolata(.regular), 12, tracking: 0.02, scaling: .caption)
    static let tag = TextRole(.inconsolata(.regular), 12, scaling: .caption)
    static let tagSmall = TextRole(.inconsolata(.regular), 10, scaling: .caption2)
    static let pillLabel = TextRole(.inconsolata(.regular), 14, scaling: .caption)
    static let prompt = TextRole(.inconsolata(.regular), 23, tracking: -0.01, lineHeight: 1.25, scaling: .title2)
    static let categoryLabel = TextRole(.inconsolata(.regular), 12, tracking: 0.06, scaling: .caption)
    static let eyebrow = TextRole(.inconsolata(.semiBold), 12, tracking: 0.13, scaling: .caption)
    static let eyebrowSmall = TextRole(.inconsolata(.semiBold), 11, tracking: 0.14, scaling: .caption2)

    // Numbers, Timers & Metrics
    static let timerDisplay = TextRole(.inconsolata(.bold), 24, tracking: 0.02, scaling: .title2)
    static let counterDisplay = TextRole(.inconsolata(.bold), 24, tracking: 0.02, scaling: .title2)
    static let statusBadge = TextRole(.inconsolata(.bold), 20, scaling: .title3)
    static let timestamp = TextRole(.inconsolata(.bold), 12, tracking: 0.02, scaling: .caption)
    static let stats = TextRole(.inconsolata(.bold), 12, tracking: 0.02, scaling: .caption)
    static let timer = TextRole(.inconsolata(.medium), 15, tracking: 0.02, scaling: .subheadline)
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
            .font(.custom(role.font.fontName, size: size, relativeTo: role.scaling))
            .tracking(size * role.trackingRatio)
            .lineSpacing(role.lineHeightRatio > 0 ? max(0, size * (role.lineHeightRatio - 1.2)) : 0)
    }
}
