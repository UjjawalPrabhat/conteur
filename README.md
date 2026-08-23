# Conteur

An iOS app for people who read, and want to be better at telling somebody about it.

It gives you a short story. You read it once, and then you tell it back without looking.
It listens without interrupting, then tells you one specific thing about *how* you told it
— and points at the moment it means, so you can go and hear it back.

Then you tell it again, against that one thing.

## Why it hands you the story

Because it is the only way the feedback can be true.

Asked to judge a retelling of a book it has never seen, a 3B on-device model has to infer
what the story was, what mattered in it, and how well you conveyed both — and it will
answer confidently either way. Everything it says is then an opinion you cannot check.

Handing you an annotated story turns almost all of that into arithmetic. The app already
knows the seven events, which of them the story turns on, what causes what, who cannot be
left out, and what is at stake. So "you introduced the daughter at 2:14 and never came
back to her" is not the model being perceptive. It is a set difference, and it is right.

The cost is real and worth naming: this measures how well you retell *its* story, not the
book you actually read. That is the trade — a narrower question, answered honestly.

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
| `Conteur/App/` | entry point, tab structure, the loop that sequences the screens |
| `Conteur/Core/` | the pipeline — capture through to spoken feedback |
| `Conteur/Features/` | Reading, Session, Feedback, History, Progress, Diagnostics |
| `Conteur/DesignSystem/` | type, colour, spacing, and the campfire |
| `Conteur/Shared/` | value types that cross layers |
| `ConteurTests/` | the deterministic layers, tested without a device |

`Core` knows nothing about any feature, and ViewModels depend on protocols
(`Transcribing`, `SourceComparing`, `Diagnosing`, `FeedbackComposing`, `Speaking`) rather
than concrete types — which is what lets the layers that decide things be tested on a Mac.

**How any of it actually works → [Conteur/Core/README.md](Conteur/Core/README.md)**

---

## What it tells you

Six things are measured. Only one is ever put in front of you, with a challenge to tell it
again against that one thing.

- **Structure** — did the shape of the story come through
- **Coherence** — could a listener follow it
- **Relevance** — was the time spent on what the story turns on
- **Engagement** — did it come across why any of it mattered
- **Delivery** — pace, pauses, pitch, fillers
- **Fidelity** — was it the story that was actually there

A dimension that could not be judged says **"Not enough to tell"** rather than reporting
strength, and a dimension that flagged something is never also called strong. Both of those
are load-bearing: silence read as excellence is the failure this app is most exposed to.

---

## What it keeps

**Nothing is recorded.** The microphone is transcribed as you speak, and the audio buffers
are analysed and discarded — no file is ever written. The camera is not used at all.

What survives a session is **text**: the transcript, the feedback, and the bands for the
dimensions that could be judged. That is what history shows you and what progress is
measured from.

Session history is SwiftData, shaped to CloudKit's constraints but **not currently
syncing** — enabling it means adding an iCloud container to the entitlement and passing
`cloudKitDatabase: .automatic` in `ConteurApp`.

---

## Not yet verified on device

Honest status, since parts of the pipeline depend on hardware behaviour that has not been
observed yet:

- Whether `SpeechTranscriber` preserves `"um"` and `"uh"` at all. If it strips them,
  `FilledPauseRule` has no input and filler detection has to move to acoustic analysis.
- How long the comparison and composition take after the speaker stops.
- `SourceMatcher`'s corroboration threshold, which the in-app evaluation harness
  (Progress → Every Number → Model evaluation, debug builds only) exists to tune and which
  has not been run across candidate values yet.
