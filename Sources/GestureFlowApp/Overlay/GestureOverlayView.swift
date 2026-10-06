import AppKit
import Combine
import GestureFlowCore

final class GestureOverlayView: NSView {
    private var points: [GesturePoint] = []
    private var trailAppearance = GestureTrailAppearance(feedback: .default)
    private var marker: GestureOverlayMarker?
    private let feedbackCardView = GestureFeedbackCardView()
    private let localization: LocalizationManager
    private var visibleLiveFeedback: LiveGestureOverlayFeedback?
    private var visibleLiveFeedbackFrame: CGRect?
    private var visibleCompletion: GestureOverlayCompletion?
    private var visibleCompletionFrame: CGRect?
    private var languageObserver: AnyCancellable?

    override var isFlipped: Bool { true }

    override var isOpaque: Bool { false }

    init(frame frameRect: NSRect, localization: LocalizationManager) {
        self.localization = localization
        super.init(frame: frameRect)
        configureFeedbackCard()
        languageObserver = localization.objectWillChange.sink { [weak self] _ in
            self?.refreshVisibleFeedback()
        }
    }

    override init(frame frameRect: NSRect) {
        self.localization = AppServices.localization
        super.init(frame: frameRect)
        configureFeedbackCard()
        languageObserver = localization.objectWillChange.sink { [weak self] _ in
            self?.refreshVisibleFeedback()
        }
    }

    required init?(coder: NSCoder) {
        self.localization = AppServices.localization
        super.init(coder: coder)
        configureFeedbackCard()
        languageObserver = localization.objectWillChange.sink { [weak self] _ in
            self?.refreshVisibleFeedback()
        }
    }

    func begin(at point: GesturePoint, appearance: GestureTrailAppearance) {
        self.points = [point]
        self.trailAppearance = appearance
        self.marker = nil
        visibleLiveFeedback = nil
        visibleLiveFeedbackFrame = nil
        visibleCompletion = nil
        visibleCompletionFrame = nil
        feedbackCardView.hide()
        needsDisplay = true
    }

    func append(_ point: GesturePoint) {
        points.append(point)
        // The overlay panel is full-screen, so invalidating the whole view forces the entire
        // surface to be re-encoded and shipped to the render server on every mouse sample.
        // Once the trail is an established polyline, only the new segment's rect needs redrawing;
        // `draw(_:)` re-strokes the full path clipped to that rect, keeping prior pixels intact.
        guard points.count > 2 else {
            needsDisplay = true
            return
        }
        setNeedsDisplay(trailSegmentInvalidationRect(from: points[points.count - 2], to: point))
    }

    func updateLive(appearance: GestureTrailAppearance, feedback: LiveGestureOverlayFeedback, feedbackFrame: CGRect?) {
        // Only the trail color/width matters for `draw(_:)`; the feedback card is a self-contained
        // subview. Repainting the whole full-screen trail every sample is what dominated CPU, so we
        // repaint it only when the appearance actually changed (e.g. highlight flips on/off). The
        // per-sample new segment is invalidated by `append`.
        let trailAppearanceChanged = appearance != trailAppearance
        trailAppearance = appearance
        visibleCompletion = nil
        visibleCompletionFrame = nil
        visibleLiveFeedback = feedback.showsCard ? feedback : nil
        visibleLiveFeedbackFrame = feedbackFrame
        if feedback.showsCard, let message = liveFeedbackMessage(for: feedback), let feedbackFrame {
            feedbackCardView.show(
                message: message,
                in: feedbackFrame,
                textColor: .labelColor,
                cornerRadius: CGFloat(trailAppearance.feedbackCardCornerRadius),
                liquidGlassEnabled: trailAppearance.feedbackCardLiquidGlassEnabled
            )
        } else {
            feedbackCardView.hide()
        }
        if trailAppearanceChanged {
            needsDisplay = true
        }
    }

    func complete(with completion: GestureOverlayCompletion, feedbackFrame: CGRect?) {
        visibleLiveFeedback = nil
        visibleLiveFeedbackFrame = nil
        visibleCompletion = completion
        visibleCompletionFrame = feedbackFrame
        if let feedbackFrame, let message = overlayMessage(for: completion) {
            feedbackCardView.show(
                message: message,
                in: feedbackFrame,
                textColor: .labelColor,
                cornerRadius: CGFloat(trailAppearance.feedbackCardCornerRadius),
                liquidGlassEnabled: trailAppearance.feedbackCardLiquidGlassEnabled
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
        visibleLiveFeedback = nil
        visibleLiveFeedbackFrame = nil
        visibleCompletion = nil
        visibleCompletionFrame = nil
        feedbackCardView.hide()
        needsDisplay = true
    }

    func refreshVisibleFeedback() {
        if let feedback = visibleLiveFeedback, let feedbackFrame = visibleLiveFeedbackFrame {
            updateLive(appearance: trailAppearance, feedback: feedback, feedbackFrame: feedbackFrame)
        } else if let completion = visibleCompletion {
            complete(with: completion, feedbackFrame: visibleCompletionFrame)
        }
    }

    private func liveFeedbackMessage(for feedback: LiveGestureOverlayFeedback) -> String? {
        if let gestureID = feedback.matchedGestureID {
            let displayName = localization.localizedGestureDisplayName(
                id: gestureID,
                storedName: feedback.matchedGestureStoredName
            )
            if !displayName.isEmpty {
                return displayName
            }
        }
        return feedback.message
    }

    private func overlayMessage(for completion: GestureOverlayCompletion) -> String? {
        switch completion {
        case let .recognized(gestureID, storedName),
             let .targetNotFound(gestureID, storedName),
             let .shortcutNotConfigured(gestureID, storedName),
             let .deliveryFailed(gestureID, storedName),
             let .executionFailed(gestureID, storedName):
            return localization.localizedGestureDisplayName(id: gestureID, storedName: storedName)
        case .unmatched:
            return localization.string(.overlayUnmatchedGesture)
        case .rejected:
            return nil
        }
    }

    var hasVisibleContent: Bool {
        !points.isEmpty || feedbackCardView.isVisible || marker != nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // Reset the invalidated region to fully transparent before stroking. This keeps partial
        // (single-segment) redraws correct: the semi-transparent trail is re-stroked over a cleared
        // area instead of blending onto whatever was already there.
        NSGraphicsContext.current?.cgContext.clear(dirtyRect)
        drawTrail(in: dirtyRect)
        drawMarker()
    }

    /// Distance around a segment that its stroke (plus anti-aliasing) can touch.
    private var trailSegmentMargin: Double {
        let halfLineWidth = trailAppearance.strokeEnabled
            ? trailAppearance.width / 2 + trailAppearance.strokeWidth
            : trailAppearance.width / 2
        return halfLineWidth + 2
    }

    private func trailSegmentInvalidationRect(from start: GesturePoint, to end: GesturePoint) -> NSRect {
        let margin = trailSegmentMargin
        let minX = min(start.x, end.x) - margin
        let minY = min(start.y, end.y) - margin
        let maxX = max(start.x, end.x) + margin
        let maxY = max(start.y, end.y) + margin
        return NSRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func drawTrail(in dirtyRect: NSRect) {
        guard !points.isEmpty else { return }

        if points.count == 1, let point = points.first {
            drawSinglePointTrail(at: point)
            return
        }

        let path = makeTrailPath(intersecting: dirtyRect)
        guard !path.isEmpty else { return }
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

    /// With round caps and joins the stroke is the union of per-segment capsules, so segments whose
    /// capsule cannot reach the dirty rect are skipped without changing any pixel inside it. Subpaths stay
    /// short because Core Graphics double-paints translucent self-overlaps within a subpath longer than
    /// about 256 segments, which would make overlaps depend on how a dirty rect splits the trail.
    private func makeTrailPath(intersecting dirtyRect: NSRect) -> NSBezierPath {
        let path = NSBezierPath()
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        let points = self.points
        let margin = trailSegmentMargin
        let minX = Double(dirtyRect.minX) - margin
        let maxX = Double(dirtyRect.maxX) + margin
        let minY = Double(dirtyRect.minY) - margin
        let maxY = Double(dirtyRect.maxY) + margin
        var segmentsInSubpath = 0

        for index in 1..<points.count {
            let start = points[index - 1]
            let end = points[index]
            guard max(start.x, end.x) >= minX,
                  min(start.x, end.x) <= maxX,
                  max(start.y, end.y) >= minY,
                  min(start.y, end.y) <= maxY else {
                segmentsInSubpath = 0
                continue
            }
            if segmentsInSubpath == 0 {
                path.move(to: start.nsPoint)
            }
            path.line(to: end.nsPoint)
            segmentsInSubpath = (segmentsInSubpath + 1) % Self.maximumSegmentsPerSubpath
        }

        return path
    }

    private static let maximumSegmentsPerSubpath = 128

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

private extension GesturePoint {
    var nsPoint: NSPoint {
        NSPoint(x: x, y: y)
    }
}
