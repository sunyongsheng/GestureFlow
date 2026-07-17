import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    typealias ApplicationControllerFactory = (
        SettingsWindowCoordinator,
        SettingsWindowOpener
    ) -> any GestureFlowApplicationCoordinating

    private let makeApplicationController: ApplicationControllerFactory
    private let scheduleOnMain: (@escaping () -> Void) -> Void
    private let launchReasonDetector: LaunchReasonDetecting

    let settingsCoordinator: SettingsWindowCoordinator
    let settingsOpener: SettingsWindowOpener
    let presentationController: AppPresentationController
    private(set) var applicationController: (any GestureFlowApplicationCoordinating)?

    override init() {
        let dependencies = SettingsWindowDependencies.shared
        self.settingsCoordinator = dependencies.coordinator
        self.settingsOpener = dependencies.opener
        self.presentationController = dependencies.presentationController
        self.scheduleOnMain = { DispatchQueue.main.async(execute: $0) }
        self.launchReasonDetector = LaunchReasonDetector()
        self.makeApplicationController = Self.defaultApplicationControllerFactory(
            dependencies: dependencies,
            scheduleOnMain: self.scheduleOnMain
        )
        super.init()
    }

    init(
        settingsCoordinator: SettingsWindowCoordinator = SettingsWindowDependencies.shared.coordinator,
        settingsOpener: SettingsWindowOpener = SettingsWindowDependencies.shared.opener,
        presentationController: AppPresentationController = SettingsWindowDependencies.shared.presentationController,
        scheduleOnMain: @escaping (@escaping () -> Void) -> Void = { DispatchQueue.main.async(execute: $0) },
        launchReasonDetector: LaunchReasonDetecting = LaunchReasonDetector(),
        makeApplicationController: ApplicationControllerFactory? = nil
    ) {
        self.settingsCoordinator = settingsCoordinator
        self.settingsOpener = settingsOpener
        self.presentationController = presentationController
        self.scheduleOnMain = scheduleOnMain
        self.launchReasonDetector = launchReasonDetector
        self.makeApplicationController = makeApplicationController ?? Self.defaultApplicationControllerFactory(
            coordinator: settingsCoordinator,
            opener: settingsOpener,
            presentationController: presentationController,
            scheduleOnMain: scheduleOnMain
        )
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = makeApplicationController(settingsCoordinator, settingsOpener)
        applicationController = controller
        controller.launch(
            shouldPresentSettingsOnLaunch: SettingsPresentationFlow.shouldPresentSettingsOnLaunch(
                detector: launchReasonDetector
            )
        )
    }
}

extension AppDelegate {
    static func defaultApplicationControllerFactory(
        dependencies: SettingsWindowDependencies,
        scheduleOnMain: @escaping (@escaping () -> Void) -> Void
    ) -> ApplicationControllerFactory {
        defaultApplicationControllerFactory(
            coordinator: dependencies.coordinator,
            opener: dependencies.opener,
            presentationController: dependencies.presentationController,
            scheduleOnMain: scheduleOnMain
        )
    }

    static func defaultApplicationControllerFactory(
        coordinator: SettingsWindowCoordinator,
        opener: SettingsWindowOpener,
        presentationController: AppPresentationController,
        scheduleOnMain: @escaping (@escaping () -> Void) -> Void
    ) -> ApplicationControllerFactory {
        { injectedCoordinator, injectedOpener in
            GestureFlowApplication(
                showSettings: makeShowSettingsHandler(
                    coordinator: injectedCoordinator,
                    opener: injectedOpener,
                    presentationController: presentationController,
                    scheduleOnMain: scheduleOnMain
                )
            )
        }
    }

    static func makeShowSettingsHandler(
        coordinator: SettingsWindowCoordinator,
        opener: SettingsWindowOpener,
        presentationController: AppPresentationController,
        scheduleOnMain: @escaping (@escaping () -> Void) -> Void
    ) -> (SettingsViewModel, SettingsPresentationSource) -> Void {
        { viewModel, source in
            SettingsWindowDependencies.presentSettings(
                viewModel: viewModel,
                source: source,
                coordinator: coordinator,
                opener: opener,
                presentationController: presentationController,
                scheduleOnMain: scheduleOnMain
            )
        }
    }
}
