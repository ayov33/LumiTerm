import Cocoa

struct TabInfo {
    let id: UUID
    let index: Int
    var title: String
    var customTitle: String?  // User-set name, nil = show version
    let terminalVC: TerminalViewController
    let outputMonitor: OutputMonitor
    var status: TerminalStatus = .idle
}

class TabManager {
    static let maxTabs = 3
    static let appVersion = "1.0.0"
    static var claudeVersion: String = ""

    private(set) var tabs: [TabInfo] = []
    private(set) var activeTabIndex: Int = 0
    private var nextIndex: Int = 1

    var onTabSwitched: ((Int) -> Void)?
    var onTabsChanged: (() -> Void)?
    var onStatusChanged: ((TerminalStatus) -> Void)?
    var onBackgroundTabFinished: (() -> Void)?

    weak var containerView: NSView?

    var activeTerminalVC: TerminalViewController? {
        guard activeTabIndex < tabs.count else { return nil }
        return tabs[activeTabIndex].terminalVC
    }

    // MARK: - Detect Claude Code version

    func detectClaudeVersion(completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-l", "-c", "claude --version 2>/dev/null"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice

            var detectedVersion = ""
            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    let version = output.components(separatedBy: " ").first ?? output
                    if !version.isEmpty { detectedVersion = version }
                }
            } catch {}

            DispatchQueue.main.async {
                if !detectedVersion.isEmpty { TabManager.claudeVersion = detectedVersion }
                completion()
            }
        }
    }

    // MARK: - Create initial tab

    func createInitialTab() {
        _ = addTab()
    }

    // MARK: - Add tab

    @discardableResult
    func addTab() -> Bool {
        guard tabs.count < TabManager.maxTabs else { return false }
        guard let container = containerView else { return false }

        let vc = TerminalViewController()
        let monitor = OutputMonitor()
        let tabIdx = nextIndex
        nextIndex += 1

        // Wire output monitoring
        vc.onOutput = { [weak monitor] charCount in
            monitor?.handleOutput(charCount)
        }

        let tabId = UUID()

        monitor.onStatusChange = { [weak self, tabId] status in
            DispatchQueue.main.async {
                self?.updateTabStatus(id: tabId, status: status)
            }
        }

        monitor.onCommandFinished = { [weak self, tabId] in
            DispatchQueue.main.async {
                self?.handleTabFinished(id: tabId)
            }
        }

        let info = TabInfo(
            id: tabId,
            index: tabIdx,
            title: "Tab \(tabIdx)",
            terminalVC: vc,
            outputMonitor: monitor,
            status: .idle
        )

        tabs.append(info)

        // Add view to container with current size
        vc.view.frame = container.bounds
        vc.view.autoresizingMask = [.width, .height]
        vc.view.isHidden = true
        container.addSubview(vc.view)

        // Switch to new tab
        switchToTab(tabs.count - 1)

        // Force layout so terminal gets correct size
        vc.view.needsLayout = true
        vc.view.layoutSubtreeIfNeeded()

        onTabsChanged?()

        return true
    }

    // MARK: - Close tab

    func closeTab(at index: Int) {
        guard index >= 0, index < tabs.count else { return }
        guard tabs.count > 1 else { return } // keep at least one

        let tab = tabs[index]
        tab.terminalVC.cleanup()
        tab.terminalVC.view.removeFromSuperview()
        tabs.remove(at: index)

        // Adjust active index
        if activeTabIndex >= tabs.count {
            activeTabIndex = tabs.count - 1
        } else if index < activeTabIndex {
            activeTabIndex -= 1
        } else if index == activeTabIndex {
            activeTabIndex = min(activeTabIndex, tabs.count - 1)
        }

        switchToTab(activeTabIndex)
        onTabsChanged?()
    }

    func closeActiveTab() {
        closeTab(at: activeTabIndex)
    }

    // MARK: - Switch tab

    func switchToTab(_ index: Int) {
        guard index >= 0, index < tabs.count else { return }

        // Hide current
        if activeTabIndex < tabs.count {
            tabs[activeTabIndex].terminalVC.view.isHidden = true
        }

        activeTabIndex = index

        // Show new
        tabs[activeTabIndex].terminalVC.view.isHidden = false
        onTabSwitched?(activeTabIndex)
    }

    func switchToNextTab() {
        guard tabs.count > 1 else { return }
        switchToTab((activeTabIndex + 1) % tabs.count)
    }

    func switchToPreviousTab() {
        guard tabs.count > 1 else { return }
        switchToTab((activeTabIndex - 1 + tabs.count) % tabs.count)
    }

    // MARK: - Focus

    func focusActiveTerminal() {
        activeTerminalVC?.focusTerminal()
    }

    // MARK: - Rename

    func renameTab(at index: Int, to name: String) {
        guard index >= 0, index < tabs.count else { return }
        let trimmed = String(name.prefix(20))
        tabs[index].customTitle = trimmed.isEmpty ? nil : trimmed
        onTabsChanged?()
    }

    // MARK: - Status

    func aggregateStatus() -> TerminalStatus {
        return tabs.contains(where: { $0.status == .running }) ? .running : .idle
    }

    private func updateTabStatus(id: UUID, status: TerminalStatus) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[idx].status = status
        onStatusChanged?(aggregateStatus())
    }

    private func handleTabFinished(id: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        if idx != activeTabIndex {
            onBackgroundTabFinished?()
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        for tab in tabs {
            tab.terminalVC.cleanup()
        }
    }
}
