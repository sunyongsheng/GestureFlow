import SwiftUI
import GestureFlowCore

struct GestureTrailPreview: View {
    let feedback: FeedbackConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("预览")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            ZStack {
                TrailPreviewCheckerboard()
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )

                ZStack {
                    if feedback.trailStrokeEnabled {
                        TrailPreviewCurve()
                            .stroke(
                                strokeColor,
                                style: StrokeStyle(
                                    lineWidth: strokeLineWidth,
                                    lineCap: .round,
                                    lineJoin: .round
                                )
                            )
                    }

                    TrailPreviewCurve()
                        .stroke(
                            trailColor,
                            style: StrokeStyle(
                                lineWidth: CGFloat(feedback.trailWidth),
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                        .opacity(feedback.trailOpacity)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
            .frame(height: 76)
        }
        .accessibilityLabel("手势轨迹预览")
    }

    private var trailColor: Color {
        ColorHexFormatting.color(fromHex: feedback.trailColorHex)
    }

    private var strokeColor: Color {
        ColorHexFormatting.color(fromHex: feedback.trailStrokeColorHex)
    }

    private var strokeLineWidth: CGFloat {
        CGFloat(feedback.trailWidth + 2 * feedback.trailStrokeWidth)
    }
}

private struct TrailPreviewCheckerboard: View {
    private let squareSize: CGFloat = 10

    var body: some View {
        Canvas { context, size in
            let columns = Int(ceil(size.width / squareSize))
            let rows = Int(ceil(size.height / squareSize))

            for row in 0..<rows {
                for column in 0..<columns {
                    let isLight = (row + column).isMultiple(of: 2)
                    let rect = CGRect(
                        x: CGFloat(column) * squareSize,
                        y: CGFloat(row) * squareSize,
                        width: squareSize,
                        height: squareSize
                    )
                    context.fill(
                        Path(rect),
                        with: .color(isLight ? lightSquare : darkSquare)
                    )
                }
            }
        }
    }

    private var lightSquare: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    private var darkSquare: Color {
        Color.primary.opacity(0.12)
    }
}

private struct TrailPreviewCurve: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let start = CGPoint(x: rect.minX, y: rect.midY + rect.height * 0.18)
        let end = CGPoint(x: rect.maxX, y: rect.midY - rect.height * 0.18)
        path.move(to: start)
        path.addCurve(
            to: end,
            control1: CGPoint(x: rect.width * 0.38, y: rect.maxY - 2),
            control2: CGPoint(x: rect.width * 0.62, y: rect.minY + 2)
        )
        return path
    }
}
