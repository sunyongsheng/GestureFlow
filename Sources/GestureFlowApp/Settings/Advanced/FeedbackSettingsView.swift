import AppKit
import SwiftUI
import GestureFlowCore

struct FeedbackSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @FocusState.Binding var isSliderValueFieldFocused: Bool

    var body: some View {
        SettingsCard(
            title: "手势反馈",
            description: "控制手势轨迹的颜色、粗细与透明度，让反馈更自然。"
        ) {
            SettingsGroupedRows {
                GestureTrailPreview(feedback: viewModel.configuration.feedback)

                SettingsRowDivider()

                SettingsValueRow(
                    title: "轨迹颜色",
                    description: "绘制手势路径时使用的主色调。",
                    statusText: nil
                ) {
                    TrailColorPickerControl(color: trailColorBinding)
                }

                SettingsRowDivider()

                SettingsSliderRow(
                    title: "轨迹粗细",
                    description: "控制手势轨迹线条的宽度。",
                    value: feedbackBinding(\.trailWidth),
                    range: 1...12,
                    step: 0.5,
                    precision: 1,
                    isFocused: $isSliderValueFieldFocused
                )

                SettingsRowDivider()

                SettingsSliderRow(
                    title: "轨迹透明度",
                    description: "控制手势轨迹的不透明度，描边不受此项影响。",
                    value: feedbackBinding(\.trailOpacity),
                    range: 0.1...1,
                    step: 0.05,
                    precision: 2,
                    isFocused: $isSliderValueFieldFocused
                )

                SettingsRowDivider()

                SettingsValueRow(
                    title: "启用轨迹描边",
                    description: "在轨迹外侧绘制一圈对比色描边。",
                    statusText: nil
                ) {
                    Toggle("", isOn: feedbackBinding(\.trailStrokeEnabled))
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                if viewModel.configuration.feedback.trailStrokeEnabled {
                    SettingsRowDivider()

                    SettingsValueRow(
                        title: "描边颜色",
                        description: "轨迹外侧描边使用的颜色。",
                        statusText: nil
                    ) {
                        TrailColorPickerControl(color: strokeColorBinding, help: "选择描边颜色")
                    }

                    SettingsRowDivider()

                    SettingsSliderRow(
                        title: "描边粗细",
                        description: "控制轨迹外侧描边线条的宽度。",
                        value: feedbackBinding(\.trailStrokeWidth),
                        range: 0.5...8,
                        step: 0.1,
                        precision: 1,
                        isFocused: $isSliderValueFieldFocused
                    )
                }
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    isSliderValueFieldFocused = false
                }
            )
        }
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

    private var strokeColorBinding: Binding<Color> {
        Binding(
            get: {
                ColorHexFormatting.color(fromHex: viewModel.configuration.feedback.trailStrokeColorHex)
            },
            set: { newColor in
                viewModel.updateFeedback { feedback in
                    feedback.trailStrokeColorHex = ColorHexFormatting.hexString(from: newColor)
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

}

private struct TrailColorPickerControl: View {
    @Binding var color: Color
    var help: String = "选择轨迹颜色"
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
        .help(help)
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
            Task { @MainActor in
                self?.syncFromPanel()
            }
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
