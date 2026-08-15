import SwiftUI

extension ChallengeVerdict {
    var tint: Color {
        switch self {
        case .met: .green
        case .closer: .orange
        case .notYet: .secondary
        }
    }
}
