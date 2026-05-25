import ServiceManagement
import XCTest
@testable import GestureFlowApp

final class LaunchAtLoginServiceTests: XCTestCase {
    func testIsEnabledReflectsRegisteredStatus() {
        let service = LaunchAtLoginService(statusProvider: { .enabled })

        XCTAssertTrue(service.isEnabled)

        let disabledService = LaunchAtLoginService(statusProvider: { .notRegistered })

        XCTAssertFalse(disabledService.isEnabled)
    }

    func testSetEnabledRegistersWhenTurnedOn() throws {
        var registerCount = 0
        var unregisterCount = 0
        let service = LaunchAtLoginService(
            statusProvider: { .notRegistered },
            register: { registerCount += 1 },
            unregister: { unregisterCount += 1 }
        )

        try service.setEnabled(true)

        XCTAssertEqual(registerCount, 1)
        XCTAssertEqual(unregisterCount, 0)
    }

    func testSetEnabledUnregistersWhenTurnedOff() throws {
        var registerCount = 0
        var unregisterCount = 0
        let service = LaunchAtLoginService(
            statusProvider: { .enabled },
            register: { registerCount += 1 },
            unregister: { unregisterCount += 1 }
        )

        try service.setEnabled(false)

        XCTAssertEqual(registerCount, 0)
        XCTAssertEqual(unregisterCount, 1)
    }

    func testSetEnabledPropagatesRegistrationError() {
        struct TestError: Error {}
        let service = LaunchAtLoginService(
            statusProvider: { .notRegistered },
            register: { throw TestError() },
            unregister: {}
        )

        XCTAssertThrowsError(try service.setEnabled(true)) { error in
            XCTAssertTrue(error is TestError)
        }
    }
}
