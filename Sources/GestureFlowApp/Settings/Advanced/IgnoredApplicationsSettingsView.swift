import SwiftUI
import GestureFlowCore

struct IgnoredApplicationsSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @EnvironmentObject private var l10n: LocalizationManager

    var body: some View {
        SettingsCard(
            title: l10n.string(.advancedIgnoredAppsTitle),
            description: l10n.string(.advancedIgnoredAppsDescription)
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.ignoredApplicationBundleIdentifiers.isEmpty {
                    Text(l10n.string(.advancedIgnoredAppsEmpty))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.ignoredApplicationBundleIdentifiers.enumerated()), id: \.element) { index, bundleIdentifier in
                            if index > 0 {
                                SettingsRowDivider()
                            }

                            ignoredApplicationRow(bundleIdentifier: bundleIdentifier)
                        }
                    }
                }

                addApplicationMenu
            }
        }
    }

    private func ignoredApplicationRow(bundleIdentifier: String) -> some View {
        HStack(spacing: 8) {
            ApplicationBundleIconView(bundleIdentifier: bundleIdentifier)

            Text(viewModel.displayName(for: bundleIdentifier))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                viewModel.removeIgnoredApplication(bundleIdentifier: bundleIdentifier)
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.plain)
            .help(l10n.string(.advancedIgnoredAppsRemoveHelp))
        }
        .padding(.vertical, 4)
    }

    private var addApplicationMenu: some View {
        Menu {
            Button(l10n.string(.advancedIgnoredAppsAddFromFile)) {
                viewModel.addIgnoredApplicationFromPanel()
            }

            Menu(l10n.string(.advancedIgnoredAppsAddFromRunning)) {
                let runningApplications = viewModel.runningApplicationsAvailableForIgnore
                if runningApplications.isEmpty {
                    Text(l10n.string(.advancedIgnoredAppsRunningEmpty))
                } else {
                    ForEach(runningApplications, id: \.bundleIdentifier) { application in
                        Button(application.name) {
                            viewModel.addIgnoredApplication(bundleIdentifier: application.bundleIdentifier)
                        }
                    }
                }
            }
        } label: {
            Label(l10n.string(.advancedIgnoredAppsAdd), systemImage: "plus")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
