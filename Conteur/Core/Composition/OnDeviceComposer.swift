import Foundation
import FoundationModels

/// Turns a finding into something worth hearing.
///
/// Every fact is supplied; the model only phrases it. That is a small, bounded job,
/// and it is the reason a 3B on-device model is sufficient here.
struct OnDeviceComposer: FeedbackComposing {
    private static let options = GenerationOptions(sampling: .greedy)

    func compose(from diagnosis: Diagnosis, history: Band?, progress: RetellingProgress?) async -> Feedback? {
        // Nothing could be judged at all — the caller says so rather than inventing one.
        guard diagnosis.isJudgeable else { return nil }

        // Nothing was wrong. Saying nothing would leave the speaker with a blank screen
        // and no way back into the loop, so this still earns a note and a challenge.
        guard let focus = diagnosis.focus, !focus.findings.isEmpty else {
            return TemplateComposer().nothingStoodOut(in: diagnosis, progress: progress)
        }

        let fallback = TemplateComposer().compose(focus, progress: progress)
        guard case .available = SystemLanguageModel.default.availability else { return fallback }

        do {
            let session = LanguageModelSession(instructions: Self.instructions)
            let draft = try await session.respond(
                to: Self.brief(for: focus, history: history, progress: progress),
                generating: NoteDraft.self,
                options: Self.options
            ).content

            return Feedback(
                dimension: focus.dimension,
                note: draft.note,
                challenge: draft.challenge,
                evidence: focus.findings.flatMap(\.evidence)
            )
        } catch {
            return fallback
        }
    }

    private static func brief(
        for focus: DimensionAssessment,
        history: Band?,
        progress: RetellingProgress?
    ) -> String {
        var lines: [String] = []

        // On a second telling the comparison leads, because that is what they were
        // asked to change and what they are waiting to hear about.
        if let progress {
            lines.append("They were asked: \(progress.challenge)")
            lines.append("Verdict: \(progress.verdict.rawValue)")
            lines.append(contentsOf: progress.resolved.map { "- fixed: \($0.observation)" })
            lines.append(contentsOf: progress.persisted.map { "- still there: \($0.observation)" })
            lines.append(contentsOf: progress.introduced.map { "- new this time: \($0.observation)" })
        }

        lines.append("What they did: \(focus.dimension.rawValue)")
        lines.append(contentsOf: focus.findings.map { "- \($0.observation)" })
        if let history, progress == nil {
            lines.append("Last time this was \(history.rawValue).")
        }
        return lines.joined(separator: "\n")
    }

    private static let instructions = """
        You are the listener somebody just told a story to. You are given exactly what
        was observed about how they told it. Say it back to them.

        Use only what you are given. Never invent a detail, a quote or a number.

        Speak to them directly, as one person to another. Name the moment, say what it
        cost the story, and stop. Three or four sentences.

        No score, no grade, no list, no headings. Do not open by praising them and do
        not soften the observation into a suggestion.

        If you are told what they were asked to change, say whether it happened before
        anything else. The verdict is already decided — never contradict it, and never
        congratulate them for something the verdict does not credit.

        Then give them one thing to do differently when they tell it again. Make it
        specific to what you just described, and make it a single sentence.
        """
}

@Generable
private struct NoteDraft {
    @Guide(description: "Three or four sentences, spoken directly to the storyteller.")
    var note: String

    @Guide(description: "One sentence: what to do differently next time.")
    var challenge: String
}

/// Used when the model is unavailable or declines. Blunter than the composed version,
/// but every claim in it is still true and still traceable.
private struct TemplateComposer {
    func compose(_ focus: DimensionAssessment, progress: RetellingProgress?) -> Feedback {
        let observations = focus.findings.prefix(2).map(\.observation)
        let opening = progress.map { "\($0.verdict.label.lowercased()) on what you were asked to change. " } ?? ""

        return Feedback(
            dimension: focus.dimension,
            note: "\(opening)Listening to that back: \(observations.joined(separator: ", and ")).",
            challenge: challenge(for: focus.dimension),
            evidence: focus.findings.flatMap(\.evidence)
        )
    }

    /// Deliberately templated rather than generated. Handed a brief with no findings in
    /// it, the model's obvious move is to invent one.
    func nothingStoodOut(in diagnosis: Diagnosis, progress: RetellingProgress?) -> Feedback {
        let held = diagnosis.strengths.first?.dimension
        let opening = progress.map { "\($0.verdict.label). " } ?? ""
        let praise = held.map { "Nothing pulled me out of that one — \($0.title.lowercased()) especially held up." }
            ?? "Nothing pulled me out of that one."

        return Feedback(
            dimension: held ?? .structure,
            note: opening + praise + " So the useful thing now is to make it harder for yourself.",
            challenge: "Tell it again in half the time, and keep everything that matters.",
            evidence: []
        )
    }

    private func challenge(for dimension: Dimension) -> String {
        switch dimension {
        case .structure: "Tell it again, and this time land how it ended up."
        case .coherence: "Tell it again, and follow every thread you open through to its end."
        case .relevance: "Tell it again, and keep only what the story turns on."
        case .engagement: "Tell it again, and say out loud why each turn mattered."
        case .delivery: "Tell it again, and let the silences do some of the work."
        }
    }
}
