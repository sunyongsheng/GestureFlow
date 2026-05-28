import SwiftUI

struct AboutSettingsView: View {
    @EnvironmentObject private var l10n: LocalizationManager

    private let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        ?? "GestureFlow"
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    private let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

    var body: some View {
        SettingsPage {
            SettingsCard(
                title: appName,
                description: l10n.string(.aboutCardDescription)
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    versionRow(
                        title: l10n.string(.aboutVersionLabel),
                        value: version ?? l10n.string(.aboutDevelopmentEnvironment)
                    )
                    versionRow(
                        title: l10n.string(.aboutBuildLabel),
                        value: build ?? l10n.string(.aboutBuildUnavailable)
                    )
                }
            }
        }
    }

    private func versionRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.medium)
        }
        .font(.body)
    }
}
