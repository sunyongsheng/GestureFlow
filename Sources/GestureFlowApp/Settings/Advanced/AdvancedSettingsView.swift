import SwiftUI

struct AdvancedSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var isRestoreDefaultsConfirmationPresented = false
    @FocusState private var isSliderValueFieldFocused: Bool

    var body: some View {
        SettingsPage {
            VStack(alignment: .leading, spacing: 24) {
                GestureTriggerSettingsView(
                    viewModel: viewModel,
                    isSliderValueFieldFocused: $isSliderValueFieldFocused
                )
                FeedbackSettingsView(
                    viewModel: viewModel,
                    isSliderValueFieldFocused: $isSliderValueFieldFocused
                )
                FeedbackPopupSettingsView(
                    viewModel: viewModel,
                    isSliderValueFieldFocused: $isSliderValueFieldFocused
                )

                restoreDefaultsButton
            }
            .frame(maxWidth: 720, alignment: .leading)
            .simultaneousGesture(
                TapGesture().onEnded {
                    isSliderValueFieldFocused = false
                }
            )
        }
        .confirmationDialog(
            "是否恢复为默认设置",
            isPresented: $isRestoreDefaultsConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("确认", role: .destructive) {
                viewModel.restoreDefaultAdvancedSettings()
            }
            Button("取消", role: .cancel) {}
        }
    }

    private var restoreDefaultsButton: some View {
        HStack {
            Spacer()

            Button("恢复默认") {
                isRestoreDefaultsConfirmationPresented = true
            }
            .buttonStyle(.bordered)
        }
    }
}
