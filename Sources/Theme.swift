import Cocoa

/// Theme D: Apple × Warm Fusion — Design Tokens
struct Theme {
    // MARK: - Surfaces (Apple-inspired luminance stepping)
    static let bgVoid      = NSColor(red: 0.031, green: 0.035, blue: 0.039, alpha: 1.0)  // #08090A
    static let bgPanel     = NSColor(red: 0.078, green: 0.078, blue: 0.086, alpha: 0.60)  // #141416 @ 60%
    static let bgSurface   = NSColor(red: 0.110, green: 0.110, blue: 0.118, alpha: 1.0)  // #1C1C1E (systemGray6)
    static let bgElevated  = NSColor(red: 0.173, green: 0.173, blue: 0.180, alpha: 1.0)  // #2C2C2E
    static let bgTerminal  = NSColor(red: 0.094, green: 0.094, blue: 0.094, alpha: 1.0)  // #181818 (Warp default)

    // MARK: - Terminal colors (Warp default theme)
    static let termFg      = NSColor(red: 0.847, green: 0.847, blue: 0.847, alpha: 1.0)  // #D8D8D8
    static let termCursor  = NSColor(red: 0.486, green: 0.749, blue: 0.761, alpha: 1.0)  // #7CAFC2

    // MARK: - Text (not pure white)
    static let textPrimary   = NSColor(red: 0.969, green: 0.973, blue: 0.973, alpha: 1.0)  // #F7F8F8
    static let textSecondary = NSColor.white.withAlphaComponent(0.65)
    static let textTertiary  = NSColor.white.withAlphaComponent(0.4)
    static let textMuted     = NSColor.white.withAlphaComponent(0.25)

    // MARK: - Accent (warm indigo)
    static let accent      = NSColor(red: 0.424, green: 0.494, blue: 0.902, alpha: 1.0)  // #6C7EE6
    static let accentHover = NSColor(red: 0.545, green: 0.608, blue: 0.941, alpha: 1.0)  // #8B9BF0
    static let accentSubtle = NSColor(red: 0.424, green: 0.494, blue: 0.902, alpha: 0.12)

    // MARK: - Status (Apple SF Symbols colors)
    static let success = NSColor(red: 0.188, green: 0.820, blue: 0.345, alpha: 1.0)  // #30D158
    static let warning = NSColor(red: 1.000, green: 0.624, blue: 0.039, alpha: 1.0)  // #FF9F0A
    static let error   = NSColor(red: 1.000, green: 0.271, blue: 0.227, alpha: 1.0)  // #FF453A
    static let info    = NSColor(red: 0.039, green: 0.518, blue: 1.000, alpha: 1.0)  // #0A84FF

    // MARK: - Border (Linear-inspired whisper-thin)
    static let border       = NSColor.white.withAlphaComponent(0.08)
    static let borderSubtle = NSColor.white.withAlphaComponent(0.05)

    // MARK: - Radii
    static let radiusPanel: CGFloat  = 14
    static let radiusInner: CGFloat  = 10
    static let radiusButton: CGFloat = 8
    static let radiusStrip: CGFloat  = 12
    static let radiusBubble: CGFloat = 14

    // MARK: - Animation durations
    static let durationFast: TimeInterval   = 0.15
    static let durationNormal: TimeInterval = 0.25
    static let durationSpring: TimeInterval = 0.4

    // MARK: - Fonts
    static let fontMono = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    static let fontUI   = NSFont.systemFont(ofSize: 13, weight: .medium)
    static let fontUISmall = NSFont.systemFont(ofSize: 11, weight: .medium)
    static let fontLabel = NSFont.systemFont(ofSize: 9, weight: .semibold)
}
