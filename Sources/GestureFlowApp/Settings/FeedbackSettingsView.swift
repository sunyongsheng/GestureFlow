import SwiftUI
import GestureFlowCore

struct FeedbackSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        SettingsCard(
            title: "Feedback",
            description: "控制手势轨迹的颜色、粗细与透明度，让反馈更自然。"
        ) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Trail color")
                        .font(.body.weight(.medium))

                    TextField("Trail color", text: feedbackBinding(\.trailColorHex))
                        .textFieldStyle(.roundedBorder)

                    Text("输入十六进制颜色值，例如 #4A90E2。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                sliderRow(
                    title: "Trail width",
                    valueText: formatted(viewModel.configuration.feedback.trailWidth, precision: 1),
                    rangeText: "1.0 - 12.0",
                    slider: Slider(value: feedbackBinding(\.trailWidth), in: 1...12, step: 0.5)
                )

                sliderRow(
                    title: "Trail opacity",
                    valueText: formatted(viewModel.configuration.feedback.trailOpacity, precision: 2),
                    rangeText: "0.10 - 1.00",
                    slider: Slider(value: feedbackBinding(\.trailOpacity), in: 0.1...1, step: 0.05)
                )
            }
        }
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
