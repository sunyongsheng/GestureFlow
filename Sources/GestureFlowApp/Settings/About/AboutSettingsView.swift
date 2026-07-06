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
                description: l10n.string(.aboutTagline)
            ) {
                VStack(alignment: .leading, spacing: 18) {
                    SettingsValueRow(
                        title: l10n.string(.aboutVersionLabel),
                        description: nil,
                        statusText: nil
                    ) {
                        HStack(spacing: 10) {
                            Text(versionDisplayValue)
                                .foregroundColor(.secondary)

                            Button(action: {
                                viewModel.checkForUpdates()
                            }) {
                                Text(l10n.string(.aboutCheckForUpdatesButton))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .disabled(!viewModel.canCheckForUpdates)
                        }
                    }
                    .frame(height: 24)

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
                    .frame(height: 24)

                    Divider()

                    Link(destination: GitHubReleaseClient.repositoryWebURL) {
                        SettingsValueRow(
                            title: l10n.string(.aboutOpenSourceTitle),
                            description: nil,
                            statusText: nil
                        ) {
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                    .frame(height: 24)
                }
            }

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
