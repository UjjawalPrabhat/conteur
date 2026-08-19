import Foundation
import FoundationModels

extension Error {
    /// Whether the model declined rather than answered.
    ///
    /// Worth a named check in one place: pattern-matching the case against the result of
    /// `as?` silently tests an Optional and never matches, which is how nine refusals in a
    /// row were counted as zero.
    var isGuardrailRefusal: Bool {
        guard let generation = self as? LanguageModelSession.GenerationError else { return false }
        if case .guardrailViolation = generation { return true }
        return false
    }
}
