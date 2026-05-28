import SwiftUI

struct PermissionGuideView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @EnvironmentObject private var l10n: LocalizationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l10n.string(.permissionGuideTitle))
                .font(.headline)

            Text(
                viewModel.isAccessibilityTrusted
                    ? l10n.string(.permissionGuideTrustedDescription)
                    : l10n.string(.permissionGuideUntrustedDescription)
            )
            .font(.caption)
            .foregroundColor(.secondary)

            Button(l10n.string(.permissionGuideRequestButton)) {
                viewModel.requestAccessibilityPermission()
            }
            .disabled(viewModel.isAccessibilityTrusted)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }
}
