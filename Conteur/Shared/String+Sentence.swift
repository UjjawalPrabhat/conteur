import Foundation

extension String {
    /// Sentence case without touching the rest of the string.
    ///
    /// `capitalized` would title-case every word, which turns "two dimensions Strong in one
    /// telling" into something no person wrote. Requirements and advice are authored as
    /// fragments so they can be read mid-sentence, and this is what lets the same string also
    /// open one.
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
