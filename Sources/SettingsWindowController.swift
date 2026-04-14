import Cocoa
import ServiceManagement

class SettingsWindowController: NSWindowController {

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.center()
        window.isReleasedWhenClosed = false
        self.init(window: window)

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        window.contentView = contentView

        buildUI(in: contentView)
    }

    private func buildUI(in container: NSView) {
        var y: CGFloat = container.bounds.height - 32

        // ── General ──
        y = addSectionHeader("General", in: container, y: y)

        // Launch at Login
        let launchToggle = NSSwitch()
        launchToggle.target = self
        launchToggle.action = #selector(toggleLaunchAtLogin(_:))
        launchToggle.state = isLaunchAtLoginEnabled() ? .on : .off
        y = addRow("Launch at Login", control: launchToggle, in: container, y: y)

        // Hotkey
        let hotkeyLabel = NSTextField(labelWithString: "Cmd + Shift + A")
        hotkeyLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        hotkeyLabel.textColor = .secondaryLabelColor
        y = addRow("Global Hotkey", control: hotkeyLabel, in: container, y: y)

        // Dock position
        let dockPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        dockPopup.addItems(withTitles: ["Right 右", "Left 左", "Top 上", "Bottom 下"])
        let savedEdge = UserDefaults.standard.string(forKey: "dockEdge") ?? "right"
        let edgeIndex = ["right": 0, "left": 1, "top": 2, "bottom": 3][savedEdge] ?? 0
        dockPopup.selectItem(at: edgeIndex)
        dockPopup.target = self
        dockPopup.action = #selector(dockEdgeChanged(_:))
        y = addRow("Dock Position", control: dockPopup, in: container, y: y)

        y -= 12

        // ── Appearance ──
        y = addSectionHeader("Appearance", in: container, y: y)

        // Capsule style
        let stylePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        stylePopup.addItems(withTitles: ["Aurora 光晕", "Pixel Pet 像素宠物"])
        let savedMode = UserDefaults.standard.string(forKey: "capsuleMode") ?? "aurora"
        stylePopup.selectItem(at: savedMode == "pet" ? 1 : 0)
        stylePopup.target = self
        stylePopup.action = #selector(capsuleModeChanged(_:))
        y = addRow("Capsule Style", control: stylePopup, in: container, y: y)

        // Opacity
        let opacitySlider = NSSlider(value: Double(UserDefaults.standard.float(forKey: "panelOpacity") == 0 ? 1.0 : UserDefaults.standard.float(forKey: "panelOpacity")),
                                     minValue: 0.5, maxValue: 1.0, target: self, action: #selector(opacityChanged(_:)))
        opacitySlider.numberOfTickMarks = 0
        y = addRow("Panel Opacity", control: opacitySlider, in: container, y: y)

        // Font size
        let fontStepper = NSStepper()
        fontStepper.minValue = 10
        fontStepper.maxValue = 20
        fontStepper.integerValue = UserDefaults.standard.integer(forKey: "fontSize") == 0 ? 13 : UserDefaults.standard.integer(forKey: "fontSize")
        fontStepper.target = self
        fontStepper.action = #selector(fontSizeChanged(_:))
        let fontLabel = NSTextField(labelWithString: "\(fontStepper.integerValue)px")
        fontLabel.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        fontLabel.textColor = .secondaryLabelColor
        fontLabel.tag = 100
        let fontStack = NSStackView(views: [fontLabel, fontStepper])
        fontStack.spacing = 8
        y = addRow("Font Size", control: fontStack, in: container, y: y)

        y -= 12

        // ── Notifications ──
        y = addSectionHeader("Notifications", in: container, y: y)

        let notifToggle = NSSwitch()
        notifToggle.target = self
        notifToggle.action = #selector(toggleNotifications(_:))
        notifToggle.state = UserDefaults.standard.bool(forKey: "notificationsDisabled") ? .off : .on
        y = addRow("Command Finished Alert", control: notifToggle, in: container, y: y)

        y -= 12

        // ── About ──
        y = addSectionHeader("About", in: container, y: y)

        let versionLabel = NSTextField(labelWithString: "v0.1.0")
        versionLabel.font = .systemFont(ofSize: 12, weight: .medium)
        versionLabel.textColor = .tertiaryLabelColor
        y = addRow("Version", control: versionLabel, in: container, y: y)
    }

    // MARK: - UI Helpers

    private func addSectionHeader(_ title: String, in container: NSView, y: CGFloat) -> CGFloat {
        let label = NSTextField(labelWithString: title.uppercased())
        label.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .tertiaryLabelColor
        label.frame = NSRect(x: 20, y: y - 20, width: 200, height: 16)
        container.addSubview(label)
        return y - 28
    }

    private func addRow(_ title: String, control: NSView, in container: NSView, y: CGFloat) -> CGFloat {
        let rowH: CGFloat = 32
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        label.textColor = .labelColor
        label.frame = NSRect(x: 20, y: y - rowH, width: 180, height: rowH)
        container.addSubview(label)

        control.frame = NSRect(x: 220, y: y - rowH + 4, width: container.bounds.width - 240, height: rowH - 8)
        if control is NSSlider { control.frame.origin.y = y - rowH + 8 }
        container.addSubview(control)

        return y - rowH - 4
    }

    // MARK: - Actions

    @objc private func toggleLaunchAtLogin(_ sender: NSSwitch) {
        if #available(macOS 13.0, *) {
            do {
                if sender.state == .on {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // Silently fail
            }
        }
    }

    @objc private func dockEdgeChanged(_ sender: NSPopUpButton) {
        let edges = ["right", "left", "top", "bottom"]
        let edge = edges[sender.indexOfSelectedItem]
        UserDefaults.standard.set(edge, forKey: "dockEdge")
        NotificationCenter.default.post(name: .init("DockEdgeChanged"), object: nil, userInfo: ["edge": edge])
    }

    @objc private func capsuleModeChanged(_ sender: NSPopUpButton) {
        let mode = sender.indexOfSelectedItem == 1 ? "pet" : "aurora"
        UserDefaults.standard.set(mode, forKey: "capsuleMode")
        NotificationCenter.default.post(name: .init("CapsuleModeChanged"), object: nil, userInfo: ["mode": mode])
    }

    @objc private func opacityChanged(_ sender: NSSlider) {
        let opacity = Float(sender.doubleValue)
        UserDefaults.standard.set(opacity, forKey: "panelOpacity")
        NotificationCenter.default.post(name: .init("SettingsChanged"), object: nil)
    }

    @objc private func fontSizeChanged(_ sender: NSStepper) {
        UserDefaults.standard.set(sender.integerValue, forKey: "fontSize")
        // Update label
        if let fontLabel = sender.superview?.viewWithTag(100) as? NSTextField {
            fontLabel.stringValue = "\(sender.integerValue)px"
        }
        NotificationCenter.default.post(name: .init("SettingsChanged"), object: nil)
    }

    @objc private func toggleNotifications(_ sender: NSSwitch) {
        UserDefaults.standard.set(sender.state == .off, forKey: "notificationsDisabled")
    }

    private func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }
}
