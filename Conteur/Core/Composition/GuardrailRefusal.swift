import Foundation
import FoundationModels

extension Error {
    /// Whether the model declined rather than answered.
    ///
    /// Worth a named check in one place: pattern-matching the case against the result of
    /// `as?` silently tests an Optional and never matches, which is how nine refusals in a
    /// row were counted as zero.
    var isGuardrailRefusal: Bool {
        if let generation = self as? LanguageModelSession.GenerationError,
           case .guardrailViolation = generation {
            return true
        }
        // The typed case did not match a refusal that plainly was one, and being unable to
        // count refusals made two evaluation runs unreadable. Matching the message is a poor
        // way to identify an error and the only one that currently works.
        return localizedDescription.localizedCaseInsensitiveContains("unsafe")
    }
}
