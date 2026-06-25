import AppKit
import Combine

enum StatusBarMenuItemTag: Int {
    case gestureFlow = 1001
    case settings = 1002
    case quit = 1003
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
    private let localization: LocalizationManager
    private let scheduleOnMain: (@escaping () -> Void) -> Void
    private let menu = NSMenu()
    private var dismissMenuTracking: () -> Void
    private var languageObserver: AnyCancellable?
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
        localization: LocalizationManager,
        scheduleOnMain: @escaping (@escaping () -> Void) -> Void = { DispatchQueue.main.async(execute: $0) }
    ) {
        self.statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        self.actions = actions
        self.localization = localization
        self.scheduleOnMain = scheduleOnMain
        self.dismissMenuTracking = {}
        super.init()
        configureStatusItem()
        configureMenu()
        languageObserver = localization.objectWillChange.sink { [weak self] _ in
            self?.refreshLocalizedStrings()
        }
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

    var isVisible: Bool {
        get { statusItem.isVisible }
        set { statusItem.isVisible = newValue }
    }

    func update(state: StatusBarState) {
        menuState = state
        if let gestureFlowItem = menu.item(withTag: StatusBarMenuItemTag.gestureFlow.rawValue) {
            gestureFlowItem.title = state.isRunning
                ? localization.string(.statusBarStop)
                : localization.string(.statusBarStart)
            gestureFlowItem.isEnabled = true
        }
        applyStatusItemIcon(isRunning: state.isRunning)
        statusItem.button?.toolTip = localization.string(.statusBarToolTip)
    }

    func refreshLocalizedStrings() {
        if let settingsItem = menu.item(withTag: StatusBarMenuItemTag.settings.rawValue) {
            settingsItem.title = localization.string(.statusBarSettings)
        }
        if let quitItem = menu.item(withTag: StatusBarMenuItemTag.quit.rawValue) {
            quitItem.title = localization.string(.statusBarQuit)
        }
        update(state: menuState)
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
        applyStatusItemIcon(isRunning: menuState.isRunning)
        statusItem.button?.toolTip = localization.string(.statusBarToolTip)
        statusItem.menu = menu
    }

    private func applyStatusItemIcon(isRunning: Bool) {
        statusItem.button?.title = ""
        statusItem.button?.image = StatusBarIcon.image(isRunning: isRunning)
        statusItem.button?.imagePosition = .imageOnly
    }

    private func configureMenu() {
        menu.delegate = self
        menu.removeAllItems()
        addItem(
            title: localization.string(.statusBarStart),
            action: #selector(toggleGestureFlow),
            tag: StatusBarMenuItemTag.gestureFlow.rawValue
        )
        addItem(
            title: localization.string(.statusBarSettings),
            action: #selector(openSettingsMenuItem),
            tag: StatusBarMenuItemTag.settings.rawValue
        )
        menu.addItem(.separator())
        addItem(
            title: localization.string(.statusBarQuit),
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
