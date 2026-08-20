import Foundation
import FoundationModels

/// Why a model call produced nothing. Kept apart because they call for different responses:
/// a refusal is worth retrying, a full context window means the request was too big, and
/// anything else is a bug until shown otherwise.
enum ModelFailure: String, LocalizedError, Sendable {
    case refused
    case contextExceeded
    case other

    init(_ error: any Error) {
        // Already classified. Individual event judgements are classified where they fail,
        // because `any Error` cannot cross a task boundary.
        if let failure = error as? ModelFailure {
            self = failure
            return
        }
        if let generation = error as? LanguageModelSession.GenerationError {
            switch generation {
            case .guardrailViolation: self = .refused; return
            case .exceededContextWindowSize: self = .contextExceeded; return
            default: break
            }
        }
        // The typed cases did not match failures that plainly were these, and being unable to
        // count them made two evaluation runs unreadable. Matching the message is a poor way
        // to identify an error and the only one that has worked.
        let message = error.localizedDescription.lowercased()
        if message.contains("unsafe") {
            self = .refused
        } else if message.contains("context window") {
            self = .contextExceeded
        } else {
            self = .other
        }
    }

    var errorDescription: String? { label }

    var label: String {
        switch self {
        case .refused: "refused by the guardrail"
        case .contextExceeded: "filled the context window"
        case .other: "failed"
        }
    }
}

extension Error {
    var isGuardrailRefusal: Bool { ModelFailure(self) == .refused }
}
