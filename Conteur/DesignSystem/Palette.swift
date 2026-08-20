import SwiftUI

/// The palette, named for what each colour *is* rather than where it happens to be used.
///
/// The app is dark by design — it is meant to feel like sitting at a fire at night — so
/// there is no light variant. `RootView` pins the appearance rather than these adapting.
extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    // Night — the standard screen behind everything that is not the fire.
    static let nightTop = Color(hex: 0x0D1E36)
    static let nightMid = Color(hex: 0x081324)
    static let nightDeep = Color(hex: 0x050D1A)

    // The fire scene.
    static let sceneSkyTop = Color(hex: 0x040A16)
    static let sceneSkyMid = Color(hex: 0x071020)
    static let sceneSkyLow = Color(hex: 0x0A0F18)
    static let sceneGround = Color(hex: 0x110D0A)
    static let sceneGroundTop = Color(hex: 0x0B0A09)
    static let sceneGroundDeep = Color(hex: 0x161010)
    static let treeline = Color(hex: 0x050A10)

    // Ember — the one accent. Primary buttons, the active tab, timestamps.
    static let ember = Color(hex: 0xF0A44C)
    /// Text sitting on an ember-tinted fill, where `ember` itself would not read.
    static let emberLight = Color(hex: 0xF5CB93)
    /// Warning text over the fire, which needs to beat the flame behind it.
    static let emberPale = Color(hex: 0xFFDCAE)
    static let emberEdge = Color(hex: 0xC4622A)

    static let flameCore = Color(hex: 0xFFF3E0)
    static let flameHeart = Color(hex: 0xFFFBF0)
    static let flameBody = Color(hex: 0xFFD79A)
    static let logTop = Color(hex: 0x3A2317)
    static let logBase = Color(hex: 0x1B100B)

    /// Primary text. Never used at full strength — see `Ink`.
    static let paper = Color(hex: 0xF4EFE7)
    /// The label on a primary button, which sits on ember and has to be near-black.
    static let onEmber = Color(hex: 0x160D03)
}

/// Text strengths on dark.
///
/// The design fixes these as opacities of one colour rather than separate greys, so a
/// paragraph and its caption stay related no matter what sits behind them.
enum Ink {
    static let primary = Color.paper.opacity(0.9)
    static let secondary = Color.paper.opacity(0.58)
    static let tertiary = Color.paper.opacity(0.45)
    static let quaternary = Color.paper.opacity(0.35)
    /// Words the transcriber has already settled on, behind the phrase being spoken now.
    static let settled = Color.paper.opacity(0.34)
}

/// Fills and hairlines. Every card in the app is one of these.
enum Surface {
    static let card = Color.white.opacity(0.055)
    static let cardQuiet = Color.white.opacity(0.045)
    static let finding = Color.white.opacity(0.05)
    /// An absence is a different class of claim than a timestamped finding, so it gets a
    /// fainter fill and a dashed edge rather than the same card with something missing.
    static let absence = Color.white.opacity(0.03)
    static let pill = Color.white.opacity(0.07)
    static let hairline = Color.white.opacity(0.08)
    static let divider = Color.white.opacity(0.07)
    static let dividerQuiet = Color.white.opacity(0.05)
    static let dashed = Color.white.opacity(0.14)

    static let emberWash = Color.ember.opacity(0.09)
    static let emberEdge = Color.ember.opacity(0.2)
    static let emberCallout = Color.ember.opacity(0.10)
    static let emberCalloutEdge = Color.ember.opacity(0.22)
    static let emberWarning = Color.ember.opacity(0.14)
    static let emberWarningEdge = Color.ember.opacity(0.3)
    static let emberPill = Color.ember.opacity(0.16)
    static let emberRow = Color.ember.opacity(0.07)
    static let tabBar = Color(hex: 0x050D1A).opacity(0.72)
}
