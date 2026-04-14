import Cocoa

class FloatingPanel: NSPanel {
    init(contentRect: NSRect, cornerRadius: CGFloat = Theme.radiusPanel, bgColor: NSColor = Theme.bgPanel) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isExcludedFromWindowsMenu = true

        let container = NSView(frame: NSRect(origin: .zero, size: contentRect.size))
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor
        container.layer?.cornerRadius = cornerRadius
        container.layer?.masksToBounds = true
        container.layer?.borderWidth = 0.5
        container.layer?.borderColor = Theme.border.cgColor
        contentView = container
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
