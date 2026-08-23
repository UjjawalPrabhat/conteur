import Foundation
import Testing

@testable import Conteur

/// The Progress tab makes claims about somebody over months. It is pure arithmetic over
/// stored tellings, so unlike the fire it can be checked exactly — and it has to be, because
/// a wrong claim here is one the user cannot go and verify against a recording.
struct ProgressReportTests {
    // MARK: - Fire level

    @Test func noHistoryIsUnlitRatherThanZero() {
        let report = ProgressReport.over([])

        #expect(report.standing.level == .unlit)
        #expect(report.tellings == 0)
        #expect(report.workOnThis == nil)
    }

    @Test func oneTellingIsASpark() {
        #expect(FireLevel.standing(over: [telling()]).level == .spark)
    }

    @Test func threeTellingsReachKindling() {
        let history = (0..<3).map { telling(daysAgo: $0) }

        #expect(FireLevel.standing(over: history).level == .kindling)
    }

    /// The rung the design names, and the one the feedback screen awards.
    @Test func twoStrongDimensionsInOneTellingReachSteadyFlame() {
        let strong = telling(scores: [.structure: 0.9, .fidelity: 0.9])

        #expect(FireLevel.standing(over: [strong]).level == .steadyFlame)
    }

    /// Two dimensions Strong across two *different* tellings is not the same achievement.
    @Test func twoStrongDimensionsSpreadAcrossTellingsIsNotSteadyFlame() {
        let history = [
            telling(daysAgo: 0, scores: [.structure: 0.9]),
            telling(daysAgo: 1, scores: [.fidelity: 0.9]),
        ]

        #expect(FireLevel.standing(over: history).level < .steadyFlame)
    }

    @Test func allSixStrongReachesBeaconEvenOnAShortHistory() {
        let perfect = telling(scores: Dictionary(uniqueKeysWithValues: Dimension.allCases.map { ($0, 0.9) }))

        #expect(FireLevel.standing(over: [perfect]).level == .beacon)
    }

    /// A count-based rung can report how far off it is; a single-telling rung cannot, and
    /// inventing a fraction for it would be a made-up number on a screen of real ones.
    @Test func onlyCountedRungsCarryAFraction() {
        let towardsKindling = FireLevel.standing(over: [telling(), telling(daysAgo: 1)])

        #expect(towardsKindling.next == .kindling)
        #expect(towardsKindling.progress?.done == 2)
        #expect(towardsKindling.progress?.needed == 3)

        let towardsSteadyFlame = FireLevel.standing(over: (0..<3).map { telling(daysAgo: $0) })
        #expect(towardsSteadyFlame.next == .steadyFlame)
        #expect(towardsSteadyFlame.progress == nil)
    }

    // MARK: - Archetype

    @Test func aPairStrongInThreeOfFiveIsNamed() {
        let history = (0..<5).map { index in
            telling(daysAgo: index, scores: index < 3 ? [.structure: 0.9, .fidelity: 0.9] : [:])
        }

        let archetype = Archetype.over(history)

        #expect(archetype?.name == "The Chronicler")
        #expect(archetype?.met == 3)
        #expect(archetype?.considered == 5)
    }

    @Test func aPairStrongTwiceIsNotYetAnArchetype() {
        let history = (0..<5).map { index in
            telling(daysAgo: index, scores: index < 2 ? [.structure: 0.9, .fidelity: 0.9] : [:])
        }

        #expect(Archetype.over(history) == nil)
    }

    /// Having no shape yet is a real answer, and the screen says so rather than picking the
    /// least-bad pair.
    @Test func tooLittleHistoryHasNoArchetype() {
        #expect(Archetype.over([telling(), telling(daysAgo: 1)]) == nil)
    }

    @Test func theOrderOfADimensionPairDoesNotMatter() {
        #expect(DimensionPair(.structure, .fidelity) == DimensionPair(.fidelity, .structure))
    }

    /// Fifteen pairs, six named. The rest still have to render.
    @Test func anUnnamedPairStillGetsAName() {
        let history = (0..<3).map { telling(daysAgo: $0, scores: [.delivery: 0.9, .relevance: 0.9]) }

        let archetype = Archetype.over(history)

        #expect(archetype != nil)
        #expect(archetype?.name.isEmpty == false)
    }

    // MARK: - The fixed story

    /// One telling of the benchmark story compares with nothing, so there is no claim to make.
    @Test func oneBenchmarkTellingIsNotATrend() {
        let history = [telling(isBenchmark: true, storyID: StoryLibrary.benchmark.id)]

        #expect(ProgressReport.over(history).benchmark == nil)
    }

    /// The only comparison in the app where the difficulty was held still.
    @Test func theFixedStoryToldTwiceReportsWhatChanged() {
        let history = [
            telling(daysAgo: 0, isBenchmark: true, scores: [.structure: 0.9, .fidelity: 0.9]),
            telling(daysAgo: 30, isBenchmark: true, scores: [.structure: 0.9]),
            // A different story in between must not enter the series.
            telling(daysAgo: 15, scores: Dimension.allCases.reduce(into: [:]) { $0[$1] = 0.9 }),
        ]

        let claim = ProgressReport.over(history).benchmark

        #expect(claim?.of == 2)
        #expect(claim?.out == Dimension.allCases.count)
        #expect(claim?.statement.contains("up from 1") == true)
    }

    // MARK: - Not enough to tell

    /// A dimension nothing could be judged on carries a score of 1 while it is in memory, as
    /// the placeholder for "no deductions were taken". Persisting that placeholder made every
    /// count over history read it back as a perfect score — so a telling too sparse to look at
    /// awarded tiers, badges and archetypes it had not earned.
    ///
    /// `Assessment.scores` now omits unjudged dimensions, so the stored record has no entry at
    /// all. This is the shape that arrives here, and none of it may read as strength.
    @Test func aDimensionThatCouldNotBeJudgedIsNeverAStrength() {
        // Delivery judged and weak; everything else absent because nothing could evaluate it.
        let sparse = telling(scores: [.delivery: 0.4])

        #expect(sparse.strongDimensions == 0)
        #expect(Dimension.allCases.allSatisfy { !sparse.isStrong($0) })
        #expect(sparse.band(for: .structure) == nil)

        let report = ProgressReport.over(Array(repeating: sparse, count: 5))

        #expect(report.standing.level == .kindling)
        #expect(report.archetype == nil)
        #expect(report.badges.contains { $0.id == "faithful" } == false)
        #expect(report.alreadyTrue.isEmpty)
    }

    // MARK: - Badges

    @Test func aFirstTellingEarnsFirstFire() {
        #expect(Badge.earned(over: [telling()]).contains { $0.id == "first-fire" })
    }

    @Test func meetingAChallengeEarnsHeldIt() {
        let group = UUID()
        let history = [
            telling(daysAgo: 0, attempt: 2, group: group, verdict: .met),
            telling(daysAgo: 1, attempt: 1, group: group),
        ]

        #expect(Badge.earned(over: history).contains { $0.id == "held-it" })
    }

    /// The badge says the challenge was met. Telling it again is not meeting it, and the badge
    /// would otherwise be awarded for pressing the button.
    @Test func aSecondTellingThatMissedDoesNotEarnHeldIt() {
        let group = UUID()
        let history = [
            telling(daysAgo: 0, attempt: 2, group: group, verdict: .notYet),
            telling(daysAgo: 1, attempt: 1, group: group),
        ]

        #expect(Badge.earned(over: history).contains { $0.id == "held-it" } == false)
    }

    /// Three attempts at one story is persistence with a single story, not a run of three.
    @Test func retellingOneStoryThreeTimesIsNotAnUnbrokenRun() {
        let group = UUID()
        let history = (1...3).map { telling(daysAgo: 3 - $0, attempt: $0, group: group) }

        #expect(Badge.earned(over: history).contains { $0.id == "unbroken" } == false)
    }

    @Test func threeStoriesEachToldTwiceIsAnUnbrokenRun() {
        var history: [StoredRetelling] = []
        for story in 0..<3 {
            let group = UUID()
            history.append(telling(daysAgo: story * 2, attempt: 2, group: group))
            history.append(telling(daysAgo: story * 2 + 1, attempt: 1, group: group))
        }

        #expect(Badge.earned(over: history).contains { $0.id == "unbroken" })
    }

    @Test func tellingEveryGenreEarnsLongWayRound() {
        let history = Genre.allCases.enumerated().map { index, genre in
            telling(daysAgo: index, storyID: StoryLibrary.stories(in: genre).first?.id)
        }

        #expect(Badge.earned(over: history).contains { $0.id == "long-way-round" })
    }

    @Test func tellingOneGenreDoesNotEarnLongWayRound() {
        let history = StoryLibrary.stories(in: .folkTale).prefix(3).enumerated().map { index, story in
            telling(daysAgo: index, storyID: story.id)
        }

        #expect(Badge.earned(over: history).contains { $0.id == "long-way-round" } == false)
    }

    // MARK: - Claims

    /// The same failure four times in ten is a habit. This is what the coaching line says.
    @Test func aRecurringFailureBecomesTheThingToWorkOn() {
        let history = (0..<6).map { index in
            telling(daysAgo: index, subjects: index < 4 ? ["order"] : ["fillers"])
        }

        let claim = ProgressReport.over(history, now: .now).workOnThis

        #expect(claim?.id == "order")
        #expect(claim?.of == 4)
        #expect(claim?.out == 6)
    }

    /// Leaving Mira out twice and Nadia out twice is one habit, not two problems. The rules
    /// build these subjects per character, so counting them raw would never aggregate.
    @Test func thesameFailureAboutDifferentPeopleCountsOnce() {
        let history = [
            telling(daysAgo: 0, subjects: ["missing-Mira"]),
            telling(daysAgo: 1, subjects: ["missing-Mira"]),
            telling(daysAgo: 2, subjects: ["missing-Nadia"]),
            telling(daysAgo: 3, subjects: ["missing-Rosalind"]),
        ]

        let claim = ProgressReport.over(history, now: .now).workOnThis

        #expect(claim?.id == "missing")
        #expect(claim?.of == 4)
    }

    @Test func aFailureThatHappenedTwiceIsNotYetAHabit() {
        let history = (0..<6).map { index in
            telling(daysAgo: index, subjects: index < 2 ? ["order"] : [])
        }

        #expect(ProgressReport.over(history, now: .now).workOnThis == nil)
    }

    /// Tellings saved before finding subjects were recorded carry none, and an empty list
    /// must not read as a clean telling.
    @Test func tellingsWithNoRecordedFindingsAreNotCountedAsClean() {
        let history = (0..<8).map { telling(daysAgo: $0) }

        #expect(ProgressReport.over(history, now: .now).workOnThis == nil)
    }

    @Test func anUnrecognisedSubjectProducesNoClaimRatherThanRawText() {
        let history = (0..<5).map { telling(daysAgo: $0, subjects: ["some-new-rule"]) }

        #expect(ProgressReport.over(history, now: .now).workOnThis == nil)
    }

    @Test func aDimensionStrongMostOfTheTimeIsStatedAsFact() {
        let history = (0..<5).map { index in
            telling(daysAgo: index, scores: index < 4 ? [.delivery: 0.9] : [.delivery: 0.2])
        }

        let claims = ProgressReport.over(history, now: .now).alreadyTrue

        #expect(claims.contains { $0.id == "strong-delivery" && $0.of == 4 })
    }

    // MARK: - Totals

    @Test func totalsAddUpAcrossHistory() {
        let history = [
            telling(daysAgo: 0, words: 200, duration: 60),
            telling(daysAgo: 1, words: 150, duration: 90),
        ]

        let report = ProgressReport.over(history, now: .now)

        #expect(report.tellings == 2)
        #expect(report.wordsTold == 350)
        #expect(report.timeAtTheFire == 150)
    }

    /// Two attempts at one story is one story retold, not two.
    @Test func retoldTwiceCountsStoriesNotRecords() {
        let group = UUID()
        let history = [
            telling(daysAgo: 0, attempt: 2, group: group),
            telling(daysAgo: 1, attempt: 1, group: group),
            telling(daysAgo: 2, attempt: 2, group: UUID()),
        ]

        #expect(ProgressReport.over(history, now: .now).retoldTwice == 2)
    }

    /// A delta needs a previous stretch to compare against. With only recent tellings there
    /// is no change to report, which is not the same as no improvement.
    @Test func aDeltaWithNothingToCompareAgainstIsAbsent() {
        let history = (0..<3).map { telling(daysAgo: $0, scores: [.structure: 0.8]) }

        let deltas = ProgressReport.over(history, now: .now).deltas

        #expect(deltas.first { $0.dimension == .structure }?.change == nil)
    }

    @Test func improvementSinceTheMonthBeforeReadsPositive() {
        let history = [
            telling(daysAgo: 2, scores: [.structure: 0.8]),
            telling(daysAgo: 40, scores: [.structure: 0.4]),
        ]

        let change = ProgressReport.over(history, now: .now).deltas
            .first { $0.dimension == .structure }?.change

        #expect(change != nil)
        #expect((change ?? 0) > 0)
    }

    @Test func paceIsReportedOldestFirstSoTheLineReadsForwards() {
        let history = [
            telling(daysAgo: 0, words: 200, duration: 60),
            telling(daysAgo: 5, words: 100, duration: 60),
        ]

        let pace = ProgressReport.over(history, now: .now).pace

        #expect(pace.count == 2)
        #expect(pace[0].wordsPerMinute == 100)
        #expect(pace[1].wordsPerMinute == 200)
    }

    // MARK: - Fixture

    private func telling(
        daysAgo: Int = 0,
        attempt: Int = 1,
        group: UUID? = nil,
        verdict: ChallengeVerdict? = nil,
        isBenchmark: Bool = false,
        storyID: String? = nil,
        scores: [Conteur.Dimension: Double] = [:],
        subjects: [String] = [],
        words: Int = 150,
        duration: TimeInterval = 60
    ) -> StoredRetelling {
        StoredRetelling(
            recordedAt: Date(timeIntervalSinceNow: -Double(daysAgo) * 86_400),
            groupID: group ?? UUID(),
            attempt: attempt,
            isBenchmark: isBenchmark,
            storyID: storyID,
            focus: Dimension.structure.rawValue,
            verdict: verdict?.rawValue,
            scoreData: try? JSONEncoder().encode(scores),
            findingData: subjects.isEmpty ? nil : (try? JSONEncoder().encode(subjects)),
            wordCount: words,
            duration: duration
        )
    }
}
