import SwiftUI

@main
struct GestureFlowShellApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Settings UI is hosted by a value-bound WindowGroup (not SwiftUI's Settings scene).
        // Reopen with the same `value` brings the existing window forward instead of spawning another.
        SettingsHostedWindowScene(coordinator: SettingsWindowDependencies.shared.coordinator)
            .commands {
                SettingsWindowCommands()
            }
    }
}

private struct SettingsHostedWindowScene: Scene {
    let coordinator: SettingsWindowCoordinator

    var body: some Scene {
        WindowGroup(
            id: SettingsWindowSceneIDs.settings,
            for: String.self
        ) { _ in
            SettingsRootView(coordinator: coordinator)
        } defaultValue: {
            SettingsWindowSceneIDs.settingsInstance
        }
        .defaultSize(width: 920, height: 620)
    }
}

private struct SettingsWindowCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("设置…") {
                SettingsWindowFrontmostPresenter.activateExistingOrOpen {
                    openWindow(
                        id: SettingsWindowSceneIDs.settings,
                        value: SettingsWindowSceneIDs.settingsInstance
                    )
                }
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}
