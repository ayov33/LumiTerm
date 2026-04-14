import Cocoa

/// LumiTerm Design Tokens
struct Theme {
    // Surfaces
    static let bgPanel = NSColor(red: 0.078, green: 0.078, blue: 0.086, alpha: 0.60)
    static let bgPanelSolid = NSColor(red: 0.078, green: 0.078, blue: 0.086, alpha: 1.0)
    static let bgSettings = NSColor(red: 0.965, green: 0.965, blue: 0.965, alpha: 1.0)

    // Border
    static let border = NSColor.white.withAlphaComponent(0.08)

    // Radii
    static let radiusPanel: CGFloat = 15
}

// MARK: - Notification Names

extension Notification.Name {
    static let capsuleModeChanged = Notification.Name("CapsuleModeChanged")
    static let dockEdgeChanged = Notification.Name("DockEdgeChanged")
    static let settingsChanged = Notification.Name("SettingsChanged")
}
