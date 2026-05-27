import XCTest
@testable import GestureFlowApp
import GestureFlowCore

final class CustomGestureSignatureTests: XCTestCase {
    func testCommitGestureConfigurationToDiskPersistsCustomSignatures() throws {
        var savedConfiguration: GestureConfiguration?
        let viewModel = makeViewModel(
            saveGestureConfiguration: { savedConfiguration = $0 }
        )

        viewModel.gestureConfiguration.customGestureSignatures = [
            GestureSignature(tokens: [.up, .left])
        ]
        viewModel.commitGestureConfigurationToDisk()

        XCTAssertEqual(savedConfiguration?.customGestureSignatures.count, 1)
        XCTAssertEqual(savedConfiguration?.customGestureSignatures[0].tokens, [.up, .left])
    }

    func testRestoreDefaultClearsCustomGestureSignatures() throws {
        var savedConfiguration: GestureConfiguration?
        let viewModel = makeViewModel(
            gestureConfiguration: GestureConfiguration(
                gestures: [GestureDefinition.builtInCloseWindow],
                customGestureSignatures: [GestureSignature(tokens: [.up, .left])]
            ),
            saveGestureConfiguration: { savedConfiguration = $0 }
        )

        viewModel.restoreDefaultGestureConfiguration()

        XCTAssertTrue(viewModel.gestureConfiguration.customGestureSignatures.isEmpty)
        XCTAssertTrue(savedConfiguration?.customGestureSignatures.isEmpty ?? false)
    }

    private func makeViewModel(
        gestureConfiguration: GestureConfiguration = .defaultTemplate,
        saveGestureConfiguration: @escaping (GestureConfiguration) throws -> Void = { _ in }
    ) -> SettingsViewModel {
        SettingsViewModel(
            loadResult: ConfigurationLoadResult(
                configuration: AppConfiguration(),
                didRecoverFromCorruption: false,
                backupURL: nil
            ),
            gestureConfiguration: gestureConfiguration,
            isRunning: false,
            isAccessibilityTrusted: true,
            saveConfiguration: { _ in },
            saveGestureConfiguration: saveGestureConfiguration,
            requestAccessibilityPermission: {},
            startGestureFlow: {},
            stopGestureFlow: {},
            quitApplication: {},
            pauseGestureRecognition: {},
            resumeGestureRecognition: {}
        )
    }
}
