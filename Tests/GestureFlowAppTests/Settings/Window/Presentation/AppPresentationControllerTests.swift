import AppKit
import XCTest
@testable import GestureFlowApp

final class AppPresentationControllerTests: XCTestCase {
    func testPrepareToShowSettingsPromotesAccessoryAppToRegular() {
        let harness = AppPresentationControllerHarness()
        let controller = harness.makeController()

        controller.prepareToShowSettings()

        XCTAssertEqual(harness.activationPolicies, [.regular])
        XCTAssertEqual(controller.state, .promotingToForeground)
    }

    func testClosingLastSettingsWindowSchedulesAccessoryFallbackOnNextMainTurn() {
        let harness = AppPresentationControllerHarness()
        let controller = harness.makeController()
        controller.prepareToShowSettings()
        controller.handleSettingsDidAppear()

        controller.handleLastSettingsWindowDidClose()

        XCTAssertEqual(controller.state, .returningToAccessory)
        XCTAssertEqual(harness.activationPolicies, [.regular])
        XCTAssertGreaterThanOrEqual(harness.scheduledBlocks.count, 1)

        harness.runScheduledBlocksUntilDrained()

        XCTAssertEqual(harness.activationPolicies, [.regular, .accessory])
        XCTAssertEqual(controller.state, .accessoryBackground)
    }

    func testReopenBeforeFallbackCancelsAccessoryFallback() {
        let harness = AppPresentationControllerHarness()
        let controller = harness.makeController()
        controller.prepareToShowSettings()
        controller.handleSettingsDidAppear()
        controller.handleLastSettingsWindowDidClose()

        controller.cancelPendingAccessoryFallbackIfNeeded()
        controller.prepareToShowSettings()
        harness.runScheduledBlocksUntilDrained()

        XCTAssertEqual(harness.activationPolicies, [.regular])
        XCTAssertEqual(controller.state, .promotingToForeground)
    }

    func testDuplicateOpenRequestsDoNotRepeatPolicyChange() {
        let harness = AppPresentationControllerHarness()
        let controller = harness.makeController()

        controller.prepareToShowSettings()
        controller.prepareToShowSettings()
        controller.handleSettingsDidAppear()
        controller.prepareToShowSettings()

        XCTAssertEqual(harness.activationPolicies, [.regular])
        XCTAssertEqual(controller.state, .foregroundSettingsVisible)
    }

    func testPrepareAfterEarlySettingsDidAppearStillPromotesToForeground() {
        let harness = AppPresentationControllerHarness()
        let controller = harness.makeController()

        controller.handleSettingsDidAppear()
        controller.prepareToShowSettings()

        XCTAssertEqual(harness.activationPolicies, [.regular])
        XCTAssertEqual(controller.state, .promotingToForeground)
    }
}

private final class AppPresentationControllerHarness {
    private(set) var activationPolicies: [NSApplication.ActivationPolicy] = []
    private(set) var scheduledBlocks: [() -> Void] = []

    func makeController() -> AppPresentationController {
        AppPresentationController(
            application: .shared,
            setActivationPolicy: { [weak self] policy in
                self?.activationPolicies.append(policy)
                return true
            },
            scheduleOnMain: { [weak self] block in
                self?.scheduledBlocks.append(block)
            }
        )
    }

    func runScheduledBlocksUntilDrained() {
        while scheduledBlocks.isEmpty == false {
            let blocks = scheduledBlocks
            scheduledBlocks.removeAll()
            blocks.forEach { $0() }
        }
    }
}
