import Foundation

public enum GesturePointCoordinateSystem {
    /// AppKit screen coordinates (Y increases upward).
    case screen
    /// View coordinates (Y increases downward), e.g. SwiftUI canvas.
    case view
}
