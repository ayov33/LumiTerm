import Cocoa
import ServiceManagement

// MARK: - Settings Window Controller

class SettingsWindowController: NSWindowController {

    private let bgColor = NSColor(red: 0.965, green: 0.965, blue: 0.965, alpha: 1.0)
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
        window.backgroundColor = NSColor(red: 0.965, green: 0.965, blue: 0.965, alpha: 1.0)
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

        let s2 = CustomSwitch(isOn: true)
        s2.onToggle = { _ in }
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
            NotificationCenter.default.post(name: .init("CapsuleModeChanged"), object: nil, userInfo: ["mode": m])
        }
        y = addCard("Capsule Style", control: dd, w: w, y: y)
        y -= rowGap

        let op = UserDefaults.standard.float(forKey: "panelOpacity")
        let sl = CustomSlider(value: Double(op == 0 ? 0.6 : op), min: 0.3, max: 1.0)
        sl.onChange = { v in
            UserDefaults.standard.set(Float(v), forKey: "panelOpacity")
            NotificationCenter.default.post(name: .init("SettingsChanged"), object: nil)
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
        let vals = ["LumiTerm", "v1.0.0", "A lightweight floating terminal", "—", "Ayo"]
        for i in 0..<keys.count {
            let k = makeLabel(keys[i], font: labelFont)
            k.frame = NSRect(x: 0, y: y - lineH, width: labelW, height: lineH)
            sectionContainer.addSubview(k)
            let v = makeLabel(vals[i], font: labelFontItalic)
            v.frame = NSRect(x: labelW, y: y - lineH, width: w - labelW, height: lineH)
            sectionContainer.addSubview(v)
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
                NotificationCenter.default.post(name: .init("DockEdgeChanged"), object: nil, userInfo: ["edge": edge])
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
            NotificationCenter.default.post(name: .init("SettingsChanged"), object: nil)
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

// MARK: - Custom Switch (42×22, black pill, white knob)

class CustomSwitch: NSView {
    var isOn: Bool
    var onToggle: ((Bool) -> Void)?
    private let knob = NSView()

    init(isOn: Bool) {
        self.isOn = isOn
        super.init(frame: NSRect(x: 0, y: 0, width: 42, height: 22))
        wantsLayer = true
        layer?.cornerRadius = 11
        knob.wantsLayer = true
        knob.layer?.cornerRadius = 9
        knob.layer?.backgroundColor = NSColor.white.cgColor
        addSubview(knob)
        updateUI()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func updateUI() {
        layer?.backgroundColor = isOn ? NSColor.black.cgColor : NSColor(white: 0.78, alpha: 1).cgColor
        let x: CGFloat = isOn ? 22 : 2
        knob.frame = NSRect(x: x, y: 2, width: 18, height: 18)
    }

    override func mouseDown(with event: NSEvent) {
        isOn.toggle()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            self.knob.animator().frame.origin.x = self.isOn ? 22 : 2
        }
        layer?.backgroundColor = isOn ? NSColor.black.cgColor : NSColor(white: 0.78, alpha: 1).cgColor
        onToggle?(isOn)
    }
}

// MARK: - Custom Dock Button (24×24, black border, selected=black fill)

class CustomDockButton: NSView {
    var symbol = ""
    var isSelected = false
    var onTap: ((Int) -> Void)?
    var buttonTag = 0

    override func draw(_ dirtyRect: NSRect) {
        let ctx = NSGraphicsContext.current!.cgContext
        let r = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = CGPath(roundedRect: r, cornerWidth: 4, cornerHeight: 4, transform: nil)

        if isSelected {
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.addPath(path)
            ctx.fillPath()
        }

        ctx.setStrokeColor(NSColor.black.cgColor)
        ctx.setLineWidth(1)
        ctx.addPath(path)
        ctx.strokePath()

        // Draw symbol
        let color: NSColor = isSelected ? .white : .black
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: color
        ]
        let str = NSAttributedString(string: symbol, attributes: attrs)
        let sz = str.size()
        let pt = NSPoint(x: (bounds.width - sz.width) / 2, y: (bounds.height - sz.height) / 2)
        str.draw(at: pt)
    }

    override func mouseDown(with event: NSEvent) {
        onTap?(buttonTag)
    }
}

// MARK: - Custom Dropdown (91×28, thin border, chevron path)

class CustomDropdown: NSView {
    var items: [String]
    var selectedIndex: Int
    var onChange: ((Int) -> Void)?

    init(items: [String], selected: Int) {
        self.items = items
        self.selectedIndex = selected
        super.init(frame: NSRect(x: 0, y: 0, width: 91, height: 28))
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let ctx = NSGraphicsContext.current!.cgContext
        let r = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = CGPath(roundedRect: r, cornerWidth: 4, cornerHeight: 4, transform: nil)

        ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.5).cgColor)
        ctx.setLineWidth(1)
        ctx.addPath(path)
        ctx.strokePath()

        // Text
        let text = items[selectedIndex]
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "Helvetica", size: 14) ?? NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.black
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let sz = str.size()
        str.draw(at: NSPoint(x: 13, y: (bounds.height - sz.height) / 2))

        // Chevron — draw V shape with path
        ctx.setStrokeColor(NSColor.black.cgColor)
        ctx.setLineWidth(1.5)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        let cx = bounds.width - 14
        let cy = bounds.height / 2
        ctx.move(to: CGPoint(x: cx - 3.5, y: cy + 2))
        ctx.addLine(to: CGPoint(x: cx, y: cy - 2))
        ctx.addLine(to: CGPoint(x: cx + 3.5, y: cy + 2))
        ctx.strokePath()
    }

    override func mouseDown(with event: NSEvent) {
        let menu = NSMenu()
        for (i, item) in items.enumerated() {
            let mi = NSMenuItem(title: item, action: #selector(itemSelected(_:)), keyEquivalent: "")
            mi.target = self
            mi.tag = i
            if i == selectedIndex { mi.state = .on }
            menu.addItem(mi)
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: bounds.height), in: self)
    }

    @objc private func itemSelected(_ sender: NSMenuItem) {
        selectedIndex = sender.tag
        needsDisplay = true
        onChange?(selectedIndex)
    }
}

// MARK: - Custom Slider (130×15, rounded gray track, black fill, white knob)

class CustomSlider: NSView {
    var value: Double
    var minVal: Double
    var maxVal: Double
    var onChange: ((Double) -> Void)?
    private var dragging = false

    init(value: Double, min: Double, max: Double) {
        self.value = value
        self.minVal = min
        self.maxVal = max
        super.init(frame: NSRect(x: 0, y: 0, width: 100, height: 20))
    }
    required init?(coder: NSCoder) { fatalError() }

    private let knobSize: CGFloat = 15

    private var knobCenterX: CGFloat {
        let ratio = CGFloat((value - minVal) / (maxVal - minVal))
        let half = knobSize / 2
        return half + ratio * (bounds.width - knobSize)
    }

    override func draw(_ dirtyRect: NSRect) {
        let ctx = NSGraphicsContext.current!.cgContext
        let midY = bounds.height / 2
        let trackH: CGFloat = 4
        let trackY = midY - trackH / 2
        let trackR = trackH / 2

        // Full track (gray, rounded)
        let fullTrack = CGRect(x: 0, y: trackY, width: bounds.width, height: trackH)
        let fullPath = CGPath(roundedRect: fullTrack, cornerWidth: trackR, cornerHeight: trackR, transform: nil)
        ctx.setFillColor(NSColor(white: 0.85, alpha: 1).cgColor)
        ctx.addPath(fullPath)
        ctx.fillPath()

        // Filled track (black, rounded)
        let fillW = knobCenterX
        if fillW > 0 {
            let fillTrack = CGRect(x: 0, y: trackY, width: fillW, height: trackH)
            let fillPath = CGPath(roundedRect: fillTrack, cornerWidth: trackR, cornerHeight: trackR, transform: nil)
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.addPath(fillPath)
            ctx.fillPath()
        }

        // Knob (white circle with subtle shadow)
        let knobY = midY - knobSize / 2
        let knobRect = CGRect(x: knobCenterX - knobSize / 2, y: knobY, width: knobSize, height: knobSize)
        ctx.setShadow(offset: CGSize(width: 0, height: -1), blur: 2, color: NSColor.black.withAlphaComponent(0.15).cgColor)
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fillEllipse(in: knobRect)
        ctx.setShadow(offset: .zero, blur: 0)
        ctx.setStrokeColor(NSColor(white: 0.78, alpha: 1).cgColor)
        ctx.setLineWidth(0.5)
        ctx.strokeEllipse(in: knobRect)
    }

    override func mouseDown(with event: NSEvent) { dragging = true; updateValue(event) }
    override func mouseDragged(with event: NSEvent) { guard dragging else { return }; updateValue(event) }
    override func mouseUp(with event: NSEvent) { dragging = false }

    private func updateValue(_ event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        let ratio = Double(max(0, min(1, pt.x / bounds.width)))
        value = minVal + ratio * (maxVal - minVal)
        needsDisplay = true
        onChange?(value)
    }
}

// MARK: - Custom Stepper (16×32, up/down chevron paths)

class CustomStepper: NSView {
    var value: Int
    var minVal: Int
    var maxVal: Int
    var onChange: ((Int) -> Void)?

    init(value: Int, min: Int, max: Int) {
        self.value = value
        self.minVal = min
        self.maxVal = max
        super.init(frame: NSRect(x: 0, y: 0, width: 16, height: 32))
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let ctx = NSGraphicsContext.current!.cgContext
        ctx.setStrokeColor(NSColor.black.cgColor)
        ctx.setLineWidth(1.5)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        let cx = bounds.width / 2
        // Up chevron (top half)
        let uy = bounds.height * 0.75
        ctx.move(to: CGPoint(x: cx - 4, y: uy - 3))
        ctx.addLine(to: CGPoint(x: cx, y: uy + 3))
        ctx.addLine(to: CGPoint(x: cx + 4, y: uy - 3))
        ctx.strokePath()

        // Down chevron (bottom half)
        let dy = bounds.height * 0.25
        ctx.move(to: CGPoint(x: cx - 4, y: dy + 3))
        ctx.addLine(to: CGPoint(x: cx, y: dy - 3))
        ctx.addLine(to: CGPoint(x: cx + 4, y: dy + 3))
        ctx.strokePath()
    }

    override func mouseDown(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        if pt.y > bounds.height / 2 {
            if value < maxVal { value += 1; onChange?(value) }
        } else {
            if value > minVal { value -= 1; onChange?(value) }
        }
    }
}

// MARK: - Lumi Logo View (white bg + L gradient)

class LumiLogoView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let s = bounds.size
        let scale = s.width / 96.0  // design is 96×96

        // White rounded background
        let bgPath = NSBezierPath(roundedRect: bounds, xRadius: 20 * scale, yRadius: 20 * scale)
        NSColor.white.setFill()
        bgPath.fill()

        // Subtle border
        NSColor(white: 0.85, alpha: 1).setStroke()
        bgPath.lineWidth = 0.5
        bgPath.stroke()

        let vRect = CGRect(x: 24 * scale, y: s.height - 24 * scale - 47 * scale,
                           width: 17 * scale, height: 47 * scale)
        let hRect = CGRect(x: 24 * scale, y: s.height - 54 * scale - 17 * scale,
                           width: 47 * scale, height: 17 * scale)

        let cs = CGColorSpaceCreateDeviceRGB()

        // Vertical bar: top→bottom = black→transparent (flipped coords: bottom→top)
        let vColors = [NSColor.black.cgColor, NSColor.black.withAlphaComponent(0).cgColor]
        if let g = CGGradient(colorsSpace: cs, colors: vColors as CFArray, locations: [0, 1]) {
            ctx.saveGState()
            ctx.clip(to: vRect)
            ctx.drawLinearGradient(g,
                                   start: CGPoint(x: vRect.midX, y: vRect.maxY),
                                   end: CGPoint(x: vRect.midX, y: vRect.minY),
                                   options: [])
            ctx.restoreGState()
        }

        // Horizontal bar: left→right = transparent→black (rotated gradient from Figma)
        let hColors = [NSColor.black.withAlphaComponent(0).cgColor, NSColor.black.cgColor]
        if let g = CGGradient(colorsSpace: cs, colors: hColors as CFArray, locations: [0, 1]) {
            ctx.saveGState()
            ctx.clip(to: hRect)
            ctx.drawLinearGradient(g,
                                   start: CGPoint(x: hRect.minX, y: hRect.midY),
                                   end: CGPoint(x: hRect.maxX, y: hRect.midY),
                                   options: [])
            ctx.restoreGState()
        }
    }
}
