import SwiftUI
import XCTest
@testable import GestureFlowApp

final class GeneralSettingsViewTests: XCTestCase {
    func testGeneralSettingsContentUsesMinimalCopy() {
        XCTAssertNil(GeneralSettingsContent.controlCardTitle)
        XCTAssertNil(GeneralSettingsContent.controlCardDescription)
        XCTAssertNil(GeneralSettingsContent.gestureRecognitionStatusText(isRunning: true))
        XCTAssertNil(GeneralSettingsContent.gestureRecognitionStatusText(isRunning: false))
        XCTAssertNil(GeneralSettingsContent.quitSectionTitle)
        XCTAssertNil(GeneralSettingsContent.quitSectionDescription)
    }

    func testSettingsPageCanBeInitializedWithContentOnly() {
        _ = SettingsPage {
            Text("Content")
        }
    }
}
