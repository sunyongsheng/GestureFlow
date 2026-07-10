import AppKit
import Combine
import GestureFlowCore

final class GestureOverlayWindow: GestureOverlayDisplaying {
    private var screenOverlays: [ScreenOverlay] = []
    private var hideWorkItem: DispatchWorkItem?
    private var screenObserver: NSObjectProtocol?
    private let localization: LocalizationManager
    /// Screen geometry captured whenever panels are (re)built or their frames refreshed, so the
    /// per-sample feedback placement during a gesture avoids repeated `NSScreen.screens` queries.
    private var cachedScreenFrames: [CGRect] = []
    private var cachedMainScreenFrame: CGRect?

    init(localization: LocalizationManager) {
        self.localization = localization
        rebuildScreenOverlays()
        observeScreenChanges()
    }

    func beginGesture(at point: GesturePoint, appearance: GestureTrailAppearance) {
        cancelPendingHide()
        refreshPanelFrames()
        for overlay in screenOverlays {
            let localPoint = Self.localPoint(fromScreen: point, overlay: overlay)
            overlay.overlayView.begin(at: localPoint, appearance: appearance)
        }
        showPanels()
    }

    func appendGesturePoint(_ point: GesturePoint) {
        for overlay in screenOverlays {
            let localPoint = Self.localPoint(fromScreen: point, overlay: overlay)
            overlay.overlayView.append(localPoint)
        }
    }

    func updateLiveGesture(
        at point: GesturePoint,
        appearance: GestureTrailAppearance,
        feedback: LiveGestureOverlayFeedback
    ) {
        cancelPendingHide()
        if !isPanelContentVisible {
            refreshPanelFrames()
            showPanels()
        }
        let feedbackScreenIndex = screenIndex(containing: point)
        for (index, overlay) in screenOverlays.enumerated() {
            let feedbackFrame: CGRect? = (index == feedbackScreenIndex)
                ? resolveFeedbackFrame(for: point, in: overlay)
                : nil
            overlay.overlayView.updateLive(
                appearance: appearance,
                feedback: index == feedbackScreenIndex ? feedback : LiveGestureOverlayFeedback(message: nil, showsCard: false),
                feedbackFrame: feedbackFrame
            )
        }
    }

    func completeGesture(
        with completion: GestureOverlayCompletion,
        at point: GesturePoint?,
        hideAfter: TimeInterval
    ) {
        let feedbackScreenIndex = point.flatMap { screenIndex(containing: $0) }
        for (index, overlay) in screenOverlays.enumerated() {
            let feedbackFrame: CGRect?
            if index == feedbackScreenIndex, let point {
                feedbackFrame = resolveFeedbackFrame(for: point, in: overlay)
            } else {
                feedbackFrame = nil
            }
            overlay.overlayView.complete(with: completion, feedbackFrame: feedbackFrame)
        }
        scheduleHide(after: hideAfter)
    }

    func showMarker(_ marker: GestureOverlayMarker, appearance: GestureTrailAppearance) {
        cancelPendingHide()
        refreshPanelFrames()
        for overlay in screenOverlays {
            let localPoint = Self.localPoint(fromScreen: marker.point, overlay: overlay)
            overlay.overlayView.showMarker(
                GestureOverlayMarker(point: localPoint, style: marker.style),
                appearance: appearance
            )
        }
        showPanels()
    }

    func clearMarker() {
        for overlay in screenOverlays {
            overlay.overlayView.clearMarker()
        }
        let anyVisible = screenOverlays.contains { $0.overlayView.hasVisibleContent }
        if !anyVisible {
            hidePanels()
        }
    }

    func cancelGesture() {
        cancelPendingHide()
        hideNow()
    }

    // MARK: - Panel Management

    private struct ScreenOverlay {
        let panel: NSPanel
        let overlayView: GestureOverlayView
    }

    private func rebuildScreenOverlays() {
        for overlay in screenOverlays {
            overlay.panel.orderOut(nil)
        }

        let screens = NSScreen.screens
        if screens.isEmpty {
            let fallbackFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
            let overlayView = GestureOverlayView(frame: NSRect(origin: .zero, size: fallbackFrame.size), localization: localization)
            let panel = Self.makePanel(frame: fallbackFrame, contentView: overlayView)
            screenOverlays = [ScreenOverlay(panel: panel, overlayView: overlayView)]
            cachedScreenFrames = [fallbackFrame]
            cachedMainScreenFrame = nil
            return
        }

        screenOverlays = screens.map { screen in
            let viewFrame = NSRect(origin: .zero, size: screen.frame.size)
            let overlayView = GestureOverlayView(frame: viewFrame, localization: localization)
            let panel = Self.makePanel(frame: screen.frame, contentView: overlayView)
            return ScreenOverlay(panel: panel, overlayView: overlayView)
        }
        cachedScreenFrames = screens.map(\.frame)
        cachedMainScreenFrame = NSScreen.main?.frame
    }

    private static func makePanel(frame: NSRect, contentView: NSView) -> NSPanel {
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
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
        panel.contentView = contentView
        panel.setFrame(frame, display: false)
        panel.alphaValue = 0
        return panel
    }

    private func refreshPanelFrames() {
        let screens = NSScreen.screens
        if screens.count != screenOverlays.count {
            rebuildScreenOverlays()
            return
        }
        for (index, screen) in screens.enumerated() {
            let overlay = screenOverlays[index]
            overlay.panel.setFrame(screen.frame, display: false)
            overlay.overlayView.frame = NSRect(origin: .zero, size: screen.frame.size)
        }
        cachedScreenFrames = screens.map(\.frame)
        cachedMainScreenFrame = NSScreen.main?.frame
    }

    // MARK: - Visibility

    private var isPanelContentVisible: Bool {
        screenOverlays.first.map { $0.panel.alphaValue > 0 } ?? false
    }

    private func showPanels() {
        for overlay in screenOverlays {
            overlay.panel.alphaValue = 1
            overlay.panel.orderFrontRegardless()
        }
    }

    private func hidePanels() {
        for overlay in screenOverlays {
            overlay.panel.alphaValue = 0
        }
    }

    // MARK: - Hide Scheduling

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
        for overlay in screenOverlays {
            overlay.overlayView.reset()
        }
        hidePanels()
        hideWorkItem = nil
    }

    // MARK: - Screen Changes

    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.rebuildScreenOverlays()
        }
    }

    // MARK: - Coordinate Conversion

    private static func localPoint(fromScreen point: GesturePoint, overlay: ScreenOverlay) -> GesturePoint {
        GestureOverlayCoordinateConverter.localPoint(
            fromScreen: point,
            panel: overlay.panel,
            view: overlay.overlayView
        )
    }

    private func screenIndex(containing point: GesturePoint) -> Int? {
        let cgPoint = CGPoint(x: point.x, y: point.y)
        guard cachedScreenFrames.count == screenOverlays.count else { return nil }
        return cachedScreenFrames.firstIndex(where: { $0.contains(cgPoint) })
    }

    private func resolveFeedbackFrame(for point: GesturePoint, in overlay: ScreenOverlay) -> CGRect {
        let screenFrame = GestureOverlayGeometry.resolveScreenFrame(
            containing: point,
            screenFrames: cachedScreenFrames,
            mainScreenFrame: cachedMainScreenFrame
        )
        let globalFrame = GestureOverlayGeometry.feedbackAnchor(in: screenFrame)
        return GestureOverlayCoordinateConverter.localRect(
            fromScreen: globalFrame,
            panel: overlay.panel,
            view: overlay.overlayView
        )
    }
}
