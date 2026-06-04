import SwiftUI

struct AboutSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @EnvironmentObject private var l10n: LocalizationManager

    private let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        ?? "GestureFlow"
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String

    var body: some View {
        SettingsPage {
            SettingsCard(
                title: appName,
                description: nil
            ) {
                VStack(alignment: .leading, spacing: 18) {
                    SettingsValueRow(
                        title: l10n.string(.aboutVersionLabel),
                        description: nil,
                        statusText: nil
                    ) {
                        HStack(spacing: 10) {
                            Text(versionDisplayValue)
                                .font(.body.weight(.medium))

                            Button(action: {
                                viewModel.checkForUpdates()
                            }) {
                                HStack(spacing: 8) {
                                    if viewModel.isCheckingForUpdates {
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                                    Text(l10n.string(.aboutCheckForUpdatesButton))
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .disabled(!viewModel.canCheckForUpdates || viewModel.isCheckingForUpdates)
                        }
                    }

                    Divider()

                    SettingsValueRow(
                        title: l10n.string(.aboutAutomaticUpdateTitle),
                        description: nil,
                        statusText: nil
                    ) {
                        Toggle("", isOn: automaticUpdateBinding)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }
            }

            #if DEBUG
            Text(l10n.string(.aboutUpdateUnavailableInDevelopment))
                .font(.subheadline)
                .foregroundColor(.secondary)
            #endif
        }
        .alert(
            viewModel.updateCheckAlertTitle,
            isPresented: $viewModel.isUpdateCheckAlertPresented
        ) {
            Button(l10n.string(.settingsConfirm), role: .cancel) {}
        } message: {
            Text(viewModel.updateCheckAlertMessage)
        }
    }

    private var versionDisplayValue: String {
        version ?? l10n.string(.aboutDevelopmentEnvironment)
    }

    private var automaticUpdateBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isAutomaticUpdateEnabled },
            set: { viewModel.setAutomaticUpdateEnabled($0) }
        )
    }
}
