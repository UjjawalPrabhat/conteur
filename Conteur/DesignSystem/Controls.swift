import SwiftUI

/// The one prominent action on a screen. There is never more than one.
struct EmberButtonStyle: ButtonStyle {
    var height: CGFloat = 54
    var radius: CGFloat = Radius.button

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(.action)
            .foregroundStyle(Color.onEmber)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(Color.ember, in: .rect(cornerRadius: radius))
            .shadow(color: Color.ember.opacity(0.28), radius: 15, y: 5)
            .opacity(configuration.isPressed ? 0.86 : 1)
    }
}

/// The alternative to the ember button, where a screen offers a way out as well as a way on.
struct OutlineButtonStyle: ButtonStyle {
    var height: CGFloat = 54

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(.actionQuiet)
            .foregroundStyle(Ink.primary)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay {
                RoundedRectangle(cornerRadius: Radius.button)
                    .strokeBorder(Color.paper.opacity(0.2), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// The stop button on the telling screen. It sits over the fire, so it is glass rather than
/// a fill — a solid button there punches a hole in the scene.
struct FiresideButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(.actionQuiet)
            .foregroundStyle(Color(hex: 0xF7EADA))
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(.ultraThinMaterial.opacity(0.6), in: .rect(cornerRadius: Radius.button))
            .background(Color(hex: 0x140C08).opacity(0.45), in: .rect(cornerRadius: Radius.button))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.button)
                    .strokeBorder(Color(hex: 0xFFD6AA).opacity(0.28), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// A back button. The chevron is the system's, not a drawn one.
struct BackButton: View {
    let title: String
    var tint: Color = .ember
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .textStyle(.actionQuiet)
            }
            .foregroundStyle(tint)
            // Text alone is a target well under the 44pt minimum, and this is the only way
            // back on three of the screens.
            .frame(minWidth: 44, minHeight: 44, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// A rating, or a one-word status. Ember when it is something to be pleased about.
struct Pill: View {
    let text: String
    var isStrong = false

    var body: some View {
        Text(text)
            .textStyle(.pillLabel)
            .foregroundStyle(isStrong ? Color.emberLight : Ink.secondary)
            .padding(.horizontal, Space.s)
            .padding(.vertical, Space.xxs)
            .background(
                isStrong ? Surface.emberPill : Surface.pill,
                in: .rect(cornerRadius: Radius.rating)
            )
    }
}

/// A block of ember-tinted text used to warn or to instruct — never to praise.
struct Callout: View {
    let text: String
    var isWarning = false

    var body: some View {
        Text(text)
            .textStyle(.secondary)
            .foregroundStyle(isWarning ? Color.emberPale : Color.emberLight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Space.md)
            .padding(.horizontal, Space.l)
            .background(
                isWarning ? Surface.emberWarning : Surface.emberCallout,
                in: .rect(cornerRadius: Radius.callout)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Radius.callout)
                    .strokeBorder(
                        isWarning ? Surface.emberWarningEdge : Surface.emberCalloutEdge,
                        lineWidth: 1
                    )
            }
    }
}

/// A serif section heading, with the app's voice rather than the interface's.
struct SectionHeading: View {
    let title: String
    var note: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            Text(title)
                .textStyle(.sectionHeading)
                .foregroundStyle(Ink.primary)
            if let note {
                Text(note)
                    .textStyle(.secondary)
                    .foregroundStyle(Ink.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The user's own words, set apart. The rule down the left is what marks it as a quotation
/// of them rather than a line of the app's own copy.
struct QuotedWords: View {
    let text: String

    var body: some View {
        Text(text)
            .textStyle(.quote)
            .foregroundStyle(Ink.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, Space.m)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Color.ember.opacity(0.5))
                    .frame(width: 2)
            }
    }
}

/// One line of transcript: when it was said, and what was said.
struct TranscriptLine: View {
    let at: String
    let text: String
    var size: TextRole = .body
    /// Set on the passage a finding was sent to, so the words the claim came from are picked
    /// out of the rest of the telling rather than merely scrolled into view.
    var isHighlighted = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.m) {
            Text(at)
                .textStyle(.timestamp)
                .foregroundStyle(isHighlighted ? Color.ember : Ink.quaternary)
                .frame(width: 34, alignment: .leading)
            Text(text)
                .textStyle(size)
                .foregroundStyle(isHighlighted ? Ink.primary : Color.paper.opacity(0.72))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(
            isHighlighted ? Color.ember.opacity(0.12) : .clear,
            in: .rect(cornerRadius: Radius.finding)
        )
    }
}
