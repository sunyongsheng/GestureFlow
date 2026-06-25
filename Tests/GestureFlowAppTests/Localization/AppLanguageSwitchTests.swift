import XCTest
@testable import GestureFlowApp
import GestureFlowCore

final class AppLanguageSwitchTests: XCTestCase {
    func testSetAppLanguageUpdatesLocalizationManager() throws {
        let defaults = UserDefaults(suiteName: "test.\(UUID())")!
        defaults.set([AppLanguage.zhHans.rawValue], forKey: LocalizationManager.defaultsKey)
        let localization = LocalizationManager(defaults: defaults)
        let viewModel = SettingsViewModel(
            loadResult: ConfigurationLoadResult(
                configuration: AppConfiguration(),
                didRecoverFromCorruption: false,
                backupURL: nil
            ),
            gestureConfiguration: .defaultTemplate,
            isRunning: false,
            isAccessibilityTrusted: true,
            localizationManager: localization,
            saveConfiguration: { _ in },
            saveGestureConfiguration: { _ in },
            requestAccessibilityPermission: {},
            startGestureFlow: {},
            stopGestureFlow: {},
            quitApplication: {},
            pauseGestureRecognition: {},
            resumeGestureRecognition: {}
        )

        viewModel.setAppLanguage(.en)

        XCTAssertEqual(localization.language, .en)
        XCTAssertEqual(localization.string(.settingsSectionGeneral), "General")
    }
}
