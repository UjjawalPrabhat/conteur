import ARKit
import CoreImage

/// Streams facial expression coefficients from the TrueDepth camera, and optionally a
/// downscaled preview of what the camera sees.
///
/// Frames are never retained or written anywhere. The preview is produced on demand,
/// handed straight to the view, and dropped — which is what keeps "no video is
/// recorded" literally true even while the camera is running.
final class FaceCapture: NSObject, @unchecked Sendable {
    /// ARKit delivers anchors at 60fps. Expressivity is measured over windows of
    /// seconds, so 10Hz carries the same information at a sixth of the volume.
    private static let sampleInterval: TimeInterval = 0.1
    /// Enough for the preview to feel live without converting 60 images a second.
    private static let previewInterval: TimeInterval = 1.0 / 15
    private static let previewWidth: CGFloat = 320

    static var isSupported: Bool { ARFaceTrackingConfiguration.isSupported }

    private let session = ARSession()
    private let lock = NSLock()
    private lazy var imageContext = CIContext(options: [.useSoftwareRenderer: false])

    private var sampleSink: AsyncStream<ExpressionSample>.Continuation?
    private var previewSink: AsyncStream<CameraFrame>.Continuation?
    private var origin: TimeInterval?
    private var lastSample: TimeInterval?
    private var lastPreview: TimeInterval?

    func samples() -> AsyncStream<ExpressionSample> {
        let (stream, continuation) = AsyncStream<ExpressionSample>.makeStream()
        lock.withLock { sampleSink = continuation }
        return stream
    }

    /// Registering a preview is what causes frames to be converted at all.
    func previewFrames() -> AsyncStream<CameraFrame> {
        let (stream, continuation) = AsyncStream<CameraFrame>.makeStream()
        lock.withLock { previewSink = continuation }
        return stream
    }

    func start() {
        guard Self.isSupported else { return }
        session.delegate = self
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = false
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    func stop() {
        session.pause()
        lock.withLock {
            sampleSink?.finish()
            previewSink?.finish()
            sampleSink = nil
            previewSink = nil
            origin = nil
            lastSample = nil
            lastPreview = nil
        }
    }
}

extension FaceCapture: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Converting an image is far too slow to do while holding the lock, so the
        // throttle decision is taken under it and the work happens outside.
        let sink: AsyncStream<CameraFrame>.Continuation? = lock.withLock {
            guard let previewSink else { return nil }
            let at = elapsed(since: frame.timestamp)
            if let lastPreview, at - lastPreview < Self.previewInterval { return nil }
            lastPreview = at
            return previewSink
        }

        guard let sink, let image = preview(from: frame.capturedImage) else { return }
        sink.yield(CameraFrame(image: image))
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let face = anchors.compactMap({ $0 as? ARFaceAnchor }).first else { return }
        let timestamp = session.currentFrame?.timestamp ?? 0

        lock.withLock {
            let at = elapsed(since: timestamp)
            if let lastSample, at - lastSample < Self.sampleInterval { return }
            lastSample = at
            sampleSink?.yield(sample(from: face, at: at))
        }
    }

    /// Callers already hold the lock.
    private func elapsed(since timestamp: TimeInterval) -> TimeInterval {
        let origin = origin ?? {
            self.origin = timestamp
            return timestamp
        }()
        return timestamp - origin
    }

    /// ARKit hands over a landscape buffer from the front camera. The app is locked to
    /// portrait, so one fixed transform holds: rotate upright, and mirror so the
    /// self-view moves the way a mirror does rather than the way a camera does.
    private static let previewOrientation = CGImagePropertyOrientation.right

    private func preview(from buffer: CVPixelBuffer) -> CGImage? {
        let source = CIImage(cvPixelBuffer: buffer).oriented(Self.previewOrientation)
        let scale = Self.previewWidth / source.extent.width
        let scaled = source.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return imageContext.createCGImage(scaled, from: scaled.extent)
    }

    private func sample(from face: ARFaceAnchor, at time: TimeInterval) -> ExpressionSample {
        let coefficients = ExpressionChannel.allCases.reduce(into: [ExpressionChannel: Float]()) {
            partial, channel in
            let location = ARFaceAnchor.BlendShapeLocation(rawValue: channel.rawValue)
            partial[channel] = face.blendShapes[location]?.floatValue ?? 0
        }
        return ExpressionSample(at: time, coefficients: coefficients)
    }
}
