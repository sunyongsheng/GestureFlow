import AppKit

enum StatusBarMenuItemTag: Int {
    case gestureFlow = 1001
    case openSettings = 1002
    case commonGestures = 1003
    case preferences = 1004
    case accessibilityPermission = 1005
    case quit = 1006
}

struct StatusBarState: Equatable {
    var isRunning: Bool
    var isAccessibilityTrusted: Bool
}

struct StatusBarActions {
    var start: () -> Void
    var stop: () -> Void
    var openSettings: () -> Void
    var showCommonGestures: () -> Void
    var showPreferences: () -> Void
    var requestAccessibilityPermission: () -> Void
    var quit: () -> Void
}

final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let actions: StatusBarActions
    private let scheduleOnMain: (@escaping () -> Void) -> Void
    private let menu = NSMenu()
    private var dismissMenuTracking: () -> Void
    private(set) var menuState = StatusBarState(
        isRunning: false,
        isAccessibilityTrusted: false
    )

    var menuItemTitles: [String] {
        menu.items.compactMap { $0.isSeparatorItem ? nil : $0.title }
    }

    init(
        statusBar: NSStatusBar = .system,
        actions: StatusBarActions,
        scheduleOnMain: @escaping (@escaping () -> Void) -> Void = { DispatchQueue.main.async(execute: $0) },
        dismissMenuTracking: (() -> Void)? = nil
    ) {
        self.statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        self.actions = actions
        self.scheduleOnMain = scheduleOnMain
        self.dismissMenuTracking = dismissMenuTracking ?? {}
        super.init()
        configureStatusItem()
        configureMenu()
        if dismissMenuTracking == nil {
            self.dismissMenuTracking = { [weak menu = self.menu] in
                menu?.cancelTracking()
            }
        }
    }

    deinit {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func performMenuItem(title: String) {
        guard let item = menu.item(withTitle: title) else { return }
        handleMenuItem(item)
    }

    func performMenuItem(tag: StatusBarMenuItemTag) {
        guard let item = menu.item(withTag: tag.rawValue) else { return }
        handleMenuItem(item)
    }

    func update(state: StatusBarState) {
        menuState = state
        if let gestureFlowItem = menu.item(withTag: StatusBarMenuItemTag.gestureFlow.rawValue) {
            gestureFlowItem.title = state.isRunning ? "Stop GestureFlow" : "Start GestureFlow"
            gestureFlowItem.isEnabled = true
        }
        menu.item(withTag: StatusBarMenuItemTag.accessibilityPermission.rawValue)?.isEnabled = !state.isAccessibilityTrusted
        statusItem.button?.title = state.isRunning ? "GF On" : "GF"
    }

    func isMenuItemEnabled(title: String) -> Bool {
        menu.item(withTitle: title)?.isEnabled ?? false
    }

    func isMenuItemEnabled(tag: StatusBarMenuItemTag) -> Bool {
        menu.item(withTag: tag.rawValue)?.isEnabled ?? false
    }

    func menuItemAction(tag: StatusBarMenuItemTag) -> Selector? {
        menu.item(withTag: tag.rawValue)?.action
    }

    func simulateDeferredPreferencesDispatchForTesting() {
        deferMenuAction(tag: .preferences)
    }

    private func configureStatusItem() {
        statusItem.button?.title = "GF"
        statusItem.button?.toolTip = "GestureFlow"
        statusItem.menu = menu
    }

    private func configureMenu() {
        menu.delegate = self
        addItem(
            title: "Start GestureFlow",
            action: #selector(toggleGestureFlow),
            tag: StatusBarMenuItemTag.gestureFlow.rawValue
        )
        addItem(
            title: "Preferences",
            action: #selector(openSettingsMenuItem),
            tag: StatusBarMenuItemTag.preferences.rawValue
        )
        menu.addItem(.separator())
        addItem(title: "Quit", action: #selector(quit), tag: StatusBarMenuItemTag.quit.rawValue)
    }

    private func addItem(title: String, action: Selector, tag: Int = 0) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.tag = tag
        menu.addItem(item)
    }

    private func handleMenuItem(_ item: NSMenuItem) {
        switch StatusBarMenuItemTag(rawValue: item.tag) {
        case .gestureFlow:
            if menuState.isRunning {
                actions.stop()
            } else {
                actions.start()
            }
        case .openSettings:
            actions.openSettings()
        case .commonGestures:
            actions.showCommonGestures()
        case .preferences:
            actions.openSettings()
        case .accessibilityPermission:
            actions.requestAccessibilityPermission()
        case .quit:
            actions.quit()
        case nil:
            break
        }
    }

    @objc private func toggleGestureFlow(_ sender: NSMenuItem) {
        handleMenuItem(sender)
    }

    @objc private func openSettings(_ sender: NSMenuItem) {
        handleMenuItem(sender)
    }

    @objc func openSettingsMenuItem(_ sender: NSMenuItem) {
        sender.image = nil
        dismissMenuTracking()
        deferMenuAction(tag: .preferences)
    }

    func menuDidClose(_ menu: NSMenu) {}

    private func deferMenuAction(tag: StatusBarMenuItemTag) {
        guard let item = self.menu.item(withTag: tag.rawValue) else { return }
        scheduleOnMain { [weak self] in
            guard let self else { return }
            self.scheduleOnMain { [weak self] in
                guard let self else { return }
                self.handleMenuItem(item)
            }
        }
    }

    @objc private func showCommonGestures(_ sender: NSMenuItem) {
        handleMenuItem(sender)
    }

    @objc private func showPreferences(_ sender: NSMenuItem) {
        handleMenuItem(sender)
    }

    @objc private func requestAccessibilityPermission(_ sender: NSMenuItem) {
        handleMenuItem(sender)
    }

    @objc private func quit(_ sender: NSMenuItem) {
        handleMenuItem(sender)
    }
}
