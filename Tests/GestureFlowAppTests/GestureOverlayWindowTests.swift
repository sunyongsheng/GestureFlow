import AppKit
import XCTest
@testable import GestureFlowApp
import GestureFlowCore

final class GestureOverlayWindowTests: XCTestCase {
    func testOverlayPanelDisablesWindowAnimations() throws {
        let overlayWindow = GestureOverlayWindow(localization: LocalizationManager(language: .zhHans))
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
        let overlayWindow = GestureOverlayWindow(localization: LocalizationManager(language: .zhHans))

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
        let overlayWindow = GestureOverlayWindow(localization: LocalizationManager(language: .zhHans))
        let origin = GesturePoint(x: 250, y: 420)

        overlayWindow.beginGesture(
            at: origin,
            appearance: GestureTrailAppearance(feedback: .default)
        )
        overlayWindow.completeGesture(
            with: .recognized(
                gestureID: BuiltInGestureSeeds.closeWindowID,
                storedName: "关闭窗口"
            ),
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
        let overlayWindow = GestureOverlayWindow(localization: LocalizationManager(language: .zhHans))
        let origin = GesturePoint(x: 250, y: 420)

        overlayWindow.beginGesture(
            at: origin,
            appearance: GestureTrailAppearance(feedback: .default)
        )
        overlayWindow.completeGesture(
            with: .deliveryFailed(
                gestureID: BuiltInGestureSeeds.closeWindowID,
                storedName: "关闭窗口"
            ),
            at: origin,
            hideAfter: TimeInterval(FeedbackConfiguration.default.overlayHideDelayMilliseconds) / 1000
        )

        let overlayView = extractOverlayView(from: overlayWindow)
        let feedbackCardView = try XCTUnwrap(extractFeedbackCardView(from: overlayView))
        let messageLabel = try XCTUnwrap(extractFeedbackMessageLabel(from: feedbackCardView))

        XCTAssertFalse(feedbackCardView.isHidden)
        XCTAssertEqual(messageLabel.stringValue, "关闭窗口")
    }

    func testFeedbackCardTextColorStaysLabelColorForLiveAndCompletion() throws {
        let feedback = FeedbackConfiguration(
            trailColorHex: "#FF00AA",
            trailWidth: 3,
            trailOpacity: 0.85
        )
        let appearance = GestureTrailAppearance(feedback: feedback, isHighlighted: true)
        let overlayWindow = GestureOverlayWindow(localization: LocalizationManager(language: .zhHans))
        let origin = GesturePoint(x: 250, y: 420)

        overlayWindow.beginGesture(at: origin, appearance: appearance)
        overlayWindow.updateLiveGesture(
            at: origin,
            appearance: appearance,
            feedback: LiveGestureOverlayFeedback(
                message: nil,
                matchedGestureID: BuiltInGestureSeeds.closeWindowID,
                matchedGestureStoredName: "关闭窗口",
                showsCard: true
            )
        )

        let overlayView = extractOverlayView(from: overlayWindow)
        let feedbackCardView = try XCTUnwrap(extractFeedbackCardView(from: overlayView))
        let liveLabel = try XCTUnwrap(extractFeedbackMessageLabel(from: feedbackCardView))
        let liveTextColor = try XCTUnwrap(liveLabel.textColor)
        XCTAssertTrue(liveTextColor.isEqual(NSColor.labelColor))

        overlayWindow.completeGesture(
            with: .unmatched,
            at: origin,
            hideAfter: TimeInterval(FeedbackConfiguration.default.overlayHideDelayMilliseconds) / 1000
        )

        let completionLabel = try XCTUnwrap(extractFeedbackMessageLabel(from: feedbackCardView))
        let completionTextColor = try XCTUnwrap(completionLabel.textColor)
        XCTAssertEqual(
            completionLabel.stringValue,
            LocalizationManager(language: .zhHans).string(.overlayUnmatchedGesture)
        )
        XCTAssertTrue(completionTextColor.isEqual(NSColor.labelColor))
    }

    func testUnderMouseTargetNotFoundWithoutMatchUsesUnmatchedOverlay() throws {
        let overlayWindow = GestureOverlayWindow(localization: LocalizationManager(language: .zhHans))
        let origin = GesturePoint(x: 250, y: 420)
        let appearance = GestureTrailAppearance(
            feedback: FeedbackConfiguration(
                trailColorHex: "#FF00AA",
                trailWidth: 3,
                trailOpacity: 0.85
            ),
            isHighlighted: true
        )

        overlayWindow.beginGesture(at: origin, appearance: appearance)
        overlayWindow.completeGesture(
            with: .unmatched,
            at: origin,
            hideAfter: TimeInterval(FeedbackConfiguration.default.overlayHideDelayMilliseconds) / 1000
        )

        let overlayView = extractOverlayView(from: overlayWindow)
        let feedbackCardView = try XCTUnwrap(extractFeedbackCardView(from: overlayView))
        let messageLabel = try XCTUnwrap(extractFeedbackMessageLabel(from: feedbackCardView))
        let textColor = try XCTUnwrap(messageLabel.textColor)
        XCTAssertTrue(textColor.isEqual(NSColor.labelColor))
    }

    func testFeedbackCardCentersMessageLabelWithinCard() throws {
        let overlayWindow = GestureOverlayWindow(localization: LocalizationManager(language: .zhHans))
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

        let labelMidYInCard = messageLabel.convert(
            NSPoint(x: 0, y: messageLabel.bounds.midY),
            to: feedbackCardView
        ).y
        XCTAssertEqual(labelMidYInCard, feedbackCardView.bounds.midY, accuracy: 1.0)
        XCTAssertGreaterThan(messageLabel.bounds.height, 0)
    }

    private func extractPanel(from overlayWindow: GestureOverlayWindow) -> NSPanel? {
        guard let firstOverlay = extractFirstScreenOverlay(from: overlayWindow) else { return nil }
        return Mirror(reflecting: firstOverlay).children
            .first(where: { $0.label == "panel" })?
            .value as? NSPanel
    }

    private func extractOverlayView(from overlayWindow: GestureOverlayWindow) -> GestureOverlayView {
        guard let firstOverlay = extractFirstScreenOverlay(from: overlayWindow) else {
            fatalError("No screen overlays found")
        }
        return Mirror(reflecting: firstOverlay).children
            .first(where: { $0.label == "overlayView" })?
            .value as! GestureOverlayView
    }

    private func extractFirstScreenOverlay(from overlayWindow: GestureOverlayWindow) -> Any? {
        guard let overlays = Mirror(reflecting: overlayWindow).children
            .first(where: { $0.label == "screenOverlays" })?
            .value else { return nil }
        return Mirror(reflecting: overlays).children.first?.value
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
