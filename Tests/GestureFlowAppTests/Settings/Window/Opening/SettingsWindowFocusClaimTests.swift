import AppKit
import XCTest
@testable import GestureFlowApp

final class SettingsWindowFocusClaimTests: XCTestCase {
    func testBeginClaimsImmediatelyAndStopsWhenAlreadyKey() {
        let coordinator = SettingsWindowCoordinator()
        var claimCount = 0
        var scheduledDelays: [TimeInterval] = []

        SettingsWindowFocusClaim.begin(
            coordinator: coordinator,
            scheduleAfter: { delay, work in
                scheduledDelays.append(delay)
                work()
            },
            claim: { _ in
                claimCount += 1
                return true
            },
            isApplicationActive: { true },
            hasKeySettingsWindow: { _ in true }
        )

        XCTAssertEqual(claimCount, 1)
        XCTAssertTrue(scheduledDelays.isEmpty)
    }

    func testBeginRetriesWhenWindowIsNotKeyYet() {
        let coordinator = SettingsWindowCoordinator()
        var claimCount = 0
        var scheduledWorks: [() -> Void] = []
        var isKey = false

        SettingsWindowFocusClaim.begin(
            coordinator: coordinator,
            scheduleAfter: { _, work in
                scheduledWorks.append(work)
            },
            claim: { _ in
                claimCount += 1
                if claimCount >= 2 {
                    isKey = true
                }
                return true
            },
            isApplicationActive: { true },
            hasKeySettingsWindow: { _ in isKey }
        )

        XCTAssertEqual(claimCount, 1)
        XCTAssertFalse(scheduledWorks.isEmpty)

        scheduledWorks.forEach { $0() }

        XCTAssertGreaterThanOrEqual(claimCount, 2)
    }

    func testCancelPreventsScheduledRetriesFromClaiming() {
        let coordinator = SettingsWindowCoordinator()
        var claimCount = 0
        var scheduledWorks: [() -> Void] = []

        SettingsWindowFocusClaim.begin(
            coordinator: coordinator,
            scheduleAfter: { _, work in
                scheduledWorks.append(work)
            },
            claim: { _ in
                claimCount += 1
                return true
            },
            isApplicationActive: { false },
            hasKeySettingsWindow: { _ in false }
        )

        XCTAssertEqual(claimCount, 1)
        SettingsWindowFocusClaim.cancel()
        scheduledWorks.forEach { $0() }

        XCTAssertEqual(claimCount, 1)
    }
}
