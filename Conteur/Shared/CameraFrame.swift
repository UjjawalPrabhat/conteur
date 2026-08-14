import CoreGraphics

/// A downscaled still for the on-screen preview.
///
/// `CGImage` is immutable once created, so handing one to another isolation domain is
/// safe even though the type carries no `Sendable` conformance.
struct CameraFrame: @unchecked Sendable {
    let image: CGImage
}
