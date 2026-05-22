import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var coordinator: SettingsWindowCoordinator

    var body: some View {
        Group {
            if let viewModel = coordinator.viewModel {
                MainSettingsView(viewModel: viewModel)
            } else {
                ProgressView("Loading GestureFlow Settings…")
                    .frame(minWidth: 700, minHeight: 480)
            }
        }
        .background(
            SettingsWindowLifecycleObserver(coordinator: coordinator)
                .frame(width: 0, height: 0)
        )
    }
}
