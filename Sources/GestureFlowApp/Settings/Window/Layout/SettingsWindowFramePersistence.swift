import AppKit
import Foundation

struct SettingsWindowStoredFrame: Codable, Equatable {
    var originX: Double
    var originY: Double
    var width: Double
    var height: Double

    init(frame: NSRect) {
        originX = frame.origin.x
        originY = frame.origin.y
        width = frame.size.width
        height = frame.size.height
    }

    var frame: NSRect {
        NSRect(
            x: originX,
            y: originY,
            width: width,
            height: height
        )
    }
}

struct SettingsWindowFramePersistence {
    static let userDefaultsKey = "settingsWindowFrame"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> SettingsWindowStoredFrame? {
        guard let data = defaults.data(forKey: Self.userDefaultsKey) else { return nil }
        return try? JSONDecoder().decode(SettingsWindowStoredFrame.self, from: data)
    }

    func save(windowFrame: NSRect) {
        let stored = SettingsWindowStoredFrame(frame: windowFrame)
        guard let data = try? JSONEncoder().encode(stored) else { return }
        defaults.set(data, forKey: Self.userDefaultsKey)
    }

    func restoreFrame(
        for window: NSWindow,
        screens: [NSScreen] = NSScreen.screens
    ) -> Bool {
        guard let stored = load() else { return false }
        let frame = Self.constrainedFrame(
            stored.frame,
            minimumSize: window.minSize,
            screens: screens
        )
        window.setFrame(frame, display: false)
        return true
    }

    static func constrainedFrame(
        _ frame: NSRect,
        minimumSize: NSSize,
        screens: [NSScreen]
    ) -> NSRect {
        var adjusted = frame
        adjusted.size.width = max(adjusted.size.width, minimumSize.width)
        adjusted.size.height = max(adjusted.size.height, minimumSize.height)

        guard !screens.isEmpty else { return adjusted }

        let visibleUnion = screens
            .map(\.visibleFrame)
            .reduce(CGRect.null) { $0.union($1) }

        guard !visibleUnion.isNull else { return adjusted }

        if screens.contains(where: { !$0.visibleFrame.intersection(adjusted).isNull }) {
            return adjusted
        }

        adjusted.origin.x = visibleUnion.midX - adjusted.width / 2
        adjusted.origin.y = visibleUnion.midY - adjusted.height / 2
        return adjusted
    }
}
