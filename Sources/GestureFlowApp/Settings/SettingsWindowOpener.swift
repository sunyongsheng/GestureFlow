import AppKit
import SwiftUI

/// Opens the settings `WindowGroup` from AppKit-only entry points (status bar, etc.).
///
/// Prefers a SwiftUI `openWindow` action registered by `SettingsWindowOpenActionInstaller`.
/// Falls back to invoking the app menu Settings item when registration has not run yet.
final class SettingsWindowOpener {
    typealias OpenAction = () -> Void
    typealias ResolveOpenAction = () -> OpenAction?

    private var registeredOpenWindowAction: OpenAction?
    private let menuFallback: () -> Bool

    init() {
        self.menuFallback = Self.openViaMainMenu
    }

    /// Uses only the supplied action (tests and explicit injection).
    init(openWindowAction: @escaping OpenAction) {
        self.registeredOpenWindowAction = openWindowAction
        self.menuFallback = { false }
    }

    /// Resolves an action on each open attempt (legacy test hook).
    init(resolveOpenAction: @escaping ResolveOpenAction) {
        self.menuFallback = {
            guard let action = resolveOpenAction() else { return false }
            action()
            return true
        }
    }

    func registerOpenWindowAction(_ action: @escaping OpenAction) {
        registeredOpenWindowAction = action
    }

    @discardableResult
    func openSettingsWindow() -> Bool {
        if let registeredOpenWindowAction {
            registeredOpenWindowAction()
            return true
        }
        return menuFallback()
    }
}

/// Captures `@Environment(\\.openWindow)` and wires it into `SettingsWindowOpener`.
struct SettingsWindowOpenActionInstaller: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                SettingsWindowDependencies.shared.opener.registerOpenWindowAction {
                    openWindow(id: SettingsWindowSceneIDs.settings)
                }
            }
    }
}

extension SettingsWindowOpener {
    private static func openViaMainMenu() -> Bool {
        guard
            let appMenu = NSApp.mainMenu?.items.first?.submenu,
            let itemIndex = settingsItemIndex(in: appMenu)
        else {
            return false
        }

        let item = appMenu.items[itemIndex]
        let didInvokeDirectly = invokeSettingsItemAction(item)
        if didInvokeDirectly == false {
            appMenu.performActionForItem(at: itemIndex)
        }
        return true
    }

    private static func settingsItemIndex(in menu: NSMenu) -> Int? {
        if let actionMatch = menu.items.firstIndex(where: { item in
            guard let action = item.action else { return false }
            let selectorName = NSStringFromSelector(action)
            return selectorName == "showSettingsWindow:" || selectorName == "showPreferencesWindow:"
        }) {
            return actionMatch
        }

        let settingsTitles = [
            NSLocalizedString(
                "Settings\\U2026",
                tableName: "MenuCommands",
                bundle: Bundle(path: "/System/Library/Frameworks/AppKit.framework") ?? .main,
                comment: ""
            ),
            "Settings…",
            "Preferences…"
        ]

        return menu.items.firstIndex(where: { settingsTitles.contains($0.title) })
    }

    @discardableResult
    static func invokeSettingsItemAction(_ item: NSMenuItem) -> Bool {
        guard let action = item.action else { return false }

        if NSApp.sendAction(action, to: item.target, from: nil) {
            return true
        }

        if NSApp.sendAction(action, to: nil, from: nil) {
            return true
        }

        guard let target = item.target as? NSObject else { return false }
        guard target.responds(to: action) else { return false }
        _ = target.perform(action, with: nil)
        return true
    }
}
