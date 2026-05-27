import AppKit
import GestureFlowCore

final class GestureOverlayView: NSView {
    private var points: [GesturePoint] = []
    private var trailAppearance = GestureTrailAppearance(feedback: .default)
    private var marker: GestureOverlayMarker?
    private let feedbackCardView = GestureFeedbackCardView()

    override var isFlipped: Bool { true }

    override var isOpaque: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureFeedbackCard()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureFeedbackCard()
    }

    func begin(at point: GesturePoint, appearance: GestureTrailAppearance) {
        self.points = [point]
        self.trailAppearance = appearance
        self.marker = nil
        feedbackCardView.hide()
        needsDisplay = true
    }

    func append(_ point: GesturePoint) {
        points.append(point)
        needsDisplay = true
    }

    func updateLive(appearance: GestureTrailAppearance, feedback: LiveGestureOverlayFeedback, feedbackFrame: CGRect?) {
        trailAppearance = appearance
        if feedback.showsCard, let message = feedback.message, let feedbackFrame {
            feedbackCardView.show(
                message: message,
                in: feedbackFrame,
                textColor: feedbackTextColor(usesTrailColor: feedback.usesTrailColor),
                cornerRadius: CGFloat(trailAppearance.feedbackCardCornerRadius)
            )
        } else {
            feedbackCardView.hide()
        }
        needsDisplay = true
    }

    func complete(with completion: GestureOverlayCompletion, feedbackFrame: CGRect?) {
        if let feedbackFrame, let message = completion.overlayMessage {
            feedbackCardView.show(
                message: message,
                in: feedbackFrame,
                textColor: feedbackTextColor(usesTrailColor: completion.usesTrailColorText),
                cornerRadius: CGFloat(trailAppearance.feedbackCardCornerRadius)
            )
        } else {
            feedbackCardView.hide()
        }
        needsDisplay = true
    }

    func showMarker(_ marker: GestureOverlayMarker, appearance: GestureTrailAppearance) {
        self.marker = marker
        self.trailAppearance = appearance
        self.points = []
        feedbackCardView.hide()
        needsDisplay = true
    }

    func clearMarker() {
        marker = nil
        needsDisplay = true
    }

    func reset() {
        points = []
        marker = nil
        feedbackCardView.hide()
        needsDisplay = true
    }

    var hasVisibleContent: Bool {
        !points.isEmpty || feedbackCardView.isVisible || marker != nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawTrail()
        drawMarker()
    }

    private func drawTrail() {
        guard !points.isEmpty else { return }

        if points.count == 1, let point = points.first {
            drawSinglePointTrail(at: point)
            return
        }

        let path = makeTrailPath()
        if trailAppearance.strokeEnabled {
            strokePath(
                path,
                colorHex: trailAppearance.strokeColorHex,
                lineWidth: trailAppearance.width + 2 * trailAppearance.strokeWidth,
                opaque: true
            )
        }
        strokePath(
            path,
            colorHex: trailAppearance.resolvedTrailColorHex,
            lineWidth: trailAppearance.width
        )
    }

    private func drawSinglePointTrail(at point: GesturePoint) {
        if trailAppearance.strokeEnabled {
            let outerDiameter = max((trailAppearance.width + 2 * trailAppearance.strokeWidth) * 1.5, 3)
            fillCircle(
                at: point,
                diameter: outerDiameter,
                colorHex: trailAppearance.strokeColorHex,
                opaque: true
            )
        }

        let innerDiameter = max(trailAppearance.width * 1.5, 3)
        fillCircle(
            at: point,
            diameter: innerDiameter,
            colorHex: trailAppearance.resolvedTrailColorHex
        )
    }

    private func makeTrailPath() -> NSBezierPath {
        let path = NSBezierPath()
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: points[0].nsPoint)

        for point in points.dropFirst() {
            path.line(to: point.nsPoint)
        }

        return path
    }

    private func strokePath(
        _ path: NSBezierPath,
        colorHex: String,
        lineWidth: Double,
        opaque: Bool = false
    ) {
        let color = resolvedTrailColor(fromHex: colorHex, opaque: opaque)
        color.setStroke()

        let strokedPath = path.copy() as? NSBezierPath ?? path
        strokedPath.lineWidth = max(lineWidth, 1)
        strokedPath.lineCapStyle = .round
        strokedPath.lineJoinStyle = .round
        strokedPath.stroke()
    }

    private func fillCircle(
        at point: GesturePoint,
        diameter: Double,
        colorHex: String,
        opaque: Bool = false
    ) {
        let color = resolvedTrailColor(fromHex: colorHex, opaque: opaque)
        color.setFill()

        let rect = NSRect(
            x: point.x - diameter / 2,
            y: point.y - diameter / 2,
            width: diameter,
            height: diameter
        )
        NSBezierPath(ovalIn: rect).fill()
    }

    private func resolvedTrailColor(fromHex colorHex: String, opaque: Bool = false) -> NSColor {
        let alpha = opaque ? 1 : trailAppearance.opacity
        return ColorHexFormatting.nsColor(fromHex: colorHex)?
            .withAlphaComponent(alpha)
            ?? NSColor.systemBlue.withAlphaComponent(alpha)
    }

    private func feedbackTextColor(usesTrailColor: Bool) -> NSColor {
        guard usesTrailColor else { return .labelColor }
        return resolvedTrailColor(fromHex: trailAppearance.colorHex, opaque: true)
    }

    private func drawMarker() {
        guard let marker else { return }

        let color: NSColor
        switch marker.style {
        case .timeoutOrigin:
            color = NSColor.systemRed.withAlphaComponent(0.95)
        }

        color.setFill()
        let radius = max(trailAppearance.width * 1.8, 6)
        let rect = NSRect(
            x: marker.point.x - radius / 2,
            y: marker.point.y - radius / 2,
            width: radius,
            height: radius
        )
        NSBezierPath(ovalIn: rect).fill()
    }

    private func configureFeedbackCard() {
        feedbackCardView.isHidden = true
        addSubview(feedbackCardView)
    }
}

private extension GestureOverlayCompletion {
    var overlayMessage: String? {
        switch self {
        case let .recognized(name):
            return name
        case .unmatched:
            return GestureFeedbackCopy.unmatchedGesture
        case .rejected:
            return nil
        case let .targetNotFound(gestureName),
             let .shortcutNotConfigured(gestureName),
             let .deliveryFailed(gestureName),
             let .executionFailed(gestureName):
            return gestureName
        }
    }

    var usesTrailColorText: Bool {
        switch self {
        case .recognized,
             .targetNotFound,
             .shortcutNotConfigured,
             .deliveryFailed,
             .executionFailed:
            return true
        case .unmatched, .rejected:
            return false
        }
    }
}

private extension GesturePoint {
    var nsPoint: NSPoint {
        NSPoint(x: x, y: y)
    }
}
