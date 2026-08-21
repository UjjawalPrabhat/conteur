# Emotion Optimization Plan

## Goal

Disable camera input for now, then integrate and optimize `emotion2vec+` as the primary emotion source. After stabilization, camera may be reintroduced only as an optional secondary signal.

---

## Current State

- Camera/face capture is still wired into `SessionViewModel` and `SessionView`.
- `CoreMLEmotionClassifier` exists, but currently returns a stub probability when no model is bundled.
- `EmotionFeatureExtractor` derives fake features from expression coefficients, not real audio.
- Emotion events are generated, but are mostly neutral placeholders in practice.
- Relevant files:
  - `Conteur/Core/Capture/FaceCapture.swift`
  - `Conteur/Core/Signal/CoreMLEmotionClassifier.swift`
  - `Conteur/Core/Signal/EmotionFeatureExtractor.swift`
  - `Conteur/Core/Signal/EmotionEngine.swift`
  - `Conteur/Features/Session/SessionViewModel.swift`
  - `Conteur/Features/Session/SessionView.swift`

---

## Phase A — Disable Camera Input

### Objective
Remove camera capture from the active session pipeline while keeping the rest of the app stable.

### Steps
1. Stop `FaceCapture` usage in `SessionViewModel`
   - Remove `face.samples()` collection
   - Remove `face.previewFrames()` collection
   - Remove `face.start()` calls
   - Remove `selfView` updates
2. Remove self-view UI from `SessionView`
   - Remove `SelfView` overlay
   - Remove `reading` state updates that depended on face data
3. Make emotion path tolerant of empty expression input
   - Pass empty `expressions` through emotion evaluation
   - Ensure session still produces events and updates registry
4. Keep `FaceCapture` code in repo for later optional reintroduction
   - Do not delete files yet
   - Only remove active usage

### Expected Outcome
- Sessions no longer request or rely on camera input.
- Feedback, events, and registry updates still work.
- No crash or empty-state regressions in book history.

---

## Phase B — emotion2vec+ Integration

### Objective
Replace the stub emotion classifier with real on-device inference from audio.

### Step 1: Model Artifact
- Obtain `emotion2vec+ base` INT8 quantized model.
- Convert to Core ML `.mlpackage`.
- Bundle it in the app target.

### Step 2: Input Path Decision
Recommended: **audio-only first**
- Extract audio feature windows from transcription/capture path.
- Avoids camera permissions and simplifies inference pipeline.
- Camera can return later as an optional confidence booster only.

### Step 3: Replace Stub Inference
- Update `CoreMLEmotionClassifier` to load the bundled `.mlpackage`.
- Run inference on real feature vectors.
- Return real label probabilities.

### Step 4: Replace Feature Extraction
- Update `EmotionFeatureExtractor` to use audio-derived features instead of expression coefficients.
- Preferred features:
  - mel-spectrogram summary features
  - or model-specific input format required by `emotion2vec+`
- Ensure feature extraction happens on the audio path, not camera path.

### Step 5: Confidence and Calibration
- Keep existing `minimumConfidence` threshold.
- Add simple per-user smoothing so one strong outlier does not dominate emotion history.
- Keep adjacent-emotion fallback behavior.

### Step 6: Validation
- Confirm emotion events appear per beat.
- Confirm emotion labels change across expressive vs neutral speech.
- Confirm coaching context includes realistic emotion history.

### Step 7: Optional Camera Reintroduction
- Only after audio emotion is stable.
- Use camera as secondary input for expression confidence boosting.
- Keep it disabled by default.

---

## Recommended Execution Order

1. Execute Phase A now
2. Prepare audio feature path while model is being converted
3. Add model bundle
4. Wire real inference
5. Validate end-to-end emotion behavior
6. Optionally revisit camera later

---

## Notes

- This plan keeps the architecture on-device only.
- Do not add network-dependent emotion inference.
- Preserve graceful fallback behavior if the model fails to load or infer.
