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
        configureCardShadow(containerView)

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
                    contentView.bottomAnchor.constraint(equalTo: glassView.bottomAnchor)
                ]
        )

        return BackgroundInstallation(container: containerView, labelConstraints: labelConstraints)
    }

    private static func makeLegacyVisualEffectBackgroundView(messageLabel: NSTextField) -> BackgroundInstallation {
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 18
        configureCardShadow(containerView)

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

    private static func configureCardShadow(_ containerView: NSView) {
        containerView.wantsLayer = true
        containerView.layer?.shadowColor = NSColor.black.withAlphaComponent(0.35).cgColor
        containerView.layer?.shadowOpacity = 1
        containerView.layer?.shadowRadius = 16
        containerView.layer?.shadowOffset = CGSize(width: 0, height: 2)
    }

    private static func messageLabelConstraints(
        in containerView: NSView,
        messageLabel: NSTextField,
        horizontalPadding: CGFloat
    ) -> [NSLayoutConstraint] {
        [
            messageLabel.leadingAnchor.constraint(
                equalTo: containerView.leadingAnchor,
                constant: horizontalPadding
            ),
            messageLabel.trailingAnchor.constraint(
                equalTo: containerView.trailingAnchor,
                constant: -horizontalPadding
            ),
            messageLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ]
    }
}
