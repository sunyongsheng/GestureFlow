import AppKit

final class GestureFeedbackCardView: NSView {
    private let messageLabel = NSTextField(labelWithString: "")
    private var backgroundView: NSView
    private var usesLiquidGlassBackground = false
    private var messageLabelConstraints: [NSLayoutConstraint] = []

    var isVisible: Bool {
        !isHidden
    }

    override init(frame frameRect: NSRect) {
        backgroundView = NSView()
        super.init(frame: frameRect)
        installBackground(liquidGlass: false)
    }

    required init?(coder: NSCoder) {
        backgroundView = NSView()
        super.init(coder: coder)
        installBackground(liquidGlass: false)
    }

    func show(
        message: String,
        in anchorFrame: CGRect,
        textColor: NSColor = .labelColor,
        cornerRadius: CGFloat,
        liquidGlassEnabled: Bool
    ) {
        applyBackgroundStyle(liquidGlassEnabled: liquidGlassEnabled)
        applyCornerRadius(cornerRadius)
        messageLabel.stringValue = message
        if usesLiquidGlassBackground {
            messageLabel.textColor = .labelColor
        } else {
            messageLabel.textColor = textColor
        }
        let labelSize = messageLabel.fittingSize
        let cardWidth = max(220, min(360, labelSize.width + 36))
        let cardHeight = max(54, labelSize.height + 22)
        frame = NSRect(
            x: anchorFrame.midX - cardWidth / 2,
            y: anchorFrame.midY - cardHeight / 2,
            width: cardWidth,
            height: cardHeight
        ).integral
        layoutSubtreeIfNeeded()
        isHidden = false
    }

    func hide() {
        isHidden = true
    }

    private func configureMessageLabel() {
        messageLabel.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        messageLabel.textColor = .labelColor
        messageLabel.alignment = .center
        messageLabel.lineBreakMode = .byTruncatingTail
        messageLabel.maximumNumberOfLines = 1
        messageLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        messageLabel.setContentCompressionResistancePriority(.required, for: .vertical)
    }

    private func applyBackgroundStyle(liquidGlassEnabled: Bool) {
        let shouldUseGlass: Bool
        if #available(macOS 26.0, *) {
            shouldUseGlass = liquidGlassEnabled
        } else {
            shouldUseGlass = false
        }

        guard shouldUseGlass != usesLiquidGlassBackground else { return }
        installBackground(liquidGlass: shouldUseGlass)
    }

    private func installBackground(liquidGlass: Bool) {
        messageLabel.removeFromSuperview()
        NSLayoutConstraint.deactivate(messageLabelConstraints)
        backgroundView.removeFromSuperview()

        usesLiquidGlassBackground = liquidGlass
        if liquidGlass {
            if #available(macOS 26.0, *) {
                let installation = Self.makeGlassBackgroundView(messageLabel: messageLabel)
                backgroundView = installation.container
                messageLabelConstraints = installation.labelConstraints
            } else {
                let installation = Self.makeLegacyVisualEffectBackgroundView(messageLabel: messageLabel)
                backgroundView = installation.container
                messageLabelConstraints = installation.labelConstraints
                usesLiquidGlassBackground = false
            }
        } else {
            let installation = Self.makeLegacyVisualEffectBackgroundView(messageLabel: messageLabel)
            backgroundView = installation.container
            messageLabelConstraints = installation.labelConstraints
        }

        configureMessageLabel()
        backgroundView.frame = bounds
        backgroundView.autoresizingMask = [.width, .height]
        addSubview(backgroundView)
        NSLayoutConstraint.activate(messageLabelConstraints)
    }

    private func applyCornerRadius(_ cornerRadius: CGFloat) {
        backgroundView.layer?.cornerRadius = cornerRadius

        if #available(macOS 26.0, *), let glassView = glassEffectView(in: backgroundView) {
            glassView.cornerRadius = cornerRadius
            glassView.layer?.cornerRadius = cornerRadius
            for case let rimHighlightView as LiquidGlassRimHighlightView in backgroundView.subviews {
                rimHighlightView.cornerRadius = cornerRadius
            }
            return
        }

        for case let visualEffectView as NSVisualEffectView in backgroundView.subviews {
            visualEffectView.layer?.cornerRadius = cornerRadius
        }
    }

    @available(macOS 26.0, *)
    private func glassEffectView(in view: NSView) -> NSGlassEffectView? {
        view.subviews.compactMap { $0 as? NSGlassEffectView }.first
    }

    private struct BackgroundInstallation {
        let container: NSView
        let labelConstraints: [NSLayoutConstraint]
    }

    @available(macOS 26.0, *)
    private static func makeGlassBackgroundView(messageLabel: NSTextField) -> BackgroundInstallation {
        let containerView = NSView()
        configureCardShadow(containerView, opacity: 0.12, radius: 10, offset: CGSize(width: 0, height: -3))

        let glassView = NSGlassEffectView(frame: .zero)
        glassView.style = .regular
        glassView.cornerRadius = 18

        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(messageLabel)
        glassView.contentView = contentView

        glassView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(glassView)

        let rimHighlightView = LiquidGlassRimHighlightView()
        rimHighlightView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(rimHighlightView)

        let labelConstraints = messageLabelConstraints(
            in: contentView,
            messageLabel: messageLabel,
            horizontalPadding: 18
        )

        NSLayoutConstraint.activate(
            labelConstraints
                + [
                    glassView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                    glassView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                    glassView.topAnchor.constraint(equalTo: containerView.topAnchor),
                    glassView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                    contentView.leadingAnchor.constraint(equalTo: glassView.leadingAnchor),
                    contentView.trailingAnchor.constraint(equalTo: glassView.trailingAnchor),
                    contentView.topAnchor.constraint(equalTo: glassView.topAnchor),
                    contentView.bottomAnchor.constraint(equalTo: glassView.bottomAnchor),
                    rimHighlightView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                    rimHighlightView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                    rimHighlightView.topAnchor.constraint(equalTo: containerView.topAnchor),
                    rimHighlightView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
                ]
        )

        return BackgroundInstallation(container: containerView, labelConstraints: labelConstraints)
    }

    private static func makeLegacyVisualEffectBackgroundView(messageLabel: NSTextField) -> BackgroundInstallation {
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 18
        configureCardShadow(containerView, opacity: 0.35, radius: 16, offset: CGSize(width: 0, height: 2))

        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .popover
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.isEmphasized = false
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 18
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(visualEffectView)

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.addSubview(messageLabel)

        let labelConstraints = messageLabelConstraints(
            in: visualEffectView,
            messageLabel: messageLabel,
            horizontalPadding: 18
        )

        NSLayoutConstraint.activate(
            [
                visualEffectView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                visualEffectView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                visualEffectView.topAnchor.constraint(equalTo: containerView.topAnchor),
                visualEffectView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ]
            + labelConstraints
        )

        return BackgroundInstallation(container: containerView, labelConstraints: labelConstraints)
    }

    private static func configureCardShadow(
        _ containerView: NSView,
        opacity: Float,
        radius: CGFloat,
        offset: CGSize
    ) {
        containerView.wantsLayer = true
        containerView.layer?.shadowColor = NSColor.black.cgColor
        containerView.layer?.shadowOpacity = opacity
        containerView.layer?.shadowRadius = radius
        containerView.layer?.shadowOffset = offset
    }

    private static func messageLabelConstraints(
        in containerView: NSView,
        messageLabel: NSTextField,
        horizontalPadding: CGFloat
    ) -> [NSLayoutConstraint] {
        let trailing = messageLabel.trailingAnchor.constraint(
            equalTo: containerView.trailingAnchor,
            constant: -horizontalPadding
        )
        trailing.priority = .defaultHigh
        return [
            messageLabel.leadingAnchor.constraint(
                equalTo: containerView.leadingAnchor,
                constant: horizontalPadding
            ),
            trailing,
            messageLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ]
    }
}

/// Liquid Glass only renders its specular rim while its window is key in the active app. The overlay
/// panel never becomes key, so the rim is drawn here, lit from the top and bottom like the system rim.
final class LiquidGlassRimHighlightView: NSView {
    private static let lineWidth: CGFloat = 1

    var cornerRadius: CGFloat = 18 {
        didSet {
            guard cornerRadius != oldValue else { return }
            needsDisplay = true
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let inset = Self.lineWidth / 2
        let rimRect = bounds.insetBy(dx: inset, dy: inset)
        guard rimRect.width > 0, rimRect.height > 0,
              let context = NSGraphicsContext.current?.cgContext else { return }

        let isDark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let radius = max(0, min(cornerRadius - inset, rimRect.width / 2, rimRect.height / 2))
        guard let gradient = Self.makeRimGradient(
            cornerRadius: radius,
            height: bounds.height,
            peakAlpha: isDark ? 0.35 : 0.5,
            spread: (isDark ? 70 : 80) * .pi / 180
        ) else { return }

        let rimPath = CGPath(roundedRect: rimRect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        context.addPath(
            rimPath.copy(strokingWithWidth: Self.lineWidth, lineCap: .butt, lineJoin: .miter, miterLimit: 10)
        )
        context.clip()
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: bounds.midX, y: bounds.maxY),
            end: CGPoint(x: bounds.midX, y: bounds.minY),
            options: []
        )
    }

    /// On a corner arc, the edge `cornerRadius * (1 - cos(angle))` away from the top or bottom faces
    /// `angle` away from vertical, so a vertical gradient fades the rim by edge angle without seams.
    private static func makeRimGradient(
        cornerRadius: CGFloat,
        height: CGFloat,
        peakAlpha: CGFloat,
        spread: CGFloat
    ) -> CGGradient? {
        let steps = 12
        let edgeStops = (0...steps).map { step -> (location: CGFloat, alpha: CGFloat) in
            let progress = CGFloat(step) / CGFloat(steps)
            let strength = 1 - progress
            let distanceFromEdge = lineWidth / 2 + cornerRadius * (1 - cos(spread * progress))
            return (
                location: min(distanceFromEdge / height, 0.5),
                alpha: peakAlpha * strength * strength * (3 - 2 * strength)
            )
        }
        let stops = edgeStops + edgeStops.reversed().map { (location: 1 - $0.location, alpha: $0.alpha) }
        return CGGradient(
            colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
            colors: stops.map { NSColor.white.withAlphaComponent($0.alpha).cgColor } as CFArray,
            locations: stops.map(\.location)
        )
    }
}
