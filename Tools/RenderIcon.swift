import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Renders the Conteur app icon from the design spec. Geometry is taken from the 320pt
// master in the handoff and expressed as fractions of the canvas, so any size is exact
// rather than resampled.

struct Stop {
    let location: CGFloat
    let rgba: (CGFloat, CGFloat, CGFloat, CGFloat)
}

func hex(_ value: UInt32, _ alpha: CGFloat = 1) -> (CGFloat, CGFloat, CGFloat, CGFloat) {
    (
        CGFloat((value >> 16) & 0xFF) / 255,
        CGFloat((value >> 8) & 0xFF) / 255,
        CGFloat(value & 0xFF) / 255,
        alpha
    )
}

let space = CGColorSpaceCreateDeviceRGB()

func gradient(_ stops: [Stop]) -> CGGradient {
    var components: [CGFloat] = []
    var locations: [CGFloat] = []
    for stop in stops {
        components.append(contentsOf: [stop.rgba.0, stop.rgba.1, stop.rgba.2, stop.rgba.3])
        locations.append(stop.location)
    }
    return CGGradient(colorSpace: space, colorComponents: &components, locations: &locations, count: stops.count)!
}

/// A CSS radial-gradient with separate horizontal and vertical radii: drawn as a circle in
/// a scaled coordinate system, which is the only way CoreGraphics does ellipses.
func fillEllipticalGradient(
    _ context: CGContext,
    center: CGPoint,
    rx: CGFloat,
    ry: CGFloat,
    stops: [Stop]
) {
    context.saveGState()
    context.translateBy(x: center.x, y: center.y)
    context.scaleBy(x: 1, y: ry / rx)
    context.drawRadialGradient(
        gradient(stops),
        startCenter: .zero,
        startRadius: 0,
        endCenter: .zero,
        endRadius: rx,
        options: [.drawsAfterEndLocation]
    )
    context.restoreGState()
}

/// The flame silhouette, from the CSS `border-radius: A A B B / C C D D` form: a rect whose
/// corners are elliptical quarters.
///
/// Built in CSS's own coordinate space — origin top-left, y growing downward — and flipped
/// at the end. Reasoning about arc directions in CoreGraphics' upward y is how the first
/// attempt came out with the dome underneath and the feet in the air.
///
/// Top-left and top-right both take half the width, so their arcs meet at the crown with no
/// edge between them: the top is one continuous half-ellipse. Vertical radii sum to the full
/// height, so the sides are points rather than segments. What is left is a dome on two feet.
func flamePath(in rect: CGRect, topRatio: CGFloat, bottomRatioX: CGFloat, bottomRatioY: CGFloat) -> CGPath {
    /// Circular-arc bezier constant. Exact enough that the difference is invisible at 1024.
    let k: CGFloat = 0.5522847498
    let w = rect.width
    let h = rect.height
    let topRX = w * 0.5
    let topRY = h * topRatio
    let bottomRX = w * bottomRatioX
    let bottomRY = h * bottomRatioY

    /// Top-down point into CoreGraphics' bottom-up space.
    func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: rect.minX + x, y: rect.maxY - y)
    }

    let path = CGMutablePath()
    path.move(to: at(0, topRY))
    // Left shoulder up to the crown.
    path.addCurve(
        to: at(topRX, 0),
        control1: at(0, topRY - topRY * k),
        control2: at(topRX - topRX * k, 0)
    )
    // Crown down to the right shoulder.
    path.addCurve(
        to: at(w, topRY),
        control1: at(topRX + topRX * k, 0),
        control2: at(w, topRY - topRY * k)
    )
    // Right foot.
    path.addCurve(
        to: at(w - bottomRX, h),
        control1: at(w, h - bottomRY + bottomRY * k),
        control2: at(w - bottomRX + bottomRX * k, h)
    )
    path.addLine(to: at(bottomRX, h))
    // Left foot.
    path.addCurve(
        to: at(0, h - bottomRY),
        control1: at(bottomRX - bottomRX * k, h),
        control2: at(0, h - bottomRY + bottomRY * k)
    )
    path.closeSubpath()
    return path
}

/// Fractions of the canvas, measured off the 320pt master.
enum Geometry {
    static let groundStops = [
        Stop(location: 0, rgba: hex(0x1E1206)),
        Stop(location: 0.52, rgba: hex(0x0B1220)),
        Stop(location: 1, rgba: hex(0x050D1A)),
    ]
    static let glowStops = [
        Stop(location: 0, rgba: hex(0xF0A44C, 0.34)),
        Stop(location: 0.52, rgba: hex(0xC4622A, 0.1)),
        Stop(location: 0.78, rgba: hex(0xC4622A, 0)),
    ]
    static let flameStops = [
        Stop(location: 0, rgba: hex(0xFFF3E0)),
        Stop(location: 0.26, rgba: hex(0xFFD79A)),
        Stop(location: 0.52, rgba: hex(0xF0A44C)),
        Stop(location: 0.76, rgba: hex(0xD65A1E, 0.55)),
        Stop(location: 0.92, rgba: hex(0xD65A1E, 0)),
    ]
    static let coreStops = [
        Stop(location: 0, rgba: hex(0xFFFCF4)),
        Stop(location: 0.52, rgba: hex(0xFFF3E0, 0.6)),
        Stop(location: 0.84, rgba: hex(0xFFD79A, 0)),
    ]
}

func render(size: CGFloat, embers: Bool) -> CGImage {
    let pixels = Int(size)
    // No alpha channel: the App Store rejects icons that carry one, and the artwork is
    // full-bleed anyway.
    let context = CGContext(
        data: nil,
        width: pixels,
        height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: space,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )!
    context.interpolationQuality = .high
    let s = size / 320

    // Ground: radial 120% × 100% at (50%, 118%). In CSS that origin is below the canvas, so
    // the warm centre only shows as a lift in the bottom corners.
    fillEllipticalGradient(
        context,
        center: CGPoint(x: size / 2, y: size - size * 1.18),
        rx: size * 1.2,
        ry: size,
        stops: Geometry.groundStops
    )

    // Firelight on the ground, centred below the base.
    let glowDiameter = 373 * s
    let glowBottom = size + 48 * s
    fillEllipticalGradient(
        context,
        center: CGPoint(x: size / 2, y: size - (glowBottom - glowDiameter / 2)),
        rx: glowDiameter / 2,
        ry: glowDiameter / 2,
        stops: Geometry.glowStops
    )

    // Flame.
    let flame = CGRect(
        x: size / 2 - 65.5 * s,
        y: 69 * s,
        width: 131 * s,
        height: 176 * s
    )
    context.saveGState()
    context.addPath(flamePath(in: flame, topRatio: 0.68, bottomRatioX: 0.42, bottomRatioY: 0.32))
    context.clip()
    fillEllipticalGradient(
        context,
        center: CGPoint(x: flame.midX, y: flame.minY + flame.height * 0.2),
        rx: flame.width * 0.56,
        ry: flame.height * 0.66,
        stops: Geometry.flameStops
    )
    context.restoreGState()

    // The hot core inside it.
    let core = CGRect(
        x: size / 2 - 26.5 * s,
        y: 80 * s,
        width: 53 * s,
        height: 88 * s
    )
    context.saveGState()
    context.addPath(flamePath(in: core, topRatio: 0.70, bottomRatioX: 0.44, bottomRatioY: 0.30))
    context.clip()
    fillEllipticalGradient(
        context,
        center: CGPoint(x: core.midX, y: core.minY + core.height * 0.22),
        rx: core.width * 0.58,
        ry: core.height * 0.68,
        stops: Geometry.coreStops
    )
    context.restoreGState()

    // Embers are dropped below 120px, where they land on a pixel or two and read as grit
    // rather than as sparks.
    if embers {
        for (diameter, offsetX, bottom, colour) in [
            (9.0, -32.0, 229.0, hex(0xFFC98A, 0.75)),
            (7.0, 19.0, 261.0, hex(0xFFB870, 0.55)),
        ] {
            let d = CGFloat(diameter) * s
            let x = size / 2 + CGFloat(offsetX) * s
            let y = CGFloat(bottom) * s
            context.setFillColor(red: colour.0, green: colour.1, blue: colour.2, alpha: colour.3)
            context.fillEllipse(in: CGRect(x: x, y: y, width: d, height: d))
        }
    }

    return context.makeImage()!
}

func write(_ image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path) as CFURL
    let destination = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
}

let output = CommandLine.arguments[1]
write(render(size: 1024, embers: true), to: "\(output)/AppIcon-1024.png")
print("wrote 1024")
