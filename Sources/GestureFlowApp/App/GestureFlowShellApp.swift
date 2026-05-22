import SwiftUI

@main
struct GestureFlowShellApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The app shell declares the system-managed settings surface.
        // First-open behavior is handled outside the settings content lifecycle.
        SettingsWindowScene(bridge: SettingsSceneServices.shared.bridge)
            .commands {
                SettingsWindowCommands()
            }
    }
}

private struct SettingsWindowScene: Scene {
    let bridge: SettingsSceneBridge

    var body: some Scene {
        WindowGroup(id: SettingsWindowSceneIDs.settings) {
            SettingsSceneRoot(bridge: bridge)
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
