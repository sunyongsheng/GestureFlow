import SwiftUI

@main
struct GestureFlowShellApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Settings UI is hosted by a dedicated WindowGroup (not SwiftUI's Settings scene).
        // First-open and menu-bar reopen go through SettingsWindowDependencies / SettingsWindowOpener.
        SettingsHostedWindowScene(coordinator: SettingsWindowDependencies.shared.coordinator)
            .commands {
                SettingsWindowCommands()
            }
    }
}

private struct SettingsHostedWindowScene: Scene {
    let coordinator: SettingsWindowCoordinator

    var body: some Scene {
        WindowGroup(id: SettingsWindowSceneIDs.settings) {
            SettingsRootView(coordinator: coordinator)
                .background(SettingsWindowOpenActionInstaller())
        }
        .defaultSize(width: 920, height: 620)
    }
}

private struct SettingsWindowCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") {
                openWindow(id: SettingsWindowSceneIDs.settings)
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}
