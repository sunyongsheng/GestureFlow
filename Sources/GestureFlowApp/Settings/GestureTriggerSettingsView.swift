import SwiftUI
import GestureFlowCore

struct GestureTriggerSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        SettingsCard(
            title: "Trigger",
            description: "调整识别触发时机与采样容错范围，平衡灵敏度和稳定性。"
        ) {
            VStack(alignment: .leading, spacing: 18) {
                sliderRow(
                    title: "Movement threshold",
                    valueText: "\(formatted(viewModel.configuration.trigger.movementThreshold, precision: 0)) pt",
                    rangeText: "4 - 80 pt",
                    slider: Slider(value: movementThresholdBinding, in: 4...80, step: 1)
                )

                sliderRow(
                    title: "Hold timeout",
                    valueText: "\(viewModel.configuration.trigger.holdTimeoutMilliseconds) ms",
                    rangeText: "50 - 1000 ms",
                    slider: Slider(value: holdTimeoutBinding, in: 50...1000, step: 25)
                )

                sliderRow(
                    title: "Sample jump threshold",
                    valueText: "\(formatted(viewModel.configuration.trigger.maximumSampleDistance, precision: 0)) pt",
                    rangeText: "40 - 240 pt",
                    slider: Slider(value: maximumSampleDistanceBinding, in: 40...240, step: 5)
                )
            }
        }
    }

    private var movementThresholdBinding: Binding<Double> {
        Binding(
            get: { viewModel.configuration.trigger.movementThreshold },
            set: { newValue in
                viewModel.updateTriggerConfiguration { trigger in
                    trigger.movementThreshold = newValue
                }
            }
        )
    }

    private var holdTimeoutBinding: Binding<Double> {
        Binding(
            get: { Double(viewModel.configuration.trigger.holdTimeoutMilliseconds) },
            set: { newValue in
                viewModel.updateTriggerConfiguration { trigger in
                    trigger.holdTimeoutMilliseconds = Int(newValue.rounded())
                }
            }
        )
    }

    private var maximumSampleDistanceBinding: Binding<Double> {
        Binding(
            get: { viewModel.configuration.trigger.maximumSampleDistance },
            set: { newValue in
                viewModel.updateTriggerConfiguration { trigger in
                    trigger.maximumSampleDistance = newValue
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
