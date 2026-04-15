import Cocoa
import ServiceManagement

// MARK: - Settings Window Controller

class SettingsWindowController: NSWindowController {

    private let bgColor = Theme.bgSettings
    private let cardColor = NSColor.white
    private let cardRadius: CGFloat = 8
    private let sidePad: CGFloat = 24
    private let topPad: CGFloat = 24
    private let rowH: CGFloat = 50
    private let rowGap: CGFloat = 8
    private let rowPadX: CGFloat = 16
    private let tabGap: CGFloat = 24
    private let tabFont = NSFont(name: "Helvetica-Bold", size: 16) ?? NSFont.boldSystemFont(ofSize: 16)
    private let labelFont = NSFont(name: "Helvetica", size: 14) ?? NSFont.systemFont(ofSize: 14)
    private let labelFontItalic = NSFont(name: "Helvetica-LightOblique", size: 14) ?? NSFont.systemFont(ofSize: 14)

    private var currentTab = 0
    private var tabLabels: [NSTextField] = []
    private var mainView: NSView!
    private var sectionContainer: NSView!

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 460),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        window.title = "LumiTerm"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = Theme.bgSettings
        window.center()
        window.isReleasedWhenClosed = false
        self.init(window: window)

        mainView = NSView(frame: window.contentView!.bounds)
        mainView.autoresizingMask = [.width, .height]
        mainView.wantsLayer = true
        mainView.layer?.backgroundColor = bgColor.cgColor
        window.contentView = mainView

        buildTabs()
        buildSectionContainer()
        showTab(0)
    }

    // MARK: - Tabs

    private func buildTabs() {
        let tabs = ["General", "Appearance", "Notifications", "About"]
        var x = sidePad
        for (i, title) in tabs.enumerated() {
            let label = NSTextField(labelWithString: title)
            label.font = tabFont
            label.textColor = .labelColor
            label.alphaValue = (i == 0) ? 1.0 : 0.4
            label.sizeToFit()
            label.frame.origin = NSPoint(x: x, y: mainView.bounds.height - topPad - label.frame.height)
            mainView.addSubview(label)
            let click = NSClickGestureRecognizer(target: self, action: #selector(tabClicked(_:)))
            label.addGestureRecognizer(click)
            label.tag = i
            tabLabels.append(label)
            x += label.frame.width + tabGap
        }
    }

    private func buildSectionContainer() {
        let tabBottom = tabLabels[0].frame.origin.y
        let h = tabBottom - 36 - 32
        sectionContainer = NSView(frame: NSRect(x: sidePad, y: 36, width: mainView.bounds.width - sidePad * 2, height: h))
        mainView.addSubview(sectionContainer)
    }

    @objc private func tabClicked(_ g: NSClickGestureRecognizer) {
        guard let v = g.view as? NSTextField else { return }
        showTab(v.tag)
    }

    private func showTab(_ idx: Int) {
        currentTab = idx
        for (i, l) in tabLabels.enumerated() { l.alphaValue = (i == idx) ? 1.0 : 0.4 }
        sectionContainer.subviews.forEach { $0.removeFromSuperview() }
        switch idx {
        case 0: buildGeneral()
        case 1: buildAppearance()
        case 2: buildNotifications()
        case 3: buildAbout()
        default: break
        }
    }

    // MARK: - General

    private func buildGeneral() {
        let w = sectionContainer.bounds.width
        var y = sectionContainer.bounds.height

        let s1 = CustomSwitch(isOn: isLaunchAtLoginEnabled())
        s1.onToggle = { [weak self] on in self?.doLaunchAtLogin(on) }
        y = addCard("Launch at Login", control: s1, w: w, y: y)
        y -= rowGap

        let hotkeyEnabled = !UserDefaults.standard.bool(forKey: "hotkeyDisabled")
        let s2 = CustomSwitch(isOn: hotkeyEnabled)
        s2.onToggle = { on in
            UserDefaults.standard.set(!on, forKey: "hotkeyDisabled")
        }
        y = addCard("Global Hotkey", control: s2, w: w, y: y)
        y -= rowGap

        y = addCard("Dock Position", control: makeDockButtons(), w: w, y: y)
    }

    // MARK: - Appearance

    private func buildAppearance() {
        let w = sectionContainer.bounds.width
        var y = sectionContainer.bounds.height

        let saved = UserDefaults.standard.string(forKey: "capsuleMode") ?? "aurora"
        let dd = CustomDropdown(items: ["Aurora", "Pixel Pet"], selected: saved == "pet" ? 1 : 0)
        dd.onChange = { idx in
            let m = idx == 1 ? "pet" : "aurora"
            UserDefaults.standard.set(m, forKey: "capsuleMode")
            NotificationCenter.default.post(name: .capsuleModeChanged, object: nil, userInfo: ["mode": m])
        }
        y = addCard("Capsule Style", control: dd, w: w, y: y)
        y -= rowGap

        let op = UserDefaults.standard.float(forKey: "panelOpacity")
        let sl = CustomSlider(value: Double(op > 0 ? op : Theme.defaultOpacity), min: 0.3, max: 1.0)
        sl.onChange = { v in
            UserDefaults.standard.set(Float(v), forKey: "panelOpacity")
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
        y = addCard("Panel Opacity", control: sl, w: w, y: y)
        y -= rowGap

        y = addCard("Font Size", control: makeFontSize(), w: w, y: y)
        y -= rowGap

        y = addThemeCard(w: w, y: y)
    }

    // MARK: - Theme Selector Card

    private func addThemeCard(w: CGFloat, y: CGFloat) -> CGFloat {
        let cardH: CGFloat = 172
        let card = NSView(frame: NSRect(x: 0, y: y - cardH, width: w, height: cardH))
        card.wantsLayer = true
        card.layer?.backgroundColor = cardColor.cgColor
        card.layer?.cornerRadius = cardRadius
        sectionContainer.addSubview(card)

        // "Theme" label at top-left
        let titleLabel = makeLabel("Theme", font: labelFont)
        titleLabel.frame.origin = NSPoint(x: rowPadX, y: cardH - 12 - titleLabel.frame.height)
        card.addSubview(titleLabel)

        // Theme definitions for preview
        struct ThemeDef {
            let key: String
            let name: String
            let bgColor: NSColor
            let fgColor: NSColor
            let promptColor: NSColor   // for "claude" text
            let pathColor: NSColor     // for "~project" text
            let dotColors: [NSColor]
        }

        let themes: [ThemeDef] = [
            ThemeDef(
                key: "default", name: "Default",
                bgColor: Theme.panelBgDefault,
                fgColor: NSColor(red: 0.847, green: 0.847, blue: 0.847, alpha: 1.0),
                promptColor: NSColor(red: 0.486, green: 0.686, blue: 0.761, alpha: 1.0),
                pathColor: NSColor(red: 0.188, green: 0.820, blue: 0.345, alpha: 1.0),
                dotColors: [
                    NSColor(red: 1.0, green: 0.271, blue: 0.227, alpha: 1.0),
                    NSColor(red: 0.188, green: 0.820, blue: 0.345, alpha: 1.0),
                    NSColor(red: 1.0, green: 0.624, blue: 0.039, alpha: 1.0),
                    NSColor(red: 0.039, green: 0.518, blue: 1.0, alpha: 1.0),
                    NSColor(red: 0.749, green: 0.353, blue: 0.949, alpha: 1.0),
                    NSColor(red: 0.486, green: 0.686, blue: 0.761, alpha: 1.0),
                    NSColor(red: 0.969, green: 0.973, blue: 0.973, alpha: 1.0)
                ]
            ),
            ThemeDef(
                key: "tokyoNight", name: "Tokyo Night",
                bgColor: Theme.panelBgTokyoNight,
                fgColor: NSColor(red: 0.663, green: 0.694, blue: 0.839, alpha: 1.0),
                promptColor: NSColor(red: 0.478, green: 0.635, blue: 0.969, alpha: 1.0),
                pathColor: NSColor(red: 0.620, green: 0.808, blue: 0.416, alpha: 1.0),
                dotColors: [
                    NSColor(red: 0.969, green: 0.463, blue: 0.557, alpha: 1.0),
                    NSColor(red: 0.620, green: 0.808, blue: 0.416, alpha: 1.0),
                    NSColor(red: 0.878, green: 0.686, blue: 0.408, alpha: 1.0),
                    NSColor(red: 0.478, green: 0.635, blue: 0.969, alpha: 1.0),
                    NSColor(red: 0.733, green: 0.604, blue: 0.969, alpha: 1.0),
                    NSColor(red: 0.490, green: 0.812, blue: 1.0, alpha: 1.0),
                    NSColor(red: 0.663, green: 0.694, blue: 0.839, alpha: 1.0)
                ]
            ),
            ThemeDef(
                key: "catppuccin", name: "Catppuccin",
                bgColor: Theme.panelBgCatppuccin,
                fgColor: NSColor(red: 0.804, green: 0.839, blue: 0.957, alpha: 1.0),
                promptColor: NSColor(red: 0.537, green: 0.706, blue: 0.980, alpha: 1.0),
                pathColor: NSColor(red: 0.651, green: 0.890, blue: 0.631, alpha: 1.0),
                dotColors: [
                    NSColor(red: 0.953, green: 0.545, blue: 0.659, alpha: 1.0),
                    NSColor(red: 0.651, green: 0.890, blue: 0.631, alpha: 1.0),
                    NSColor(red: 0.976, green: 0.886, blue: 0.686, alpha: 1.0),
                    NSColor(red: 0.537, green: 0.706, blue: 0.980, alpha: 1.0),
                    NSColor(red: 0.796, green: 0.651, blue: 0.969, alpha: 1.0),
                    NSColor(red: 0.580, green: 0.886, blue: 0.835, alpha: 1.0),
                    NSColor(red: 0.729, green: 0.761, blue: 0.871, alpha: 1.0)
                ]
            )
        ]

        let savedTheme = UserDefaults.standard.string(forKey: "terminalTheme") ?? "default"
        let previewGap: CGFloat = 8
        let previewW = (w - rowPadX * 2 - previewGap * 2) / 3
        let previewH: CGFloat = 64
        let previewY = cardH - 12 - titleLabel.frame.height - 8 - previewH
        let dotsY = previewY - 16
        let radioY = dotsY - 22

        var radioButtons: [ThemeRadioButton] = []

        for (i, theme) in themes.enumerated() {
            let px = rowPadX + CGFloat(i) * (previewW + previewGap)

            // Mini preview background
            let preview = NSView(frame: NSRect(x: px, y: previewY, width: previewW, height: previewH))
            preview.wantsLayer = true
            preview.layer?.backgroundColor = theme.bgColor.cgColor
            preview.layer?.cornerRadius = 6
            card.addSubview(preview)

            // Colored prompt text: "user@:~project $" in theme colors
            let monoFont = NSFont(name: "Menlo", size: 8) ?? NSFont.monospacedSystemFont(ofSize: 8, weight: .regular)

            let promptStr = NSMutableAttributedString()
            promptStr.append(NSAttributedString(string: "user@", attributes: [
                .font: monoFont, .foregroundColor: theme.fgColor
            ]))
            promptStr.append(NSAttributedString(string: ":~project", attributes: [
                .font: monoFont, .foregroundColor: theme.pathColor
            ]))
            promptStr.append(NSAttributedString(string: " $ ", attributes: [
                .font: monoFont, .foregroundColor: theme.fgColor
            ]))
            promptStr.append(NSAttributedString(string: "claude", attributes: [
                .font: monoFont, .foregroundColor: theme.promptColor
            ]))

            let textField = NSTextField(labelWithAttributedString: promptStr)
            textField.frame = NSRect(x: 8, y: previewH - 20, width: previewW - 16, height: 14)
            textField.lineBreakMode = .byTruncatingTail
            preview.addSubview(textField)

            // Second line: cursor bar
            let cursorLine = NSMutableAttributedString()
            cursorLine.append(NSAttributedString(string: "> ", attributes: [
                .font: monoFont, .foregroundColor: theme.fgColor.withAlphaComponent(0.5)
            ]))
            cursorLine.append(NSAttributedString(string: "|", attributes: [
                .font: monoFont, .foregroundColor: theme.promptColor
            ]))
            let line2 = NSTextField(labelWithAttributedString: cursorLine)
            line2.frame = NSRect(x: 8, y: previewH - 34, width: previewW - 16, height: 14)
            preview.addSubview(line2)

            // Color dots row
            let dotSize: CGFloat = 7
            let dotGap: CGFloat = 4
            let totalDotsW = dotSize * CGFloat(theme.dotColors.count) + dotGap * CGFloat(theme.dotColors.count - 1)
            let dotsStartX = px + (previewW - totalDotsW) / 2

            for (di, color) in theme.dotColors.enumerated() {
                let dot = NSView(frame: NSRect(
                    x: dotsStartX + CGFloat(di) * (dotSize + dotGap),
                    y: dotsY,
                    width: dotSize, height: dotSize
                ))
                dot.wantsLayer = true
                dot.layer?.backgroundColor = color.cgColor
                dot.layer?.cornerRadius = dotSize / 2
                card.addSubview(dot)
            }

            // Theme name label centered below dots
            let nameLabel = NSTextField(labelWithString: theme.name)
            nameLabel.font = NSFont(name: "Helvetica", size: 10) ?? NSFont.systemFont(ofSize: 10)
            nameLabel.textColor = .secondaryLabelColor
            nameLabel.sizeToFit()
            nameLabel.frame.origin = NSPoint(
                x: px + (previewW - nameLabel.frame.width) / 2,
                y: radioY + 2
            )
            card.addSubview(nameLabel)

            // Radio button
            let radio = ThemeRadioButton(
                frame: NSRect(x: px + (previewW - 16) / 2, y: radioY - 18, width: 16, height: 16),
                isSelected: theme.key == savedTheme
            )
            radio.themeKey = theme.key
            radio.onSelect = { key in
                UserDefaults.standard.set(key, forKey: "terminalTheme")
                NotificationCenter.default.post(name: .settingsChanged, object: nil)
                for rb in radioButtons {
                    rb.isSelected = (rb.themeKey == key)
                    rb.needsDisplay = true
                }
            }
            card.addSubview(radio)
            radioButtons.append(radio)
        }

        return y - cardH
    }

    // MARK: - Notifications

    private func buildNotifications() {
        let w = sectionContainer.bounds.width
        var y = sectionContainer.bounds.height

        let s1 = CustomSwitch(isOn: !UserDefaults.standard.bool(forKey: "notificationsDisabled"))
        s1.onToggle = { on in UserDefaults.standard.set(!on, forKey: "notificationsDisabled") }
        y = addCard("Finished Alert", control: s1, w: w, y: y)
        y -= rowGap

        let s2 = CustomSwitch(isOn: !UserDefaults.standard.bool(forKey: "soundDisabled"))
        s2.onToggle = { on in UserDefaults.standard.set(!on, forKey: "soundDisabled") }
        y = addCard("Completion Sound", control: s2, w: w, y: y)
    }

    // MARK: - About

    private func buildAbout() {
        let w = sectionContainer.bounds.width
        let labelW: CGFloat = 120
        let lineH: CGFloat = 32
        var y = sectionContainer.bounds.height

        // Logo (white bg, rounded corners, L-shape gradient)
        let logoSize: CGFloat = 64
        let logoView = LumiLogoView(frame: NSRect(
            x: (w - logoSize) / 2, y: y - logoSize, width: logoSize, height: logoSize
        ))
        sectionContainer.addSubview(logoView)
        y -= logoSize + 16

        let keys = ["App Name", "Version", "Tagline", "GitHub", "Author"]
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
        let vals = ["LumiTerm", "v\(version)", "A lightweight floating terminal", "ayov33/LumiTerm", "Ayo"]
        let ghURL = "https://github.com/ayov33/LumiTerm"
        for i in 0..<keys.count {
            let k = makeLabel(keys[i], font: labelFont)
            k.frame = NSRect(x: 0, y: y - lineH, width: labelW, height: lineH)
            sectionContainer.addSubview(k)
            if keys[i] == "GitHub" {
                let link = NSTextField(labelWithAttributedString: NSAttributedString(
                    string: vals[i],
                    attributes: [
                        .font: labelFontItalic,
                        .foregroundColor: NSColor.linkColor,
                        .underlineStyle: NSUnderlineStyle.single.rawValue,
                        .link: URL(string: ghURL)!
                    ]
                ))
                link.frame = NSRect(x: labelW, y: y - lineH, width: w - labelW, height: lineH)
                link.allowsEditingTextAttributes = true
                link.isSelectable = true
                sectionContainer.addSubview(link)
            } else {
                let v = makeLabel(vals[i], font: labelFontItalic)
                v.frame = NSRect(x: labelW, y: y - lineH, width: w - labelW, height: lineH)
                sectionContainer.addSubview(v)
            }
            y -= lineH
        }
    }

    // MARK: - Helpers

    private func addCard(_ title: String, control: NSView, w: CGFloat, y: CGFloat) -> CGFloat {
        let card = NSView(frame: NSRect(x: 0, y: y - rowH, width: w, height: rowH))
        card.wantsLayer = true
        card.layer?.backgroundColor = cardColor.cgColor
        card.layer?.cornerRadius = cardRadius
        sectionContainer.addSubview(card)

        let lbl = makeLabel(title, font: labelFont)
        lbl.frame.origin = NSPoint(x: rowPadX, y: (rowH - lbl.frame.height) / 2)
        card.addSubview(lbl)

        let cW = max(control.frame.width, 20)
        let cH = max(control.frame.height, 20)
        control.frame = NSRect(x: w - rowPadX - cW, y: (rowH - cH) / 2, width: cW, height: cH)
        card.addSubview(control)

        return y - rowH
    }

    private func makeLabel(_ text: String, font: NSFont) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = font
        l.textColor = .labelColor
        l.isBezeled = false
        l.drawsBackground = false
        l.isEditable = false
        l.sizeToFit()
        return l
    }

    private func makeDockButtons() -> NSView {
        let s: CGFloat = 24, gap: CGFloat = 5
        let container = NSView(frame: NSRect(x: 0, y: 0, width: s * 4 + gap * 3, height: s))
        let syms = ["↑", "↓", "←", "→"]
        let edges = ["top", "bottom", "left", "right"]
        let saved = UserDefaults.standard.string(forKey: "dockEdge") ?? "right"
        for (i, sym) in syms.enumerated() {
            let btn = CustomDockButton(frame: NSRect(x: CGFloat(i) * (s + gap), y: 0, width: s, height: s))
            btn.symbol = sym
            btn.isSelected = (edges[i] == saved)
            btn.buttonTag = i
            btn.onTap = { tag in
                let edge = edges[tag]
                UserDefaults.standard.set(edge, forKey: "dockEdge")
                NotificationCenter.default.post(name: .dockEdgeChanged, object: nil, userInfo: ["edge": edge])
                for case let b as CustomDockButton in container.subviews {
                    b.isSelected = (edges[b.buttonTag] == edge)
                    b.needsDisplay = true
                }
            }
            container.addSubview(btn)
        }
        return container
    }

    private func makeFontSize() -> NSView {
        let fs = UserDefaults.standard.integer(forKey: "fontSize") == 0 ? 13 : UserDefaults.standard.integer(forKey: "fontSize")
        let lbl = makeLabel("\(fs) px", font: labelFont)
        lbl.tag = 100

        let stepper = CustomStepper(value: fs, min: 10, max: 20)
        stepper.onChange = { [weak lbl] val in
            UserDefaults.standard.set(val, forKey: "fontSize")
            lbl?.stringValue = "\(val) px"
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }

        let w = lbl.frame.width + 9 + stepper.frame.width
        let h = max(lbl.frame.height, stepper.frame.height)
        let c = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        lbl.frame.origin = NSPoint(x: 0, y: (h - lbl.frame.height) / 2)
        stepper.frame.origin = NSPoint(x: lbl.frame.width + 9, y: (h - stepper.frame.height) / 2)
        c.addSubview(lbl)
        c.addSubview(stepper)
        return c
    }

    // MARK: - Actions

    private func doLaunchAtLogin(_ on: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if on { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch {}
        }
    }

    private func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) { return SMAppService.mainApp.status == .enabled }
        return false
    }
}
