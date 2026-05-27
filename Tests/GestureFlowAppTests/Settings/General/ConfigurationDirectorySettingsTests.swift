import XCTest
@testable import GestureFlowApp
import GestureFlowCore

final class ConfigurationDirectorySettingsTests: XCTestCase {
    func testConfirmDisabledWhenDraftMatchesPersistedPath() {
        let viewModel = makeViewModel(configurationDirectoryPath: "~/sync/GestureFlow")

        XCTAssertFalse(viewModel.canConfirmConfigurationDirectoryChange)
    }

    func testPrefillDefaultUpdatesDraftWithoutChangingPersistedPath() {
        let viewModel = makeViewModel(configurationDirectoryPath: "~/other/GestureFlow")

        viewModel.prefillDefaultConfigurationDirectory()

        XCTAssertEqual(
            viewModel.draftConfigurationDirectoryPath,
            ConfigurationDirectoryResolver.defaultConfigurationDirectoryDisplayPath
        )
        XCTAssertEqual(viewModel.persistedConfigurationDirectoryPath, "~/other/GestureFlow")
        XCTAssertTrue(viewModel.canConfirmConfigurationDirectoryChange)
    }

    func testPrefillXDGUpdatesDraftWithoutChangingPersistedPath() {
        let viewModel = makeViewModel(configurationDirectoryPath: "~/other/GestureFlow")

        viewModel.prefillXDGConfigurationDirectory()

        XCTAssertEqual(
            viewModel.draftConfigurationDirectoryPath,
            ConfigurationDirectoryResolver.xdgConfigurationDirectoryDisplayPath(environment: [:])
        )
        XCTAssertEqual(viewModel.persistedConfigurationDirectoryPath, "~/other/GestureFlow")
        XCTAssertTrue(viewModel.canConfirmConfigurationDirectoryChange)
    }

    func testConfirmEnabledWhenDraftDiffersFromPersistedPath() {
        let viewModel = makeViewModel(configurationDirectoryPath: "~/sync/GestureFlow")
        viewModel.draftConfigurationDirectoryPath = "~/other/GestureFlow"

        XCTAssertTrue(viewModel.canConfirmConfigurationDirectoryChange)
    }

    func testConfirmRelocationInvokesCopyModeAndUpdatesPersistedPath() {
        var relocatedPath: String?
        var relocationMode: ConfigurationDirectoryRelocationMode?
        let viewModel = makeViewModel(
            configurationDirectoryPath: "~/old",
            relocateConfigurationDirectory: { path, mode in
                relocatedPath = path
                relocationMode = mode
            }
        )
        viewModel.draftConfigurationDirectoryPath = "~/new"

        viewModel.confirmConfigurationDirectoryChange()

        XCTAssertEqual(relocatedPath, "~/new")
        XCTAssertEqual(relocationMode, .copyCurrentToEmptyTarget)
        XCTAssertEqual(viewModel.persistedConfigurationDirectoryPath, "~/new")
        XCTAssertNil(viewModel.configurationDirectoryErrorMessage)
    }

    func testConfirmShowsAdoptionAlertWhenTargetHasConfigurationFiles() {
        var relocationInvoked = false
        let viewModel = makeViewModel(
            configurationDirectoryPath: "~/old",
            targetHasConfigurationFiles: { _ in true },
            relocateConfigurationDirectory: { _, _ in
                relocationInvoked = true
            }
        )
        viewModel.draftConfigurationDirectoryPath = "~/new"

        viewModel.confirmConfigurationDirectoryChange()

        XCTAssertTrue(viewModel.isConfigurationDirectoryAdoptionAlertPresented)
        XCTAssertFalse(relocationInvoked)
        XCTAssertEqual(viewModel.persistedConfigurationDirectoryPath, "~/old")
    }

    func testCancelAdoptionAlertDoesNotRelocate() {
        var relocationInvoked = false
        let viewModel = makeViewModel(
            configurationDirectoryPath: "~/old",
            targetHasConfigurationFiles: { _ in true },
            relocateConfigurationDirectory: { _, _ in
                relocationInvoked = true
            }
        )
        viewModel.draftConfigurationDirectoryPath = "~/new"
        viewModel.confirmConfigurationDirectoryChange()

        viewModel.cancelConfigurationDirectoryAdoption()

        XCTAssertFalse(viewModel.isConfigurationDirectoryAdoptionAlertPresented)
        XCTAssertFalse(relocationInvoked)
        XCTAssertEqual(viewModel.persistedConfigurationDirectoryPath, "~/old")
        XCTAssertNil(viewModel.configurationDirectoryErrorMessage)
    }

    func testConfirmAdoptionInvokesAdoptModeAndUpdatesPersistedPath() {
        var relocatedPath: String?
        var relocationMode: ConfigurationDirectoryRelocationMode?
        let viewModel = makeViewModel(
            configurationDirectoryPath: "~/old",
            targetHasConfigurationFiles: { _ in true },
            relocateConfigurationDirectory: { path, mode in
                relocatedPath = path
                relocationMode = mode
            }
        )
        viewModel.draftConfigurationDirectoryPath = "~/new"
        viewModel.confirmConfigurationDirectoryChange()

        viewModel.confirmConfigurationDirectoryAdoption()

        XCTAssertEqual(relocatedPath, "~/new")
        XCTAssertEqual(relocationMode, .adoptTargetAndMergeMissing)
        XCTAssertEqual(viewModel.persistedConfigurationDirectoryPath, "~/new")
        XCTAssertFalse(viewModel.isConfigurationDirectoryAdoptionAlertPresented)
    }

    func testConfirmAdoptionSurfacesValidationErrorWithoutUpdatingPersistedPath() {
        let viewModel = makeViewModel(
            configurationDirectoryPath: "~/old",
            targetHasConfigurationFiles: { _ in true },
            relocateConfigurationDirectory: { _, _ in
                throw ConfigurationDirectoryRelocationError.invalidConfigurationContent
            }
        )
        viewModel.draftConfigurationDirectoryPath = "~/new"
        viewModel.confirmConfigurationDirectoryChange()
        viewModel.confirmConfigurationDirectoryAdoption()

        XCTAssertEqual(
            viewModel.configurationDirectoryErrorMessage,
            ConfigurationDirectoryRelocationError.invalidConfigurationContent.localizedDescription
        )
        XCTAssertEqual(viewModel.persistedConfigurationDirectoryPath, "~/old")
    }

    func testConfirmRelocationSurfacesErrorMessage() {
        let viewModel = makeViewModel(
            configurationDirectoryPath: "~/old",
            relocateConfigurationDirectory: { _, _ in
                throw ConfigurationDirectoryRelocationError.copyFailed
            }
        )
        viewModel.draftConfigurationDirectoryPath = "~/new"

        viewModel.confirmConfigurationDirectoryChange()

        XCTAssertEqual(
            viewModel.configurationDirectoryErrorMessage,
            ConfigurationDirectoryRelocationError.copyFailed.localizedDescription
        )
        XCTAssertEqual(viewModel.persistedConfigurationDirectoryPath, "~/old")
    }

    private func makeViewModel(
        configurationDirectoryPath: String = "~",
        targetHasConfigurationFiles: @escaping (String) -> Bool = { _ in false },
        relocateConfigurationDirectory: @escaping (String, ConfigurationDirectoryRelocationMode) throws -> Void = { _, _ in }
    ) -> SettingsViewModel {
        SettingsViewModel(
            loadResult: ConfigurationLoadResult(
                configuration: AppConfiguration(),
                didRecoverFromCorruption: false,
                backupURL: nil
            ),
            gestureConfiguration: .defaultTemplate,
            configurationDirectoryPath: configurationDirectoryPath,
            isRunning: false,
            isAccessibilityTrusted: true,
            saveConfiguration: { _ in },
            saveGestureConfiguration: { _ in },
            relocateConfigurationDirectory: relocateConfigurationDirectory,
            targetHasConfigurationFiles: targetHasConfigurationFiles,
            requestAccessibilityPermission: {},
            startGestureFlow: {},
            stopGestureFlow: {},
            quitApplication: {},
            pauseGestureRecognition: {},
            resumeGestureRecognition: {}
        )
    }
}
