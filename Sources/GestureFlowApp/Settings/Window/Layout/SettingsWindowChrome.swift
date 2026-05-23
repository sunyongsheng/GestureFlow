import AppKit
import SwiftUI

/// Visual chrome for the settings window (sidebar + titlebar region), aligned with System Settings.
enum SettingsWindowChrome {
    /// Sidebar column fill, including the area behind the traffic-light buttons.
    static let sidebarBackground = Color(nsColor: .windowBackgroundColor)

    /// Detail pane background.
    static let detailBackground = Color(nsColor: .controlBackgroundColor)
}
