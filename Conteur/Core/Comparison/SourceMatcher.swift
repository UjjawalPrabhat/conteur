import Foundation

/// Everything about a retelling that can be measured against its source without asking
/// anything. Pure, so it is testable with no device and no model.
///
/// This is where most of the comparison lives. Only beat coverage needs a model, because
/// only that requires recognising an event described in different words.

/// A name spoken that belongs to nobody in the story, and when it was spoken.
struct InventedName: Sendable, Hashable {
    let name: String
    let at: TimeInterval
}

struct SourceMatcher: Sendable {
    func entities(
        in transcript: Transcript,
        from story: GuidedStory
    ) -> (mentioned: [StoryEntity], omitted: [StoryEntity]) {
        let mentioned = story.cast.filter { entity in
            entity.surfaceForms.contains { transcript.contains(phrase: $0) }
        }
        let names = Set(mentioned.map(\.name))
        return (mentioned, story.cast.filter { !names.contains($0.name) })
    }

    /// Proper nouns spoken that belong to nobody in the story.
    ///
    /// Crude by design — capitalised, not sentence-initial, absent from the story's own
    /// words. It exists because the failure it catches is the worst one available: a
    /// retelling populated with people the story never had.
    func inventedNames(in transcript: Transcript, from story: GuidedStory) -> [InventedName] {
        let known = Set(
            story.cast
                .flatMap(\.surfaceForms)
                .flatMap { $0.lowercased().split(separator: " ").map(String.init) }
        )
        let storyWords = Set(
            story.prose.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init)
        )

        var invented: [InventedName] = []
        for (index, word) in transcript.words.enumerated() {
            // A possessive is the same name: "Elspeth's" was being reported as somebody the
            // story never had.
            let bare = word.text
                .trimmingCharacters(in: .punctuationCharacters)
                .replacingOccurrences(of: "'s", with: "")
                .replacingOccurrences(of: "\u{2019}s", with: "")
            guard
                bare.count > 2,
                bare.first?.isUppercase == true,
                index > 0,
                !transcript.words[index - 1].endsClause
            else { continue }

            let lowered = bare.lowercased()
            guard !known.contains(lowered), !storyWords.contains(lowered) else { continue }
            guard !invented.contains(where: { $0.name == bare }) else { continue }
            invented.append(InventedName(name: bare, at: word.start))
        }
        return invented
    }

    /// Names that belong to one part of the story rather than running through it.
    ///
    /// The protagonist appears in every event, so their name corroborates nothing. A name that
    /// turns up in only a couple of events does.
    func distinctiveEntities(of beat: CanonicalBeat, in story: GuidedStory) -> [StoryEntity] {
        let appearances = story.beats.reduce(into: [String: Int]()) { counts, beat in
            for entity in beat.entities { counts[entity, default: 0] += 1 }
        }
        let threshold = Double(story.beats.count) / 2
        return beat.entities
            .filter { Double(appearances[$0] ?? 0) < threshold }
            .compactMap { story.entity(named: $0) }
    }

    /// Whether the retelling contains anything only this event would have brought up.
    ///
    /// An event with no distinctive name is left alone: there is nothing to check it against,
    /// and rejecting it for that would be worse than accepting it.
    func corroborates(_ transcript: Transcript, _ beat: CanonicalBeat, in story: GuidedStory) -> Bool {
        let distinctive = distinctiveEntities(of: beat, in: story)
        guard !distinctive.isEmpty else { return true }
        return distinctive.contains { entity in
            entity.surfaceForms.contains { transcript.contains(phrase: $0) }
        }
    }

    /// Fraction of covered beat pairs told in the story's own order. A concordant-pair
    /// measure, so six beats with one displaced scores far better than six told backwards.
    ///
    /// Only located coverages can be ordered — a beat known to be covered but not to be
    /// placed says nothing about sequence.
    func orderAccuracy(of covered: [BeatCoverage]) -> Double {
        let covered = covered.filter(\.isLocated).sorted { ($0.at ?? 0) < ($1.at ?? 0) }
        guard covered.count >= 2 else { return 1 }

        var concordant = 0
        var total = 0
        for i in covered.indices {
            for j in covered.indices where j > i {
                total += 1
                if covered[i].beat.id < covered[j].beat.id { concordant += 1 }
            }
        }
        return total > 0 ? Double(concordant) / Double(total) : 1
    }
}

extension Transcript {
    var normalizedText: String {
        words.map(\.normalized).joined(separator: " ")
    }

    /// Whether the retelling contains a phrase, matched on whole words.
    ///
    /// Substring matching counted "she" inside "shes" and "her" inside "there", which
    /// inflated every entity match.
    func contains(phrase: String) -> Bool {
        locate(phrase) != nil
    }

    /// Where a phrase was spoken, or nil when it was not.
    ///
    /// This is the guard against a fabricated quote: the model is asked to copy words from
    /// the retelling, and anything it did not copy cannot be located and is dropped.
    func locate(_ phrase: String) -> TimeInterval? {
        let needle = phrase
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
        guard !needle.isEmpty else { return nil }

        let haystack = words.map(\.normalized)
        guard haystack.count >= needle.count else { return nil }

        for start in 0...(haystack.count - needle.count) {
            if Array(haystack[start..<start + needle.count]) == needle {
                return words[start].start
            }
        }
        return nil
    }
}
