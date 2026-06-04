import XCTest
@testable import GestureFlowApp

final class UpdateSchedulerTests: XCTestCase {
    func testShouldCheckWhenNeverCheckedBefore() {
        let scheduler = UpdateScheduler(interval: 7 * 24 * 60 * 60, now: { Date() })
        XCTAssertTrue(scheduler.shouldPerformCheck(lastCheckDate: nil))
    }

    func testShouldNotCheckWithinInterval() {
        let now = Date()
        let scheduler = UpdateScheduler(interval: 7 * 24 * 60 * 60, now: { now })
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: now)!
        XCTAssertFalse(scheduler.shouldPerformCheck(lastCheckDate: threeDaysAgo))
    }

    func testShouldCheckAfterInterval() {
        let now = Date()
        let scheduler = UpdateScheduler(interval: 7 * 24 * 60 * 60, now: { now })
        let eightDaysAgo = Calendar.current.date(byAdding: .day, value: -8, to: now)!
        XCTAssertTrue(scheduler.shouldPerformCheck(lastCheckDate: eightDaysAgo))
    }
}
