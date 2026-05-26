import SwiftUI
import GestureFlowCore

struct GestureTriggerSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @FocusState.Binding var isSliderValueFieldFocused: Bool

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
                    .fixedSize()
                }

                SettingsRowDivider()

                SettingsSliderRow(
                    title: "移动阈值",
                    description: "指针移动超过该距离后才开始绘制并识别手势。",
                    value: movementThresholdBinding,
                    range: 4...80,
                    step: 1,
                    precision: 0,
                    valueSuffix: " pt",
                    isFocused: $isSliderValueFieldFocused
                )

                SettingsRowDivider()

                SettingsSliderRow(
                    title: "按住超时",
                    description: "右键按住超过该时间后，在按下位置显示超时原点标记。",
                    value: holdTimeoutBinding,
                    range: 50...1000,
                    step: 10,
                    precision: 0,
                    valueSuffix: " ms",
                    usesIntegerDisplay: true,
                    isFocused: $isSliderValueFieldFocused
                )

                SettingsRowDivider()

                SettingsSliderRow(
                    title: "采样跳变阈值",
                    description: "相邻采样点允许的最大间距，用于过滤指针抖动。",
                    value: maximumSampleDistanceBinding,
                    range: 40...240,
                    step: 1,
                    precision: 0,
                    valueSuffix: " pt",
                    isFocused: $isSliderValueFieldFocused
                )
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    isSliderValueFieldFocused = false
                }
            )
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

}
