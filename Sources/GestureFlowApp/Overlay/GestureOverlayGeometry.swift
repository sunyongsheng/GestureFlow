import CoreGraphics
import GestureFlowCore

enum GestureOverlayGeometry {
    static let hotspotOffset = GesturePoint(x: 0, y: 0)
    private static let feedbackSize = CGSize(width: 320, height: 44)

    static func applyHotspotOffset(
        to point: GesturePoint,
        offset: GesturePoint = hotspotOffset
    ) -> GesturePoint {
        GesturePoint(x: point.x + offset.x, y: point.y + offset.y)
    }

    static func resolveScreenFrame(
        containing point: GesturePoint,
        screenFrames: [CGRect],
        mainScreenFrame: CGRect?
    ) -> CGRect {
        let point = CGPoint(x: point.x, y: point.y)

        if let resolved = screenFrames.first(where: { $0.contains(point) }) {
            return resolved
        }

        return mainScreenFrame ?? .zero
    }

    static func feedbackAnchor(in screenFrame: CGRect) -> CGRect {
        let width = min(feedbackSize.width, max(screenFrame.width - 32, 160))
        let size = CGSize(width: width, height: feedbackSize.height)
        let y = screenFrame.minY + screenFrame.height * 0.25 - size.height / 2

        return CGRect(
            x: screenFrame.midX - size.width / 2,
            y: y,
            width: size.width,
            height: size.height
        )
    }
}
