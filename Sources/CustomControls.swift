import Cocoa

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
