import SwiftUI
import GestureFlowCore

struct FeedbackPopupSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @EnvironmentObject private var l10n: LocalizationManager
    @FocusState.Binding var isSliderValueFieldFocused: Bool

    var body: some View {
        if #available(macOS 26.0, *) {
            SettingsCard(
                title: l10n.string(.feedbackCardTitle),
                description: l10n.string(.feedbackCardDescription)
            ) {
                SettingsGroupedRows {
                    liquidGlassSettingRow
                }
                .simultaneousGesture(
                    TapGesture().onEnded {
                        isSliderValueFieldFocused = false
                    }
                )
            }
        }
    }

    @available(macOS 26.0, *)
    private var liquidGlassSettingRow: some View {
        SettingsValueRow(
            title: l10n.string(.feedbackLiquidGlassTitle),
            description: l10n.string(.feedbackLiquidGlassDescription),
            statusText: nil
        ) {
            Toggle("", isOn: feedbackBinding(\.feedbackCardLiquidGlassEnabled))
                .labelsHidden()
                .toggleStyle(.switch)
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
}
