import SwiftUI
import GestureFlowCore

struct GestureSignatureRecordingView: View {
    @Binding var recognizedSignature: GestureSignature?

    private let canvasSize = CGSize(width: 240, height: 240)
    private let maxSegmentCount = GestureRecognizer.maxRecordingSegmentCount
    private let liveStrokeLineWidth: CGFloat = 3
    private let previewGlyphLineWidth: CGFloat = 3
    private let recognizer = GestureRecognizer()

    @State private var strokePoints: [GesturePoint] = []

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.35), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(nsColor: .windowBackgroundColor))
                    )

                liveStrokeLayer

                if let recognizedSignature {
                    GestureSignatureGlyphRenderer.image(
                        for: recognizedSignature,
                        size: CGSize(width: 72, height: 72),
                        lineWidth: previewGlyphLineWidth
                    )
                    .opacity(0.35)
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        if recognizedSignature?.tokens.count ?? 0 >= maxSegmentCount {
                            return
                        }
                        if strokePoints.isEmpty {
                            strokePoints = [GesturePoint(x: value.location.x, y: value.location.y)]
                        } else {
                            strokePoints.append(GesturePoint(x: value.location.x, y: value.location.y))
                        }
                        recognizedSignature = recognizer.recognize(
                            points: strokePoints,
                            coordinateSystem: .view,
                            maxTokenCount: maxSegmentCount
                        )
                    }
                    .onEnded { _ in
                        recognizedSignature = recognizer.recognize(
                            points: strokePoints,
                            coordinateSystem: .view,
                            maxTokenCount: maxSegmentCount
                        )
                        strokePoints = []
                    }
            )

            Text(statusText)
                .font(.subheadline)
                .foregroundStyle(recognizedSignature == nil ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var liveStrokeLayer: some View {
        Canvas { context, _ in
            guard strokePoints.count >= 2 else { return }

            var path = Path()
            path.move(to: CGPoint(x: strokePoints[0].x, y: strokePoints[0].y))
            for point in strokePoints.dropFirst() {
                path.addLine(to: CGPoint(x: point.x, y: point.y))
            }

            context.stroke(
                path,
                with: .color(GestureSignatureGlyphRenderer.defaultTrailColor),
                style: StrokeStyle(
                    lineWidth: liveStrokeLineWidth,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
        .allowsHitTesting(false)
    }

    private var statusText: String {
        if let recognizedSignature {
            let directions = recordingDirectionDisplayName(for: recognizedSignature)
            if recognizedSignature.tokens.count >= maxSegmentCount {
                return "\(directions)（已达 \(maxSegmentCount) 段上限）"
            }
            return directions
        }
        return "使用左键在画布内绘制手势（最多 \(maxSegmentCount) 段）"
    }

    private func recordingDirectionDisplayName(for signature: GestureSignature) -> String {
        signature.tokens.map(\.chineseDisplayName).joined(separator: "→")
    }
}
