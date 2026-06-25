import GestureFlowCore
import SwiftUI

enum GeneralSettingsContent {
    static let controlCardTitle: String? = nil
    static let controlCardDescription: String? = nil
    static let quitSectionTitle: String? = nil
    static let quitSectionDescription: String? = nil

    static func gestureRecognitionStatusText(isRunning: Bool) -> String? {
        nil
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @EnvironmentObject private var l10n: LocalizationManager

    var body: some View {
        SettingsPage {
            SettingsCard(
                title: GeneralSettingsContent.controlCardTitle,
                description: GeneralSettingsContent.controlCardDescription
            ) {
                VStack(alignment: .leading, spacing: 18) {
                    SettingsValueRow(
                        title: l10n.string(.generalLaunchAtLoginTitle),
                        description: l10n.string(.generalLaunchAtLoginDescription),
                        statusText: nil
                    ) {
                        Toggle("", isOn: launchAtLoginBinding)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }

                    if let errorMessage = viewModel.launchAtLoginErrorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }

                    Divider()

                    SettingsValueRow(
                        title: l10n.string(.generalGestureRecognitionTitle),
                        description: l10n.string(.generalGestureRecognitionDescription),
                        statusText: GeneralSettingsContent.gestureRecognitionStatusText(
                            isRunning: viewModel.isRunning
                        )
                    ) {
                        Toggle("", isOn: gestureRecognitionBinding)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }

                    Divider()

                    SettingsValueRow(
                        title: l10n.string(.generalMenuBarIconTitle),
                        description: l10n.string(.generalMenuBarIconDescription),
                        statusText: nil
                    ) {
                        Toggle("", isOn: menuBarIconBinding)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }

                    Divider()

                    SettingsValueRow(
                        title: l10n.string(.generalAppLanguageTitle),
                        description: l10n.string(.generalAppLanguageDescription),
                        statusText: nil
                    ) {
                        Picker("", selection: appLanguageBinding) {
                            ForEach(AppLanguage.allCases, id: \.self) { language in
                                Text(language.nativeDisplayName).tag(language)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 220, alignment: .trailing)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        Text(l10n.string(.generalConfigDirectoryTitle))
                            .font(.body.weight(.medium))

                        Text(l10n.string(.generalConfigDirectoryDescription))
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack(spacing: 12) {
                            TextField(
                                l10n.string(.generalConfigDirectoryPathPlaceholder),
                                text: $viewModel.draftConfigurationDirectoryPath
                            )
                            .textFieldStyle(.roundedBorder)
                            .disabled(viewModel.isRelocatingConfigurationDirectory)

                            configurationDirectoryIconButton(
                                systemImage: "arrow.counterclockwise",
                                help: l10n.string(.generalConfigDirectoryResetHelp)
                            ) {
                                viewModel.prefillDefaultConfigurationDirectory()
                            }
                            .disabled(viewModel.isRelocatingConfigurationDirectory)

                            configurationDirectoryIconButton(
                                systemImage: "folder.badge.gearshape",
                                help: l10n.string(.generalConfigDirectoryXDGHelp)
                            ) {
                                viewModel.prefillXDGConfigurationDirectory()
                            }
                            .disabled(viewModel.isRelocatingConfigurationDirectory)

                            configurationDirectoryIconButton(
                                systemImage: "checkmark.circle.fill",
                                help: l10n.string(.generalConfigDirectoryConfirmHelp)
                            ) {
                                viewModel.confirmConfigurationDirectoryChange()
                            }
                            .disabled(
                                !viewModel.canConfirmConfigurationDirectoryChange
                                    || viewModel.isRelocatingConfigurationDirectory
                            )
                        }

                        if let errorMessage = viewModel.configurationDirectoryErrorMessage {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        Text(l10n.string(.generalAccessibilityTitle))
                            .font(.body.weight(.medium))

                        Text(
                            viewModel.isAccessibilityTrusted
                                ? l10n.string(.generalAccessibilityTrustedDescription)
                                : l10n.string(.generalAccessibilityUntrustedDescription)
                        )
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                        Button(action: {
                            viewModel.requestAccessibilityPermission()
                        }) {
                            HStack {
                                Text(
                                    viewModel.isAccessibilityTrusted
                                        ? l10n.string(.generalAccessibilityTrustedButton)
                                        : l10n.string(.generalAccessibilityRequestButton)
                                )
                                .fontWeight(.semibold)
                                .foregroundColor(
                                    viewModel.isAccessibilityTrusted
                                        ? Color(nsColor: .systemGreen)
                                        : .primary
                                )

                                Spacer()

                                if !viewModel.isAccessibilityTrusted {
                                    Image(systemName: "arrow.up.right.square")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(nsColor: .windowBackgroundColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(
                                        viewModel.isAccessibilityTrusted
                                            ? Color(nsColor: .systemGreen).opacity(0.35)
                                            : Color.primary.opacity(0.08),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isAccessibilityTrusted)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        if let quitSectionTitle = GeneralSettingsContent.quitSectionTitle {
                            Text(quitSectionTitle)
                                .font(.body.weight(.medium))
                        }

                        if let quitSectionDescription = GeneralSettingsContent.quitSectionDescription {
                            Text(quitSectionDescription)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Button(action: {
                            viewModel.quitApplication()
                        }) {
                            Text(l10n.string(.generalQuitApplication))
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(nsColor: .systemRed))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .alert(
            l10n.string(.generalConfigAdoptionAlertTitle),
            isPresented: $viewModel.isConfigurationDirectoryAdoptionAlertPresented
        ) {
            Button(l10n.string(.generalConfigAdoptionAlertNo), role: .cancel) {
                viewModel.cancelConfigurationDirectoryAdoption()
            }
            Button(l10n.string(.generalConfigAdoptionAlertYes)) {
                viewModel.confirmConfigurationDirectoryAdoption()
            }
        } message: {
            Text(l10n.string(.generalConfigAdoptionAlertMessage))
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isLaunchAtLoginEnabled },
            set: { viewModel.setLaunchAtLoginEnabled($0) }
        )
    }

    private var appLanguageBinding: Binding<AppLanguage> {
        Binding(
            get: { viewModel.configuration.general.language },
            set: { viewModel.setAppLanguage($0) }
        )
    }

    private func configurationDirectoryIconButton(
        systemImage: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .help(help)
        .accessibilityLabel(help)
    }

    private var gestureRecognitionBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isRunning },
            set: { newValue in
                viewModel.setGestureRecognitionEnabled(newValue)
            }
        )
    }

    private var menuBarIconBinding: Binding<Bool> {
        Binding(
            get: { viewModel.configuration.general.showMenuBarIcon },
            set: { viewModel.setShowMenuBarIcon($0) }
        )
    }
}
