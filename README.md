# Conteur

An iOS app for people who read, and want to be better at talking about what they read.

You finish a book, open the app, and tell it about what you just read. It doesn't ask
which book, or for how long. It listens without interrupting, then tells you one specific
thing about *how* you told it — and points at the moment it means, so you can hear it back.

Then you tell it again.

---

## Getting started

**You need an iPhone 15 Pro or newer**, on iOS 26, with Apple Intelligence turned on.
Apple's on-device model is a hard requirement and there is no fallback path. Nothing but
the tests runs in the simulator.

```bash
sudo xcode-select -s /Applications/Xcode.app     # once, if xcodebuild can't find the SDK

xcodebuild -scheme Conteur -destination 'generic/platform=iOS' build

xcodebuild -scheme Conteur \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:ConteurTests test
```

On first launch the speech model downloads — expect a wait on "One moment" that won't
happen again.

---

## Where things are

| Directory | Holds |
|---|---|
| `Conteur/App/` | entry point, tab structure |
| `Conteur/Core/` | the pipeline — capture through to spoken feedback |
| `Conteur/Features/` | Session, Feedback, Challenge, History, Diagnostics |
| `Conteur/Shared/` | value types that cross layers |
| `ConteurTests/` | the deterministic layers, tested without a device |

`Core` knows nothing about any feature, and ViewModels depend on protocols
(`Transcribing`, `NarrativeAnalyzing`, `Diagnosing`, `FeedbackComposing`, `Speaking`,
`Playing`) rather than concrete types — which is what lets the layers that decide things
be tested on a Mac.

**How any of it actually works → [Conteur/Core/README.md](Conteur/Core/README.md)**

---

## What it tells you

Five things are measured. Only the weakest is ever put in front of you, with a challenge
to tell it again against that one thing.

- **Structure** — did the shape of the story come through
- **Coherence** — could a listener follow it
- **Relevance** — was the time spent on what the story turns on
- **Engagement** — did it come across why any of it mattered
- **Delivery** — pace, pauses, pitch, fillers

---

## What it keeps

**Nothing is recorded.** The microphone is transcribed as you speak, and the audio buffers
are analysed and discarded — no file is ever written. The camera is not used at all.

What survives a session is **text**: the transcript, the feedback, and per-dimension
scores. That is what history shows you and what progress is measured from.

Session history is SwiftData, shaped to CloudKit's constraints but **not currently
syncing** — enabling it means adding an iCloud container to the entitlement and passing
`cloudKitDatabase: .automatic` in `ConteurApp`.

---

## Not yet verified on device

Honest status, since much of the pipeline depends on hardware behaviour that hasn't been
observed yet:

- Whether `SpeechTranscriber` preserves `"um"` and `"uh"` at all. If it strips them,
  `FilledPauseRule` has no input and filler detection has to move to acoustic analysis.
- How long Pass B plus composition take after the speaker stops.

