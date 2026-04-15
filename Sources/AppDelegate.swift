import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: FloatingPanel!
    var stateManager: WindowStateManager!
    var statusBar: StatusBarView!
    var statusItem: NSStatusItem!
    var edgeMonitor: ScreenEdgeMonitor!
    var settingsWC: SettingsWindowController?

    var terminalContainerView: NSView!
    var terminalVC: TerminalViewController!
    var outputMonitor: OutputMonitor!
    var transitionOverlay: NSView!

    var localHotkeyMonitor: Any?
    var globalHotkeyMonitor: Any?
    var flagsGlobalMonitor: Any?
    var flagsLocalMonitor: Any?
    var lastRightOptionTime: Date = .distantPast
    var isPinned = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Panel
        panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 500),
            cornerRadius: 15,
            bgColor: Theme.bgPanel
        )

        // 2. State manager
        stateManager = WindowStateManager(panel: panel)

        // 3. Status bar (collapsed state)
        statusBar = StatusBarView(frame: panel.contentView!.bounds)
        statusBar.autoresizingMask = [.width, .height]
        statusBar.onDragEnd = { [weak self] in
            guard let self = self else { return }
            self.stateManager.snapToNearestEdge()
            self.updateAuroraOrientation()
        }
        panel.contentView?.addSubview(statusBar)

        // 4. Terminal container (expanded state)
        terminalContainerView = NSView(frame: panel.contentView!.bounds)
        terminalContainerView.autoresizingMask = [.width, .height]
        terminalContainerView.wantsLayer = true
        terminalContainerView.layer?.backgroundColor = NSColor.clear.cgColor
        terminalContainerView.isHidden = true
        panel.contentView?.addSubview(terminalContainerView)

        // 5. Single TerminalViewController (manages tabs internally via JS)
        terminalVC = TerminalViewController()
        terminalVC.view.frame = terminalContainerView.bounds
        terminalVC.view.autoresizingMask = [.width, .height]
        terminalContainerView.addSubview(terminalVC.view)

        outputMonitor = OutputMonitor()
        terminalVC.onOutput = { [weak self] charCount in
            self?.outputMonitor.handleOutput(charCount)
        }
        terminalVC.onLastTabClosed = { [weak self] in
            self?.stateManager.collapse()
        }
        outputMonitor.onStatusChange = { [weak self] status in
            DispatchQueue.main.async {
                self?.statusBar.updateStatus(status)
            }
        }
        outputMonitor.onCommandFinished = { [weak self] in
            DispatchQueue.main.async {
                self?.statusBar.flashDone()
                // Play sound when collapsed and sound enabled
                if self?.stateManager.state == .collapsed,
                   !UserDefaults.standard.bool(forKey: "soundDisabled") {
                    NSSound(named: "Tink")?.play()
                }
            }
        }
        terminalVC.onBell = { [weak self] in
            DispatchQueue.main.async {
                if self?.stateManager.state == .collapsed {
                    self?.statusBar.flashDone()
                }
            }
        }

        // Detect Claude Code version
        detectClaudeVersion()

        // 6. Transition overlay for smooth expand/collapse
        transitionOverlay = NSView(frame: panel.contentView!.bounds)
        transitionOverlay.autoresizingMask = [.width, .height]
        transitionOverlay.wantsLayer = true
        transitionOverlay.layer?.backgroundColor = Theme.bgPanelSolid.cgColor
        transitionOverlay.isHidden = true
        panel.contentView?.addSubview(transitionOverlay)

        // 7. Edge detection
        edgeMonitor = ScreenEdgeMonitor()
        edgeMonitor.onMouseAtEdge = { [weak self] in
            self?.isPinned = false
            self?.stateManager.expand()
        }
        edgeMonitor.onMouseAwayFromPanel = { [weak self] in
            guard let self = self else { return }
            if !self.isPinned {
                self.stateManager.collapse()
            }
        }
        edgeMonitor.panelFrameProvider = { [weak self] in
            guard let self = self else { return .zero }
            return self.stateManager.state == .collapsed
                ? self.stateManager.collapsedFrame()
                : self.panel.frame
        }
        edgeMonitor.stateProvider = { [weak self] in
            return self?.stateManager.state ?? .collapsed
        }
        edgeMonitor.start()

        // 8. Capsule mode (aurora / pet)
        let savedMode = UserDefaults.standard.string(forKey: "capsuleMode") ?? "aurora"
        if savedMode == "pet" {
            statusBar.setMode("pet")
        }
        NotificationCenter.default.addObserver(forName: .capsuleModeChanged, object: nil, queue: .main) { [weak self] notif in
            if let mode = notif.userInfo?["mode"] as? String {
                self?.statusBar.setMode(mode)
            }
        }

        // Dock edge change from Settings
        NotificationCenter.default.addObserver(forName: .dockEdgeChanged, object: nil, queue: .main) { [weak self] notif in
            guard let self = self, let edgeStr = notif.userInfo?["edge"] as? String,
                  let edge = DockEdge(rawValue: edgeStr) else { return }
            self.stateManager.dockEdge = edge
            if self.stateManager.state == .collapsed {
                self.stateManager.setupInitial()
                self.updateAuroraOrientation()
            }
        }

        // Settings changes (opacity, font size)
        NotificationCenter.default.addObserver(forName: .settingsChanged, object: nil, queue: .main) { [weak self] _ in
            self?.applySettings()
        }

        // 9. State change callbacks
        stateManager.onWillExpand = { [weak self] in
            guard let self = self else { return }
            self.outputMonitor.isPaused = true
            self.statusBar.pauseAnimations()
            self.statusBar.isHidden = true
            self.terminalContainerView.isHidden = true
            self.terminalContainerView.autoresizingMask = []
            // Show semi-transparent bg during expand animation (matches terminal bg)
            self.transitionOverlay.layer?.backgroundColor = Theme.bgPanel.cgColor
            self.transitionOverlay.layer?.opacity = 1.0
            self.transitionOverlay.isHidden = false
        }
        stateManager.onWillCollapse = { [weak self] in
            guard let self = self else { return }
            self.outputMonitor.isPaused = true
            self.terminalContainerView.autoresizingMask = []
            self.terminalContainerView.isHidden = true
            self.statusBar.isHidden = true
            self.transitionOverlay.isHidden = false
            self.transitionOverlay.layer?.opacity = 1.0
        }
        stateManager.onStateChanged = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .expanded:
                let container = self.terminalContainerView!
                container.frame = self.panel.contentView!.bounds
                container.autoresizingMask = [.width, .height]
                container.isHidden = false
                self.transitionOverlay.isHidden = true
                self.panel.makeKey()
                self.terminalVC.focusTerminal()
                self.outputMonitor.isPaused = false

            case .collapsed:
                self.transitionOverlay.isHidden = true
                self.statusBar.alphaValue = 0
                self.statusBar.frame = self.panel.contentView!.bounds
                self.statusBar.autoresizingMask = [.width, .height]
                self.statusBar.isHidden = false
                self.statusBar.resumeAnimations()
                self.updateAuroraOrientation()
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.15
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    self.statusBar.animator().alphaValue = 1.0
                }
                // Resume output monitor after transition settles
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.outputMonitor.isPaused = false
                    self?.outputMonitor.resetPending()
                }
            }
        }

        // 9. Hotkeys
        globalHotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleHotkey(event)
        }
        localHotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.stateManager.state == .expanded {
                if let handled = self?.handleTabShortcut(event), handled {
                    return nil
                }
            }
            if self?.isHotkey(event) == true {
                self?.handleHotkey(event)
                return nil
            }
            return event
        }
        flagsGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
        flagsLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }

        // 10. Menu bar + edit menu
        setupStatusItem()
        setupEditMenu()

        // 11. Initial state
        panel.alphaValue = 1.0
        stateManager.setupInitial()
        applySettings()

        // Restore previous state if app was expanded+pinned when quit
        if UserDefaults.standard.bool(forKey: "wasExpanded") && UserDefaults.standard.bool(forKey: "wasPinned") {
            isPinned = true
            stateManager.expand()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Save state for restoration
        UserDefaults.standard.set(stateManager.state == .expanded, forKey: "wasExpanded")
        UserDefaults.standard.set(isPinned, forKey: "wasPinned")

        edgeMonitor.stop()
        terminalVC.cleanup()
        if let monitor = globalHotkeyMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localHotkeyMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = flagsGlobalMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = flagsLocalMonitor { NSEvent.removeMonitor(monitor) }
    }

    // MARK: - Claude Code version

    private func detectClaudeVersion() {
        DispatchQueue.global(qos: .utility).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-l", "-c", "claude --version 2>/dev/null"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice

            var version = ""
            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    version = output.components(separatedBy: " ").first ?? output
                }
            } catch {}

            if !version.isEmpty {
                DispatchQueue.main.async { [weak self] in
                    self?.terminalVC.setDefaultTitle(version)
                }
            }
        }
    }

    // MARK: - Apply Settings

    private func applySettings() {
        // Panel background opacity — controlled via HTML body background only
        let opacity = UserDefaults.standard.float(forKey: "panelOpacity")
        if opacity > 0 {
            terminalVC.setBackgroundOpacity(opacity)
        }
        // Font size
        let fontSize = UserDefaults.standard.integer(forKey: "fontSize")
        if fontSize > 0 {
            terminalVC.setFontSize(fontSize)
        }
    }

    // MARK: - Hotkeys

    private func isHotkey(_ event: NSEvent) -> Bool {
        return event.modifierFlags.contains([.command, .shift])
            && event.charactersIgnoringModifiers == "a"
    }

    private func handleHotkey(_ event: NSEvent) {
        guard !UserDefaults.standard.bool(forKey: "hotkeyDisabled") else { return }
        guard isHotkey(event) else { return }
        stateManager.toggle()
    }

    private func handleTabShortcut(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard let chars = event.charactersIgnoringModifiers else { return false }

        // Cmd+T: new tab
        if flags == .command && chars == "t" {
            terminalVC.createTab()
            return true
        }
        // Cmd+W: close tab or collapse
        if flags == .command && chars == "w" {
            terminalVC.closeActiveTab()
            return true
        }
        // Cmd+1~5: switch to tab by index
        if flags == .command, let n = Int(chars), n >= 1 && n <= 5 {
            terminalVC.switchToTab(index: n - 1)
            return true
        }
        return false
    }

    private var lastFlagsEventTime: Date = .distantPast

    private func handleFlagsChanged(_ event: NSEvent) {
        guard !UserDefaults.standard.bool(forKey: "hotkeyDisabled") else { return }
        guard event.keyCode == 61 else { return }
        guard event.modifierFlags.contains(.option) else { return }
        let now = Date()

        // Deduplicate: global + local monitors can both fire for the same event
        let sinceLast = now.timeIntervalSince(lastFlagsEventTime)
        lastFlagsEventTime = now
        guard sinceLast > 0.05 else { return }

        let elapsed = now.timeIntervalSince(lastRightOptionTime)
        lastRightOptionTime = now
        if elapsed > 0.1 && elapsed < 0.4 {
            lastRightOptionTime = .distantPast
            if stateManager.state == .collapsed {
                isPinned = true
                stateManager.expand()
            } else {
                isPinned = false
                stateManager.collapse()
            }
        }
    }

    // MARK: - Menu bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = makeLumiMenuBarIcon()
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Toggle Panel", action: #selector(togglePanel), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func togglePanel() { stateManager.toggle() }

    @objc private func openSettings() {
        if settingsWC == nil { settingsWC = SettingsWindowController() }
        settingsWC?.showWindow(nil)
        settingsWC?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() { NSApp.terminate(nil) }

    private func setupEditMenu() {
        let mainMenu = NSMenu()
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        NSApp.mainMenu = mainMenu
    }

    private func updateAuroraOrientation() {
        let edge = stateManager.dockEdge
        let orient = (edge == .top || edge == .bottom) ? "horizontal" : "vertical"
        statusBar.setOrientation(orient)
    }

    // MARK: - Logo

    /// Draw the L-shaped gradient logo for the menu bar (18×18 template image)
    private func makeLumiMenuBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let img = NSImage(size: size, flipped: true) { rect in
            // L shape scaled to 18×18 (original 96×96 → scale ≈ 0.1875)
            // Vertical bar: 17×47 at (24,24) → ~3.2×8.8 at (4.5, 4.5)
            // Horizontal bar: 47×17 at (24,54) → ~8.8×3.2 at (4.5, 10.1)
            let vBar = NSRect(x: 4.5, y: 4.5, width: 3.2, height: 8.8)
            let hBar = NSRect(x: 4.5, y: 10.1, width: 8.8, height: 3.2)

            // Vertical bar gradient (top to bottom: black → transparent)
            if let ctx = NSGraphicsContext.current?.cgContext {
                let colors = [NSColor.black.cgColor, NSColor.black.withAlphaComponent(0).cgColor]
                let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                          colors: colors as CFArray, locations: [0, 1])!
                ctx.saveGState()
                ctx.clip(to: vBar)
                ctx.drawLinearGradient(gradient,
                                       start: CGPoint(x: vBar.midX, y: vBar.minY),
                                       end: CGPoint(x: vBar.midX, y: vBar.maxY),
                                       options: [])
                ctx.restoreGState()

                // Horizontal bar gradient (left to right: transparent → black)
                ctx.saveGState()
                ctx.clip(to: hBar)
                let hColors = [NSColor.black.withAlphaComponent(0).cgColor, NSColor.black.cgColor]
                let hGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                            colors: hColors as CFArray, locations: [0, 1])!
                ctx.drawLinearGradient(hGradient,
                                       start: CGPoint(x: hBar.minX, y: hBar.midY),
                                       end: CGPoint(x: hBar.maxX, y: hBar.midY),
                                       options: [])
                ctx.restoreGState()
            }
            return true
        }
        img.isTemplate = true
        return img
    }
}
