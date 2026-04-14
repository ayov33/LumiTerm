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
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 280),
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
        let sl = CustomSlider(value: Double(op == 0 ? 0.6 : op), min: 0.3, max: 1.0)
        sl.onChange = { v in
            UserDefaults.standard.set(Float(v), forKey: "panelOpacity")
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
        y = addCard("Panel Opacity", control: sl, w: w, y: y)
        y -= rowGap

        y = addCard("Font Size", control: makeFontSize(), w: w, y: y)
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
