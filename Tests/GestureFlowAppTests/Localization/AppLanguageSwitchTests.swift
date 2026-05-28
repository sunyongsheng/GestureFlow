import XCTest
@testable import GestureFlowApp
import GestureFlowCore

final class AppLanguageSwitchTests: XCTestCase {
    func testSetAppLanguageUpdatesLocalizationManagerAndPersistsConfiguration() throws {
        var savedConfiguration: AppConfiguration?
        let localization = LocalizationManager(language: .zhHans)
        let viewModel = SettingsViewModel(
            loadResult: ConfigurationLoadResult(
                configuration: AppConfiguration(
                    general: GeneralConfiguration(language: .zhHans)
                ),
                didRecoverFromCorruption: false,
                backupURL: nil
            ),
            gestureConfiguration: .defaultTemplate,
            isRunning: false,
            isAccessibilityTrusted: true,
            localizationManager: localization,
            saveConfiguration: { configuration in
                savedConfiguration = configuration
            },
            saveGestureConfiguration: { _ in },
            requestAccessibilityPermission: {},
            startGestureFlow: {},
            stopGestureFlow: {},
            quitApplication: {},
            pauseGestureRecognition: {},
            resumeGestureRecognition: {}
        )

        viewModel.setAppLanguage(.en)

        XCTAssertEqual(savedConfiguration?.general.language, .en)
        XCTAssertEqual(localization.string(.settingsSectionGeneral), "General")
    }
}
