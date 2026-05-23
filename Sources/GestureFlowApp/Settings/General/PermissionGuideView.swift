import SwiftUI

struct PermissionGuideView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("辅助功能")
                .font(.headline)

            Text(viewModel.isAccessibilityTrusted
                ? "GestureFlow 可以正常监听鼠标手势。"
                : "请开启辅助功能权限，GestureFlow 才能接收手势输入。")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("请求权限") {
                viewModel.requestAccessibilityPermission()
            }
            .disabled(viewModel.isAccessibilityTrusted)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }
}
