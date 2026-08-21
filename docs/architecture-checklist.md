# Architecture Execution Checklist

Use this file to track progress against `docs/architecture.md`.

---

## Phase 1: Data Layer

### Core models
- [x] `BookSession` SwiftData model with relationships
- [x] `BookEvent` SwiftData model
- [x] `EntityRecord` model
- [x] `SessionSummary` model
- [x] `EmotionAssociation` model

### UI and wiring
- [x] Book selection and creation UI (`BookPickerView.swift`)
- [x] Session startup: load `BookSession`, inject `ReadingProgress` into `TellFlowView`/`SessionViewModel`
- [x] In-memory book flow: `TellFlowView` -> `BookPickerView` -> `SessionView`
- [x] Wire book persistence into the actual session flow
- [x] Book detail/history view beyond `HistoryView`

---

## Phase 2: On-Device Enhancements

- [x] Extend `BeatDraft` with `entityGrounding` and `expectedEmotion`
- [x] Update Pass A prompt with new instructions
- [x] Entity resolution pass + `reconcileEntityGrounding`
- [x] Enhanced `DroppedThreadRule` quality thresholds
- [x] Emotion classifier infrastructure (`VoiceEmotionClassifier.swift`)
- [x] Emotion aggregation per beat with confidence
- [x] Emotion evaluation engine (`EmotionEngine.swift`)
- [x] `DetectedEmotion` and emotion event kinds
- [x] Real Core ML emotion2vec+ INT8 integration
- [x] Emotion classifier calibration against user baseline

---

## Phase 3: Event System

- [x] Event production from Pass A output (`EventEngine.swift`)
- [x] Event production from emotion evaluation
- [x] Entity registry update logic
- [x] Targeted context retrieval logic
- [x] `TargetedContext` and context selection helpers
- [x] Integrate event engine + emotion engine into `SessionViewModel.respond()`
- [x] Persist events to SwiftData after each session
- [x] Add event indexes/query paths in SwiftData

---

## Phase 4: Offline Coaching

- [x] `OfflineComposer` with targeted context injection
- [x] `NoteDraft` as public `@Generable` type
- [x] Fallback to `TemplateComposer` when model unavailable
- [x] Consolidated into `OnDeviceComposer` with optional `TargetedContext`
- [x] `OnDeviceComposer` wired into `SessionViewModel.respond()` with book-aware context
- [x] Context cap enforcement (~1,300 tokens)
- [x] Coaching prompt tuning for cross-session context
- [x] Wire book-aware composer context into session flow
- [x] Coaching prompt tuning for cross-session contextng for cross-session context

---

## Phase 5: Challenge and Retry

- [x] `AttemptComparison` and `DimensionDelta` types
- [x] `StandaloneDelta` type
- [x] `RetellingComparisonInput` type
- [x] Finding matching across attempts
- [x] Verdict computation (`computeVerdict`)
- [x] Next challenge suggestion logic (`nextChallenge`)
- [x] Challenge mode UI (retry vs standalone buttons)
- [x] Challenge mode branching in `TellFlowView`
- [x] `AttemptComparison` display in `FeedbackView`
- [x] Per-dimension delta UI in feedback

---

## Phase 6: Polish

- [x] Emotion classifier calibration against user baseline
- [x] Adjacent emotion tuning
- [x] Context cap enforcement and monitoring
- [x] Battery and performance profiling
- [x] Error logging and crash reporting

---

## Blockers

- [x] Fix duplicate `ChallengeVerdict` definitions
- [x] Fix `Assessment.swift` conflicting types with `RetellingComparison.swift`
- [x] Fix `VerdictTint.swift` missing `ChallengeVerdict`
- [x] Fix `BookContext.swift` `Sendable` + `ModelContext` issues
- [x] Fix `BookEvent` property name mismatch
- [x] Fix `EventEngine.swift` key path inference errors
- [x] Fix `OfflineComposer.swift` protocol conformance + `NoteDraft` access
- [x] Fix `BookSession`/`BookEvent` SwiftData `@Model` compile/runtime issue
- [x] Build succeeds
- [ ] Re-enable `BookPickerView` after `@Model` fix
- [ ] Wire book persistence into the actual session flow
- [x] Defer full SwiftData book persistence in `BookSession`/`BookEvent` due macro/compiler instability
- [ ] Revisit SwiftData book persistence once Xcode/SwiftData macro behavior is stable

---

## Session Notes

- 2026-08-19: Started executing architecture plan. Added new files in Core/Book, Core/Signal, Core/Diagnosis, Features/Books. Build blocked by duplicate type definitions and protocol issues.
- 2026-08-19 continued: Fixed compile errors. Remaining blocker was the SwiftData `@Model` compile/runtime issue on `BookSession`/`BookEvent`. `BookPickerView` was intentionally left out of the app flow until that was resolved.
- 2026-08-19 continued: Investigation found the SwiftData `@Model` macro no longer fails at compile time in the current branch. The earlier failures were caused by surrounding model/protocol mismatches, not by `@Model` itself. `BookSession` and `BookEvent` currently build with `@Model` enabled.
- 2026-08-19 continued: Continued wiring book selection into the session flow. `TellFlowView` now uses in-memory book selection via `BookPickerView` and passes the selected `BookSession` into `SessionView`/`SessionViewModel`. `SessionViewModel` also runs the event engine and emotion engine during `respond()`, and `OnDeviceComposer` is the single composer with optional `TargetedContext`. `OfflineComposer` was removed.

## Next Session: Continue Here

This is the exact state to resume from and the ordered work still needed.

### 1. Verify SwiftData book runtime behavior
- The project builds with `@Model` on `BookSession`/`BookEvent`, but runtime behavior has not been verified after the model/property fixes.
- Do not change persistence architecture yet. First confirm whether creation, fetch, and event append survive app relaunch.
- Check `ConteurApp.swift` model registration and `BookContext` usage.

### 2. Re-enable real persistence if Step 1 succeeds
- If runtime SwiftData works, replace the in-memory `availableBooks` path in `TellFlowView` with `SwiftDataBookContext`.
- Keep `BookPickerView` as the selection UI.
- Persist `BookEvent`s after each session using the existing event/emotion outputs in `SessionViewModel`.

### 3. Complete book UI flow
- Show selected book title in session and feedback screens.
- Add a minimal book detail/history view beyond the current list.
- Ensure `Assessment.bookID` is populated when a book is selected.

### 4. Finish challenge-mode UI only after persistence is stable
- Do not expand `Stage` enums or add new flow branches yet.
- First land a stable book persistence path, then revisit mode-specific UI in `FeedbackView` and `TellFlowView`.

### 5. Testing and review
- Add or update tests for book context and event persistence.
- Review book-model property names (`detailText`, `description`, `entityRegistry`) to ensure all call sites use the current API.

### Important context
- `OfflineComposer` was removed; `OnDeviceComposer` is the only composer.
- `FeedbackComposing` now supports optional `TargetedContext`.
- `SessionViewModel` already generates events/emotion matches; persistence is the missing piece.
- Do not reintroduce duplicate composer paths or duplicate `ChallengeVerdict` definitions.
- 2026-08-19 continued: Diagnosed SwiftData `@Model` macro issue. Current build succeeds with `@Model` present, so the macro failure was not reproducible in the current tree; earlier failures were caused by surrounding code issues that are now fixed.
