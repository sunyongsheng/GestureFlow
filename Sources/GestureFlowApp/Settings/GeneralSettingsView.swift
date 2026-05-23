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

    var body: some View {
        SettingsPage {
            SettingsCard(
                title: GeneralSettingsContent.controlCardTitle,
                description: GeneralSettingsContent.controlCardDescription
            ) {
                VStack(alignment: .leading, spacing: 18) {
                    SettingsValueRow(
                        title: "登录时打开",
                        description: "系统登录后自动启动 GestureFlow。",
                        statusText: "暂未实现"
                    ) {
                        Toggle("", isOn: launchAtLoginBinding)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }

                    Divider()

                    SettingsValueRow(
                        title: "手势识别",
                        description: "开启后，GestureFlow 会开始监听并识别配置的鼠标手势。",
                        statusText: GeneralSettingsContent.gestureRecognitionStatusText(
                            isRunning: viewModel.isRunning
                        )
                    ) {
                        Toggle("", isOn: gestureRecognitionBinding)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("辅助功能")
                            .font(.body.weight(.medium))

                        Text(
                            viewModel.isAccessibilityTrusted
                                ? "辅助功能权限已满足，GestureFlow 可以正常监听鼠标手势。"
                                : "请先授予辅助功能权限，GestureFlow 才能接收手势输入。"
                        )
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                        Button(action: {
                            viewModel.requestAccessibilityPermission()
                        }) {
                            HStack {
                                Text(viewModel.isAccessibilityTrusted ? "辅助功能已启用" : "开启辅助功能权限")
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
                            Text("退出 GestureFlow")
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
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { false },
            set: { newValue in
                guard newValue else { return }
                viewModel.showLaunchAtLoginPlaceholder()
            }
        )
    }

    private var gestureRecognitionBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isRunning },
            set: { newValue in
                viewModel.setGestureRecognitionEnabled(newValue)
            }
        )
    }
}
