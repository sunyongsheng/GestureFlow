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
        for liquidGlassEnabled in [false, true] {
            var feedback = FeedbackConfiguration.default
            feedback.feedbackCardLiquidGlassEnabled = liquidGlassEnabled
            let overlayWindow = GestureOverlayWindow(localization: LocalizationManager(language: .zhHans))
            let origin = GesturePoint(x: 250, y: 420)

            overlayWindow.beginGesture(
                at: origin,
                appearance: GestureTrailAppearance(feedback: feedback)
            )
            overlayWindow.completeGesture(
                with: .unmatched,
                at: origin,
                hideAfter: TimeInterval(feedback.overlayHideDelayMilliseconds) / 1000
            )

            let overlayView = extractOverlayView(from: overlayWindow)
            let feedbackCardView = try XCTUnwrap(extractFeedbackCardView(from: overlayView))
            let messageLabel = try XCTUnwrap(extractFeedbackMessageLabel(from: feedbackCardView))
            feedbackCardView.layoutSubtreeIfNeeded()

            let labelMidYInCard = messageLabel.convert(
                NSPoint(x: 0, y: messageLabel.bounds.midY),
                to: feedbackCardView
            ).y
            XCTAssertEqual(labelMidYInCard, feedbackCardView.bounds.midY, accuracy: 1.0, "liquid glass \(liquidGlassEnabled)")
            XCTAssertGreaterThan(messageLabel.bounds.height, 0, "liquid glass \(liquidGlassEnabled)")
        }
    }

    func testLiquidGlassFeedbackCardDrawsRimHighlightAboveGlass() throws {
        guard #available(macOS 26.0, *) else {
            throw XCTSkip("Liquid glass requires macOS 26")
        }
        var feedback = FeedbackConfiguration.default
        feedback.feedbackCardCornerRadius = 22
        feedback.feedbackCardLiquidGlassEnabled = true
        let appearance = GestureTrailAppearance(feedback: feedback)
        let overlayWindow = GestureOverlayWindow(localization: LocalizationManager(language: .zhHans))
        let origin = GesturePoint(x: 250, y: 420)

        overlayWindow.beginGesture(at: origin, appearance: appearance)
        overlayWindow.completeGesture(
            with: .unmatched,
            at: origin,
            hideAfter: TimeInterval(feedback.overlayHideDelayMilliseconds) / 1000
        )

        let overlayView = extractOverlayView(from: overlayWindow)
        let feedbackCardView = try XCTUnwrap(extractFeedbackCardView(from: overlayView))
        let backgroundView = try XCTUnwrap(
            Mirror(reflecting: feedbackCardView).children
                .first(where: { $0.label == "backgroundView" })?
                .value as? NSView
        )
        let glassIndex = try XCTUnwrap(backgroundView.subviews.firstIndex { $0 is NSGlassEffectView })
        let rimIndex = try XCTUnwrap(backgroundView.subviews.firstIndex { $0 is LiquidGlassRimHighlightView })
        let rimView = try XCTUnwrap(backgroundView.subviews[rimIndex] as? LiquidGlassRimHighlightView)

        XCTAssertGreaterThan(rimIndex, glassIndex)
        XCTAssertEqual(rimView.cornerRadius, 22, accuracy: 0.001)
    }

    func testFeedbackCardKeepsLongGestureNameInsideCard() throws {
        for liquidGlassEnabled in [false, true] {
            var feedback = FeedbackConfiguration.default
            feedback.feedbackCardLiquidGlassEnabled = liquidGlassEnabled
            let overlayWindow = GestureOverlayWindow(localization: LocalizationManager(language: .zhHans))
            let origin = GesturePoint(x: 250, y: 420)

            overlayWindow.beginGesture(
                at: origin,
                appearance: GestureTrailAppearance(feedback: feedback)
            )
            overlayWindow.completeGesture(
                with: .recognized(gestureID: UUID(), storedName: String(repeating: "很长的手势名称", count: 6)),
                at: origin,
                hideAfter: TimeInterval(feedback.overlayHideDelayMilliseconds) / 1000
            )

            let overlayView = extractOverlayView(from: overlayWindow)
            let feedbackCardView = try XCTUnwrap(extractFeedbackCardView(from: overlayView))
            let messageLabel = try XCTUnwrap(extractFeedbackMessageLabel(from: feedbackCardView))
            feedbackCardView.layoutSubtreeIfNeeded()

            let labelFrameInCard = messageLabel.convert(messageLabel.bounds, to: feedbackCardView)
            XCTAssertFalse(messageLabel.hasAmbiguousLayout, "liquid glass \(liquidGlassEnabled)")
            XCTAssertLessThanOrEqual(labelFrameInCard.maxX, feedbackCardView.bounds.maxX, "liquid glass \(liquidGlassEnabled)")
        }
    }

    func testTrailLayersSitBelowFeedbackCard() throws {
        let view = GestureOverlayView(
            frame: NSRect(x: 0, y: 0, width: 400, height: 300),
            localization: LocalizationManager(language: .zhHans)
        )
        let trailView = try XCTUnwrap(extractTrailView(from: view))
        let feedbackCardView = try XCTUnwrap(extractFeedbackCardView(from: view))

        XCTAssertLessThan(
            try XCTUnwrap(view.subviews.firstIndex(of: trailView)),
            try XCTUnwrap(view.subviews.firstIndex(of: feedbackCardView))
        )
        let sublayers = try XCTUnwrap(trailView.layer?.sublayers)
        XCTAssertLessThan(
            try XCTUnwrap(sublayers.firstIndex(of: trailView.outlineLayer)),
            try XCTUnwrap(sublayers.firstIndex(of: trailView.trailLayer))
        )
    }

    func testTrailLayerChangesApplyWithoutImplicitAnimation() throws {
        let overlayWindow = GestureOverlayWindow(localization: LocalizationManager(language: .zhHans))
        let overlayView = extractOverlayView(from: overlayWindow)
        let trailView = try XCTUnwrap(extractTrailView(from: overlayView))
        var feedback = FeedbackConfiguration.default
        feedback.trailOpacity = 0.6
        let point = GesturePoint(x: 300, y: 380)

        overlayWindow.beginGesture(at: GesturePoint(x: 250, y: 420), appearance: GestureTrailAppearance(feedback: feedback))
        overlayView.window?.displayIfNeeded()
        CATransaction.flush()
        overlayWindow.appendGesturePoint(point)
        overlayWindow.updateLiveGesture(
            at: point,
            appearance: GestureTrailAppearance(feedback: feedback, isHighlighted: false),
            feedback: LiveGestureOverlayFeedback(message: nil, showsCard: false)
        )
        overlayView.renderTrail()
        overlayWindow.showMarker(GestureOverlayMarker(point: point, style: .timeoutOrigin), appearance: GestureTrailAppearance(feedback: .default))

        for layer in [trailView.outlineLayer, trailView.trailLayer, trailView.markerLayer] {
            XCTAssertEqual(layer.animationKeys() ?? [], [])
        }
        overlayWindow.cancelGesture()
    }

    func testTrailLayersStrokeThePolylineWithOutlineAndLayerOpacity() throws {
        let view = GestureOverlayView(
            frame: NSRect(x: 0, y: 0, width: 400, height: 300),
            localization: LocalizationManager(language: .zhHans)
        )
        let trailView = try XCTUnwrap(extractTrailView(from: view))
        var feedback = FeedbackConfiguration.default
        feedback.trailWidth = 6
        feedback.trailOpacity = 0.6
        feedback.trailStrokeWidth = 2
        let points = [GesturePoint(x: 10, y: 20), GesturePoint(x: 60, y: 20), GesturePoint(x: 60, y: 90)]

        view.begin(at: points[0], appearance: GestureTrailAppearance(feedback: feedback))
        points.dropFirst().forEach { view.append($0) }

        let expected = points.map { CGPoint(x: $0.x, y: $0.y) }
        XCTAssertEqual(pathPoints(of: trailView.trailLayer.path), expected)
        XCTAssertEqual(pathPoints(of: trailView.outlineLayer.path), expected)
        XCTAssertEqual(trailView.trailLayer.lineWidth, 6)
        XCTAssertEqual(trailView.outlineLayer.lineWidth, 10)
        XCTAssertEqual(trailView.trailLayer.opacity, 0.6, accuracy: 0.0001)
        XCTAssertEqual(trailView.trailLayer.strokeColor?.alpha, 1)
        XCTAssertEqual(trailView.outlineLayer.strokeColor?.alpha, 1)
        XCTAssertNil(trailView.trailLayer.fillColor)

        feedback.trailStrokeEnabled = false
        view.updateLive(
            appearance: GestureTrailAppearance(feedback: feedback),
            feedback: LiveGestureOverlayFeedback(message: nil, showsCard: false),
            feedbackFrame: nil
        )
        XCTAssertNil(trailView.outlineLayer.path)
        XCTAssertEqual(pathPoints(of: trailView.trailLayer.path), expected)
    }

    func testStartPointAndTimeoutMarkerRenderAsCircles() throws {
        let view = GestureOverlayView(
            frame: NSRect(x: 0, y: 0, width: 400, height: 300),
            localization: LocalizationManager(language: .zhHans)
        )
        let trailView = try XCTUnwrap(extractTrailView(from: view))
        let appearance = GestureTrailAppearance(feedback: .default)

        view.begin(at: GesturePoint(x: 50, y: 40), appearance: appearance)

        // Default trail: width 3 with a 2 pt outline, so dots of 1.5 x (3 + 2 x 2) and 1.5 x 3.
        assertCircle(trailView.outlineLayer.path, center: CGPoint(x: 50, y: 40), diameter: 10.5)
        assertCircle(trailView.trailLayer.path, center: CGPoint(x: 50, y: 40), diameter: 4.5)
        XCTAssertNotNil(trailView.trailLayer.fillColor)
        XCTAssertNil(trailView.trailLayer.strokeColor)

        view.showMarker(GestureOverlayMarker(point: GesturePoint(x: 80, y: 70), style: .timeoutOrigin), appearance: appearance)

        XCTAssertNil(trailView.trailLayer.path)
        XCTAssertNil(trailView.outlineLayer.path)
        assertCircle(trailView.markerLayer.path, center: CGPoint(x: 80, y: 70), diameter: 6)

        view.clearMarker()

        XCTAssertNil(trailView.markerLayer.path)
    }

    func testAppendedPointsWaitForDisplayRefreshWhileResetAppliesImmediately() throws {
        let overlayWindow = GestureOverlayWindow(localization: LocalizationManager(language: .zhHans))
        let overlayView = extractOverlayView(from: overlayWindow)
        let trailView = try XCTUnwrap(extractTrailView(from: overlayView))
        let origin = GesturePoint(x: 250, y: 420)

        overlayWindow.beginGesture(at: origin, appearance: GestureTrailAppearance(feedback: .default))
        overlayWindow.appendGesturePoint(GesturePoint(x: 260, y: 420))
        overlayWindow.appendGesturePoint(GesturePoint(x: 270, y: 430))

        XCTAssertNotNil(trailView.trailLayer.fillColor, "still the start dot until the display refreshes")

        overlayView.renderTrail()

        XCTAssertEqual(pathPoints(of: trailView.trailLayer.path).count, 3)

        overlayWindow.cancelGesture()

        XCTAssertNil(trailView.trailLayer.path)
        XCTAssertNil(trailView.outlineLayer.path)
    }

    func testOverlayKeepsNoScreenSizedBackingStore() throws {
        let overlayWindow = GestureOverlayWindow(localization: LocalizationManager(language: .zhHans))
        let overlayView = extractOverlayView(from: overlayWindow)
        let trailView = try XCTUnwrap(extractTrailView(from: overlayView))

        overlayWindow.beginGesture(at: GesturePoint(x: 250, y: 420), appearance: GestureTrailAppearance(feedback: .default))
        overlayWindow.appendGesturePoint(GesturePoint(x: 300, y: 380))
        overlayView.renderTrail()
        overlayView.window?.displayIfNeeded()
        CATransaction.flush()

        XCTAssertNil(overlayView.layer?.contents)
        XCTAssertNil(trailView.layer?.contents)
        overlayWindow.cancelGesture()
    }

    private func pathPoints(of path: CGPath?) -> [CGPoint] {
        var points: [CGPoint] = []
        path?.applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint, .addLineToPoint:
                points.append(element.pointee.points[0])
            default:
                break
            }
        }
        return points
    }

    private func assertCircle(
        _ path: CGPath?,
        center: CGPoint,
        diameter: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let bounds = path?.boundingBoxOfPath else {
            XCTFail("missing path", file: file, line: line)
            return
        }
        XCTAssertEqual(bounds.midX, center.x, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(bounds.midY, center.y, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(bounds.width, diameter, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(bounds.height, diameter, accuracy: 0.001, file: file, line: line)
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

    private func extractTrailView(from overlayView: GestureOverlayView) -> GestureTrailView? {
        Mirror(reflecting: overlayView).children
            .first(where: { $0.label == "trailView" })?
            .value as? GestureTrailView
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
