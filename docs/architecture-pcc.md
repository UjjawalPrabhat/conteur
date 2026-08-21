# Conteur — Production Architecture Plan (Private Cloud Compute)

## 1. Product principle

The app coaches storytelling. Every technical decision should serve that goal.

The app must:
- judge only what it can verify
- degrade gracefully when components fail
- keep all personal data on-device unless the user opts in
- treat cloud compute as a function, not a memory

---

## 2. System overview

```
┌──────────────────────────────────────────────────────────┐
│                    USER DEVICE                            │
│                                                          │
│  ┌─────────────┐    ┌──────────────┐    ┌─────────────┐ │
│  │   Audio     │    │   Camera     │    │   Local     │ │
│  │   Capture   │    │   (optional) │    │   Store     │ │
│  └──────┬──────┘    └──────┬──────┘    │  (SwiftData)│ │
│         │                  │             └──────┬──────┘ │
│         ▼                  ▼                    │        │
│  ┌─────────────────────────────────────────────────────┐ │
│  │              ON-DEVICE PIPELINE                     │ │
│  │  ┌─────────────┐  ┌──────────────┐  ┌───────────┐  │ │
│  │  │  Prosody    │  │   Pass A     │  │  Emotion  │  │ │
│  │  │  Analyzer   │  │  (Foundation │  │  Class.   │  │ │
│  │  │  (existing) │  │   Models)    │  │  (CoreML) │  │ │
│  │  └──────┬──────┘  └──────┬──────┘  └─────┬─────┘  │ │
│  │         │                │                │        │ │
│  │         ▼                ▼                ▼        │ │
│  │  ┌─────────────────────────────────────────────────┐│ │
│  │  │          Entity Resolution Pass                 ││ │
│  │  │   (intra-session, Swift-only, no model calls)   ││ │
│  │  └────────────────────────┬────────────────────────┘│ │
│  │                           │                         │ │
│  │         ┌─────────────────┼─────────────────┐       │ │
│  │         ▼                 ▼                 ▼       │ │
│  │  ┌─────────────┐  ┌──────────────┐  ┌───────────┐  │ │
│  │  │   On-Device │  │   Emotion    │  │  Event    │  │ │
│  │  │   Rules     │  │  Evaluator   │  │  Engine   │  │ │
│  │  │ (delivery,  │  │  (expected   │  │ (entities,│  │ │
│  │  │  coherence, │  │   vs actual) │  │ emotions, │  │ │
│  │  │  relevance) │  │              │  │  tracks)  │  │ │
│  │  └──────┬──────┘  └──────┬──────┘  └─────┬─────┘  │ │
│  │         │                │                │        │ │
│  │         ▼                ▼                ▼        │ │
│  │  ┌─────────────────────────────────────────────────┐│ │
│  │  │         Targeted Context Retrieval              ││ │
│  │  │   (app logic decides what prior context to send)││ │
│  └──┼─────────────────────────────────────────────────┼┘ │
│     │                                                  │   │
│     ▼                                                  │   │
│  ┌─────────────┐                             ┌──────────┘   │
│  │   PCC       │   (optional, if available)  │             │
│  │   Request   │ ──────────────────────────►│             │
│  │ (standalone, │                             │             │
│  │  stateless)  │   ┌─────────────┐          │             │
│  └─────────────┘   │   PCC        │          │             │
│                    │  Response    │          │             │
│                    │ (diagnosis,  │─────────►│             │
│                    │  coaching)   │          │             │
│                    └─────────────┘           │             │
│                                                 ▼             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                    DIAGNOSIS MERGE                       │ │
│  │   on-device findings + PCC findings → unified output     │ │
│  └──────────────────────────┬──────────────────────────────┘ │
│                             │                               │
│                             ▼                               │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                      FEEDBACK SCREEN                     │ │
│  │   coaching, evidence, challenge, transcript, all raw    │ │
│  └─────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

---

## 3. Data model

### 3.1 BookSession

```swift
struct BookSession: Identifiable, Sendable, Codable {
    let id: UUID
    var title: String
    var shape: StoryShape
    var startedAt: Date
    var lastSessionNumber: Int
    var currentProgress: ReadingProgress
    var events: [BookEvent]
    var entityRegistry: [EntityRecord]
    var recentSummaries: [SessionSummary]
}
```

### 3.2 ReadingProgress

```swift
struct ReadingProgress: Sendable, Codable {
    var previousSessions: Int
    var coveredComponents: Set<StoryComponent>
    var knownEntities: Set<String>
    var stakesEstablished: Bool
}
```

### 3.3 BookEvent (immutable, append-only)

```swift
struct BookEvent: Identifiable, Sendable, Codable {
    let id: UUID
    let sessionNumber: Int
    let timestamp: TimeInterval
    let kind: EventKind
    let subject: String
    let description: String
    let evidenceStart: TimeInterval?
}

enum EventKind: String, Sendable, Codable {
    case entityIntroduced
    case entityReferenced
    case componentCovered
    case stakesStated
    case emotionalMatch
    case emotionalMismatch
    case emotionalAdjacent
}
```

### 3.4 EntityRecord

```swift
struct EntityRecord: Identifiable, Sendable, Codable {
    let id: UUID
    let name: String
    let introducedInSession: Int
    let firstAppearanceDescription: String
    var lastMentionedSession: Int
    var mentionCount: Int
    var emotionalAssociations: [EmotionAssociation]
}

struct EmotionAssociation: Sendable, Codable {
    let session: Int
    let emotion: DetectedEmotion
    let context: String
}
```

### 3.5 Persistence

- Storage: SwiftData (on-device, sandboxed)
- Indexes: `sessionNumber`, `kind`, `subject` on `BookEvent`
- Relationships: `BookSession` → `events` (cascade delete)
- No cloud sync. No network persistence.

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
  - Request camera permission (optional, deferred)
  - Load entity registry and recent events
  - Warm up on-device models
```

### 4.2 Recording and processing

```
Audio in
    ↓
Pass A: Foundation Models labels chunks → beats
  - Extended fields: entityGrounding (new/carried/ambiguous)
  - Extended fields: expectedEmotion per beat
    ↓
Intra-session entity resolution pass (Swift-only)
  - Reclassify entities already seen in this session
  - Pronouns → referenced
    ↓
Delivery analysis (existing)
  - WPM, fillers, stalls, restarts
    ↓
Voice emotion classifier (Core ML, real-time)
  - Prosodic features → emotion probabilities per window
  - Aggregated to dominant emotion per beat
    ↓
Emotion evaluation
  - Compare expected (model) vs actual (classifier)
  - Match / adjacent / mismatched
    ↓
Event production
  - Entity events from resolved beats
  - Emotional events from evaluation
  - Component coverage events from arc analysis
    ↓
Entity registry update
  - New entities → records created
  - Referenced entities → mention count + last session updated
```

### 4.3 Diagnosis and coaching

```
On-device rules evaluate:
  - Delivery (always on-device)
  - Coherence (causal density on-device, dropped threads cloud)
  - Relevance (always on-device)
  - Structure (cloud, needs book context)
  - Engagement (hybrid)
    ↓
Targeted context retrieval
  - App logic selects relevant events from book log
  - Fetches entity history, coverage gaps, stakes context
  - Caps at 20 events, 200 tokens per description
    ↓
PCC call (if available)
  - Standalone, stateless request
  - No conversation history
  - Complete context in one shot
  - Timeout: 8 seconds
    ↓
Merge on-device + PCC results
  - PCC findings override on-device "insufficient"
  - On-device findings take priority when both exist
  - Each finding tagged: onDevice / cloud / hybrid
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

### 4.4 Session end

- No background processing
- No pending network calls
- All data persisted before feedback screen appears

---

## 5. On-device components

### 5.1 Pass A (Foundation Models)

Extends existing `BeatDraft`:

```swift
@Generable
private struct BeatDraft {
    var summary: String
    var kind: SpanKind
    var entitiesIntroduced: [String]
    var entitiesReferenced: [String]
    var entityGrounding: [EntityGrounding]      // new
    var statesStakes: Bool
    var connectsCausally: Bool
    var expectedEmotion: String?                // new
}

struct EntityGrounding: Codable, Sendable {
    let entity: String
    let status: EntityStatus
}

enum EntityStatus: String, Sendable, Codable {
    case new
    case carried
    case ambiguous
}
```

Prompt addition:
```
For each entity mentioned in this chunk, indicate whether it is:
- new: this is the first appearance in the entire retelling
- carried: already appeared earlier, just referenced here
- ambiguous: unclear whether new or carried

Only mark as new if the chunk introduces the entity with description or definition.

The primary emotion this stretch of storytelling should convey.
Choose: joy, sadness, anger, fear, surprise, tension, relief, neutral, mixed.
```

### 5.2 Entity resolution pass

After Pass A, before rules run:

```swift
extension [Beat] {
    func resolveEntities() -> [Beat] {
        var seen: Set<String> = []
        return map { beat in
            let alreadySeen = seen
            let reclassified = beat.entitiesIntroduced.filter { entity in
                pronouns.contains(entity) || alreadySeen.contains(entity)
            }
            let corrected = Beat(
                start: beat.start,
                end: beat.end,
                summary: beat.summary,
                kind: beat.kind,
                entitiesIntroduced: beat.entitiesIntroduced.filter { entity in
                    !pronouns.contains(entity) && !alreadySeen.contains(entity)
                },
                entitiesReferenced: beat.entitiesReferenced + reclassified,
                statesStakes: beat.statesStakes,
                connectsCausally: beat.connectsCausally
            )
            seen.formUnion(beat.entitiesIntroduced)
            seen.formUnion(beat.entitiesReferenced)
            return corrected
        }
    }
}
```

Then reconcile with model's `entityGrounding`:
- `carried` or `ambiguous` → move from `entitiesIntroduced` to `entitiesReferenced`
- `new` → keep in `entitiesIntroduced`

### 5.3 DroppedThreadRule (enhanced)

```swift
struct DroppedThreadRule: DiagnosticRule {
    let dimension = Dimension.coherence
    private static let minimumBeatCount = 3

    func canEvaluate(in input: DiagnosticInput) -> Bool {
        input.narrative.beats.count >= Self.minimumBeatCount
    }

    func findings(in input: DiagnosticInput) -> [Finding] {
        let beats = input.narrative.beats
        guard beats.count >= Self.minimumBeatCount else { return [] }

        var mentionCounts: [String: Int] = [:]
        for beat in beats {
            for entity in beat.entitiesIntroduced {
                mentionCounts[entity, default: 0] += 1
            }
            for entity in beat.entitiesReferenced {
                mentionCounts[entity, default: 0] += 1
            }
        }

        var introductions: [String: Beat] = [:]
        for beat in beats {
            for entity in beat.entitiesIntroduced where introductions[entity] == nil {
                introductions[entity] = beat
            }
        }

        let everReferenced = Set(beats.flatMap(\.entitiesReferenced))

        return introductions
            .filter { entity, beat in
                guard (mentionCounts[entity] ?? 0) >= 2 else { return false }
                guard beat.end < beats.last?.end ?? 0 else { return false }
                return !everReferenced.contains(entity)
            }
            .sorted { $0.value.start < $1.value.start }
            .map { entity, beat in
                Finding(
                    dimension: dimension,
                    subject: entity,
                    observation: "\(entity) was introduced at \(beat.start.timestampLabel) and never came up again",
                    magnitude: 1,
                    weight: 0.3,
                    evidence: [Evidence(at: beat.start, quote: beat.summary, measure: nil)]
                )
            }
    }
}
```

Quality thresholds:
- Minimum 3 beats before evaluating
- Entity must appear at least twice across all beats
- Introduction must not be the final beat

### 5.4 Voice emotion classifier

**Model:** emotion2vec+ base, INT8 quantized, converted to Core ML

**Pipeline:**
```
Audio stream
    ↓
VAD → speech windows
    ↓
Feature extractor → mel-spectrograms
    ↓
Emotion classifier → probabilities per window
    ↓
Aggregator → dominant emotion per beat with confidence
```

**Output:**
```swift
struct EmotionReading: Sendable, Identifiable {
    let id: UUID
    let emotion: DetectedEmotion
    let confidence: Double
    let alternatives: [DetectedEmotion: Double]
}

enum DetectedEmotion: String, Sendable {
    case joy
    case sadness
    case anger
    case fear
    case surprise
    case tension
    case relief
    case neutral
}
```

**Model mapping (emotion2vec+ 9 classes → 8 coaching classes):**
```
angry     → anger
disgusted → neutral (fallback — not storytelling-relevant)
fearful   → fear
happy     → joy
neutral   → neutral
other     → neutral (fallback)
sad       → sadness
surprised → surprise
unknown   → noEvidence (skip coaching)
```

**Confidence handling:**
```swift
if emotionReading.confidence < 0.6 {
    return .noEvidence  // do not fabricate feedback
}
```

### 5.5 Emotion evaluation engine

```swift
struct EmotionalEngine {
    func evaluate(
        beats: [Beat],
        expressions: [ExpressionSample]
    ) -> [EmotionMatch] {
        beats
            .emotionalBeats()
            .compactMap { beat in
                guard let expected = expectedEmotion(for: beat) else { return nil }
                guard let actual = actualEmotion(during: beat.start..<beat.end, from: expressions) else { return nil }
                return matcher.compare(expected: expected, actual: actual.emotion, beat: beat)
            }
    }

    func produceEvents(from matches: [EmotionMatch], session: Int) -> [BookEvent] {
        matches.map { match in
            BookEvent(
                kind: match.result.eventKind,
                subject: match.expected.rawValue,
                description: match.description,
                sessionNumber: session,
                timestamp: match.beatStart
            )
        }
    }
}

enum MatchResult {
    case matched
    case adjacent
    case mismatched

    var eventKind: EventKind {
        switch self {
        case .matched:   return .emotionalMatch
        case .adjacent:  return .emotionalAdjacent
        case .mismatched: return .emotionalMismatch
        }
    }
}

private func isAdjacent(_ a: DetectedEmotion, _ b: DetectedEmotion) -> Bool {
    switch (a, b) {
    case (.sadness, .relief), (.relief, .sadness): return true
    case (.fear, .tension), (.tension, .fear): return true
    case (.joy, .surprise), (.surprise, .joy): return true
    case (.anger, .tension), (.tension, .anger): return true
    default: return false
    }
}
```

---

## 6. Event engine

### 6.1 Event production (per session)

After each session, the engine produces events from two sources:

**Source 1: On-device model output (Pass A)**
- Entity introduced → `entityIntroduced` event
- Entity referenced → `entityReferenced` event
- Component covered (from arc) → `componentCovered` event
- Stakes stated → `stakesStated` event

**Source 2: Rule and emotion output**
- Component judgment → `componentCovered` event
- Emotional match/mismatch → `emotionalMatch` / `emotionalMismatch` / `emotionalAdjacent` event

Events are immutable. Appended to book log. Never modified after creation.

### 6.2 Targeted context retrieval

Before PCC call, app logic selects relevant context:

```swift
func relevantContext(
    for retelling: RetellingContext,
    in book: BookSession
) -> TargetedContext {

    let mentioned = retelling.beats.flatMap(\.entitiesReferenced)
    let presentComponents = retelling.arc.present
    let missingComponents = book.currentProgress.coveredComponents.subtracting(presentComponents)
    let hasStakes = retelling.beats.contains(where: \.statesStakes)
    let hasEmotionalBeats = retelling.beats.contains { $0.kind == .emotional }

    return TargetedContext(
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
        emotionalHistory: hasEmotionalBeats
            ? book.events
                .matching(kinds: [.emotionalMatch, .emotionalMismatch, .emotionalAdjacent])
                .inLast(3.sessions)
            : nil,
        recentSummaries: book.recentSummaries.limit(2)
    )
}
```

**Hard limits:**
- Max 20 events in context
- Max 200 tokens per event description
- Total book context: ~1,500–2,000 tokens

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
                if let emotion = session.emotionFor(entity) {
                    record.emotionalAssociations.append(emotion)
                }
                book.entityRegistry[entity] = record
            }
        }
    }
}
```

---

## 7. Private Cloud Compute integration

### 7.1 Request contract (standalone, stateless)

```swift
struct PCCRequest: Sendable, Codable {
    let bookTitle: String
    let evaluationMode: EvaluationMode
    let retelling: RetellingContext
    let targetedContext: TargetedContext
}

enum EvaluationMode: String, Sendable, Codable {
    case continuation
    case standalone
}

struct TargetedContext: Sendable, Codable {
    let entityEvents: [BookEvent]?
    let componentEvents: [BookEvent]?
    let stakesEvent: BookEvent?
    let emotionalHistory: [BookEvent]?
    let recentSummaries: [SessionSummary]?
}

struct PCCResponse: Sendable, Codable {
    let assessments: [DimensionAssessment]
    let feedback: Feedback
    let updatedProgress: ReadingProgress
}

struct DimensionAssessment: Sendable, Codable {
    let dimension: Dimension
    let band: Band
    let score: Double
    let findings: [Finding]
    let evaluatedFrom: EvaluationSource
}

enum EvaluationSource: String, Sendable, Codable {
    case onDevice
    case cloud
    case hybrid
}
```

### 7.2 Request size budget

| Component | Token estimate |
|-----------|---------------|
| System prompt | ~300 |
| Book title + shape | ~50 |
| Targeted context (events) | ~1,500–2,000 |
| Current retelling (beats + transcript + delivery) | ~2,500 |
| Total | ~4,000–5,000 |

Well within 32k window. Headroom for detailed entity histories, multiple session summaries, and explicit priority instructions.

### 7.3 Fallback behavior

```swift
enum PCCResult {
    case success(Diagnosis)
    case unavailable(Diagnosis)        // PCC not available, on-device only
    case timeout(OnDeviceDiagnosis)     // PCC slow, use on-device
    case error(Error, OnDeviceDiagnosis) // PCC failed, logged internally
}

func evaluateWithPCC(
    input: DiagnosticInput,
    book: BookSession,
    timeout: TimeInterval = 8.0
) async -> PCCResult {

    let onDevice = onDeviceEvaluation(input)

    guard PCC.isAvailable, book.currentProgress.previousSessions > 0 else {
        return .unavailable(onDevice)
    }

    do {
        let context = relevantContext(for: input, in: book)
        let cloud = try await PCC.evaluate(
            request: PCCRequest(book: book, context: context, retelling: input),
            timeout: timeout
        )
        return .success(merge(onDevice: onDevice, cloud: cloud))

    } catch {
        return .error(error, onDevice)
    }
}
```

User experience: never sees an error. Sees coaching. If degraded, subtle hint:
```
"Feedback based on this session only.
 Enable cloud analysis for book continuity."
```

### 7.4 Privacy model

| Data | Where it lives | When it leaves device |
|------|---------------|----------------------|
| Audio | On-device only | Never |
| Transcript | On-device only | Transient PCC request only, not stored |
| Beats/labels | On-device only | Included in PCC request, not stored by PCC |
| Book context | SwiftData | Never |
| Events | SwiftData | Never |
| Entity registry | SwiftData | Never |
| PCC request | Transient | During call only |
| PCC response | On-device only | Stored as part of session result |

No cloud persistence. No user profiles. No cross-user data. Each PCC call is independent and stateless.

---

## 8. UI flow

### 8.1 App launch

```
App launches
    ↓
Load last active BookSession
    ↓
BookSession exists?
  YES → Resume book
  NO  → Show book picker (create or choose)
    ↓
User taps "Start session"
```

### 8.2 Book creation

```
User taps "New book"
    ↓
Enter book title
    ↓
BookSession created with:
  - title
  - shape: .episodic (default, updated after first session)
  - currentProgress: .none
  - events: []
  - entityRegistry: [:]
  - recentSummaries: []
```

### 8.3 Book selection

```
User taps "Continue reading"
    ↓
List of BookSessions with:
  - Title
  - Last session date
  - Entity count
  - Session count
    ↓
User selects book
    ↓
Load BookSession
    ↓
Start session
```

### 8.4 Feedback screen (full diagnostic view)

Sections (all always visible when data exists):

1. Reading progress (continuation mode only)
   - Session number
   - Covered components
   - Stakes state
   - Known entities

2. What changed (second telling onward)
   - Challenge text
   - Verdict with before/after bands
   - Resolved / persisted / introduced findings

3. Composed note (primary coaching)

4. All findings (raw rule output, per dimension)
   - Observation, weight, magnitude, evidence

5. Delivery signals
   - WPM, word count, duration
   - Fillers, restarts, stalls with timestamps

6. Raw beats
   - Per-beat: kind, timestamp, transcript, entities, flags

7. Feedback evidence
   - Composer's evidence with scroll-to-transcript

8. All findings
   - Every raw finding from every dimension

9. Delivery signals
   - WPM, fillers, restarts, stalls

10. Raw beats
    - Per-beat details with entities and flags

11. Challenge + retry
    - Retry button (continuation mode)
    - Standalone challenge button (new)

12. Dimension scores (summary bands)

13. Full transcript with highlighting

---

## 9. Challenge modes

### 9.1 Retry (continuation)

```
User taps "Tell it again"
    ↓
previous = current assessment
current = nil
attempt += 1
mode = .continuation
readingProgress = previous.readingProgress (accumulated)
    ↓
Next session evaluates as continuation
Rules suppress findings already covered
```

### 9.2 Standalone (challenge)

```
User taps "Tell it as if to a stranger"
    ↓
previous = current assessment
current = nil
attempt += 1
mode = .standalone
readingProgress = .none
    ↓
Next session evaluates as standalone
All rules fire fully
User judged on whether chapter is self-contained
```

### 9.3 Challenge selection UI

```
[Tell it again]          [Tell it to a stranger]
(continuation mode)     (standalone challenge)
```

Two buttons. No ambiguity. User chooses the evaluation frame.

---

## 10. Component dependency map

```
Audio capture
    ↓
Transcription (existing)
    ↓
Pass A (Foundation Models)
    ├─→ Beat labels + entity grounding + expected emotion
    ↓
Entity resolution (Swift)
    ├─→ Resolved beats
    ↓
├─→ On-device rules (delivery, coherence, relevance)
├─→ Emotion evaluator (expected vs actual)
└─→ Event engine (entities, emotions, components)
    ↓
Entity registry update
    ↓
Targeted context retrieval
    ↓
├─→ PCC call (if available) → cross-session coaching
└─→ On-device fallback → within-session coaching only
    ↓
Merge
    ↓
Feedback
    ↓
Persistence (SwiftData)
```

---

## 11. Implementation order

### Phase 1: Data layer (foundation)
- [ ] `BookSession` SwiftData model with relationships
- [ ] `BookEvent` SwiftData model with indexes
- [ ] `EntityRecord` SwiftData model
- [ ] Book selection and creation UI
- [ ] Session startup: load BookSession, inject ReadingProgress

### Phase 2: On-device enhancements
- [ ] Extend `BeatDraft` with `entityGrounding` and `expectedEmotion`
- [ ] Update Pass A prompt with new instructions
- [ ] Entity resolution pass + reconciliation with `entityGrounding`
- [ ] Enhanced `DroppedThreadRule` with quality thresholds
- [ ] Emotion classifier Core ML integration (emotion2vec+ base INT8)
- [ ] Emotion aggregation per beat with confidence
- [ ] Emotion evaluation engine (match/adjacent/mismatch)

### Phase 3: Event system
- [ ] Event production from Pass A output
- [ ] Event production from emotion evaluation
- [ ] Entity registry update logic
- [ ] Targeted context retrieval logic
- [ ] Event storage and indexing

### Phase 4: PCC integration
- [ ] `PCCRequest` / `PCCResponse` types
- [ ] PCC call with timeout and fallback
- [ ] Merge logic (on-device + cloud)
- [ ] `EvaluationSource` tagging per finding
- [ ] Graceful degradation messaging

### Phase 5: Coaching and feedback
- [ ] Challenge mode UI (retry vs standalone)
- [ ] Challenge mode branching in `TellFlowView`
- [ ] Feedback composition with events
- [ ] Full diagnostic UI (all raw data visible)
- [ ] Cross-session emotional coaching prompts

### Phase 6: Polish
- [ ] Emotion classifier calibration against user baseline
- [ ] Adjacent emotion tuning
- [ ] Context cap enforcement and monitoring
- [ ] Battery and performance profiling
- [ ] Error logging and crash reporting (internal only)

---

## 12. Failure modes and fallbacks

| Component | Failure mode | Fallback |
|-----------|-------------|----------|
| Foundation Models | Unavailable or slow | Skip beat-level emotion tagging, use delivery-only coaching |
| Emotion classifier | Fails to load or infer | Skip emotion coaching, show other feedback |
| PCC | Network error or timeout | On-device diagnosis only, subtle hint |
| Camera | Permission denied or unsupported | Voice-only emotion, no face data |
| SwiftData | Corruption or migration failure | In-memory session, prompt user to re-create book |
| VAD | No speech detected | Show "I didn't hear anything" before processing |

Every fallback produces *something useful*. The app never shows a blank error screen when it can show partial feedback.

---

## 13. Open questions

1. **Book identification.** Does the user manually select a book, or does the app infer from content similarity? Manual selection is more reliable. Inference is more frictionless. For production, manual selection with optional auto-suggest.

2. **Chapter boundaries.** Currently not modeled. If users want chapter-level continuity, add chapter markers. If book-level continuity is sufficient, skip chapters entirely.

3. **Emotion classifier training data.** emotion2vec+ is general-purpose. Storytelling speech has different prosodic patterns — slower pace, deliberate pauses, theatrical emphasis. Fine-tuning on storytelling data would improve accuracy. Worth doing after the prototype validates the pipeline.

4. **Multi-emotion beats.** Some storytelling moments carry mixed emotions (bittersweet, anxious hope). The current model returns one dominant emotion. Multi-label classification is possible but complicates coaching. Start single-label, add multi-label if users need it.

5. **Cultural calibration.** Emotional expression varies by culture, personality, and skill level. The app should learn the user's baseline across sessions rather than compare against a universal threshold. This is a Phase 6 refinement.

---

## 14. Retry mechanics

### 14.1 Principle

The retry loop compares every dimension, not just the challenge target. The challenge determines the primary coaching message; the comparison determines what actually changed.

### 14.2 AttemptComparison

```swift
struct AttemptComparison: Sendable {
    let attemptNumber: Int
    let mode: ChallengeMode
    let challenge: String
    let focusDimension: Dimension?
    let deltas: [DimensionDelta]
    let overallVerdict: ChallengeVerdict
    let primaryImprovement: DimensionDelta?
    let newProblemAreas: [DimensionDelta]
}

struct DimensionDelta: Sendable, Identifiable {
    let id: UUID
    let dimension: Dimension
    let before: Band
    let after: Band
    let beforeScore: Double
    let afterScore: Double
    let resolved: [Finding]
    let persisted: [Finding]
    let introduced: [Finding]
    let improvement: Double  // afterScore - beforeScore, can be negative
}

enum ChallengeVerdict: String, Sendable, Hashable {
    case met
    case closer
    case notYet
}
```

### 14.3 What the user sees

```
VERDICT: Closer

DELIVERY (the challenge)
  Before: Developing → After: Emerging  +0.4
  ✓ Resolved: 2 filler pauses
  ⚠ Persisted: 1 stall at 05:22

OTHER DIMENSIONS
  Coherence: unchanged (causal density still thin)
  Structure: improved (missing setting now covered)

NEW THIS TIME
  Dropped thread "the house" — introduced at 01:20, never returned to

NOTE:
  "You kept the energy at the climax this time. The stall
   at 05:22 is the only remaining delivery issue — it came
   right after the confrontation, which suggests you lost
   the thread for a moment. The house came up once and
   disappeared — consider whether it needs a second
   mention or should be cut entirely."

NEXT:
  "Try again, and this time carry the house thread through
   to the resolution."
```

The verdict is never binary for the whole telling. Each dimension gets its own verdict. The overall verdict is the synthesis:

- **met**: primary dimension improved significantly, no new problems
- **closer**: primary dimension improved, or no dimension got worse
- **notYet**: primary dimension didn't improve, or new problems appeared

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

### 14.5 Verdict logic

```swift
func computeVerdict(
    primaryDelta: DimensionDelta?,
    newProblems: [DimensionDelta],
    overallImprovement: Double
) -> ChallengeVerdict {

    guard let primaryDelta else { return .notYet }

    // Primary dimension improved significantly and resolved more than persisted
    if primaryDelta.improvement >= 0.3 && primaryDelta.resolved.count >= primaryDelta.persisted.count {
        return newProblems.isEmpty ? .met : .closer
    }

    // Primary dimension improved slightly with some resolution
    if primaryDelta.improvement > 0 && primaryDelta.resolved.count > 0 {
        return newProblems.isEmpty ? .closer : .closer
    }

    // Primary didn't improve but nothing got worse
    if primaryDelta.improvement >= -0.1 && newProblems.isEmpty {
        return .closer
    }

    // Things got worse or stayed the same
    return .notYet
}
```

### 14.6 Standalone mode comparison

Standalone mode doesn't compare against the previous attempt. It compares the same retelling evaluated as continuation vs. as standalone:

```swift
struct StandaloneDelta: Sendable {
    let dimension: Dimension
    let asContinuation: Band
    let asStandalone: Band
    let difference: Double
    let standaloneOnlyFindings: [Finding]
    let continuationOnlyFindings: [Finding]
}
```

This shows: "When judged as a standalone story, you're missing the setting and stakes. As a continuation, those are already covered. The standalone view reveals what a stranger would need."

### 14.7 Next challenge suggestion

After each retry, the app suggests a next challenge based on remaining weaknesses:

```swift
func nextChallenge(
    after comparison: AttemptComparison,
    mode: ChallengeMode
) -> String? {

    // Primary dimension improved — target next weakest dimension
    if comparison.primaryDelta?.improvement ?? 0 >= 0.3 {
        let nextWeakest = comparison.otherDeltas
            .sorted { $0.afterScore < $1.afterScore }
            .first

        guard let next = nextWeakest else { return nil }
        return challengeText(for: next.dimension, mode: mode, basedOn: next.persisted)
    }

    // Primary didn't improve enough — retry same challenge
    return comparison.challenge
}
```

The challenge evolves with the user. Once they meet the first challenge, the next targets the next weakest area.

### 14.8 Comparison storage

No stored comparison state. The `RetellingComparison` is computed fresh each time the user taps retry:

```swift
struct Assessment: Sendable, Codable {
    let id: UUID
    let attemptNumber: Int
    let bookID: UUID
    let mode: ChallengeMode
    let challenge: String?
    let diagnosis: Diagnosis
    let readingProgress: ReadingProgress
    let timestamp: Date
}
```

The comparison reads `previous.assessment` (attempt N) and the new assessment (attempt N+1). Everything is recomputed from the two diagnoses. No cached verdicts.

### 14.9 Fallback behavior

If PCC is unavailable for the comparison step, the app uses on-device findings only. The comparison still works — it's just less nuanced about cross-session context. The user sees the same verdict structure with on-device data only.

---

## 15. What this plan does NOT include

- Ebook or audiobook import
- ISBN lookup or metadata fetching
- Social sharing or multi-user features
- Subscription or cloud sync
- Watch companion app
- Custom model training pipeline

These are product decisions, not architecture decisions. The architecture supports them but does not require them.
