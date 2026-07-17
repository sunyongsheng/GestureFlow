import AppKit
import Carbon
import XCTest
@testable import GestureFlowApp

final class LaunchReasonDetectorTests: XCTestCase {
    func testIsLaunchedAtLoginReturnsFalseWhenEventIsNil() {
        XCTAssertFalse(LaunchReasonDetector.isLaunchedAtLogin(event: nil))
    }

    func testIsLaunchedAtLoginReturnsFalseForOrdinaryOpenApplicationEvent() {
        let event = makeOpenApplicationEvent(propData: nil)

        XCTAssertFalse(LaunchReasonDetector.isLaunchedAtLogin(event: event))
    }

    func testIsLaunchedAtLoginReturnsTrueWhenPropDataIsLoginItem() {
        let propData = NSAppleEventDescriptor(enumCode: OSType(keyAELaunchedAsLogInItem))
        let event = makeOpenApplicationEvent(propData: propData)

        XCTAssertTrue(LaunchReasonDetector.isLaunchedAtLogin(event: event))
    }

    func testWasLaunchedAtLoginUsesInjectedCurrentAppleEvent() {
        let propData = NSAppleEventDescriptor(enumCode: OSType(keyAELaunchedAsLogInItem))
        let event = makeOpenApplicationEvent(propData: propData)
        let detector = LaunchReasonDetector(currentAppleEvent: { event })

        XCTAssertTrue(detector.wasLaunchedAtLogin)
    }

    func testWasLaunchedAtLoginReturnsFalseWhenInjectedEventIsNil() {
        let detector = LaunchReasonDetector(currentAppleEvent: { nil })

        XCTAssertFalse(detector.wasLaunchedAtLogin)
    }

    private func makeOpenApplicationEvent(
        propData: NSAppleEventDescriptor?
    ) -> NSAppleEventDescriptor {
        let event = NSAppleEventDescriptor(
            eventClass: AEEventClass(kCoreEventClass),
            eventID: AEEventID(kAEOpenApplication),
            targetDescriptor: nil,
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
        if let propData {
            event.setParam(propData, forKeyword: AEKeyword(keyAEPropData))
        }
        return event
    }
}
