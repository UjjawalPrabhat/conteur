# Conteur — Production Architecture Plan (On-Device Only)

## 1. Product principle

The app coaches storytelling. Every technical decision should serve that goal.

The app must:
- judge only what it can verify
- degrade gracefully when components fail
- keep all personal data on-device
- work fully offline with no network dependency

---

## 2. System overview

```
┌──────────────────────────────────────────────────────────┐
│                    USER DEVICE                            │
│                                                          │
│  ┌─────────────┐                            ┌───────────┐ │
│  │   Audio     │                            │   Local   │ │
│  │   Capture   │                            │   Store   │ │
│  └──────┬──────┘                            │ (SwiftData)│ │
│         │                                   └──────┬──────┘ │
│         ▼                                          │        │
│  ┌─────────────────────────────────────────────────────┐ │
│  │              ON-DEVICE PIPELINE                     │ │
│  │  ┌─────────────┐  ┌──────────────┐                 │ │
│  │  │  Prosody    │  │   Pass A     │                 │ │
│  │  │  Analyzer   │  │  (Foundation │                 │ │
│  │  │  (existing) │  │   Models)    │                 │ │
│  │  └──────┬──────┘  └──────┬──────┘                 │ │
│  │         │                │                         │ │
│  │         ▼                ▼                         │ │
│  │  ┌─────────────────────────────────────────────────┐│ │
│  │  │          Entity Resolution Pass                 ││ │
│  │  │   (intra-session, Swift-only, no model calls)   ││ │
│  │  └────────────────────────┬────────────────────────┘│ │
│  │                           │                         │ │
│  │         ┌─────────────────┼─────────────────┐       │ │
│  │         ▼                 ▼                 ▼       │ │
│  │  ┌─────────────┐  ┌──────────────┐  ┌───────────┐  │ │
│  │  │   On-Device │  │  Event       │  │  Session   │  │ │
│  │  │   Rules     │  │  Engine      │  │  Summary   │  │ │
│  │  │ (delivery,  │  │ (entities,   │  │  Builder   │  │ │
│  │  │  coherence, │  │  components, │  │            │  │ │
│  │  │  relevance, │  │  stakes)     │  │            │  │ │
│  │  │  structure) │  │              │  │            │  │ │
│  │  └──────┬──────┘  └──────┬──────┘  └─────┬─────┘  │ │
│  │         │                │                │        │ │
│  │         ▼                ▼                │        │ │
│  │  ┌─────────────────────────────────────────────────┐│ │
│  │  │         Targeted Context Retrieval              ││ │
│  │  │   (app logic selects relevant prior events)     ││ │
│  │  └────────────────────────┬────────────────────────┘│ │
│  │                           │                         │ │
│  │                           ▼                         │ │
│  │  ┌─────────────────────────────────────────────────┐│ │
│  │  │         Offline Coaching Generation             ││ │
│  │  │   (Foundation Models reads context + findings   ││ │
│  │  │    → coaching text, no conversation)            ││ │
│  │  └────────────────────────┬────────────────────────┘│ │
│  └───────────────────────────┼────────────────────────┘ │
│                              │                          │
│                              ▼                          │
│  ┌─────────────────────────────────────────────────────┐ │
│  │                    FEEDBACK SCREEN                   │ │
│  │   coaching, evidence, challenge, transcript, raw    │ │
│  └─────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

No cloud. No network. No merge logic. All processing on-device.

Audio is the only signal source. No video is captured or analyzed.

---

## 3. Device constraints

- iPhone 15 Pro or newer
- iOS 26 with Apple Intelligence enabled
- On-device speech model required
- Nothing but tests runs in the simulator

---

## 4. Session lifecycle

### 4.1 Session start

```
User opens app
    ↓
Load last active BookSession (or show book picker)
    ↓
User selects existing book or creates new one
    ↓
Pre-session:
  - Request microphone permission if needed
  - Load entity registry and recent events
  - Warm up on-device models
```

### 4.2 Recording and processing

```
Audio in
    ↓
Pass A: Foundation Models labels chunks → beats
  - Extended fields: entityGrounding (new/carried/ambiguous)
    ↓
Intra-session entity resolution pass (Swift-only)
  - Reclassify entities already seen in this session
  - Pronouns → referenced
    ↓
Delivery analysis (existing)
  - WPM, fillers, stalls, restarts
    ↓
Event production
  - Entity events from resolved beats
  - Component coverage events from arc analysis
  - Stakes events from beats
    ↓
Entity registry update
  - New entities → records created
  - Referenced entities → mention count + last session updated
```

### 4.3 Diagnosis and coaching

```
On-device rules evaluate:
  - Delivery (always on-device)
  - Coherence (causal density, dropped threads)
  - Relevance (always on-device)
  - Structure (coveredComponents vs expected)
  - Engagement (stakes presence)
    ↓
Targeted context retrieval
  - App logic selects relevant events from book log
  - Fetches entity history, coverage gaps, stakes context
  - Caps at 20 events, 200 tokens per description
    ↓
Offline coaching generation
  - Foundation Models reads targeted context + findings
  - Produces coaching text in a single request
  - No conversation history, no multi-turn
    ↓
Save session
  - Updated ReadingProgress → BookSession
  - Events appended to book log
  - Entity registry updated
  - Session summary stored
    ↓
Feedback screen
  - Composed coaching (primary finding)
  - All raw findings, signals, beats, evidence
  - Challenge prompt
```

---

## 5. Data model

### 5.1 BookSession

The central persistence object. One per book being retold.

```swift
@Model
final class BookSession {
    var id: UUID
    var title: String
    var shape: StoryShape          // .plotDriven, .thematic, .episodic, etc.
    var startedAt: Date
    var lastSessionNumber: Int

    @Relationship(deleteRule: .cascade, inverse: \BookEvent.book)
    var events: [BookEvent]

    var entityRegistry: [EntityRecord]
    var readingProgress: ReadingProgress
}
```

### 5.2 BookEvent

Immutable append-only log of what happened in a session.

```swift
@Model
final class BookEvent {
    var id: UUID
    var sessionNumber: Int
    var timestamp: TimeInterval
    var kind: EventKind           // entityIntroduced, entityReferenced, etc.
    var subject: String
    var detailText: String
    var evidenceStart: TimeInterval?

    @Relationship(inverse: \BookSession.events)
    var book: BookSession?
}
```

Event kinds:
- `entityIntroduced`
- `entityReferenced`
- `componentCovered`
- `stakesStated`

### 5.3 EntityRecord

Tracks entities across sessions.

```swift
struct EntityRecord: Sendable, Codable, Hashable {
    let id: UUID
    var name: String
    var introducedInSession: Int
    var firstAppearanceDescription: String
    var lastMentionedSession: Int
    var mentionCount: Int
    var emotionalAssociations: [EmotionAssociation]
}
```

### 5.4 Session summary

The session summary captures what changed for book-level context:

```swift
struct SessionSummary: Sendable, Codable, Hashable {
    let sessionNumber: Int
    let recordedAt: Date
    let focusDimension: Dimension?
    let verdictLabel: String?
    let note: String
}
```

This is used by `TargetedContext` to provide recent coaching history to the composer.

### 5.5 Coaching constraints

Foundation Models is used for a single bounded task: phrasing findings into coaching text. It does not decide what to say.

Rules:
- Coaching text is 3–4 sentences
- Every claim must trace back to a finding or event
- The model must not invent scenes, characters, or emotions not in the transcript
- No conversation memory — each request is stateless
- Generation uses greedy sampling for reproducibility

---

## 6. Event system

### 6.1 Event production (per session)

After each session, the engine produces events from on-device model output and rule output:

**Source 1: On-device model output (Pass A)**
- Entity introduced → `entityIntroduced` event
- Entity referenced → `entityReferenced` event
- Component covered (from arc) → `componentCovered` event
- Stakes stated → `stakesStated` event

**Source 2: Rule output**
- Component judgment → `componentCovered` event

Events are immutable. Appended to book log. Never modified after creation.

### 6.2 Targeted context retrieval

Before coaching generation, app logic selects relevant context:

```swift
func relevantContext(
    for retelling: RetellingContext,
    in book: BookSession
) -> TargetedContext {

    let mentioned = retelling.beats.flatMap(\.entitiesReferenced)
    let presentComponents = retelling.arc.present
    let missingComponents = book.currentProgress.coveredComponents.subtracting(presentComponents)
    let hasStakes = retelling.beats.contains(where: \.statesStakes)

    return TargetedContext(
        bookTitle: book.title,
        evaluationMode: retelling.mode,
        entityEvents: book.events
            .matching(kinds: [.entityIntroduced, .entityReferenced])
            .matching(subjects: mentioned)
            .sorted(by: \.timestamp)
            .limit(10),
        componentEvents: book.events
            .matching(kind: .componentCovered)
            .matching(subjects: missingComponents.map(\.rawValue)),
        stakesEvent: hasStakes
            ? book.events.mostRecent(kind: .stakesStated).first
            : nil,
        emotionalHistory: nil  // removed — no expression/emotion analysis
    )
}
```

### 6.3 Entity registry update

After each session:
```swift
func updateEntityRegistry(from session: SessionSnapshot, into book: inout BookSession) {
    for beat in session.beats {
        for entity in beat.entitiesIntroduced {
            if book.entityRegistry[entity] == nil {
                book.entityRegistry[entity] = EntityRecord(
                    id: UUID(),
                    name: entity,
                    introducedInSession: session.number,
                    firstAppearanceDescription: beat.summary,
                    lastMentionedSession: session.number,
                    mentionCount: 1,
                    emotionalAssociations: []
                )
            }
        }
        for entity in beat.entitiesReferenced {
            if var record = book.entityRegistry[entity] {
                record.lastMentionedSession = session.number
                record.mentionCount += 1
                book.entityRegistry[entity] = record
            }
        }
    }
}
```

---

## 7. Scope and exclusions

### 7.1 What is NOT in this plan

- No PCC request/response types
- No merge logic between on-device and cloud findings
- No `EvaluationSource` tagging per finding
- No network dependency
- No timeout handling for cloud calls
- No graceful degradation for cloud failures
- No transient cloud requests
- No video capture or face analysis

### 7.2 Data residency

| Data | Location | Exits device |
|------|----------|-------------|
| Audio | On-device only | Never |
| Transcript | On-device only | Never |
| Beats/labels | On-device only | Never |
| Book context | SwiftData | Never |
| Events | SwiftData | Never |
| Entity registry | SwiftData | Never |
| Coaching generation | On-device only | Never |

---

## 8. What the user sees

### First session

```
Open app → no book
    ↓
Create book
    ↓
Tell the story
    ↓
Feedback: "You established the house and the brother, but the brother never came back. Next time, follow every thread you open through to its end."
```

### Second session (retry)

```
Open app → select same book
    ↓
Tell the story again
    ↓
Feedback: "Closer. The house came back, and you spent more time on the brother. You still dropped one thread — the city. Next time, follow every thread."
```

### Standalone session

```
Open app → select book
    ↓
Tell the story
    ↓
Feedback: same shape as first session, no comparison
```

---

## 9. Success criteria

This plan is complete when:

1. A user can retell a book, receive coaching, retry, and see an evolved challenge
2. The challenge targets the next weakest area, not the already-met one
3. The coaching text never contradicts the verdict
4. All data survives force-quit and relaunch
5. The app runs fully offline with no recorded media
6. Every item in `docs/production-readiness.md` is marked ✅

---

## 10. Open questions

1. **Voice emotion classification:** Audio-only delivery signals (WPM, pitch variation, stalls) are sufficient for the current feedback dimensions. Voice emotion classification is not required. If added later, it should be modeled as an optional signal source, not a dependency.
2. **PCC integration:** If Apple adds Private Cloud Compute support for Foundation Models, the architecture can be extended with a remote evaluation path. This plan does not preclude that, but it does not require it.
3. **Context window limits:** Foundation Models' context window determines how much book history can be included in coaching prompts. Monitor as the event log grows. If needed, compress older events into rolling summaries.

---

## 11. Implementation order

### Phase 1: Data layer (foundation)
- [ ] `BookSession` SwiftData model with relationships
- [ ] `BookEvent` SwiftData model with indexes
- [ ] `EntityRecord` SwiftData model
- [ ] Book selection and creation UI
- [ ] Session startup: load BookSession, inject ReadingProgress

### Phase 2: On-device enhancements
- [ ] Extend `BeatDraft` with `entityGrounding`
- [ ] Update Pass A prompt with new instructions
- [ ] Entity resolution pass + reconciliation with `entityGrounding`
- [ ] Enhanced `DroppedThreadRule` with quality thresholds

### Phase 3: Event system
- [ ] Event production from Pass A output
- [ ] Entity registry update logic
- [ ] Targeted context retrieval logic
- [ ] Event storage and indexing

### Phase 4: Offline coaching
- [ ] `OnDeviceComposer` with targeted context injection
- [ ] Coaching prompt design for cross-session context
- [ ] Context cap enforcement and monitoring
- [ ] Fallback to `TemplateComposer` when model unavailable

### Phase 5: Challenge and retry
- [ ] Challenge mode UI (retry vs standalone)
- [ ] Challenge mode branching in `TellFlowView`
- [ ] `AttemptComparison` and `DimensionDelta` types
- [ ] Finding matching across attempts
- [ ] Verdict computation (met/closer/notYet)
- [ ] Next challenge suggestion logic
- [ ] Full diagnostic UI (all raw data visible)

### Phase 6: Polish
- [ ] Context cap enforcement and monitoring
- [ ] Battery and performance profiling
- [ ] Error logging and crash reporting (internal only)

---

## 12. Failure modes and fallbacks

| Component | Failure mode | Fallback |
|-----------|-------------|----------|
| Foundation Models | Unavailable or slow | Skip coaching text, use template composer |
| Speech model | Fails to download or initialize | Show "One moment" / retry prompt, no analysis |
| SwiftData | Corruption or migration failure | In-memory session, prompt user to re-create book |
| VAD | No speech detected | Show "I didn't hear anything" before processing |
| Network | Not applicable | Not applicable — app works fully offline |

---

## 13. Testing strategy

- Unit tests for every rule, composer, and event producer
- Device-only manual validation for capture, transcription, and model behavior
- `SignalProbeView` as a runtime diagnostic surface during development
- Regression tests for book persistence and retry loop after every change

---

## 14. Retry and comparison logic

### 14.1 Evaluation types

```swift
struct RetellingEvaluation {
    let verdict: ChallengeVerdict
    let deltas: [Dimension: DimensionDelta]
    let focusDelta: DimensionDelta
    let resolved: [Finding]
    let persisted: [Finding]
    let introduced: [Finding]
    let newProblemAreas: [Dimension]
    let nextChallenge: Challenge
}

struct Challenge {
    let text: String
    let targetDimension: Dimension?
    let mode: ChallengeMode
}
```

### 14.2 Single entry point

`evaluateRetelling(first:second:challenge:bookState:)` is the only function that computes verdict, deltas, and next challenge. No other path computes these independently.

### 14.3 BookState as required input

`BookState` is non-optional. It carries per-dimension running statistics and recurring finding subjects. Built from `BookEvent[]` after each session.

### 14.4 Finding matching across attempts

Findings are matched by `subject` + `dimension`, not by timestamp. Timestamps don't carry across attempts because the user speaks at different speeds.

```swift
extension Array where Element == Finding {
    func resolvedFindings(from previous: [Finding], in dimension: Dimension) -> [Finding] {
        previous.filter { previousFinding in
            !self.contains { currentFinding in
                currentFinding.subject == previousFinding.subject &&
                currentFinding.dimension == dimension &&
                abs(currentFinding.magnitude - previousFinding.magnitude) < 0.1
            }
        }
    }

    func persistedFindings(from previous: [Finding], in dimension: Dimension) -> [Finding] {
        self.filter { currentFinding in
            previous.contains { previousFinding in
                currentFinding.subject == previousFinding.subject &&
                currentFinding.dimension == dimension &&
                abs(currentFinding.magnitude - previousFinding.magnitude) < 0.1
            }
        }
    }

    func newFindings(comparedTo previous: [Finding], in dimension: Dimension) -> [Finding] {
        self.filter { currentFinding in
            !previous.contains { previousFinding in
                currentFinding.subject == previousFinding.subject &&
                currentFinding.dimension == dimension
            }
        }
    }
}
```

### 14.5 Verdict computation

```swift
private func verdict(
    before: [Finding],
    persisted: [Finding],
    newProblemAreas: [Dimension]
) -> ChallengeVerdict {
    guard !persisted.isEmpty else { return .met }

    let was = before.reduce(0) { $0 + $1.magnitude }
    let now = persisted.reduce(0) { $0 + $1.magnitude }
    guard was > 0 else { return .notYet }

    let improvement = (was - now) / was
    if improvement >= Self.meaningfulImprovement {
        return .closer
    }

    return .notYet
}
```

### 14.6 Next challenge selection

```swift
func nextChallenge(
    after evaluation: RetellingEvaluation,
    mode: ChallengeMode
) -> Challenge {
    if mode == .standalone {
        return Challenge(
            text: genericChallenge(for: evaluation.focusDelta.dimension),
            targetDimension: evaluation.focusDelta.dimension,
            mode: .standalone
        )
    }

    // Continuation: target the next weakest area, excluding new problems
    let eligible = evaluation.deltas.values
        .filter { delta in
            delta.dimension != evaluation.focusDelta.dimension &&
            !evaluation.newProblemAreas.contains(delta.dimension)
        }
        .sorted { $0.afterScore < $1.afterScore }

    guard let target = eligible.first else {
        return Challenge(
            text: "Tell it to a stranger who hasn’t read the book.",
            targetDimension: nil,
            mode: .continuation
        )
    }

    return Challenge(
        text: specificChallenge(for: target.dimension),
        targetDimension: target.dimension,
        mode: .continuation
    )
}
```

### 14.7 Composer contract

The composer never decides the verdict. It phrases what the evaluation decided.

```swift
enum ComposeInput {
    case firstTelling(FirstTellingInput)
    case retry(RetryInput)
}

struct RetryInput {
    let diagnosis: Diagnosis
    let evaluation: RetellingEvaluation
    let context: TargetedContext?
}
```

In retry mode, `evaluation` is non-optional. The compiler enforces that coaching a retry without the verdict is impossible.

### 14.8 UI contract

`FeedbackView` renders from `Assessment.evaluation`:

- Overall verdict symbol and label
- Per-dimension before/after bands
- New problem areas
- Resolved / persisted / introduced for the focus dimension
- Evolved challenge from `evaluation.nextChallenge`

There is no “focus dimension only” carve-out. The evaluation contains all dimensions, and the UI renders what it receives.

### 14.9 What this plan does NOT include

- Ebook or audiobook import
- ISBN lookup or metadata fetching
- Social sharing or multi-user features
- Subscription or cloud sync
- Watch companion app
- Custom model training pipeline
- Video capture or expression-based emotion analysis

These are product decisions, not architecture decisions. The architecture supports them but does not require them.
