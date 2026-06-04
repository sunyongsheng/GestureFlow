import SwiftUI

struct AboutSettingsView: View {
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
                versionRow(
                    title: l10n.string(.aboutVersionLabel),
                    value: versionDisplayValue
                )
            }
        }
    }

    private var versionDisplayValue: String {
        version ?? l10n.string(.aboutDevelopmentEnvironment)
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
