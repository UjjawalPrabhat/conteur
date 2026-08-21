import Foundation
import FoundationModels

@Generable
struct NoteDraft: Codable, Sendable, Hashable {
    @Guide(description: "Three or four sentences, spoken directly to the storyteller.")
    var note: String

    @Guide(description: "One sentence: what to do differently next time.")
    var challenge: String
}
