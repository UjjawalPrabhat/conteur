import Foundation

struct Transcript: Sendable, Hashable {
    let words: [SpokenWord]

    static let empty = Transcript(words: [])

    var text: String {
        words.map(\.text).joined(separator: " ")
    }

    var duration: TimeInterval {
        guard let first = words.first, let last = words.last else { return 0 }
        return last.end - first.start
    }
}
