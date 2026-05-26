import AppKit
import XCTest
@testable import GestureFlowApp
import GestureFlowCore

final class GestureOverlayWindowTests: XCTestCase {
    func testOverlayPanelDisablesWindowAnimations() throws {
        let overlayWindow = GestureOverlayWindow()
        let panel = try XCTUnwrap(extractPanel(from: overlayWindow))

        XCTAssertEqual(panel.animationBehavior, .none)
    }

    func testScreenPointConversionUsesWindowAndViewCoordinateConversion() {
        let panel = NSPanel(
            contentRect: NSRect(x: 100, y: 200, width: 400, height: 300),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        let overlayView = GestureOverlayView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        panel.contentView = overlayView

        let localPoint = GestureOverlayCoordinateConverter.localPoint(
            fromScreen: GesturePoint(x: 250, y: 420),
            panel: panel,
            view: overlayView
        )

        XCTAssertEqual(localPoint, GesturePoint(x: 150, y: 80))
    }

    func testScreenRectConversionUsesWindowAndViewCoordinateConversion() {
        let panel = NSPanel(
            contentRect: NSRect(x: 100, y: 200, width: 400, height: 300),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        let overlayView = GestureOverlayView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        panel.contentView = overlayView

        let localRect = GestureOverlayCoordinateConverter.localRect(
            fromScreen: CGRect(x: 180, y: 320, width: 120, height: 44),
            panel: panel,
            view: overlayView
        )

        XCTAssertEqual(localRect.origin.x, 80, accuracy: 0.001)
        XCTAssertEqual(localRect.origin.y, 136, accuracy: 0.001)
        XCTAssertEqual(localRect.width, 120, accuracy: 0.001)
        XCTAssertEqual(localRect.height, 44, accuracy: 0.001)
    }

    func testShowMarkerUsesWindowAndViewCoordinateConversion() {
        let overlayWindow = GestureOverlayWindow()

        overlayWindow.showMarker(
            GestureOverlayMarker(
                point: GesturePoint(x: 250, y: 420),
                style: .timeoutOrigin
            ),
            appearance: GestureTrailAppearance(feedback: .default)
        )

        let overlayView = extractOverlayView(from: overlayWindow)
        let marker = extractMarker(from: overlayView)

        XCTAssertEqual(marker?.style, .timeoutOrigin)
        XCTAssertEqual(marker?.point, GestureOverlayCoordinateConverter.localPoint(
            fromScreen: GesturePoint(x: 250, y: 420),
            panel: extractPanel(from: overlayWindow)!,
            view: overlayView
        ))
    }

    func testCompletingGestureShowsDedicatedFeedbackCard() throws {
        let overlayWindow = GestureOverlayWindow()
        let origin = GesturePoint(x: 250, y: 420)

        overlayWindow.beginGesture(
            at: origin,
            appearance: GestureTrailAppearance(feedback: .default)
        )
        overlayWindow.completeGesture(
            with: .recognized(name: "关闭窗口"),
            at: origin,
            hideAfter: TimeInterval(FeedbackConfiguration.default.overlayHideDelayMilliseconds) / 1000
        )

        let overlayView = extractOverlayView(from: overlayWindow)
        let feedbackCardView = try XCTUnwrap(extractFeedbackCardView(from: overlayView))
        let messageLabel = try XCTUnwrap(extractFeedbackMessageLabel(from: feedbackCardView))

        XCTAssertFalse(feedbackCardView.isHidden)
        XCTAssertEqual(messageLabel.stringValue, "关闭窗口")
    }

    func testActionFailedCompletionShowsMatchedGestureName() throws {
        let overlayWindow = GestureOverlayWindow()
        let origin = GesturePoint(x: 250, y: 420)

        overlayWindow.beginGesture(
            at: origin,
            appearance: GestureTrailAppearance(feedback: .default)
        )
        overlayWindow.completeGesture(
            with: .actionFailed(displayName: "关闭窗口"),
            at: origin,
            hideAfter: TimeInterval(FeedbackConfiguration.default.overlayHideDelayMilliseconds) / 1000
        )

        let overlayView = extractOverlayView(from: overlayWindow)
        let feedbackCardView = try XCTUnwrap(extractFeedbackCardView(from: overlayView))
        let messageLabel = try XCTUnwrap(extractFeedbackMessageLabel(from: feedbackCardView))

        XCTAssertFalse(feedbackCardView.isHidden)
        XCTAssertEqual(messageLabel.stringValue, "关闭窗口")
    }

    func testFeedbackCardCentersMessageLabelWithinCard() throws {
        let overlayWindow = GestureOverlayWindow()
        let origin = GesturePoint(x: 250, y: 420)

        overlayWindow.beginGesture(
            at: origin,
            appearance: GestureTrailAppearance(feedback: .default)
        )
        overlayWindow.completeGesture(
            with: .unmatched,
            at: origin,
            hideAfter: TimeInterval(FeedbackConfiguration.default.overlayHideDelayMilliseconds) / 1000
        )

        let overlayView = extractOverlayView(from: overlayWindow)
        let feedbackCardView = try XCTUnwrap(extractFeedbackCardView(from: overlayView))
        let messageLabel = try XCTUnwrap(extractFeedbackMessageLabel(from: feedbackCardView))
        feedbackCardView.layoutSubtreeIfNeeded()

        XCTAssertEqual(messageLabel.frame.midY, feedbackCardView.bounds.midY, accuracy: 1.0)
        XCTAssertLessThanOrEqual(messageLabel.frame.height, messageLabel.fittingSize.height + 1.0)
    }

    private func extractPanel(from overlayWindow: GestureOverlayWindow) -> NSPanel? {
        Mirror(reflecting: overlayWindow).children
            .first(where: { $0.label == "panel" })?
            .value as? NSPanel
    }

    private func extractOverlayView(from overlayWindow: GestureOverlayWindow) -> GestureOverlayView {
        Mirror(reflecting: overlayWindow).children
            .first(where: { $0.label == "overlayView" })?
            .value as! GestureOverlayView
    }

    private func extractMarker(from overlayView: GestureOverlayView) -> GestureOverlayMarker? {
        Mirror(reflecting: overlayView).children
            .first(where: { $0.label == "marker" })?
            .value as? GestureOverlayMarker
    }

    private func extractFeedbackCardView(from overlayView: GestureOverlayView) -> NSView? {
        Mirror(reflecting: overlayView).children
            .first(where: { $0.label == "feedbackCardView" })?
            .value as? NSView
    }

    private func extractFeedbackMessageLabel(from feedbackCardView: NSView) -> NSTextField? {
        Mirror(reflecting: feedbackCardView).children
            .first(where: { $0.label == "messageLabel" })?
            .value as? NSTextField
    }
}
