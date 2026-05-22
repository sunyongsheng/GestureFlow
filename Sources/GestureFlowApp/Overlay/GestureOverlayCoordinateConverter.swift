import AppKit
import CoreGraphics
import GestureFlowCore

enum GestureOverlayCoordinateConverter {
    static func localPoint(
        fromScreen point: GesturePoint,
        panel: NSPanel,
        view: NSView
    ) -> GesturePoint {
        let screenRect = CGRect(x: point.x, y: point.y, width: 0, height: 0)
        let windowPoint = panel.convertFromScreen(screenRect).origin
        let localPoint = view.convert(windowPoint, from: nil)
        return GesturePoint(x: localPoint.x, y: localPoint.y)
    }

    static func localRect(
        fromScreen rect: CGRect,
        panel: NSPanel,
        view: NSView
    ) -> CGRect {
        let windowRect = panel.convertFromScreen(rect)
        return view.convert(windowRect, from: nil)
    }
}
