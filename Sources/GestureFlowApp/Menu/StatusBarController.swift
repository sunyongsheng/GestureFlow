import AppKit

enum StatusBarMenuItemTag: Int {
    case gestureFlow = 1001
    case settings = 1002
    case quit = 1003
}

private enum StatusBarMenuCopy {
    static let startGestureFlow = "启动 GestureFlow"
    static let stopGestureFlow = "停止 GestureFlow"
    static let settings = "设置…"
    static let quit = "退出"
    static let statusItemTitle = "GF"
    static let statusItemTitleRunning = "GF 开"
    static let statusItemToolTip = "GestureFlow 手势控制"
}

struct StatusBarState: Equatable {
    var isRunning: Bool
    var isAccessibilityTrusted: Bool
}

struct StatusBarActions {
    var start: () -> Void
    var stop: () -> Void
    var openSettings: () -> Void
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
        scheduleOnMain: @escaping (@escaping () -> Void) -> Void = { DispatchQueue.main.async(execute: $0) }
    ) {
        self.statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        self.actions = actions
        self.scheduleOnMain = scheduleOnMain
        self.dismissMenuTracking = {}
        super.init()
        configureStatusItem()
        configureMenu()
        self.dismissMenuTracking = { [weak menu = self.menu] in
            menu?.cancelTracking()
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
            gestureFlowItem.title = state.isRunning
                ? StatusBarMenuCopy.stopGestureFlow
                : StatusBarMenuCopy.startGestureFlow
            gestureFlowItem.isEnabled = true
        }
        statusItem.button?.title = state.isRunning
            ? StatusBarMenuCopy.statusItemTitleRunning
            : StatusBarMenuCopy.statusItemTitle
        statusItem.button?.toolTip = StatusBarMenuCopy.statusItemToolTip
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

    func simulateDeferredSettingsDispatchForTesting() {
        deferMenuAction(tag: .settings)
    }

    private func configureStatusItem() {
        statusItem.button?.title = StatusBarMenuCopy.statusItemTitle
        statusItem.button?.toolTip = StatusBarMenuCopy.statusItemToolTip
        statusItem.menu = menu
    }

    private func configureMenu() {
        menu.delegate = self
        addItem(
            title: StatusBarMenuCopy.startGestureFlow,
            action: #selector(toggleGestureFlow),
            tag: StatusBarMenuItemTag.gestureFlow.rawValue
        )
        addItem(
            title: StatusBarMenuCopy.settings,
            action: #selector(openSettingsMenuItem),
            tag: StatusBarMenuItemTag.settings.rawValue
        )
        menu.addItem(.separator())
        addItem(
            title: StatusBarMenuCopy.quit,
            action: #selector(quit),
            tag: StatusBarMenuItemTag.quit.rawValue
        )
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
        case .settings:
            actions.openSettings()
        case .quit:
            actions.quit()
        case nil:
            break
        }
    }

    @objc private func toggleGestureFlow(_ sender: NSMenuItem) {
        handleMenuItem(sender)
    }

    @objc func openSettingsMenuItem(_ sender: NSMenuItem) {
        sender.image = nil
        dismissMenuTracking()
        deferMenuAction(tag: .settings)
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

    @objc private func quit(_ sender: NSMenuItem) {
        handleMenuItem(sender)
    }
}
