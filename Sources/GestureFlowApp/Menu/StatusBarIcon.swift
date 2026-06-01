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
                roundedRect: NSRect(x: 4.1, y: 1.4, width: 9.8, height: 14.7),
                xRadius: 4.9,
                yRadius: 4.9
            )
            body.fill()

            NSGraphicsContext.saveGraphicsState()
            NSColor.clear.setFill()
            NSGraphicsContext.current?.compositingOperation = .clear

            let topSplit = NSBezierPath(
                roundedRect: NSRect(x: 8.4, y: 1.8, width: 1.2, height: 4.7),
                xRadius: 0.6,
                yRadius: 0.6
            )
            topSplit.fill()

            NSBezierPath(rect: NSRect(x: 8.4, y: 6.0, width: 5.2, height: 0.9)).fill()

            let wheel = NSBezierPath(
                roundedRect: NSRect(x: 8.1, y: 4.0, width: 1.8, height: 3.1),
                xRadius: 0.9,
                yRadius: 0.9
            )
            wheel.fill()

            NSGraphicsContext.restoreGraphicsState()

            guard isRunning else { return true }

            NSColor.black.setFill()
            NSBezierPath(ovalIn: NSRect(x: 13.4, y: 12.9, width: 2.9, height: 2.9)).fill()
            return true
        }
    }
}
