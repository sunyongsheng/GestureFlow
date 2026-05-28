import SwiftUI
import GestureFlowCore

struct GestureTriggerSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @EnvironmentObject private var l10n: LocalizationManager
    @FocusState.Binding var isSliderValueFieldFocused: Bool

    var body: some View {
        SettingsCard(
            title: l10n.string(.advancedTriggerTitle),
            description: l10n.string(.advancedTriggerDescription)
        ) {
            SettingsGroupedRows {
                SettingsValueRow(
                    title: l10n.string(.advancedGestureTargetTitle),
                    description: l10n.string(.advancedGestureTargetDescription),
                    statusText: nil
                ) {
                    Picker("", selection: gestureTargetApplicationBinding) {
                        ForEach(GestureTargetApplication.allCases, id: \.self) { target in
                            Text(l10n.localizedDisplayName(for: target)).tag(target)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }

                SettingsRowDivider()

                SettingsSliderRow(
                    title: l10n.string(.advancedMovementThresholdTitle),
                    description: l10n.string(.advancedMovementThresholdDescription),
                    value: movementThresholdBinding,
                    range: 4...80,
                    step: 1,
                    precision: 0,
                    valueSuffix: " pt",
                    isFocused: $isSliderValueFieldFocused
                )

                SettingsRowDivider()

                SettingsSliderRow(
                    title: l10n.string(.advancedHoldTimeoutTitle),
                    description: l10n.string(.advancedHoldTimeoutDescription),
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
                    title: l10n.string(.advancedSampleDistanceTitle),
                    description: l10n.string(.advancedSampleDistanceDescription),
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
