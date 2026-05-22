import AppKit

final class SettingsSceneOpenDriver {
    typealias OpenAction = () -> Void
    typealias ResolveOpenAction = () -> OpenAction?

    private let resolveOpenAction: ResolveOpenAction

    init() {
        self.resolveOpenAction = Self.resolveFromMainMenu
    }

    init(resolveOpenAction: @escaping ResolveOpenAction) {
        self.resolveOpenAction = resolveOpenAction
    }

    @discardableResult
    func openSettingsWindow() -> Bool {
        guard let action = resolveOpenAction() else { return false }
        action()
        return true
    }
}

extension SettingsSceneOpenDriver {
    private static func resolveFromMainMenu() -> OpenAction? {
        guard
            let appMenu = NSApp.mainMenu?.items.first?.submenu,
            let itemIndex = settingsItemIndex(in: appMenu)
        else {
            return nil
        }

        let item = appMenu.items[itemIndex]

        return {
            let didInvokeDirectly = invokeSettingsItemAction(item)
            if didInvokeDirectly == false {
                appMenu.performActionForItem(at: itemIndex)
            }
        }
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
