import SwiftUI

/// One figure and what it counts.
///
/// Moonlight rather than ember: a screen of ember numbers reads as a screen of buttons, and
/// the accent has to keep meaning "you can act on this".
struct StatFigure: View {
    let value: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            Text(value)
                .textStyle(.figure)
                .foregroundStyle(Color.moonlight)
            Text(caption)
                .textStyle(.categoryLabel)
                .foregroundStyle(Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A dimension and how it has moved. Direction is carried by the sign and the word, not by
/// colour alone — red-green would be the only place in the app where meaning depends on hue.
struct DeltaRow: View {
    let title: String
    let change: Double?

    var body: some View {
        HStack {
            Text(title)
                .textStyle(.rowTitle)
                .foregroundStyle(Ink.primary)
            Spacer()
            Text(label)
                .textStyle(.stats)
                .foregroundStyle(tint)
                .accessibilityLabel(spoken)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, Space.l)
    }

    private var label: String {
        guard let change else { return "—" }
        let percent = Int((change * 100).rounded())
        return percent > 0 ? "+\(percent)%" : "\(percent)%"
    }

    private var tint: Color {
        guard let change else { return Ink.quaternary }
        return change >= 0 ? Color.moonlight : Color(hex: 0xE4884A)
    }

    private var spoken: String {
        guard let change else { return "\(title), nothing to compare against yet" }
        let percent = abs(Int((change * 100).rounded()))
        return change >= 0 ? "\(title), up \(percent) percent" : "\(title), down \(percent) percent"
    }
}

/// Pace over time. Deliberately unlabelled and unaxed — it is here to show a shape, and the
/// two numbers that matter are named beside it in words.
struct Sparkline: View {
    let values: [Double]

    var body: some View {
        GeometryReader { proxy in
            if let path = path(in: proxy.size) {
                path.stroke(
                    Color.moonlight.opacity(0.8),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .frame(height: 44)
        .accessibilityHidden(true)
    }

    private func path(in size: CGSize) -> Path? {
        guard values.count > 1, let low = values.min(), let high = values.max() else { return nil }
        let span = max(high - low, 1)
        return Path { path in
            for (index, value) in values.enumerated() {
                let x = size.width * Double(index) / Double(values.count - 1)
                let y = size.height * (1 - (value - low) / span)
                let point = CGPoint(x: x, y: y)
                index == 0 ? path.move(to: point) : path.addLine(to: point)
            }
        }
    }
}

/// A section that stays shut until it is asked for.
///
/// The spine of the new feedback and numbers screens. A count on the closed row is what makes
/// folding honest — you can see there are three moments without being made to read them.
struct FoldedRow<Content: View>: View {
    let title: String
    var trailing: String?
    /// Supply this only when something outside the row has to be able to open it — a finding
    /// pointing at the transcript, say. Left nil, the row owns its own state, which is what
    /// every other use wants.
    var openness: Binding<Bool>?
    @ViewBuilder var content: () -> Content

    @State private var isOpenLocally = false

    private var fold: Binding<Bool> { openness ?? $isOpenLocally }
    private var isOpen: Bool { fold.wrappedValue }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { fold.wrappedValue.toggle() }
            } label: {
                HStack(spacing: Space.s) {
                    Text(title)
                        .textStyle(.rowTitle)
                        .foregroundStyle(Ink.primary)
                    Spacer()
                    if let trailing {
                        Text(trailing)
                            .textStyle(.stats)
                            .foregroundStyle(Ink.tertiary)
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Ink.tertiary)
                        .rotationEffect(.degrees(isOpen ? 0 : -90))
                }
                .padding(.vertical, Space.l)
                .padding(.horizontal, Space.lg)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(isOpen ? "Collapses this section" : "Expands this section")

            if isOpen {
                content()
                    .padding(.horizontal, Space.lg)
                    .padding(.bottom, Space.lg)
            }
        }
        .cardSurface(Surface.finding)
    }
}

/// The current fire level and the archetype it has grown into.
struct TierBadge: View {
    let level: FireLevel
    let archetype: Archetype?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text("You've reached").eyebrowStyle(.eyebrowSmall)
                Text(level.label)
                    .textStyle(.verdict)
                    .foregroundStyle(Color.emberLight)
            }

            Divider().overlay(Surface.divider)

            if let archetype {
                HStack(alignment: .firstTextBaseline, spacing: Space.m) {
                    Text("\(archetype.met) / \(archetype.considered)")
                        .textStyle(.stats)
                        .foregroundStyle(Ink.tertiary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(archetype.name)
                            .textStyle(.rowTitle)
                            .foregroundStyle(Ink.primary)
                        Text(archetype.summary)
                            .textStyle(.categoryLabel)
                            .foregroundStyle(Ink.tertiary)
                    }
                    Spacer()
                }
            } else {
                Text("Still finding your shape.")
                    .textStyle(.secondary)
                    .foregroundStyle(Ink.secondary)
            }
        }
        .padding(Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(Surface.emberWash, border: Surface.emberEdge)
    }
}
