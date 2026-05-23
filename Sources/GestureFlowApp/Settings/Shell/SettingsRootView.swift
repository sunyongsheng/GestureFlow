import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var coordinator: SettingsWindowCoordinator

    var body: some View {
        Group {
            if let viewModel = coordinator.viewModel {
                MainSettingsView(viewModel: viewModel)
            } else {
                ProgressView("正在加载 GestureFlow 设置…")
                    .frame(minWidth: 700, minHeight: 480)
            }
        }
        .background(SettingsWindowOpenActionInstaller())
        .overlay {
            SettingsWindowLifecycleObserver(coordinator: coordinator)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
        }
    }
}
