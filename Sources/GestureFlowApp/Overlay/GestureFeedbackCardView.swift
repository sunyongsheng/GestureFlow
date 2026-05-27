import AppKit

final class GestureFeedbackCardView: NSView {
    private let messageLabel = NSTextField(labelWithString: "")
    private let backgroundView: NSView

    var isVisible: Bool {
        !isHidden
    }

    override init(frame frameRect: NSRect) {
        if #available(macOS 26.0, *) {
            backgroundView = Self.makeGlassBackgroundView(messageLabel: messageLabel)
        } else {
            backgroundView = Self.makeLegacyVisualEffectBackgroundView(messageLabel: messageLabel)
        }
        super.init(frame: frameRect)
        configureView()
    }

    required init?(coder: NSCoder) {
        if #available(macOS 26.0, *) {
            backgroundView = Self.makeGlassBackgroundView(messageLabel: messageLabel)
        } else {
            backgroundView = Self.makeLegacyVisualEffectBackgroundView(messageLabel: messageLabel)
        }
        super.init(coder: coder)
        configureView()
    }

    func show(message: String, in anchorFrame: CGRect, textColor: NSColor = .labelColor) {
        messageLabel.stringValue = message
        messageLabel.textColor = textColor
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

    private func configureView() {
        backgroundView.frame = bounds
        backgroundView.autoresizingMask = [.width, .height]
        addSubview(backgroundView)
        configureMessageLabel()
    }

    private func configureMessageLabel() {
        messageLabel.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        messageLabel.textColor = .labelColor
        messageLabel.alignment = .center
        messageLabel.lineBreakMode = .byTruncatingTail
        messageLabel.maximumNumberOfLines = 1
        messageLabel.setContentCompressionResistancePriority(.required, for: .vertical)
    }

    @available(macOS 26.0, *)
    private static func makeGlassBackgroundView(messageLabel: NSTextField) -> NSView {
        let glassView = NSGlassEffectView(frame: .zero)
        glassView.cornerRadius = 18

        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(messageLabel)
        glassView.contentView = contentView

        NSLayoutConstraint.activate(
            contentLayoutConstraints(
                in: contentView,
                messageLabel: messageLabel,
                horizontalPadding: 18
            ) + [
                contentView.leadingAnchor.constraint(equalTo: glassView.leadingAnchor),
                contentView.trailingAnchor.constraint(equalTo: glassView.trailingAnchor),
                contentView.topAnchor.constraint(equalTo: glassView.topAnchor),
                contentView.bottomAnchor.constraint(equalTo: glassView.bottomAnchor)
            ]
        )

        return glassView
    }

    private static func makeLegacyVisualEffectBackgroundView(messageLabel: NSTextField) -> NSView {
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 18
        containerView.layer?.shadowColor = NSColor.black.withAlphaComponent(0.06).cgColor
        containerView.layer?.shadowOpacity = 1
        containerView.layer?.shadowRadius = 16
        containerView.layer?.shadowOffset = CGSize(width: 0, height: 2)

        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .popover
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.isEmphasized = false
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 18
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.layer?.borderWidth = 0.5
        visualEffectView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(visualEffectView)

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.addSubview(messageLabel)

        NSLayoutConstraint.activate(
            [
                visualEffectView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                visualEffectView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                visualEffectView.topAnchor.constraint(equalTo: containerView.topAnchor),
                visualEffectView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ]
            + contentLayoutConstraints(
                in: visualEffectView,
                messageLabel: messageLabel,
                horizontalPadding: 18
            )
        )

        return containerView
    }

    private static func contentLayoutConstraints(
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
