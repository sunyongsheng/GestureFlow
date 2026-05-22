final class SettingsSceneServices {
    static let shared = SettingsSceneServices()

    let bridge: SettingsSceneBridge
    let openDriver: SettingsSceneOpenDriver
    let presentationController: AppPresentationController

    init(
        bridge: SettingsSceneBridge = SettingsSceneBridge(),
        openDriver: SettingsSceneOpenDriver = SettingsSceneOpenDriver(),
        presentationController: AppPresentationController = AppPresentationController()
    ) {
        self.bridge = bridge
        self.openDriver = openDriver
        self.presentationController = presentationController
        self.bridge.onSettingsDidAppear = { [weak presentationController] in
            presentationController?.handleSettingsDidAppear()
        }
        self.bridge.onLastSettingsWindowDidClose = { [weak presentationController] in
            presentationController?.handleLastSettingsWindowDidClose()
        }
    }
}
