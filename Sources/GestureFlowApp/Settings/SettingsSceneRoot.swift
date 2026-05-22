import SwiftUI

struct SettingsSceneRoot: View {
    @ObservedObject var bridge: SettingsSceneBridge

    var body: some View {
        Group {
            if let viewModel = bridge.viewModel {
                MainSettingsView(viewModel: viewModel)
            } else {
                ProgressView("Loading GestureFlow Settings…")
                    .frame(minWidth: 700, minHeight: 480)
            }
        }
        .background(
            SettingsWindowLifecycleObserver(bridge: bridge)
            .frame(width: 0, height: 0)
        )
    }
}
