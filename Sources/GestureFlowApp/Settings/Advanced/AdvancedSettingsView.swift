import SwiftUI

struct AdvancedSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @EnvironmentObject private var l10n: LocalizationManager
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
            l10n.string(.settingsRestoreDefaultsTitle),
            isPresented: $isRestoreDefaultsConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(l10n.string(.settingsConfirm), role: .destructive) {
                viewModel.restoreDefaultAdvancedSettings()
            }
            Button(l10n.string(.settingsCancel), role: .cancel) {}
        }
    }

    private var restoreDefaultsButton: some View {
        HStack {
            Spacer()

            Button(l10n.string(.settingsRestoreDefaults)) {
                isRestoreDefaultsConfirmationPresented = true
            }
            .buttonStyle(.bordered)
        }
    }
}
