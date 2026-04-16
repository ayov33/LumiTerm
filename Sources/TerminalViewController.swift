import Cocoa
import WebKit

class TerminalViewController: NSViewController {
    private var webView: WKWebView!
    private var ptys: [String: PTY] = [:]  // tabId → PTY
    private var outputBuffers: [String: Data] = [:]
    private var flushScheduled: Set<String> = []

    var onOutput: ((Int) -> Void)?
    var onBell: (() -> Void)?

    private var htmlReady = false
    private var started = false

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 500))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = true
        let handler = WebViewMessageHandler(self)
        config.userContentController.add(handler, name: "terminal")

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = self

        #if DEBUG
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        }
        #endif
        view.addSubview(webView)

        loadTerminalHTML()
    }

    private func loadTerminalHTML() {
        guard let resourceURL = Bundle.module.url(
            forResource: "terminal",
            withExtension: "html",
            subdirectory: "Resources/terminal"
        ) else {
            #if DEBUG
            print("[Terminal] terminal.html not found")
            #endif
            return
        }
        let dir = resourceURL.deletingLastPathComponent()
        webView.loadFileURL(resourceURL, allowingReadAccessTo: dir)
    }

    // MARK: - Public API

    /// Call after first expand to create first tab and start shell
    func start() {
        guard htmlReady, !started else { return }
        started = true
        webView.window?.makeFirstResponder(webView)
        webView.evaluateJavaScript("termManager.ready();", completionHandler: nil)
    }

    /// Focus the webview (call on expand)
    func focusTerminal() {
        webView.window?.makeFirstResponder(webView)
        if htmlReady && started {
            webView.evaluateJavaScript("termManager.fitActive();", completionHandler: nil)
        } else if htmlReady && !started {
            start()
        }
    }

    /// Set the default tab title (e.g. Claude Code version)
    func setDefaultTitle(_ title: String) {
        guard htmlReady else { return }
        let escaped = title.replacingOccurrences(of: "'", with: "\\'")
        webView.evaluateJavaScript("termManager.setDefaultTitle('\(escaped)');", completionHandler: nil)
    }

    /// Change terminal font size for all tabs
    func setFontSize(_ size: Int) {
        guard htmlReady else { return }
        webView.evaluateJavaScript("termManager.setFontSize(\(size));", completionHandler: nil)
    }
    /// Change terminal background opacity
    func setBackgroundOpacity(_ opacity: Float) {
        guard htmlReady else { return }
        webView.evaluateJavaScript("termManager.setBackgroundOpacity(\(opacity));", completionHandler: nil)
    }

    /// Change terminal color theme
    func setTheme(_ name: String) {
        guard htmlReady else { return }
        let escaped = name.replacingOccurrences(of: "'", with: "\\'")
        webView.evaluateJavaScript("termManager.setTheme('\(escaped)');", completionHandler: nil)
    }

    /// Show/hide progress light strip (command running indicator)
    func setRunning(_ running: Bool) {
        guard htmlReady else { return }
        webView.evaluateJavaScript("termManager.setRunning(\(running));", completionHandler: nil)
    }

    /// Create a new tab via JS
    func createTab() {
        guard htmlReady else { return }
        webView.evaluateJavaScript("termManager.createTab();", completionHandler: nil)
    }

    /// Switch to tab by index (0-based)
    func switchToTab(index: Int) {
        guard htmlReady else { return }
        webView.evaluateJavaScript("termManager.switchToIndex(\(index));", completionHandler: nil)
    }

    /// Close active tab via JS. Returns tab count via callback.
    var onLastTabClosed: (() -> Void)?

    func closeActiveTab() {
        guard htmlReady else { return }
        webView.evaluateJavaScript("termManager.getTabCount();") { [weak self] result, _ in
            guard let count = result as? Int else { return }
            if count <= 1 {
                self?.onLastTabClosed?()
            } else {
                self?.webView.evaluateJavaScript("""
                    (function() { var id = termManager.getActiveTabId(); if (id) termManager.closeTab(id); })();
                """, completionHandler: nil)
            }
        }
    }

    func cleanup() {
        for (_, pty) in ptys {
            pty.terminate()
        }
        ptys.removeAll()
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "terminal")
        webView?.stopLoading()
    }

    // MARK: - PTY Output → JS

    private func handlePTYOutput(tabId: String, data: Data) {
        onOutput?(data.count)

        if outputBuffers[tabId] == nil {
            outputBuffers[tabId] = Data()
        }
        outputBuffers[tabId]!.append(data)

        if !flushScheduled.contains(tabId) {
            flushScheduled.insert(tabId)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.008) { [weak self] in
                self?.flushBuffer(tabId: tabId)
            }
        }
    }

    private func flushBuffer(tabId: String) {
        flushScheduled.remove(tabId)
        guard let buffer = outputBuffers[tabId], !buffer.isEmpty else { return }
        let b64 = buffer.base64EncodedString()
        outputBuffers[tabId] = Data()
        webView.evaluateJavaScript("termManager.writeBase64('\(tabId)', '\(b64)');") { _, error in
            #if DEBUG
            if let error = error { print("[Terminal] JS error: \(error)") }
            #endif
        }
    }

    // MARK: - JS → Swift

    fileprivate func handleJSMessage(_ body: Any) {
        guard let dict = body as? [String: Any],
              let action = dict["action"] as? String else { return }

        let tabId = dict["tabId"] as? String ?? ""

        switch action {
        case "tabCreated":
            // Start a new PTY for this tab
            let pty = PTY()
            pty.onData = { [weak self] data in
                self?.handlePTYOutput(tabId: tabId, data: data)
            }
            // Closure-captured state for restart backoff (intentional — per-tab lifecycle)
            var restartCount = 0
            var lastRestartTime: Date = .distantPast
            pty.onExit = { [weak self] code in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    guard let self = self, self.ptys[tabId] != nil else { return }
                    let now = Date()
                    // Reset counter if last restart was > 10s ago (normal exit)
                    if now.timeIntervalSince(lastRestartTime) > 10 {
                        restartCount = 0
                    }
                    restartCount += 1
                    lastRestartTime = now
                    if restartCount <= 3 {
                        self.ptys[tabId]?.start()
                    } else {
                        // Shell keeps crashing — show error instead of infinite loop
                        let msg = "\r\n\u{1b}[31m[LumiTerm] Shell exited repeatedly (code \(code)). Check your shell config.\u{1b}[0m\r\n"
                        self.handlePTYOutput(tabId: tabId, data: msg.data(using: .utf8) ?? Data())
                    }
                }
            }
            ptys[tabId] = pty
            pty.start()

        case "tabClosed":
            ptys[tabId]?.terminate()
            ptys.removeValue(forKey: tabId)
            outputBuffers.removeValue(forKey: tabId)

        case "tabSwitched":
            break  // No native action needed

        case "data":
            if let b64 = dict["data"] as? String,
               let data = Data(base64Encoded: b64) {
                ptys[tabId]?.write(data)
            }

        case "resize":
            if let cols = dict["cols"] as? Int,
               let rows = dict["rows"] as? Int {
                ptys[tabId]?.resize(cols: UInt16(cols), rows: UInt16(rows))
            }

        case "bell":
            onBell?()

        default: break
        }
    }

    deinit {
        for (_, pty) in ptys { pty.terminate() }
    }
}

extension TerminalViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        htmlReady = true
    }
}

private class WebViewMessageHandler: NSObject, WKScriptMessageHandler {
    weak var controller: TerminalViewController?
    init(_ c: TerminalViewController) { self.controller = c }

    func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage) {
        controller?.handleJSMessage(message.body)
    }
}
