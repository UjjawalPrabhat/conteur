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
            entity.surfaceForms.contains { transcript.mentions($0) }
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

    /// Words this event's summary uses that no other event's does.
    ///
    /// Naming the cast is not telling an event — the model credited events on the strength of
    /// a character being mentioned, which is why names alone are not enough to corroborate
    /// one. What an event brings with it beyond its cast is its own vocabulary.
    func distinctiveWords(of beat: CanonicalBeat, in story: GuidedStory) -> Set<String> {
        let counts = story.beats.reduce(into: [String: Int]()) { counts, beat in
            for word in Self.contentWords(of: beat.summary) { counts[word, default: 0] += 1 }
        }
        return Self.contentWords(of: beat.summary).filter { counts[$0] == 1 }
    }

    /// How much of an event's own vocabulary the retelling contains.
    ///
    /// One word is weak evidence and enough words are strong enough to outweigh a judgement,
    /// so the count is reported rather than a verdict.
    func vocabularyOverlap(
        _ transcript: Transcript,
        _ beat: CanonicalBeat,
        in story: GuidedStory
    ) -> Int {
        distinctiveWords(of: beat, in: story).count { transcript.contains(phrase: $0) }
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

    /// Whether the retelling contains anything only this event would have brought up: a name
    /// belonging to this part of the story, and a word belonging to this event.
    ///
    /// Both are required. Dropping the name half credited two more events that were never told,
    /// and events wrongly credited are the failure worth paying to avoid — the feedback then
    /// praises a passage the speaker never spoke. Its matching was the real defect: exact
    /// surface forms missed three real coverages on nothing but a determiner and a plural.
    func corroborates(_ transcript: Transcript, _ beat: CanonicalBeat, in story: GuidedStory) -> Bool {
        let entities = distinctiveEntities(of: beat, in: story)
        let named = entities.isEmpty || entities.contains { entity in
            entity.surfaceForms.contains { transcript.mentions($0) }
        }
        guard named else { return false }

        let words = distinctiveWords(of: beat, in: story)
        return words.isEmpty || words.contains { transcript.contains(phrase: $0) }
    }

    private static func contentWords(of summary: String) -> Set<String> {
        Set(
            summary
                .lowercased()
                .split(whereSeparator: { !$0.isLetter })
                .map(String.init)
                .filter { $0.count > 2 && !functionWords.contains($0) }
        )
    }

    /// Counting how many summaries use a word removes anything common, but not a function word
    /// that happens to appear in only one of them: where a single summary says "into", "into"
    /// becomes that event's distinctive word and matches any retelling at all. Deriving the
    /// list from the library's own summaries instead was tried, scored worse, and would have
    /// made the check drift as stories were added.
    private static let functionWords: Set<String> = [
        "the", "and", "but", "then", "when", "while", "from", "into", "over", "under",
        "after", "before", "for", "with", "she", "her", "hers", "his", "him", "they",
        "them", "their", "its", "this", "that", "these", "those", "there", "here",
        "who", "whom", "whose", "which", "what", "are", "was", "were", "been", "being",
        "has", "have", "had", "does", "did", "will", "would", "can", "could", "should",
        "may", "might", "must", "not", "nor", "than", "too", "very", "just", "only",
        "own", "same", "now", "out", "off", "again", "further", "once", "one", "two",
        "three", "down",
    ]

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
    /// Whether a name from the story was said, allowing for the ways speech differs from an
    /// authored surface form.
    ///
    /// Exact matching cost six real coverages for two reasons and no others: "the letters" is
    /// spoken as "full of letters", and "the briefcases" as "a different briefcase". A
    /// determiner and a plural, so those are what is allowed to differ — nothing looser, since
    /// the point of matching a name is that it was actually said.
    func mentions(_ surfaceForm: String) -> Bool {
        let words = surfaceForm
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .drop { ["the", "a", "an"].contains($0) }
        guard let last = words.last else { return false }

        let stem = words.dropLast()
        let alternatives = last.count > 3 && last.hasSuffix("s")
            ? [last, String(last.dropLast())]
            : [last, last + "s"]
        return alternatives.contains { contains(phrase: (stem + [$0]).joined(separator: " ")) }
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
