import SwiftUI
import GestureFlowCore

struct FeedbackPopupSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @FocusState.Binding var isSliderValueFieldFocused: Bool

    var body: some View {
        if #available(macOS 26.0, *) {
            SettingsCard(
                title: "反馈弹窗",
                description: "手势识别时的反馈弹窗设置"
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
            title: "液态玻璃",
            description: "手势识别弹窗使用液态玻璃效果",
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
