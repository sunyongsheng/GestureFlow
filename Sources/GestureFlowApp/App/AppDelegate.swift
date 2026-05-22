import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    typealias ApplicationControllerFactory = (
        SettingsSceneBridge,
        SettingsSceneOpenDriver
    ) -> any GestureFlowApplicationCoordinating

    private let makeApplicationController: ApplicationControllerFactory
    private let scheduleOnMain: (@escaping () -> Void) -> Void

    let settingsSceneBridge: SettingsSceneBridge
    let settingsSceneOpenDriver: SettingsSceneOpenDriver
    let presentationController: AppPresentationController
    private(set) var applicationController: (any GestureFlowApplicationCoordinating)?

    override init() {
        let settingsSceneBridge = SettingsSceneServices.shared.bridge
        let settingsSceneOpenDriver = SettingsSceneServices.shared.openDriver
        let presentationController = SettingsSceneServices.shared.presentationController

        self.settingsSceneBridge = settingsSceneBridge
        self.settingsSceneOpenDriver = settingsSceneOpenDriver
        self.presentationController = presentationController
        self.scheduleOnMain = { DispatchQueue.main.async(execute: $0) }
        self.makeApplicationController = Self.defaultApplicationControllerFactory(
            presentationController: presentationController,
            scheduleOnMain: self.scheduleOnMain
        )
        super.init()
    }

    init(
        settingsSceneBridge: SettingsSceneBridge = SettingsSceneServices.shared.bridge,
        settingsSceneOpenDriver: SettingsSceneOpenDriver = SettingsSceneServices.shared.openDriver,
        presentationController: AppPresentationController = SettingsSceneServices.shared.presentationController,
        scheduleOnMain: @escaping (@escaping () -> Void) -> Void = { DispatchQueue.main.async(execute: $0) },
        makeApplicationController: ApplicationControllerFactory? = nil
    ) {
        self.settingsSceneBridge = settingsSceneBridge
        self.settingsSceneOpenDriver = settingsSceneOpenDriver
        self.presentationController = presentationController
        self.scheduleOnMain = scheduleOnMain
        self.makeApplicationController = makeApplicationController ?? Self.defaultApplicationControllerFactory(
            presentationController: presentationController,
            scheduleOnMain: scheduleOnMain
        )
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = makeApplicationController(settingsSceneBridge, settingsSceneOpenDriver)
        applicationController = controller
        controller.launch()
    }
}

extension AppDelegate {
    static func defaultApplicationControllerFactory(
        presentationController: AppPresentationController,
        scheduleOnMain: @escaping (@escaping () -> Void) -> Void
    ) -> ApplicationControllerFactory {
        { bridge, openDriver in
            GestureFlowApplication(
                showSettings: makeShowSettingsHandler(
                    bridge: bridge,
                    openDriver: openDriver,
                    presentationController: presentationController,
                    scheduleOnMain: scheduleOnMain
                )
            )
        }
    }

    static func makeShowSettingsHandler(
        bridge: SettingsSceneBridge,
        openDriver: SettingsSceneOpenDriver,
        presentationController: AppPresentationController,
        scheduleOnMain: @escaping (@escaping () -> Void) -> Void
    ) -> (SettingsViewModel, SettingsPresentationSource) -> Void {
        { viewModel, source in
            presentationController.cancelPendingAccessoryFallbackIfNeeded()
            switch source {
            case .launch:
                bridge.install(viewModel: viewModel)
                scheduleOnMain {
                    presentationController.prepareToShowSettings()
                }
            case .menuBar:
                bridge.install(viewModel: viewModel)
                scheduleOnMain {
                    _ = openDriver.openSettingsWindow()
                    presentationController.prepareToShowSettings()
                }
            }
        }
    }
}
