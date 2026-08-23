import SwiftData
import SwiftUI

/// What the app knows about you: where you stand, the one thing to work on, and what has
/// held long enough to be stated as fact.
///
/// Named for the artboard rather than `ProgressView`, which is SwiftUI's spinner.
struct ProgressCoachView: View {
    @Environment(\.modelContext) private var context
    @State private var model: ProgressViewModel?

    var body: some View {
        NavigationStack {
            ScrollView {
                if let model, model.hasHistory {
                    content(model)
                } else {
                    empty
                }
            }
            .scrollIndicators(.hidden)
            .background(NightBackground())
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            let model = model ?? ProgressViewModel(context: context)
            self.model = model
            // Reloaded on every appearance rather than once: a telling finished in the Tell
            // tab has to show up here without relaunching.
            model.load()
        }
    }

    private func content(_ model: ProgressViewModel) -> some View {
        VStack(alignment: .leading, spacing: Space.screen) {
            header(model)
            TierBadge(level: model.report.standing.level, archetype: model.report.archetype)
            if let next = model.nextLevel {
                Text(next)
                    .textStyle(.secondary)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            workOnThis(model)
            benchmark(model)
            badges(model)
            alreadyTrue(model)
            everyNumber
        }
        .screenPadding()
        .padding(.top, Space.section)
        .padding(.bottom, Space.section)
    }

    private func header(_ model: ProgressViewModel) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("Progress")
                .textStyle(.largeTitle)
                .foregroundStyle(Ink.primary)
            Text(model.tellingsLabel)
                .textStyle(.meta)
                .foregroundStyle(Ink.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One thing, never a list. The whole diagnosis layer exists to pick a single weakness,
    /// and a screen that hands back five would undo it.
    @ViewBuilder
    private func workOnThis(_ model: ProgressViewModel) -> some View {
        if let claim = model.report.workOnThis {
            VStack(alignment: .leading, spacing: Space.sm) {
                Text("Work on this next").eyebrowStyle(.eyebrowSmall)
                Text(claim.statement)
                    .textStyle(.narrative)
                    .foregroundStyle(Ink.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(claim.evidence)
                    .textStyle(.stats)
                    .foregroundStyle(Color.moonlight)
            }
            .padding(Space.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()
        }
    }

    /// The one comparison on this screen where the story was the same one both times.
    ///
    /// Set apart from "already true" because it is a different kind of claim: those are counts
    /// over whatever was told, this is the same difficulty twice.
    @ViewBuilder
    private func benchmark(_ model: ProgressViewModel) -> some View {
        if let claim = model.report.benchmark {
            VStack(alignment: .leading, spacing: Space.sm) {
                Text("The same story, twice").eyebrowStyle(.eyebrowSmall)
                Text(claim.statement)
                    .textStyle(.excerpt)
                    .foregroundStyle(Color.paper.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
                Text(claim.evidence)
                    .textStyle(.stats)
                    .foregroundStyle(Color.moonlight)
            }
            .padding(Space.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()
        }
    }

    @ViewBuilder
    private func alreadyTrue(_ model: ProgressViewModel) -> some View {
        if !model.report.alreadyTrue.isEmpty {
            VStack(alignment: .leading, spacing: Space.md) {
                SectionHeading(title: "Already true of you")
                ForEach(model.report.alreadyTrue) { claim in
                    HStack(alignment: .firstTextBaseline, spacing: Space.m) {
                        Text(claim.statement)
                            .textStyle(.excerpt)
                            .foregroundStyle(Color.paper.opacity(0.72))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: Space.s)
                        Text(claim.evidence)
                            .textStyle(.stats)
                            .foregroundStyle(Ink.quaternary)
                    }
                }
            }
        }
    }

    private func badges(_ model: ProgressViewModel) -> some View {
        FoldedRow(title: "Badges", trailing: model.badgesLabel) {
            VStack(alignment: .leading, spacing: Space.m) {
                ForEach(model.report.badges) { badge in
                    row(badge.name, badge.detail, isEarned: true)
                }
                ForEach(model.unearnedBadges) { badge in
                    row(badge.name, badge.detail, isEarned: false)
                }
            }
        }
    }

    private func row(_ name: String, _ detail: String, isEarned: Bool) -> some View {
        HStack(alignment: .top, spacing: Space.m) {
            Image(systemName: isEarned ? "flame.fill" : "flame")
                .font(.system(size: 13))
                .foregroundStyle(isEarned ? Color.ember : Ink.quaternary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .textStyle(.rowTitle)
                    .foregroundStyle(isEarned ? Ink.primary : Ink.tertiary)
                Text(detail)
                    .textStyle(.secondary)
                    .foregroundStyle(Ink.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name). \(detail). \(isEarned ? "Earned" : "Not yet earned")")
    }

    private var everyNumber: some View {
        NavigationLink {
            EveryNumberView()
        } label: {
            HStack {
                Text("See every number")
                    .textStyle(.actionQuiet)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(Color.ember)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("Progress")
                .textStyle(.largeTitle)
                .foregroundStyle(Ink.primary)
            Text("Nothing to show yet.")
                .textStyle(.sectionHeading)
                .foregroundStyle(Ink.primary)
                .padding(.top, Space.l)
            Text("Tell a story and this fills in — where you stand, what keeps going wrong, and what has started holding.")
                .textStyle(.body)
                .foregroundStyle(Ink.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .screenPadding()
        .padding(.top, Space.section)
    }
}
