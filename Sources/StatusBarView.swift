import Cocoa
import WebKit

class StatusBarView: NSView {
    var onDragEnd: (() -> Void)?

    private var webView: WKWebView!
    private var currentStatus: TerminalStatus = .idle
    private var dragOrigin: NSPoint = .zero
    private var htmlLoaded = false
    private var pendingMode: String?

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 15
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 0.9).cgColor

        // WKWebView for Aurora CSS animation
        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = true

        webView = WKWebView(frame: bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = self

        // Allow mouse events to pass through to StatusBarView for dragging
        webView.allowsBackForwardNavigationGestures = false

        addSubview(webView)

        loadAuroraHTML()
    }

    private func loadAuroraHTML() {
        guard let url = Bundle.module.url(
            forResource: "aurora",
            withExtension: "html",
            subdirectory: "Resources/terminal"
        ) else {
            print("[Aurora] aurora.html not found")
            return
        }
        let dir = url.deletingLastPathComponent()
        webView.loadFileURL(url, allowingReadAccessTo: dir)
    }

    // MARK: - Status

    func updateStatus(_ status: TerminalStatus) {
        guard status != currentStatus else { return }
        currentStatus = status
        guard htmlLoaded else { return }

        switch status {
        case .idle:
            webView.evaluateJavaScript("window.auroraBridge.setState('idle');", completionHandler: nil)
        case .running:
            webView.evaluateJavaScript("window.auroraBridge.setState('running');", completionHandler: nil)
        }
    }

    func setOrientation(_ orient: String) {
        guard htmlLoaded else { return }
        webView.evaluateJavaScript("window.auroraBridge.setOrientation('\(orient)');", completionHandler: nil)
    }

    func updateMultiTabStatus(tabCount: Int, statuses: [TerminalStatus]) {
        updateStatus(statuses.contains(.running) ? .running : .idle)
    }

    func flashDone() {
        guard htmlLoaded else { return }
        webView.evaluateJavaScript("window.auroraBridge.flashDone();", completionHandler: nil)
    }

    func setMode(_ mode: String) {
        if htmlLoaded {
            webView.evaluateJavaScript("window.auroraBridge.setMode('\(mode)');", completionHandler: nil)
        } else {
            pendingMode = mode
        }
    }

    func pauseAnimations() {
        guard htmlLoaded else { return }
        webView.evaluateJavaScript("window.auroraBridge.pause();", completionHandler: nil)
    }

    func resumeAnimations() {
        guard htmlLoaded else { return }
        webView.evaluateJavaScript("window.auroraBridge.resume();", completionHandler: nil)
    }

    // MARK: - Mouse handling (drag through WKWebView)

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Return self instead of webView so drag events come to us
        return self
    }

    override func mouseDown(with event: NSEvent) {
        dragOrigin = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        guard let win = window else { return }
        let current = event.locationInWindow
        var origin = win.frame.origin
        origin.x += current.x - dragOrigin.x
        origin.y += current.y - dragOrigin.y
        win.setFrameOrigin(origin)
    }

    override func mouseUp(with event: NSEvent) {
        onDragEnd?()
    }
}

extension StatusBarView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        htmlLoaded = true
        // Apply current status
        updateStatus(currentStatus)
        // Apply saved capsule mode
        if let mode = pendingMode {
            setMode(mode)
            pendingMode = nil
        }
        // Set orientation based on current bounds
        let orient = bounds.width > bounds.height ? "horizontal" : "vertical"
        setOrientation(orient)
    }
}
