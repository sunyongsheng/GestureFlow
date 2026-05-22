import XCTest
@testable import GestureFlowApp

final class PermissionServiceTests: XCTestCase {
    func testReportsAccessibilityTrustFromInjectedCheck() {
        let trustedService = PermissionService(
            trustCheck: { true },
            permissionPrompt: {}
        )
        let untrustedService = PermissionService(
            trustCheck: { false },
            permissionPrompt: {}
        )

        XCTAssertTrue(trustedService.isAccessibilityTrusted)
        XCTAssertFalse(untrustedService.isAccessibilityTrusted)
    }

    func testPromptForAccessibilityPermissionUsesInjectedPrompt() {
        var promptCount = 0
        let service = PermissionService(
            trustCheck: { false },
            permissionPrompt: { promptCount += 1 }
        )

        service.promptForAccessibilityPermission()

        XCTAssertEqual(promptCount, 1)
    }
}
