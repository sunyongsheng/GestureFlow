import AppKit
import GestureFlowCore

final class GestureOverlayWindow: GestureOverlayDisplaying {
    private let panel: NSPanel
    private let overlayView: GestureOverlayView
    private var hideWorkItem: DispatchWorkItem?

    init() {
        self.overlayView = GestureOverlayView(frame: .zero)
        self.panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        configurePanel()
    }

    func beginGesture(at point: GesturePoint, appearance: GestureTrailAppearance) {
        cancelPendingHide()
        let frame = Self.overlayFrame()
        panel.setFrame(frame, display: false)
        overlayView.frame = NSRect(origin: .zero, size: frame.size)
        let localPoint = GestureOverlayCoordinateConverter.localPoint(
            fromScreen: point,
            panel: panel,
            view: overlayView
        )
        overlayView.begin(
            at: localPoint,
            appearance: appearance
        )
        panel.orderFrontRegardless()
    }

    func appendGesturePoint(_ point: GesturePoint) {
        let localPoint = GestureOverlayCoordinateConverter.localPoint(
            fromScreen: point,
            panel: panel,
            view: overlayView
        )
        overlayView.append(localPoint)
    }

    func updateLiveGesture(
        at point: GesturePoint,
        appearance: GestureTrailAppearance,
        feedback: LiveGestureOverlayFeedback
    ) {
        cancelPendingHide()
        if !panel.isVisible {
            let frame = Self.overlayFrame()
            panel.setFrame(frame, display: false)
            overlayView.frame = NSRect(origin: .zero, size: frame.size)
            panel.orderFrontRegardless()
        }
        overlayView.updateLive(
            appearance: appearance,
            feedback: feedback,
            feedbackFrame: resolveFeedbackFrame(for: point)
        )
    }

    func completeGesture(
        with completion: GestureOverlayCompletion,
        at point: GesturePoint?,
        hideAfter: TimeInterval
    ) {
        overlayView.complete(
            with: completion,
            feedbackFrame: point.map(resolveFeedbackFrame)
        )
        scheduleHide(after: hideAfter)
    }

    func showMarker(_ marker: GestureOverlayMarker, appearance: GestureTrailAppearance) {
        cancelPendingHide()
        let frame = Self.overlayFrame()
        panel.setFrame(frame, display: false)
        overlayView.frame = NSRect(origin: .zero, size: frame.size)
        let localPoint = GestureOverlayCoordinateConverter.localPoint(
            fromScreen: marker.point,
            panel: panel,
            view: overlayView
        )
        overlayView.showMarker(
            GestureOverlayMarker(point: localPoint, style: marker.style),
            appearance: appearance
        )
        panel.orderFrontRegardless()
    }

    func clearMarker() {
        overlayView.clearMarker()
        if !overlayView.hasVisibleContent {
            panel.orderOut(nil)
        }
    }

    func cancelGesture() {
        cancelPendingHide()
        hideNow()
    }

    private func configurePanel() {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.animationBehavior = .none
        panel.level = .statusBar
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle,
            .stationary
        ]
        panel.contentView = overlayView
    }

    private func scheduleHide(after delay: TimeInterval) {
        cancelPendingHide()
        let workItem = DispatchWorkItem { [weak self] in
            self?.hideNow()
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func cancelPendingHide() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
    }

    private func hideNow() {
        overlayView.reset()
        panel.orderOut(nil)
        hideWorkItem = nil
    }

    private static func overlayFrame() -> NSRect {
        NSScreen.screens
            .map(\.frame)
            .reduce(NSScreen.main?.frame ?? .zero) { partial, frame in
                partial.union(frame)
            }
    }

    private func resolveFeedbackFrame(for point: GesturePoint) -> CGRect {
        let screenFrame = GestureOverlayGeometry.resolveScreenFrame(
            containing: point,
            screenFrames: NSScreen.screens.map(\.frame),
            mainScreenFrame: NSScreen.main?.frame
        )
        let globalFrame = GestureOverlayGeometry.feedbackAnchor(in: screenFrame)
        let localFrame = GestureOverlayCoordinateConverter.localRect(
            fromScreen: globalFrame,
            panel: panel,
            view: overlayView
        )
        return localFrame
    }
}
