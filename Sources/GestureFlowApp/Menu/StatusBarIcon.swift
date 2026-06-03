import AppKit

enum StatusBarIcon {
    private static let pointSize = NSSize(width: 18, height: 18)

    static func image(isRunning: Bool) -> NSImage {
        let name = isRunning ? "icon-statusbar-running" : "icon-statusbar"
        let image = NSImage(named: name) ?? fallbackImage(isRunning: isRunning)
        image.size = pointSize
        image.isTemplate = true
        return image
    }

    private static func fallbackImage(isRunning: Bool) -> NSImage {
        NSImage(size: pointSize, flipped: true) { _ in
            NSColor.black.setFill()

            let body = NSBezierPath(
                roundedRect: NSRect(x: 4.05, y: 1.55, width: 9.9, height: 13.5),
                xRadius: 4.75,
                yRadius: 4.75
            )
            body.fill()

            NSGraphicsContext.saveGraphicsState()
            NSColor.clear.setStroke()
            NSGraphicsContext.current?.compositingOperation = .clear
            let gap = sCurveCenterlinePath()
            gap.lineWidth = 1.7
            gap.lineCapStyle = .butt
            gap.lineJoinStyle = .miter
            gap.stroke()
            NSGraphicsContext.restoreGraphicsState()

            guard isRunning else { return true }

            NSColor.black.setFill()
            NSBezierPath(ovalIn: NSRect(x: 13.3, y: 12.1, width: 2.9, height: 2.9)).fill()
            return true
        }
    }

    private static func sCurveCenterlinePath() -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 9, y: 1.55))
        path.curve(
            to: NSPoint(x: 9, y: 8.3),
            controlPoint1: NSPoint(x: 9, y: 5),
            controlPoint2: NSPoint(x: 11, y: 6.5)
        )
        path.curve(
            to: NSPoint(x: 9, y: 15.05),
            controlPoint1: NSPoint(x: 7, y: 10),
            controlPoint2: NSPoint(x: 9, y: 13)
        )
        return path
    }
}
