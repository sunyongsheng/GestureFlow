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
            ConfigurationDirectoryResolver.xdgConfigurationDirectoryDisplayPath
        )
        XCTAssertEqual(viewModel.persistedConfigurationDirectoryPath, "~/other/GestureFlow")
        XCTAssertTrue(viewModel.canConfirmConfigurationDirectoryChange)
    }

    func testConfirmEnabledWhenDraftDiffersFromPersistedPath() {
        let viewModel = makeViewModel(configurationDirectoryPath: "~/sync/GestureFlow")
        viewModel.draftConfigurationDirectoryPath = "~/other/GestureFlow"

        XCTAssertTrue(viewModel.canConfirmConfigurationDirectoryChange)
    }

    func testConfirmRelocationInvokesActionAndUpdatesPersistedPath() {
        var relocatedPath: String?
        let viewModel = makeViewModel(
            configurationDirectoryPath: "~/old",
            relocateConfigurationDirectory: { path in
                relocatedPath = path
            }
        )
        viewModel.draftConfigurationDirectoryPath = "~/new"

        viewModel.confirmConfigurationDirectoryChange()

        XCTAssertEqual(relocatedPath, "~/new")
        XCTAssertEqual(viewModel.persistedConfigurationDirectoryPath, "~/new")
        XCTAssertNil(viewModel.configurationDirectoryErrorMessage)
    }

    func testConfirmRelocationSurfacesErrorMessage() {
        let viewModel = makeViewModel(
            configurationDirectoryPath: "~/old",
            relocateConfigurationDirectory: { _ in
                throw ConfigurationDirectoryRelocationError.targetContainsConfigurationFiles
            }
        )
        viewModel.draftConfigurationDirectoryPath = "~/new"

        viewModel.confirmConfigurationDirectoryChange()

        XCTAssertEqual(
            viewModel.configurationDirectoryErrorMessage,
            ConfigurationDirectoryRelocationError.targetContainsConfigurationFiles.localizedDescription
        )
        XCTAssertEqual(viewModel.persistedConfigurationDirectoryPath, "~/old")
    }

    private func makeViewModel(
        configurationDirectoryPath: String = "~",
        relocateConfigurationDirectory: @escaping (String) throws -> Void = { _ in }
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
            requestAccessibilityPermission: {}
        )
    }
}
