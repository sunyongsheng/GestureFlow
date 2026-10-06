import AppKit
import GestureFlowCore

/// Draws the gesture trail and the timeout marker as shape layers. The render server rasterizes the paths, so the
/// full-screen overlay never holds a screen-sized backing store and an update ships a path instead of pixels.
final class GestureTrailView: NSView {
    let outlineLayer: CAShapeLayer = NonAnimatingShapeLayer()
    let trailLayer: CAShapeLayer = NonAnimatingShapeLayer()
    let markerLayer: CAShapeLayer = NonAnimatingShapeLayer()

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLayers()
    }

    func render(points: [GesturePoint], appearance: GestureTrailAppearance, marker: GestureOverlayMarker?) {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            renderTrail(points: points, appearance: appearance)
            renderMarker(marker, appearance: appearance)
        }
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        for shapeLayer in shapeLayers {
            shapeLayer.frame = bounds
        }
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        // AppKit keeps only its own backing layers at the window's scale.
        let scale = window?.backingScaleFactor ?? 1
        for shapeLayer in shapeLayers {
            shapeLayer.contentsScale = scale
        }
    }

    private var shapeLayers: [CAShapeLayer] {
        [outlineLayer, trailLayer, markerLayer]
    }

    private func configureLayers() {
        wantsLayer = true
        for shapeLayer in shapeLayers {
            shapeLayer.frame = bounds
            shapeLayer.lineCap = .round
            shapeLayer.lineJoin = .round
            layer?.addSublayer(shapeLayer)
        }
    }

    private func renderTrail(points: [GesturePoint], appearance: GestureTrailAppearance) {
        let outlineColor = appearance.strokeEnabled ? Self.opaqueColor(fromHex: appearance.strokeColorHex) : nil
        let trailColor = Self.opaqueColor(fromHex: appearance.resolvedTrailColorHex)
        // Opacity on the layer rather than in the color: the layer is flattened before blending, so a translucent
        // trail stays uniform where it crosses itself.
        trailLayer.opacity = Float(appearance.opacity)

        if points.count == 1, let point = points.first {
            // A lone point has no segment to stroke, so it shows as a dot slightly wider than the line.
            let outlineDiameter = max((appearance.width + 2 * appearance.strokeWidth) * 1.5, 3)
            outlineLayer.path = outlineColor == nil ? nil : Self.circle(at: point, diameter: outlineDiameter)
            outlineLayer.fillColor = outlineColor
            outlineLayer.strokeColor = nil
            trailLayer.path = Self.circle(at: point, diameter: max(appearance.width * 1.5, 3))
            trailLayer.fillColor = trailColor
            trailLayer.strokeColor = nil
            return
        }

        let path = points.isEmpty ? nil : Self.polyline(through: points)
        outlineLayer.path = outlineColor == nil ? nil : path
        outlineLayer.fillColor = nil
        outlineLayer.strokeColor = outlineColor
        outlineLayer.lineWidth = max(appearance.width + 2 * appearance.strokeWidth, 1)
        trailLayer.path = path
        trailLayer.fillColor = nil
        trailLayer.strokeColor = trailColor
        trailLayer.lineWidth = max(appearance.width, 1)
    }

    private func renderMarker(_ marker: GestureOverlayMarker?, appearance: GestureTrailAppearance) {
        guard let marker else {
            markerLayer.path = nil
            return
        }

        let color: NSColor
        switch marker.style {
        case .timeoutOrigin:
            color = NSColor.systemRed.withAlphaComponent(0.95)
        }
        markerLayer.path = Self.circle(at: marker.point, diameter: max(appearance.width * 1.8, 6))
        markerLayer.fillColor = color.cgColor
    }

    private static func polyline(through points: [GesturePoint]) -> CGPath {
        let path = CGMutablePath()
        path.addLines(between: points.map { CGPoint(x: $0.x, y: $0.y) })
        return path
    }

    private static func circle(at point: GesturePoint, diameter: Double) -> CGPath {
        CGPath(
            ellipseIn: CGRect(x: point.x - diameter / 2, y: point.y - diameter / 2, width: diameter, height: diameter),
            transform: nil
        )
    }

    private static func opaqueColor(fromHex colorHex: String) -> CGColor {
        (ColorHexFormatting.nsColor(fromHex: colorHex) ?? .systemBlue).withAlphaComponent(1).cgColor
    }
}

/// Standalone layers animate color, line width and opacity changes implicitly, so the start dot would morph into the
/// line and highlight color flips would cross-fade instead of switching at once.
private final class NonAnimatingShapeLayer: CAShapeLayer {
    override func action(forKey event: String) -> CAAction? {
        nil
    }
}
