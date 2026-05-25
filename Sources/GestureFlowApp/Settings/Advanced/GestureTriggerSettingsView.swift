import SwiftUI
import GestureFlowCore

struct GestureTriggerSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        SettingsCard(
            title: "触发",
            description: "调整识别触发时机与采样容错范围，平衡灵敏度和稳定性。"
        ) {
            SettingsGroupedRows {
                SettingsValueRow(
                    title: "手势目标应用",
                    description: "决定按哪个应用匹配手势规则，以及手势快捷键发往哪个应用。",
                    statusText: nil
                ) {
                    Picker("", selection: gestureTargetApplicationBinding) {
                        ForEach(GestureTargetApplication.allCases, id: \.self) { target in
                            Text(target.displayName).tag(target)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 180)
                }

                SettingsRowDivider()

                SettingsSliderRow(
                    title: "移动阈值",
                    valueText: "\(formatted(viewModel.configuration.trigger.movementThreshold, precision: 0)) pt",
                    rangeText: "4 - 80 pt"
                ) {
                    Slider(
                        value: movementThresholdBinding.snapping(to: 1, in: 4...80),
                        in: 4...80
                    )
                }

                SettingsRowDivider()

                SettingsSliderRow(
                    title: "按住超时",
                    valueText: "\(viewModel.configuration.trigger.holdTimeoutMilliseconds) ms",
                    rangeText: "50 - 1000 ms"
                ) {
                    Slider(
                        value: holdTimeoutBinding.snapping(to: 25, in: 50...1000),
                        in: 50...1000
                    )
                }

                SettingsRowDivider()

                SettingsSliderRow(
                    title: "采样跳变阈值",
                    valueText: "\(formatted(viewModel.configuration.trigger.maximumSampleDistance, precision: 0)) pt",
                    rangeText: "40 - 240 pt"
                ) {
                    Slider(
                        value: maximumSampleDistanceBinding.snapping(to: 5, in: 40...240),
                        in: 40...240
                    )
                }
            }
        }
    }

    private var gestureTargetApplicationBinding: Binding<GestureTargetApplication> {
        Binding(
            get: { viewModel.configuration.gestureTargetApplication },
            set: { viewModel.updateGestureTargetApplication($0) }
        )
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

    private func formatted(_ value: Double, precision: Int) -> String {
        String(format: "%.\(precision)f", value)
    }
}
