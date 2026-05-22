import SwiftUI

struct AboutSettingsView: View {
    private let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        ?? "GestureFlow"
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    private let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

    var body: some View {
        SettingsPage {
            SettingsCard(
                title: appName,
                description: "当前安装包的版本元信息。"
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    versionRow(title: "版本号", value: version ?? "开发环境")
                    versionRow(title: "构建号", value: build ?? "未提供")
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
