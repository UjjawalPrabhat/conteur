# Conteur — Production Readiness

Single source of truth for what must be true before this ships. Every item has a validation criterion, not a vibe.

---

## Guiding principles

1. **No recorded media.** Audio is processed and discarded. This must remain literally true after every change to capture or persistence.
2. **Deterministic findings.** The same retelling must produce the same diagnosis. No randomness, no model sampling drift in the evaluation path.
3. **Honest failure.** Every component has a fallback that produces *something useful*. The user never sees a blank screen when partial feedback is possible.
4. **Memory-aware retry.** The verdict engine knows what came before. The composer phrases what the verdict engine decided. Nothing contradicts the verdict.
5. **Tested on device.** The simulator cannot validate capture, transcription, or on-device model behavior. Device-only items are marked.

---

## Phase 0 — Non-negotiables (blocks everything else)

| # | Item | Owner | Status | Validation |
|---|---|---|---|---|
| 0.1 | `BookEvent.id` is stable across reads | Core | ⬜ | Fetch a `BookEvent`, read `.id` twice, assert equality. Must hold after app relaunch. |
| 0.2 | Selected book receives events after session | Core | ⬜ | Run a full session, assert `book.events.count == 1` and `book.lastSessionNumber == 1`. |
| 0.3 | Entity registry persists and updates | Core | ⬜ | Run two sessions, assert `entityRegistry` count grows and `mentionCount` increments on existing entities. |
| 0.4 | `availableBooks` refreshes after mutations | Features | ⬜ | Create a book, pop to picker, assert it appears without app relaunch. |
| 0.5 | Time-limit self-termination does not deadlock | Features | ⬜ | Run a 10-minute session on device, assert session ends cleanly within 60s of cap. |
| 0.6 | `ReadingProgress` has one source of truth | Core | ⬜ | Assert `BookSession.progress` equals the `readingProgress` stored in `Assessment` after every session. |
| 0.7 | `Assessment.mode` is never nil after completion | Shared | ⬜ | Assert `assessment.mode != nil` for every completed session, standalone and continuation. |

### Validation protocol for Phase 0

Run on device (iPhone 15 Pro or newer, iOS 26):

```bash
# Build and run UI tests
xcodebuild -scheme Conteur -destination 'platform=iOS,name=iPhone 17 Pro' test

# Manual smoke test:
# 1. Create a book
# 2. Run a session (>40 words, >20s)
# 3. Verify book appears in picker with 1 session
# 4. Run a second session
# 5. Verify entity count increased, events persisted
# 6. Force-quit app, relaunch, verify state survived
```

---

## Phase 1 — Feedback engine (the retry loop)

This is the highest-risk component. The verdict math is correct; the wiring is not.

### 1.1 Collapse the three-way split into one evaluation

**What:** Replace `compare()`, `attemptComparison()`, and `nextChallenge()` with a single `evaluateRetelling(first:second:challenge:bookState:) -> RetellingEvaluation`.

**Why:** Three functions computing overlapping truths from overlapping inputs, called from different places, with no type-level guarantee they agree. This is why the verdict doesn’t match the composer, why the challenge freezes, and why the UI shows only the focus dimension.

**Validation:**
- [ ] `RetellingComparisonTests.swift` updated: old tests call `evaluateRetelling`, old helpers removed or marked deprecated.
- [ ] New test: `evaluateRetelling` produces a verdict, deltas, and nextChallenge from the same input tuple. Mutate the input, assert all three outputs change consistently.
- [ ] New test: passing two diagnoses with no book state compiles but produces a warning or reduced verdict quality (documented behavior).

### 1.2 BookState is required, not optional

**What:** Introduce `BookState` as a non-optional parameter to `evaluateRetelling`. `BookState` carries:
- `sessionNumber`
- `readingProgress`
- `dimensionProfiles: [Dimension: DimensionProfile]` — running EWMA or fixed-window scores per dimension
- `recurringFindingSubjects: [Dimension: Set<String>]` — subjects that appeared in prior sessions

**Why:** The current comparison is amnesic. It sees only the previous two diagnoses. `BookState` gives it longitudinal awareness without ad-hoc optional parameters.

**Validation:**
- [ ] `BookState` is built from `BookEvent[]` after each session in `SessionViewModel.respond()`.
- [ ] `BookState` is persisted or recomputed on fetch. Decide and document the approach.
- [ ] New test: simulate 3 sessions with a finding that resolves in session 2 and reappears in session 3. Assert `evaluateRetelling` reports it as “recurring,” not “new.”

### 1.3 Composer receives the verdict as a required input

**What:** Replace `FeedbackComposing.compose(from:context:history:progress:)` with a mode-switched input:

```swift
enum ComposeInput {
    case firstTelling(FirstTellingInput)
    case retry(RetryInput)  // requires RetellingEvaluation
}

struct RetryInput {
    let diagnosis: Diagnosis
    let evaluation: RetellingEvaluation  // non-optional
    let context: TargetedContext?
}
```

**Why:** Right now `progress: RetellingProgress?` is optional. The model improvises when it’s nil. The type system should make “coach a retry without the verdict” impossible to express.

**Validation:**
- [ ] `OnDeviceComposer.compose()` signature changed. Compiler error on any call site that doesn’t provide `RetellingEvaluation` for retry mode.
- [ ] New test: `compose()` for retry mode includes `Verdict:`, `Resolved:`, `Persisted:`, `Introduced:` sections in the brief. Assert via mock or snapshot.
- [ ] New test: `TemplateComposer` fallback for retry mode includes the verdict label. Assert the string appears.

### 1.4 Finding matching uses identity + magnitude, not identity-only dictionary collapse

**What:** Replace the `Dictionary(uniquingKeysWith:)` pattern in `compare()` with proper grouping. For matched findings, compare magnitudes using a documented scale.

**Why:** Current code silently drops findings that share an identity within one diagnosis. And magnitude-aware matching with a bare `< 0.1` threshold is wrong for count-based magnitudes (stalls 5→3 has diff 2.0, not <0.1).

**Validation:**
- [ ] New test: two findings with the same `identity` in one diagnosis — assert both are preserved in the delta output.
- [ ] New test: finding with magnitude 5.0 in first, 3.0 in second, same identity — assert it is classified as “persisted but improved,” not “resolved.”
- [ ] Document the magnitude scale per rule type (rate vs. count vs. ratio) in `DiagnosticRule` or a central constants file.

### 1.5 Next challenge comes from evaluation, not composer

**What:** `RetellingEvaluation` includes `nextChallenge: Challenge`. The challenge text is derived from the deltas during `evaluateRetelling`, not written by the composer.

**Why:** The current code reuses the first telling’s challenge text forever. The user sees the same challenge after every retry.

**Validation:**
- [ ] New test: first telling has coherence as focus. Second telling resolves coherence but introduces delivery stalls. Assert `evaluation.nextChallenge.targetDimension == .delivery`.
- [ ] New test: `evaluation.nextChallenge.text` does not equal the original challenge when the focus dimension improved.
- [ ] `TellFlowView` reads the evolved challenge from `Assessment.evaluation.nextChallenge.text`, not from `Assessment.feedback.challenge`.

### 1.6 FeedbackView renders full per-dimension deltas

**What:** `FeedbackView` receives `Assessment.evaluation` and renders:
- Overall verdict
- Per-dimension before/after bands
- New problem areas
- Resolved / persisted / introduced for the focus dimension

**Why:** The current UI shows only the focus dimension’s changes. If the user improved coherence but introduced delivery problems, the regression is invisible.

**Validation:**
- [ ] Manual: complete a retry where the focus dimension improved and a non-focus dimension regressed. Assert both are visible in FeedbackView.
- [ ] Manual: assert the verdict symbol and label match `evaluation.verdict`.
- [ ] Accessibility: VoiceOver reads the verdict and dimension changes in logical order.

---

## Phase 2 — Book persistence (blocks book-aware features)

| # | Item | Owner | Status | Validation |
|---|---|---|---|---|
| 2.1 | `BookSession` SwiftData model runtime verified | Core | ⬜ | Create, fetch, update, delete a `BookSession` in a device run. Verify after force-quit + relaunch. |
| 2.2 | `BookEvent` append-only and queryable | Core | ⬜ | Append 20 events, assert fetch by `sessionNumber`, `kind`, `subject` returns correct subsets. |
| 2.3 | `EntityRecord` round-trips through SwiftData | Core | ⬜ | Update `mentionCount` and `emotionalAssociations`, save, refetch, assert values persisted. |
| 2.4 | `BookContext` protocol fully implemented | Core | ⬜ | Every method in `BookContext` protocol has a working implementation and at least one test. |
| 2.5 | Book picker refreshes after mutations | Features | ⬜ | Create a book, return to picker, assert it appears. Delete a book (if delete exists), assert it disappears. |
| 2.6 | `Assessment.bookID` is always populated | Shared | ⬜ | Run a session with a selected book, assert `assessment.bookID == book.bookID`. |
| 2.7 | `BookSession.shape` updates after first session | Core | ⬜ | Run first session, assert `book.shape == narrativeArc.shape`. |

### Validation protocol for Phase 2

Run on device:

1. Create a book named “Persistence Test”
2. Run a session with at least 3 beats and 2 entities
3. Assert in debugger or test: `book.events.count >= 3`, `book.entityRegistry.count >= 2`, `book.lastSessionNumber == 1`
4. Force-quit, relaunch
5. Assert book appears in picker with correct event count and entity count
6. Run a second session
7. Assert `book.lastSessionNumber == 2`, `book.events.count` grew, at least one entity `mentionCount >= 2`

---

## Phase 3 — Signal pipeline validation

These are device-only. The simulator cannot validate them.

| # | Item | Owner | Status | Validation |
|---|---|---|---|---|
| 3.1 | Speech transcription preserves word-level timings | Core | ⬜ | Read a scripted passage with known timing. Assert every word has non-nil `audioTimeRange` in the transcript. |
| 3.2 | Filled pauses survive transcription | Core | ⬜ | Read a script with 10 “um”/“uh” tokens. Assert `filledPauses.count >= 8` in `DeliverySignals`. |
| 3.3 | Prosody analyzer produces voiced frames | Core | ⬜ | Read for 30 seconds. Assert `timeline.prosody.filter { $0.pitch != nil }.count > 0`. |
| 3.4 | Pitch variation is non-zero for expressive speech | Core | ⬜ | Read the same passage monotone, then expressively. Assert `pitchVariation` is measurably higher in the expressive reading. |
| 3.5 | Audio buffers are not written to disk | Core | ⬜ | Run a session, assert `FileManager.default.contentsOfDirectory(at: documents)` contains no new `.caf` or audio files. |

### Validation protocol for Phase 3

Use `SignalProbeView` (currently in `Features/Diagnostics/`) as the test harness. Add a “validation mode” that runs a scripted transcript through the signal pipeline and asserts expected values.

Scripted audio can be generated by playing a known audio file through the speaker and capturing via `AVAudioEngine`, or by feeding `AudioChunk` buffers directly into `ProsodyAnalyzer` and `SpeechTranscription` in a unit test.

---

## Phase 4 — Error handling and recovery

| # | Item | Owner | Status | Validation |
|---|---|---|---|---|
| 4.1 | Transcription failure shows “I didn’t hear anything” | Features | ⬜ | Deny microphone permission, start session, assert user sees a specific error, not a crash or blank screen. |
| 4.2 | Foundation Models unavailable → template fallback | Core | ⬜ | Mock `SystemLanguageModel.default.availability = .unavailable`, run `OnDeviceComposer`, assert output is non-nil and contains findings. |
| 4.3 | Partial Pass A failure → degraded feedback | Core | ⬜ | Simulate 3 of 5 chunks failing, assert session completes, feedback notes the limitation or at least doesn’t crash. |
| 4.4 | SwiftData corruption → in-memory fallback | Core | ⬜ | Corrupt the model container, launch app, assert it runs with a prompt to reset, not a crash on launch. |
| 4.5 | Time-limit reached → session ends cleanly | Features | ⬜ | Run on device for 10 minutes, assert session ends within 60s of cap, assessment is produced, no memory leak. |

---

## Phase 5 — UI/UX and accessibility

| # | Item | Owner | Status | Validation |
|---|---|---|---|---|
| 5.1 | No tab bar during session | Features | ⬜ | Start a session, assert tab bar is hidden. End session, assert tab bar reappears. |
| 5.2 | “That’s it” button visible during listening | Features | ⬜ | Start a session, assert the end-session button is visible and tappable. |
| 5.3 | Back button disabled during listening | Features | ⬜ | Start a session, assert back button is disabled. |
| 5.4 | Feedback screen scrolls to evidence on tap | Features | ⬜ | Tap a finding in FeedbackView, assert transcript scrolls to the correct timestamp. |
| 5.5 | Dynamic Type supported | Features | ⬜ | Set system font size to Largest, assert all text is readable, no clipped labels. |
| 5.6 | VoiceOver reads feedback in logical order | Features | ⬜ | Enable VoiceOver, navigate FeedbackView, assert reading order: verdict → note → findings → challenge. |
| 5.7 | Reduced motion respected | Features | ⬜ | Enable Reduce Motion, assert `ListeningPresence` animation is reduced or removed, no crashes. |
| 5.8 | Challenge and retry buttons are clearly labeled | Features | ⬜ | Accessibility inspector audit: buttons have clear labels, traits are correct. |

---

## Phase 6 — Performance and battery

| # | Item | Owner | Status | Validation |
|---|---|---|---|---|
| 6.1 | Session CPU stays below 80% sustained | Core | ⬜ | Instruments → CPU Report during a 10-minute session on device. Assert no sustained spikes above 80%. |
| 6.2 | Memory does not grow unboundedly during session | Core | ⬜ | Instruments → Allocations during a 10-minute session. Assert heap growth plateaus after Pass A completes. |
| 6.3 | ListeningPresence redraw rate ≤ 15fps | Features | ⬜ | Instruments → Core Animation during session. Assert `ListeningPresence` canvas redraws at ≤ 15fps. |
| 6.4 | Battery impact: 30-min session < 10% drain | Core | ⬜ | Measure battery delta before/after a 30-min session on device, screen at 50% brightness. Assert < 10%. |
| 6.5 | `PerformanceProbe` records real metrics or is removed | Core | ⬜ | Assert `PerformanceProbe` either logs session duration, frame drops, and model latency, or the struct is deleted. |

---

## Phase 7 — Privacy and safety verification

| # | Item | Owner | Status | Validation |
|---|---|---|---|---|
| 7.1 | No audio files written to disk | Core | ⬜ | Run a session, assert `FileManager` shows no new audio files in Documents, Caches, or tmp. |
| 7.2 | Transcript is the only persisted session data | Core | ⬜ | Inspect `StoredRetelling` schema. Assert it contains `transcriptText`, `scoreData`, `wordCount`, `duration` — and no audio/video references. |
| 7.3 | `RecordingCleanup` removes legacy files | Core | ⬜ | Install a build with legacy `.caf` files in Documents. Launch app. Assert files are removed within 60 seconds. |
| 7.4 | No network calls during session | Core | ⬜ | Instruments → Network during a full session. Assert zero outgoing connections. |
| 7.5 | Privacy manifest is accurate | App | ⬜ | Review `PrivacyInfo.xcprivacy`. Assert it describes all data types (audio, on-device model) and their purposes. |

---

## Phase 8 — Device compatibility and launch

| # | Item | Owner | Status | Validation |
|---|---|---|---|---|
| 8.1 | Device eligibility check runs before capture | Core | ⬜ | Run on iPhone 14 Pro. Assert user sees “This iPhone can’t run on-device analysis” before any capture starts. |
| 8.2 | Apple Intelligence check runs before model use | Core | ⬜ | Disable Apple Intelligence in Settings, launch app, start session, assert user sees actionable error. |
| 8.3 | Speech model download UX is clear | Core | ⬜ | First launch on a clean device, assert user sees a “One moment” or equivalent state while the model downloads, and progress is communicated. |
| 8.4 | App launches in < 3 seconds on eligible device | App | ⬜ | Measure cold launch time on iPhone 15 Pro. Assert < 3 seconds to first frame. |
| 8.5 | `RecordingCleanup` does not block launch | App | ⬜ | Install 100 legacy `.caf` files. Launch app. Assert first frame appears within 3 seconds. |

---

## Phase 9 — Testing completeness

| # | Item | Owner | Status | Validation |
|---|---|---|---|---|
| 9.1 | Every rule has at least one test | Core | ⬜ | Count `DiagnosticRule` conformances, count test methods that exercise each. Ratio must be ≥ 1. |
| 9.2 | Feedback chain test passes end-to-end | Core | ⬜ | `FeedbackFlowTests` passes: transcript → chunks → beats → diagnosis → feedback, with model stubbed. |
| 9.3 | Retry loop test passes end-to-end | Core | ⬜ | New test: two synthetic sessions, `evaluateRetelling`, assert verdict, deltas, and nextChallenge are consistent. |
| 9.4 | Book persistence tests pass on device | Core | ⬜ | `BookPersistenceTests` runs on device, not just simulator. SwiftData behavior can differ. |
| 9.5 | Expression reader and baseline tests pass | Core | ⬜ | Existing `ExpressionReaderTests` and `ExpressionBaselineTests` pass on device with real coefficients. |
| 9.6 | Signal probe view validates real hardware | Features | ⬜ | Run `SignalProbeView` on 3+ device types. Assert transcription, prosody, and expression values are non-zero and plausible. |

---

## Tracker

Status key:
- ⬜ Not started
- 🔄 In progress
- ✅ Done
- 🚫 Blocked by another item

### Overall progress

| Phase | Total | Done | In Progress | Not Started | Blocked |
|---|---|---|---|---|---|
| 0 — Non-negotiables | 7 | 0 | 0 | 7 | 0 |
| 1 — Feedback engine | 6 | 0 | 0 | 6 | 0 |
| 2 — Book persistence | 7 | 0 | 0 | 7 | 0 |
| 3 — Signal pipeline | 5 | 0 | 0 | 5 | 0 |
| 4 — Error handling | 5 | 0 | 0 | 5 | 0 |
| 5 — UI/UX | 8 | 0 | 0 | 8 | 0 |
| 6 — Performance | 5 | 0 | 0 | 5 | 0 |
| 7 — Privacy | 5 | 0 | 0 | 5 | 0 |
| 8 — Compatibility | 5 | 0 | 0 | 5 | 0 |
| 9 — Testing | 6 | 0 | 0 | 6 | 0 |
| **Total** | **59** | **0** | **0** | **59** | **0** |

### Critical path

```
0.1 (stable IDs)
  → 0.2 (book receives events)
    → 0.3 (registry updates)
      → 2.1 (SwiftData verified)
        → 2.2 (events queryable)
          → 1.2 (BookState built from events)
            → 1.1 (evaluateRetelling with BookState)
              → 1.3 (composer receives verdict)
                → 1.4 (finding matching fixed)
                  → 1.5 (evolved challenge)
                    → 1.6 (FeedbackView renders deltas)
```

Nothing in Phase 1 can be fully validated until Phase 2 persistence works, because `BookState` depends on persisted events. Nothing in Phase 2 can be validated until Phase 0 identity bugs are fixed.

---

## What “ship ready” means

This app ships when:

1. A user can create a book, run a session, see honest feedback, retry, and see an evolved challenge — with no crashes, no blank screens, and no contradictions between the verdict and the coaching text.
2. All of the above survives a force-quit and relaunch.
3. All of the above runs on a real device, not just the simulator.
4. A reviewer can read this document, look at the tracker, and see every item marked ✅.

The architecture is sound. The math is sound. The wiring is not. This document is the wiring checklist.
