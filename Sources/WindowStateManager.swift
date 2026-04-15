import Cocoa

enum WindowState {
    case collapsed
    case expanded
}

enum DockEdge: String {
    case right, left, top, bottom
}

class WindowStateManager {
    let panel: FloatingPanel
    var state: WindowState = .collapsed
    var dockEdge: DockEdge = .right

    var onStateChanged: ((WindowState) -> Void)?
    var onWillExpand: (() -> Void)?
    var onWillCollapse: (() -> Void)?

    private let stripW: CGFloat = 30
    private let stripH: CGFloat = 100

    // Left/Right docking: tall narrow panel
    private let sideWidth: CGFloat = 650
    private let sideHeightRatio: CGFloat = 0.6

    // Top/Bottom docking: wide short panel
    private let horizWidthRatio: CGFloat = 0.5
    private let horizHeight: CGFloat = 300

    private var isAnimating = false

    // Get screen where mouse is currently located
    private var currentScreen: NSScreen {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? panel.screen ?? NSScreen.main ?? NSScreen.screens[0]
    }

    init(panel: FloatingPanel) {
        self.panel = panel
        if let saved = UserDefaults.standard.string(forKey: "dockEdge"),
           let edge = DockEdge(rawValue: saved) {
            dockEdge = edge
        }
    }

    private func panelHeight() -> CGFloat {
        return currentScreen.visibleFrame.height * sideHeightRatio
    }

    func setupInitial() {
        panel.setFrame(collapsedFrame(), display: true)
        state = .collapsed
        panel.orderFront(nil)
        onStateChanged?(.collapsed)
    }

    // MARK: - Expand: window smoothly grows from strip to panel

    func expand() {
        guard state == .collapsed, !isAnimating else { return }
        state = .expanded
        isAnimating = true

        onWillExpand?()

        let target = expandedFrame()

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.panel.animator().setFrame(target, display: true)
        }, completionHandler: { [weak self] in
            self?.isAnimating = false
            self?.onStateChanged?(.expanded)
        })
    }

    // MARK: - Collapse: window smoothly shrinks from panel to strip

    func collapse() {
        guard state == .expanded, !isAnimating else { return }
        state = .collapsed
        isAnimating = true

        onWillCollapse?()

        let target = collapsedFrame()

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.panel.animator().setFrame(target, display: true)
        }, completionHandler: { [weak self] in
            self?.isAnimating = false
            self?.onStateChanged?(.collapsed)
        })
    }

    func toggle() {
        if state == .collapsed { expand() } else { collapse() }
    }

    func snapToNearestEdge() {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let sf = screen.visibleFrame
        let wf = panel.frame

        let distRight = abs(sf.maxX - wf.maxX)
        let distLeft = abs(wf.minX - sf.minX)
        let distTop = abs(sf.maxY - wf.maxY)
        let distBottom = abs(wf.minY - sf.minY)
        let minDist = min(distRight, distLeft, distTop, distBottom)

        if minDist == distRight { dockEdge = .right }
        else if minDist == distLeft { dockEdge = .left }
        else if minDist == distTop { dockEdge = .top }
        else { dockEdge = .bottom }

        UserDefaults.standard.set(dockEdge.rawValue, forKey: "dockEdge")
        panel.setFrame(collapsedFrame(), display: true)
    }

    // MARK: - Frames

    func collapsedFrame() -> NSRect {
        let sf = currentScreen.visibleFrame
        switch dockEdge {
        case .right:
            return NSRect(x: sf.maxX - stripW, y: sf.midY - stripH/2, width: stripW, height: stripH)
        case .left:
            return NSRect(x: sf.minX, y: sf.midY - stripH/2, width: stripW, height: stripH)
        case .top:
            return NSRect(x: sf.midX - stripH/2, y: sf.maxY - stripW, width: stripH, height: stripW)
        case .bottom:
            return NSRect(x: sf.midX - stripH/2, y: sf.minY, width: stripH, height: stripW)
        }
    }

    func expandedFrame() -> NSRect {
        let sf = currentScreen.visibleFrame

        switch dockEdge {
        case .right:
            let ph = sf.height * sideHeightRatio
            let cy = sf.midY - ph / 2
            return NSRect(x: sf.maxX - sideWidth, y: cy, width: sideWidth, height: ph)
        case .left:
            let ph = sf.height * sideHeightRatio
            let cy = sf.midY - ph / 2
            return NSRect(x: sf.minX, y: cy, width: sideWidth, height: ph)
        case .top:
            let pw = sf.width * horizWidthRatio
            let cx = sf.midX - pw / 2
            return NSRect(x: cx, y: sf.maxY - horizHeight, width: pw, height: horizHeight)
        case .bottom:
            let pw = sf.width * horizWidthRatio
            let cx = sf.midX - pw / 2
            return NSRect(x: cx, y: sf.minY, width: pw, height: horizHeight)
        }
    }
}
