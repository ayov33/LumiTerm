import Cocoa

class ScreenEdgeMonitor {
    var onMouseAtEdge: (() -> Void)?
    var onMouseAwayFromPanel: (() -> Void)?
    var panelFrameProvider: (() -> NSRect)?
    var stateProvider: (() -> WindowState)?

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var pollTimer: Timer?   // periodic check — catches static mouse
    private var hoverTimer: Timer?
    private var leaveTimer: Timer?
    private var isMouseInRegion = false
    var isPaused = false

    private let edgeThreshold: CGFloat = 5
    private let hoverDelay: TimeInterval = 0.6
    private let leaveDelay: TimeInterval = 0.15
    private let pollInterval: TimeInterval = 0.2

    func start() {
        // Event-based detection (responsive when mouse is moving)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.checkMouse()
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.checkMouse()
            return event
        }
        // Timer-based fallback (catches static mouse after drag, etc.)
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.checkMouse()
        }
    }

    func stop() {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor { NSEvent.removeMonitor(m) }
        globalMonitor = nil
        localMonitor = nil
        pollTimer?.invalidate()
        pollTimer = nil
        cancelTimers()
    }

    func cancelTimers() {
        hoverTimer?.invalidate()
        hoverTimer = nil
        leaveTimer?.invalidate()
        leaveTimer = nil
        isMouseInRegion = false
    }

    private func checkMouse() {
        if isPaused { return }
        let mouse = NSEvent.mouseLocation
        let state = stateProvider?() ?? .collapsed

        // Only need poll timer in collapsed state; pause it in expanded
        if state == .expanded && pollTimer != nil {
            pollTimer?.invalidate()
            pollTimer = nil
        } else if state == .collapsed && pollTimer == nil {
            pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
                self?.checkMouse()
            }
        }

        if state == .collapsed {
            let visibleRect = panelFrameProvider?() ?? .zero
            let expandedRegion = visibleRect.insetBy(dx: -edgeThreshold, dy: -edgeThreshold)

            if expandedRegion.contains(mouse) {
                if !isMouseInRegion {
                    isMouseInRegion = true
                    leaveTimer?.invalidate()
                    hoverTimer = Timer.scheduledTimer(withTimeInterval: hoverDelay, repeats: false) { [weak self] _ in
                        self?.onMouseAtEdge?()
                    }
                }
            } else {
                if isMouseInRegion {
                    isMouseInRegion = false
                    hoverTimer?.invalidate()
                }
            }
        } else {
            let panelFrame = panelFrameProvider?() ?? .zero
            if panelFrame.contains(mouse) {
                if !isMouseInRegion {
                    isMouseInRegion = true
                    leaveTimer?.invalidate()
                }
            } else {
                if isMouseInRegion {
                    isMouseInRegion = false
                    hoverTimer?.invalidate()
                    leaveTimer = Timer.scheduledTimer(withTimeInterval: leaveDelay, repeats: false) { [weak self] _ in
                        self?.onMouseAwayFromPanel?()
                    }
                }
            }
        }
    }
}
