import Foundation

struct SpokenWord: Sendable, Hashable {
    let text: String
    let start: TimeInterval
    let end: TimeInterval

    var duration: TimeInterval { end - start }
}

extension SpokenWord {
    /// Lowercased and stripped of punctuation, for matching against known tokens.
    var normalized: String {
        text.lowercased().trimmingCharacters(in: .punctuationCharacters)
    }

    /// The transcriber attaches punctuation to the word it follows, which is the
    /// only available signal for where a clause ends.
    var endsClause: Bool {
        guard let last = text.unicodeScalars.last else { return false }
        return ".,;:!?—".unicodeScalars.contains(last)
    }
}
