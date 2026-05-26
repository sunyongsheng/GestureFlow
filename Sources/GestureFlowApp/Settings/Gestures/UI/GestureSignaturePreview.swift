import SwiftUI
import GestureFlowCore

enum GestureSignatureGlyphRenderer {
    static let listSize = CGSize(width: 28, height: 28)
    static let popoverSize = CGSize(width: 26, height: 26)

    private static let defaultFeedback = FeedbackConfiguration.default

    static var defaultTrailColor: Color {
        ColorHexFormatting
            .color(fromHex: defaultFeedback.trailColorHex)
            .opacity(defaultFeedback.trailOpacity)
    }

    static func image(
        for signature: GestureSignature,
        size: CGSize = listSize,
        lineWidth: CGFloat? = nil
    ) -> Image {
        Image(size: size) { context in
            draw(signature: signature, in: context, size: size, lineWidth: lineWidth)
        }
    }

    static func draw(
        signature: GestureSignature,
        in context: GraphicsContext,
        size: CGSize,
        lineWidth: CGFloat? = nil
    ) {
        let fitted = GestureSignaturePathGeometry.fittedPolyline(for: signature)
        guard fitted.count >= 2 else { return }

        let points = fitted.map { point in
            CGPoint(
                x: CGFloat(point.x) * size.width,
                y: CGFloat(point.y) * size.height
            )
        }

        let lineWidth = lineWidth ?? max(1.25, size.width * 0.07)
        let cornerRadius = min(size.width * 0.14, 4)

        guard let tip = points.last,
              let previous = points.dropLast().last,
              GestureSignaturePathGeometry.terminalDirection(for: signature) != nil else {
            let linePath = roundedPolylinePath(points: points, cornerRadius: cornerRadius)
            context.stroke(
                linePath,
                with: .color(defaultTrailColor),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
            return
        }

        let segment = CGPoint(x: tip.x - previous.x, y: tip.y - previous.y)
        let segmentLength = max(hypot(segment.x, segment.y), 0.001)
        let arrowSize = min(min(size.width, size.height) * 0.22, segmentLength * 0.85)
        let unit = CGPoint(x: segment.x / segmentLength, y: segment.y / segmentLength)
        let trailEnd = CGPoint(
            x: tip.x - unit.x * arrowSize,
            y: tip.y - unit.y * arrowSize
        )

        var trailPoints = points
        trailPoints[trailPoints.count - 1] = trailEnd
        let linePath = roundedPolylinePath(points: trailPoints, cornerRadius: cornerRadius)

        context.stroke(
            linePath,
            with: .color(defaultTrailColor),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        )

        let arrowPath = arrowHeadPath(tip: tip, segment: segment, size: arrowSize)
        context.fill(arrowPath, with: .color(defaultTrailColor))
    }

    static func roundedPolylinePath(points: [CGPoint], cornerRadius: CGFloat) -> Path {
        guard points.count >= 2 else { return Path() }

        var path = Path()
        if points.count == 2 {
            path.move(to: points[0])
            path.addLine(to: points[1])
            return path
        }

        path.move(to: points[0])

        for index in 1..<(points.count - 1) {
            let previous = points[index - 1]
            let corner = points[index]
            let next = points[index + 1]

            let incoming = CGPoint(x: corner.x - previous.x, y: corner.y - previous.y)
            let outgoing = CGPoint(x: next.x - corner.x, y: next.y - corner.y)
            let incomingLength = max(hypot(incoming.x, incoming.y), 0.001)
            let outgoingLength = max(hypot(outgoing.x, outgoing.y), 0.001)
            let radius = min(cornerRadius, incomingLength * 0.45, outgoingLength * 0.45)

            let beforeCorner = CGPoint(
                x: corner.x - incoming.x / incomingLength * radius,
                y: corner.y - incoming.y / incomingLength * radius
            )
            let afterCorner = CGPoint(
                x: corner.x + outgoing.x / outgoingLength * radius,
                y: corner.y + outgoing.y / outgoingLength * radius
            )

            path.addLine(to: beforeCorner)
            path.addQuadCurve(to: afterCorner, control: corner)
        }

        path.addLine(to: points[points.count - 1])
        return path
    }

    private static func arrowHeadPath(tip: CGPoint, segment: CGPoint, size: CGFloat) -> Path {
        var path = Path()
        let length = max(hypot(segment.x, segment.y), 0.001)
        let ux = segment.x / length
        let uy = segment.y / length
        let px = -uy
        let py = ux
        let back = CGPoint(x: tip.x - ux * size, y: tip.y - uy * size)
        let left = CGPoint(x: back.x + px * size * 0.45, y: back.y + py * size * 0.45)
        let right = CGPoint(x: back.x - px * size * 0.45, y: back.y - py * size * 0.45)
        path.move(to: left)
        path.addLine(to: tip)
        path.addLine(to: right)
        path.closeSubpath()
        return path
    }
}

struct GestureSignaturePreview: View {
    let signature: GestureSignature

    var body: some View {
        GestureSignatureGlyphRenderer.image(for: signature)
            .frame(
                width: GestureSignatureGlyphRenderer.listSize.width,
                height: GestureSignatureGlyphRenderer.listSize.height
            )
            .accessibilityHidden(true)
    }
}
