import Foundation
import FoundationModels
import os.log

/// Turns a finding into something worth hearing.
///
/// Every fact is supplied; the model only phrases it. That is a small, bounded job,
/// and it is the reason a 3B on-device model is sufficient here.
struct OnDeviceComposer: FeedbackComposing {
    private static let options = GenerationOptions(sampling: .greedy)
    private static let maxBriefTokens = 1300
    private static let logger = Logger(subsystem: "com.daffa.conteur", category: "composer.tokens")

    func compose(
        from diagnosis: Diagnosis,
        context: TargetedContext?,
        history: Band?,
        progress: RetellingProgress?
    ) async -> Feedback? {
        // Nothing could be judged at all — the caller says so rather than inventing one.
        guard diagnosis.isJudgeable else { return nil }

        // Nothing was wrong. Saying nothing would leave the speaker with a blank screen
        // and no way back into the loop, so this still earns a note and a challenge.
        guard let focus = diagnosis.focus, !focus.findings.isEmpty else {
            let fallback = TemplateComposer().nothingStoodOut(in: diagnosis, progress: progress)
            Self.logTokenUsage(for: fallback, promptTokens: 0)
            return fallback
        }

        let fallback = TemplateComposer().compose(focus, progress: progress)
        guard case .available = SystemLanguageModel.default.availability else {
            Self.logTokenUsage(for: fallback, promptTokens: 0)
            return fallback
        }

        do {
            let instructions = Self.instructions
            let brief = Self.brief(for: focus, context: context, history: history, progress: progress)
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(
                to: brief,
                generating: NoteDraft.self,
                options: Self.options
            )
            let draft = response.content

            let promptTokens = Self.tokenCount(for: instructions) + Self.tokenCount(for: brief)
            let outputTokens = Self.tokenCount(for: draft.note) + Self.tokenCount(for: draft.challenge)
            Self.logTokenUsage(
                for: Feedback(
                    dimension: focus.dimension,
                    note: draft.note,
                    challenge: draft.challenge,
                    evidence: focus.findings.flatMap(\.evidence)
                ),
                promptTokens: promptTokens,
                outputTokens: outputTokens
            )

            return Feedback(
                dimension: focus.dimension,
                note: draft.note,
                challenge: draft.challenge,
                evidence: focus.findings.flatMap(\.evidence)
            )
        } catch {
            Self.logTokenUsage(for: fallback, promptTokens: 0)
            return fallback
        }
    }

    private static func brief(
        for focus: DimensionAssessment,
        context: TargetedContext?,
        history: Band?,
        progress: RetellingProgress?
    ) -> String {
        var lines: [String] = []

        if let context {
            let tokenBudget = Self.maxBriefTokens - Self.tokenCount(for: Self.instructions)
            let cappedLines = Self.cappedLines(from: Self.contextLines(for: context, progress: progress), within: tokenBudget)
            lines.append(contentsOf: cappedLines)
        }

        if let progress, progress.before != progress.after {
            lines.append("Previous progress:")
            lines.append("  Covered: \(progress.before.label) → \(progress.after.label)")
            lines.append("")
        }

        lines.append("Current findings:")
        lines.append("  Dimension: \(focus.dimension.rawValue)")
        lines.append("  Band: \(focus.band.rawValue)")
        lines.append("  Score: \(focus.score)")
        lines.append("")
        for finding in focus.findings {
            lines.append("  - \(finding.observation)")
        }
        lines.append("")

        if let history {
            lines.append("Previous telling:")
            lines.append("  Band: \(history.rawValue)")
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    private static func contextLines(for context: TargetedContext, progress: RetellingProgress?) -> [String] {
        var lines: [String] = []

        lines.append("Book: \(context.bookTitle)")
        lines.append("Mode: \(context.evaluationMode.rawValue)")
        lines.append("")

        if let progress, progress.before != progress.after {
            lines.append("Previous progress:")
            lines.append("  Covered: \(progress.before.label) → \(progress.after.label)")
            lines.append("")
        }

        if !context.entityEvents.isEmpty {
            lines.append("Relevant entity history:")
            for event in context.entityEvents.prefix(10) {
                lines.append("  - \(event.description)")
            }
            lines.append("")
        }

        if let stakesEvent = context.stakesEvent {
            lines.append("Stakes event:")
            lines.append("  - \(stakesEvent.description)")
            lines.append("")
        }

        if !context.emotionalHistory.isEmpty {
            lines.append("Recent emotional pattern:")
            for event in context.emotionalHistory.prefix(6) {
                lines.append("  - \(event.description)")
            }
            lines.append("")
        }

        return lines
    }

    private static func cappedLines(from lines: [String], within remainingBudget: Int) -> [String] {
        var budget = remainingBudget
        var capped: [String] = []

        for line in lines {
            let cost = Self.tokenCount(for: line) + 1
            guard cost > 0 && cost <= budget else { break }
            capped.append(line)
            budget -= cost
        }

        return capped
    }

    private static func tokenCount(for text: String) -> Int {
        max(text.splitByWhitespaceAndPunctuation().count, 1)
    }

    private static func logTokenUsage(
        for feedback: Feedback,
        promptTokens: Int,
        outputTokens: Int? = nil
    ) {
        let noteTokens = Self.tokenCount(for: feedback.note)
        let challengeTokens = Self.tokenCount(for: feedback.challenge)
        let resolvedOutput = outputTokens ?? noteTokens + challengeTokens

        logger.debug(
            "feedback_token_usage dimension=\(feedback.dimension.rawValue) prompt_tokens=\(promptTokens) output_tokens=\(resolvedOutput) note_tokens=\(noteTokens) challenge_tokens=\(challengeTokens)"
        )
    }

    private static func logTokenUsage(promptTokens: Int, outputTokens: Int) {
        logger.debug(
            "feedback_token_usage prompt_tokens=\(promptTokens) output_tokens=\(outputTokens)"
        )
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

    func nothingStoodOut(in diagnosis: Diagnosis, progress: RetellingProgress?) -> Feedback {
        let held = diagnosis.strengths.first?.dimension
        let opening = progress.map { "\($0.verdict.label). " } ?? ""
        let praise = held.map { "Nothing pulled me out of that one — \($0.title.lowercased()) especially held up." }
            ?? "Nothing pulled me out of that one."

        return Feedback(
            dimension: held ?? .structure,
            note: "\(opening)\(praise)",
            challenge: challenge(for: held ?? .structure),
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

private extension String {
    func splitByWhitespaceAndPunctuation() -> [Substring] {
        self.split { $0.isWhitespace || $0.isPunctuation }
    }
}
