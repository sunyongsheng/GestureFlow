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
        let overlayWindow = GestureOverlayWindow(localization: LocalizationManager(language: .zhHans))
        let origin = GesturePoint(x: 250, y: 420)

        overlayWindow.beginGesture(
            at: origin,
            appearance: GestureTrailAppearance(feedback: .default)
        )
        overlayWindow.completeGesture(
            with: .recognized(gestureID: UUID(), storedName: String(repeating: "很长的手势名称", count: 6)),
            at: origin,
            hideAfter: TimeInterval(FeedbackConfiguration.default.overlayHideDelayMilliseconds) / 1000
        )

        let overlayView = extractOverlayView(from: overlayWindow)
        let feedbackCardView = try XCTUnwrap(extractFeedbackCardView(from: overlayView))
        let messageLabel = try XCTUnwrap(extractFeedbackMessageLabel(from: feedbackCardView))
        feedbackCardView.layoutSubtreeIfNeeded()

        let labelFrameInCard = messageLabel.convert(messageLabel.bounds, to: feedbackCardView)
        XCTAssertFalse(messageLabel.hasAmbiguousLayout)
        XCTAssertLessThanOrEqual(labelFrameInCard.maxX, feedbackCardView.bounds.maxX)
    }

    func testTrailRedrawOfDirtyRectMatchesFullRedraw() throws {
        let view = GestureOverlayView(
            frame: NSRect(x: 0, y: 0, width: 400, height: 300),
            localization: LocalizationManager(language: .zhHans)
        )
        var feedback = FeedbackConfiguration.default
        feedback.trailWidth = 6
        feedback.trailOpacity = 0.6
        let wave = (0..<160).map { index in
            GesturePoint(x: 30 + Double(index) * 2, y: 150 + sin(Double(index) / 8) * 100)
        }
        let crossing = (0..<120).map { index in
            GesturePoint(x: 350 - Double(index) * 2.6, y: 60 + Double(index) * 1.5)
        }
        let points = wave + crossing
        view.begin(at: points[0], appearance: GestureTrailAppearance(feedback: feedback))
        points.dropFirst().forEach { view.append($0) }

        let fullRedraw = try renderPixels(of: view, dirtyRect: view.bounds)
        let dirtyRects = [
            NSRect(x: 60, y: 40, width: 24, height: 30),
            NSRect(x: 150, y: 120, width: 60, height: 60),
            NSRect(x: 200, y: 90, width: 18, height: 70),
            NSRect(x: 280, y: 180, width: 40, height: 30),
            NSRect(x: 0, y: 0, width: 400, height: 20)
        ]
        for dirtyRect in dirtyRects {
            let partialRedraw = try renderPixels(of: view, dirtyRect: dirtyRect)
            XCTAssertLessThanOrEqual(
                partialRedraw.maxChannelDifference(from: fullRedraw, in: dirtyRect),
                2,
                "dirty rect \(dirtyRect)"
            )
        }
    }

    private struct RenderedPixels {
        let height: Int
        let bytesPerRow: Int
        let bytes: [UInt8]

        func maxChannelDifference(from other: RenderedPixels, in rect: NSRect) -> Int {
            var maximum = 0
            for row in (height - Int(rect.maxY))..<(height - Int(rect.minY)) {
                for column in Int(rect.minX)..<Int(rect.maxX) {
                    for channel in 0..<4 {
                        let index = row * bytesPerRow + column * 4 + channel
                        maximum = max(maximum, abs(Int(bytes[index]) - Int(other.bytes[index])))
                    }
                }
            }
            return maximum
        }
    }

    private func renderPixels(of view: NSView, dirtyRect: NSRect) throws -> RenderedPixels {
        let width = Int(view.bounds.width)
        let height = Int(view.bounds.height)
        let rep = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ))
        let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: rep))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.clip(to: dirtyRect)
        view.draw(dirtyRect)
        NSGraphicsContext.restoreGraphicsState()
        let data = try XCTUnwrap(rep.bitmapData)
        return RenderedPixels(
            height: height,
            bytesPerRow: rep.bytesPerRow,
            bytes: Array(UnsafeBufferPointer(start: data, count: rep.bytesPerRow * height))
        )
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
