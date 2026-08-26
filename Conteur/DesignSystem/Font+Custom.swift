import SwiftUI

// MARK: - Custom Font Weights

enum BitcountWeight: String, CaseIterable, Sendable {
    case thin = "Bitcount-Thin"
    case extraLight = "Bitcount-ExtraLight"
    case light = "Bitcount-Light"
    case regular = "Bitcount-Regular"
    case medium = "Bitcount-Medium"
    case semiBold = "Bitcount-SemiBold"
    case bold = "Bitcount-Bold"
    case extraBold = "Bitcount-ExtraBold"
    case black = "Bitcount-Black"
}

enum InconsolataWeight: String, CaseIterable, Sendable {
    case extraLight = "Inconsolata-ExtraLight"
    case light = "Inconsolata-Light"
    case regular = "Inconsolata-Regular"
    case medium = "Inconsolata-Medium"
    case semiBold = "Inconsolata-SemiBold"
    case bold = "Inconsolata-Bold"
    case extraBold = "Inconsolata-ExtraBold"
    case black = "Inconsolata-Black"
}

// MARK: - Font Extensions

extension Font {
    /// Returns a Bitcount custom font with the specified weight and size.
    static func bitcount(_ weight: BitcountWeight = .regular, size: CGFloat) -> Font {
        .custom(weight.rawValue, size: size)
    }

    /// Returns a Bitcount custom font that scales relative to a dynamic text style.
    static func bitcount(_ weight: BitcountWeight = .regular, size: CGFloat, relativeTo textStyle: Font.TextStyle) -> Font {
        .custom(weight.rawValue, size: size, relativeTo: textStyle)
    }

    /// Returns an Inconsolata custom font with the specified weight and size.
    static func inconsolata(_ weight: InconsolataWeight = .regular, size: CGFloat) -> Font {
        .custom(weight.rawValue, size: size)
    }

    /// Returns an Inconsolata custom font that scales relative to a dynamic text style.
    static func inconsolata(_ weight: InconsolataWeight = .regular, size: CGFloat, relativeTo textStyle: Font.TextStyle) -> Font {
        .custom(weight.rawValue, size: size, relativeTo: textStyle)
    }
}
