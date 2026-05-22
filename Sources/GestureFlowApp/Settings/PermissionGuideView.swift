import SwiftUI

struct PermissionGuideView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Accessibility")
                .font(.headline)

            Text(viewModel.isAccessibilityTrusted
                ? "GestureFlow can observe mouse gestures."
                : "Enable Accessibility permission so GestureFlow can observe mouse gestures.")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("Request Permission") {
                viewModel.requestAccessibilityPermission()
            }
            .disabled(viewModel.isAccessibilityTrusted)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }
}
