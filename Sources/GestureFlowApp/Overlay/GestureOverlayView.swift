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

    func complete(with completion: GestureOverlayCompletion, feedbackFrame: CGRect?) {
        if let feedbackFrame {
            feedbackCardView.show(message: completion.message, in: feedbackFrame)
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
        strokePath(path, colorHex: trailAppearance.colorHex, lineWidth: trailAppearance.width)
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
        fillCircle(at: point, diameter: innerDiameter, colorHex: trailAppearance.colorHex)
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
    var message: String {
        switch self {
        case let .recognized(name):
            return name
        case .unmatched:
            return "未找到匹配手势"
        case .rejected:
            return "手势过短"
        case .actionFailed:
            return "分发失败"
        }
    }
}

private extension GesturePoint {
    var nsPoint: NSPoint {
        NSPoint(x: x, y: y)
    }
}

private final class GestureFeedbackCardView: NSView {
    private let visualEffectView = NSVisualEffectView()
    private let messageLabel = NSTextField(labelWithString: "")

    var isVisible: Bool {
        !isHidden
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    func show(message: String, in anchorFrame: CGRect) {
        messageLabel.stringValue = message
        let labelSize = messageLabel.fittingSize
        let cardWidth = max(220, min(360, labelSize.width + 36))
        let cardHeight = max(54, labelSize.height + 22)
        frame = NSRect(
            x: anchorFrame.midX - cardWidth / 2,
            y: anchorFrame.midY - cardHeight / 2,
            width: cardWidth,
            height: cardHeight
        ).integral
        isHidden = false
    }

    func hide() {
        isHidden = true
    }

    private func configureView() {
        wantsLayer = true
        layer?.shadowColor = NSColor.black.withAlphaComponent(0.10).cgColor
        layer?.shadowOpacity = 1
        layer?.shadowRadius = 10
        layer?.shadowOffset = CGSize(width: 0, height: 4)

        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .withinWindow
        visualEffectView.state = .active
        visualEffectView.isEmphasized = false
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 18
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.layer?.borderWidth = 1
        visualEffectView.layer?.borderColor = NSColor.white.withAlphaComponent(0.28).cgColor
        visualEffectView.frame = bounds
        visualEffectView.autoresizingMask = [.width, .height]
        addSubview(visualEffectView)

        messageLabel.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        messageLabel.textColor = .labelColor
        messageLabel.alignment = .center
        messageLabel.lineBreakMode = .byTruncatingTail
        messageLabel.maximumNumberOfLines = 1
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.setContentHuggingPriority(.required, for: .vertical)
        messageLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        visualEffectView.addSubview(messageLabel)

        NSLayoutConstraint.activate([
            messageLabel.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 18),
            messageLabel.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -18),
            messageLabel.centerYAnchor.constraint(equalTo: visualEffectView.centerYAnchor)
        ])
    }
}
