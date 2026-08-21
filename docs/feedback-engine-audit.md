# Feedback Engine Audit — Current State, Target, and Fix Plan

## Executive summary

The feedback engine is split into two parts: the **verdict engine** (decides whether the user improved) and the **composer** (phrases the verdict into words). The verdict engine is broken. The composer is mostly fine. Right now the app can produce coaching text, but it cannot honestly tell a user whether they improved or not — and it has no memory of the book beyond the immediately previous session.

This document is the honest version. No architecture theatre, just what the code does.

---

## 1. What we are trying to build

The user finishes a chapter, opens the app, and tells the story. The app listens. When they finish, it tells them one specific thing about how they told it — and points at the moment it means. Then it offers a challenge: tell it again, or tell it to a stranger.

The retry loop is the product’s whole promise: *“retell against this one thing.”* For that promise to be honest, the app must:

1. Remember what the first telling found
2. Compare the second telling against those exact findings
3. Decide whether the user improved, got closer, or didn’t make it
4. Phrase that verdict honestly — never congratulating them for something they didn’t do
5. Suggest the next challenge based on what is still weak, not what was already fixed

The architecture treats this like an agent with memory: every session appends to the book’s memory, and the verdict engine retrieves only what is relevant when comparing.

---

## 2. What the code actually does right now

### The happy path

```
Session completes
    ↓
RuleBasedDiagnosis.diagnose() → Diagnosis (findings, focus, bands)
    ↓
OnDeviceComposer.compose() → Feedback (note + challenge)
    ↓
Assessment is created with:
    - diagnosis
    - feedback
    - progress = RetellingComparison.compare(previous, current)
    ↓
FeedbackView renders the note, evidence, and verdict
```

### What compare() does

`RetellingComparison.compare()` in `Conteur/Core/Diagnosis/RetellingComparison.swift`:

- Takes two `Diagnosis` objects: the previous telling and the current one
- Matches findings by `identity` = `"\(dimension)/\(subject)"`
- Splits previous findings into:
  - `resolved` — present in previous, absent in current
  - `persisted` — present in both
  - `introduced` — present in current, absent in previous
- Computes a verdict:
  - `.met` — no persisted findings
  - `.closer` — persisted findings shrank by at least 10%
  - `.notYet` — everything else

The math is sound. The problem is what it doesn’t do.

### What the composer does

`OnDeviceComposer.compose()` in `Conteur/Core/Composition/OnDeviceComposer.swift`:

- Receives the diagnosis, optional `TargetedContext`, optional `history` (a `Band`), and optional `progress` (`RetellingProgress`)
- Builds a brief for the on-device model that includes:
  - Book title and mode
  - Entity history (up to 10 events)
  - Stakes event
  - Emotional history (up to 6 events)
  - Current findings
- The model writes 3–4 sentences and a challenge
- Falls back to `TemplateComposer` if the model is unavailable

The composer gets memory context. The verdict does not.

### What the retry loop does

`TellFlowView.retell()` in `Conteur/Features/Session/TellFlowView.swift`:

```swift
private func retell() {
    previous = current
    current = nil
    attempt += 1
    mode = .continuation
    stage = .telling
}
```

And the session builder passes the challenge:
```swift
let challenge: String? = mode == .continuation ? previous?.feedback?.challenge : nil
```

The challenge is whatever the **composer** wrote into the first feedback. It never changes. `RetellingComparison.nextChallenge()` exists in `RetellingComparison.swift` but is never called in production.

---

## 3. What is broken

### 3.1 The verdict is amnesic

`compare()` sees only two diagnoses. It does not know:
- What the book’s baseline is across chapters
- Which findings were resolved in session 1 but reopened in session 3
- Whether the user is trending up or down across the whole book

If the user:
- Session 1: dropped “the house” (finding: dropped thread)
- Session 2: fixed “the house” (verdict: met)
- Session 3: dropped “the brother” (verdict: notYet)

The verdict says `.notYet`. It does not say *“You fixed the house. The brother is new.”* The comparison has no longitudinal awareness.

**Root cause:** `compare()` takes only two `Diagnosis` objects. It has no access to `BookSession`, `BookEvent[]`, or `ReadingProgress`.

### 3.2 The verdict is not delivered to the composer

`OnDeviceComposer.brief()` includes the findings but not the verdict:

```swift
if let progress, progress.before != progress.after {
    lines.append("Previous progress:")
    lines.append("  Covered: \(progress.before.label) → \(progress.after.label)")
}
```

This is reading-progress band transitions, not the challenge verdict. The model is told:

> *“The verdict is already decided — never contradict it”*

But the model is never told what the verdict is.

**Root cause:** `RetellingProgress.verdict` is not passed to the composer brief.

### 3.3 The challenge never evolves

`nextChallenge(after:mode:)` in `RetellingComparison.swift` computes an evolved challenge based on the next weakest dimension. It is never called in production.

The user sees the same challenge text after every retry, even after meeting it. If the first challenge was about coherence and they fixed it, the second challenge is still “follow every thread you open through to its end.”

**Root cause:** `TellFlowView.retell()` does not compute a new challenge. It reuses `previous?.feedback?.challenge`.

### 3.4 Finding matching is brittle

`compare()` matches findings by `identity` only:

```swift
let afterByIdentity = Dictionary(
    after.map { ($0.identity, $0) },
    uniquingKeysWith: { first, _ in first }
)
```

Where `identity = "\(dimension.rawValue)/\(subject)"`.

This fails when:
- The same finding recurs with a different `subject` string (e.g., model output variation in Pass A changes which rule fires or how the entity is named)
- The finding’s `magnitude` changed but the `subject` stayed the same (e.g., stalls went from 5 to 3 — identity says “persisted,” magnitude says “improved”)

The codebase already has magnitude-aware matching in the `Array where Element == Finding` extension:

```swift
func persistedFindings(from previous: [Finding], in dimension: Dimension) -> [Finding]
func resolvedFindings(from previous: [Finding], in dimension: Dimension) -> [Finding]
```

These use `abs(currentFinding.magnitude - previousFinding.magnitude) < 0.1` to determine if a finding persisted or resolved. `compare()` does not use them.

**Root cause:** `compare()` was written with identity-only matching and the magnitude-aware helpers were added later but never wired in.

### 3.5 `AttemptComparison` is dead code

`AttemptComparison` is a rich per-dimension delta object:
- `deltas` — every dimension’s before/after scores and findings
- `overallVerdict` — the synthesis
- `newProblemAreas` — what got worse
- `primaryImprovement` — the challenge dimension’s delta

It is built by `attemptComparison(from:)`, tested in `ConteurTests/RetellingComparisonTests.swift`, and never called in production.

`FeedbackView` shows only the focus dimension’s `resolved/persisted/introduced` lists. If the user improved coherence but introduced delivery problems, the UI stays silent on the delivery regression.

**Root cause:** `SessionViewModel.respond()` calls `compare()` but never calls `attemptComparison(from:)`. `Assessment` has no field for `AttemptComparison`. `FeedbackView` does not render it.

### 3.6 The book context is not threaded into comparison

`EventEngine.targetedContext()` builds a `TargetedContext` with entity history, emotional history, stakes events, and component coverage. This is passed to the composer. It is never passed to the comparison.

The verdict engine is the only component in the feedback path that has no access to the book’s memory.

**Root cause:** `RetellingComparison.compare()` signature does not accept `BookSession`, `TargetedContext`, or `ReadingProgress`.

---

## 4. What the target looks like

### The memory-aware retry loop

```
Session completes
    ↓
Diagnosis produced (current session)
    ↓
RetellingComparison.compare(
    previousDiagnosis,
    currentDiagnosis,
    challenge,
    bookContext: TargetedContext?,        // ← NEW
    bookProgress: ReadingProgress?         // ← NEW
) → RetellingProgress

RetellingComparison.attemptComparison(
    previousDiagnosis,
    currentDiagnosis,
    challenge,
    mode
) → AttemptComparison

RetellingComparison.nextChallenge(
    after: AttemptComparison,
    mode: ChallengeMode,
    eligibleDimensions: [Dimension]        // ← filtered by bookProgress
) → evolvedChallenge
    ↓
Assessment created with:
    - diagnosis
    - feedback (composed with verdict + deltas in brief)
    - progress (RetellingProgress)
    - attemptComparison (AttemptComparison)
    - evolvedChallenge
    ↓
FeedbackView renders:
    - Verdict (from RetellingProgress)
    - Per-dimension deltas (from AttemptComparison)
    - New problem areas (from AttemptComparison)
    - Resolved / persisted / introduced (from RetellingProgress)
    - Evolved challenge
```

### The composer brief with verdict

```
Book: The Great Gatsby
Mode: continuation

Verdict: closer
Focus: coherence

Resolved:
  - brother was introduced at 2:14 and never came up again

Persisted:
  - stalls (5 → 3, closer but not gone)

Introduced:
  - fillers (4 across 120 words)

Current findings:
  - Dimension: coherence
  - Band: developing
  - Score: 0.6
  - 1 filler pause at 3:22
```

The model phrases this. It does not decide it.

---

## 5. The fix plan

### Priority 1: Wire the verdict into the composer brief

**File:** `Conteur/Core/Composition/OnDeviceComposer.swift`

In `brief()`, include the verdict and finding deltas:

```swift
if let progress {
    lines.append("Verdict: \(progress.verdict.label)")
    lines.append("Focus: \(progress.focus.title)")
    
    if !progress.resolved.isEmpty {
        lines.append("Resolved:")
        progress.resolved.forEach { lines.append("  - \($0.observation)") }
    }
    if !progress.persisted.isEmpty {
        lines.append("Persisted:")
        progress.persisted.forEach { lines.append("  - \($0.observation)") }
    }
    if !progress.introduced.isEmpty {
        lines.append("Introduced:")
        progress.introduced.forEach { lines.append("  - \($0.observation)") }
    }
}
```

**Why first:** This is a one-file change that fixes the most damaging behavior — the model contradicting the verdict. It takes 20 minutes and eliminates the worst user-facing bug.

### Priority 2: Wire `AttemptComparison` into the production path

**Files:**
- `Conteur/Features/Session/SessionViewModel.swift`
- `Conteur/Shared/Assessment.swift`
- `Conteur/Features/Feedback/FeedbackView.swift`

In `SessionViewModel.respond()`:

```swift
let progress = previous.flatMap { first in
    challenge.flatMap { comparison.compare(first, with: diagnosis, challenge: $0) }
}

let attemptComparison = previous.flatMap { first in
    challenge.flatMap {
        comparison.attemptComparison(
            from: RetellingComparisonInput(
                first: first,
                second: diagnosis,
                challenge: $0,
                mode: .continuation
            )
        )
    }
}
```

Add `attemptComparison` to `Assessment`. Pass it to `FeedbackView`.

In `FeedbackView`, render a “What changed across all dimensions” section:
- Per-dimension before/after bands
- New problem areas highlighted
- Overall verdict

**Why second:** This fixes the “only the focus dimension is shown” problem. The data structure already exists and is tested. It just needs to be plumbed through.

### Priority 3: Call `nextChallenge()` and store the evolved challenge

**File:** `Conteur/Features/Session/TellFlowView.swift`

In `retell()`:

```swift
private func retell() {
    previous = current
    current = nil
    attempt += 1
    mode = .continuation
    
    // Compute evolved challenge from the comparison
    if let previous = previous,
       let previousChallenge = previous.feedback?.challenge,
       let comparison = RetellingComparison() {
        
        let input = RetellingComparisonInput(
            first: previous.diagnosis,
            second: previous.diagnosis, // placeholder; actual second is the new session
            challenge: previousChallenge,
            mode: .continuation
        )
        
        // The evolved challenge is computed after the new session completes.
        // Store the comparison input so respond() can finish the loop.
        comparisonInput = input
    }
    
    stage = .telling
}
```

Actually, the cleaner approach: compute `nextChallenge` in `SessionViewModel.respond()` after the comparison, and store it in `Assessment.challenge` (add a field). `TellFlowView` then reads the evolved challenge from the new `Assessment`.

**Why third:** This fixes the frozen-challenge problem. It depends on Priority 2 because `nextChallenge()` needs `AttemptComparison`.

### Priority 4: Make `compare()` memory-aware

**File:** `Conteur/Core/Diagnosis/RetellingComparison.swift`

Change the signature:

```swift
func compare(
    _ first: Diagnosis,
    with second: Diagnosis,
    challenge: String,
    bookProgress: ReadingProgress? = nil,
    bookBaseline: Baseline? = nil
) -> RetellingProgress
```

Use `bookBaseline` to adjust the verdict:

```swift
private func verdict(
    before: [Finding],
    persisted: [Finding],
    bookBaseline: Baseline?
) -> ChallengeVerdict {
    guard !persisted.isEmpty else { return .met }
    
    let was = before.reduce(0) { $0 + $1.magnitude }
    let now = persisted.reduce(0) { $0 + $1.magnitude }
    
    guard was > 0 else { return .notYet }
    
    // Improvement against the previous telling
    let previousImprovement = (was - now) / was
    
    // If no improvement against previous, check against book baseline
    if previousImprovement >= Self.meaningfulImprovement {
        return .closer
    }
    
    // TODO: compare current score against bookBaseline for the dimension
    
    return .notYet
}
```

The book-baseline comparison requires adding per-dimension baseline access to `Baseline` and threading `ReadingProgress` from `BookSession.progress` into the comparison call site.

**Why fourth:** This is the agent-memory upgrade. It depends on the book persistence fixes from the earlier audit (#1, #2 in the critical section) because `bookProgress` and `bookBaseline` require working SwiftData.

### Priority 5: Fix finding matching in `compare()`

**File:** `Conteur/Core/Diagnosis/RetellingComparison.swift`

Replace identity-only matching with magnitude-aware matching:

```swift
private func delta(for dimension: Dimension?, first: Diagnosis, second: Diagnosis) -> DimensionDelta {
    guard let dimension else { return DimensionDelta(...) }
    
    let beforeAssessment = first.assessment(for: dimension)
    let afterAssessment = second.assessment(for: dimension)
    let before = beforeAssessment?.findings ?? []
    let after = afterAssessment?.findings ?? []
    
    // Use magnitude-aware matching, not identity-only
    let persisted = before.persistedFindings(from: after, in: dimension)
    let resolved = before.resolvedFindings(from: after, in: dimension)
    let introduced = after.newFindings(comparedTo: before, in: dimension)
    
    // ... rest unchanged
}
```

Wait — the extension methods are defined on `Array where Element == Finding` but they take `from previous: [Finding]`, which means the receiver is the *current* findings and `previous` is the *old* findings. Let me verify the signatures:

```swift
func persistedFindings(from previous: [Finding], in dimension: Dimension) -> [Finding] {
    self.filter { currentFinding in
        previous.contains { previousFinding in
            currentFinding.subject == previousFinding.subject &&
            currentFinding.dimension == dimension &&
            abs(currentFinding.magnitude - previousFinding.magnitude) < 0.1
        }
    }
}
```

So `current.persistedFindings(from: previous, in: dimension)` returns findings that exist in both. That is correct. The existing `compare()` method should use these instead of the identity dictionary.

**Why fifth:** This makes the verdict more accurate for graded findings. It depends on Priority 2 because the `delta()` method is called from `attemptComparison()`.

---

## 6. The file map

| File | Current role | Problem |
|---|---|---|
| `Conteur/Core/Diagnosis/RetellingComparison.swift` | Verdict engine | Amnesic, no book context, identity-only matching |
| `Conteur/Core/Composition/OnDeviceComposer.swift` | Coaching text | Does not receive the verdict |
| `Conteur/Core/Composition/Feedback.swift` | Types | `Feedback` lacks `challenge` from comparison |
| `Conteur/Shared/Assessment.swift` | Session result | Lacks `AttemptComparison` and evolved challenge |
| `Conteur/Features/Session/SessionViewModel.swift` | Session owner | Calls `compare()` but never `attemptComparison()` or `nextChallenge()` |
| `Conteur/Features/Session/TellFlowView.swift` | Flow controller | Reuses frozen challenge from first feedback |
| `Conteur/Features/Feedback/FeedbackView.swift` | UI | Shows only focus dimension, not full deltas |
| `Conteur/Core/Book/EventEngine.swift` | Memory layer | Builds `TargetedContext` but it is not passed to comparison |
| `Conteur/Core/Book/BookModels.swift` | Data | Book persistence broken (events not linked to selected book) |

---

## 7. What “done” looks like

The retry loop is honest when:
1. The verdict matches the actual finding deltas — not a guess by the model
2. The composer never contradicts the verdict because it was given the verdict
3. The challenge evolves as the user improves, targeting the next weakest dimension
4. The user can see all dimension changes, not just the focus dimension
5. The comparison knows what the book already established, so it doesn’t challenge the user to fix something already covered

The current code gets #1 partially right (the math is correct) and fails at #2–#5.

---

## 8. The one-page fix order

| Order | Change | Files | Effort |
|---|---|---|---|
| 1 | Pass verdict + deltas into composer brief | `OnDeviceComposer.swift` | 20 min |
| 2 | Call `attemptComparison()` and store in `Assessment` | `SessionViewModel.swift`, `Assessment.swift` | 1 hour |
| 3 | Wire `AttemptComparison` into `FeedbackView` | `FeedbackView.swift` | 1 hour |
| 4 | Call `nextChallenge()` after each session | `SessionViewModel.swift`, `TellFlowView.swift` | 1 hour |
| 5 | Make `compare()` accept book context | `RetellingComparison.swift`, `SessionViewModel.swift` | 2 hours |
| 6 | Fix book persistence (events + registry) | `BookContext.swift`, `SessionViewModel.swift` | 2 hours |

Total: roughly half a day of focused work. The architecture is right. The math is right. The wiring is wrong.
