import AppKit
import SwiftUI
import GestureFlowCore

struct FeedbackSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        SettingsCard(
            title: "手势反馈",
            description: "控制手势轨迹的颜色、粗细与透明度，让反馈更自然。"
        ) {
            VStack(alignment: .leading, spacing: 18) {
                trailColorRow

                sliderRow(
                    title: "轨迹粗细",
                    valueText: formatted(viewModel.configuration.feedback.trailWidth, precision: 1),
                    rangeText: "1.0 - 12.0",
                    slider: Slider(value: feedbackBinding(\.trailWidth), in: 1...12, step: 0.5)
                )

                sliderRow(
                    title: "轨迹透明度",
                    valueText: formatted(viewModel.configuration.feedback.trailOpacity, precision: 2),
                    rangeText: "0.10 - 1.00",
                    slider: Slider(value: feedbackBinding(\.trailOpacity), in: 0.1...1, step: 0.05)
                )
            }
        }
    }

    private var trailColorRow: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("轨迹颜色")
                    .font(.body.weight(.medium))

                Text("绘制手势路径时使用的主色调。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            TrailColorPickerControl(color: trailColorBinding)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var trailColorBinding: Binding<Color> {
        Binding(
            get: {
                ColorHexFormatting.color(fromHex: viewModel.configuration.feedback.trailColorHex)
            },
            set: { newColor in
                viewModel.updateFeedback { feedback in
                    feedback.trailColorHex = ColorHexFormatting.hexString(from: newColor)
                }
            }
        )
    }

    private func feedbackBinding<Value>(_ keyPath: WritableKeyPath<FeedbackConfiguration, Value>) -> Binding<Value> {
        Binding(
            get: {
                viewModel.configuration.feedback[keyPath: keyPath]
            },
            set: { newValue in
                viewModel.updateFeedback { feedback in
                    feedback[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private func sliderRow<SliderView: View>(
        title: String,
        valueText: String,
        rangeText: String,
        slider: SliderView
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.body.weight(.medium))

                Spacer()

                Text(valueText)
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(.secondary)
            }

            slider

            Text(rangeText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func formatted(_ value: Double, precision: Int) -> String {
        String(format: "%.\(precision)f", value)
    }
}

private struct TrailColorPickerControl: View {
    @Binding var color: Color
    @State private var panelCoordinator = TrailColorPanelCoordinator()
    @State private var anchorCoordinator = ScreenAnchorCoordinator()

    private var hexDisplay: String {
        ColorHexFormatting.hexString(from: color).uppercased()
    }

    var body: some View {
        Button {
            anchorCoordinator.refreshAnchor()
            panelCoordinator.present(
                color: $color,
                anchorOnScreen: anchorCoordinator.anchorOnScreen
            )
        } label: {
            trailColorDisplay
        }
        .buttonStyle(.plain)
        .fixedSize()
        .background {
            ScreenAnchorReader(coordinator: anchorCoordinator)
        }
        .help("选择轨迹颜色")
    }

    private var trailColorDisplay: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color)
                .frame(width: 28, height: 28)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )

            Text(hexDisplay)
                .font(.body.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }
}

@MainActor
private final class TrailColorPanelCoordinator: NSObject {
    private var colorBinding: Binding<Color>?
    private var colorDidChangeObserver: NSObjectProtocol?

    func present(color: Binding<Color>, anchorOnScreen: CGRect) {
        colorBinding = color

        let panel = NSColorPanel.shared
        panel.setTarget(self)
        panel.setAction(#selector(applyPanelColor(_:)))
        panel.color = NSColor(color.wrappedValue)
        panel.showsAlpha = false
        panel.isContinuous = true
        panel.orderFront(nil)
        position(panel, relativeTo: anchorOnScreen)

        colorDidChangeObserver.map(NotificationCenter.default.removeObserver)
        colorDidChangeObserver = NotificationCenter.default.addObserver(
            forName: NSColorPanel.colorDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncFromPanel()
        }
    }

    @objc private func applyPanelColor(_ sender: Any?) {
        syncFromPanel()
    }

    private func syncFromPanel() {
        guard let colorBinding else { return }
        colorBinding.wrappedValue = Color(nsColor: NSColorPanel.shared.color)
    }

    private func position(_ panel: NSPanel, relativeTo anchor: CGRect, gap: CGFloat = 8) {
        guard anchor != .zero else { return }

        let panelSize = panel.frame.size
        var originX = anchor.minX
        var originY = anchor.minY - panelSize.height - gap

        let screen = NSScreen.screens.first(where: { $0.frame.intersects(anchor) }) ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            originX = min(max(originX, visible.minX), visible.maxX - panelSize.width)
            if originY < visible.minY {
                originY = anchor.maxY + gap
            }
            originY = min(max(originY, visible.minY), visible.maxY - panelSize.height)
        }

        panel.setFrameOrigin(NSPoint(x: originX, y: originY))
    }

    deinit {
        if let colorDidChangeObserver {
            NotificationCenter.default.removeObserver(colorDidChangeObserver)
        }
    }
}

@MainActor
private final class ScreenAnchorCoordinator {
    private(set) var anchorOnScreen: CGRect = .zero
    private weak var trackingView: NSView?

    func attach(view: NSView) {
        trackingView = view
        update(from: view)
    }

    func refreshAnchor() {
        update(from: trackingView)
    }

    private func update(from view: NSView?) {
        guard let view, let window = view.window else { return }
        let rectInWindow = view.convert(view.bounds, to: nil)
        anchorOnScreen = window.convertToScreen(rectInWindow)
    }
}

private struct ScreenAnchorReader: NSViewRepresentable {
    let coordinator: ScreenAnchorCoordinator

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.onFrameChange = { [weak view] in
            guard let view else { return }
            coordinator.attach(view: view)
        }
        return view
    }

    func updateNSView(_ nsView: TrackingView, context: Context) {
        nsView.onFrameChange = { [weak nsView] in
            guard let nsView else { return }
            coordinator.attach(view: nsView)
        }
        nsView.reportFrame()
    }

    final class TrackingView: NSView {
        var onFrameChange: (() -> Void)?

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }

        override func layout() {
            super.layout()
            onFrameChange?()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onFrameChange?()
        }

        func reportFrame() {
            onFrameChange?()
        }
    }
}
