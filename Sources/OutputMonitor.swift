import Cocoa

enum TerminalStatus {
    case idle
    case running
}

class OutputMonitor {
    var onStatusChange: ((TerminalStatus) -> Void)?
    var onCommandFinished: (() -> Void)?
    var isPaused = false

    private var commandRunning = false
    private var notified = false
    private var lastOutputTime: Date = .distantPast
    private var cooldownUntil: Date = .distantPast
    private var startTime: Date = Date()
    private var totalOutputChars = 0
    private var pendingChars = 0  // accumulate before triggering running
    private var idleTimer: Timer?

    private let idleThreshold: TimeInterval = 2.0
    private let initGracePeriod: TimeInterval = 20.0
    private let minCharsToTriggerRunning = 200  // ignore small outputs (prompt redraw etc)
    private let minCharsForDone = 100
    private let postCommandCooldown: TimeInterval = 5.0

    init() {}

    deinit { idleTimer?.invalidate() }

    private func ensureIdleTimer() {
        guard idleTimer == nil else { return }
        idleTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkIdle()
        }
    }

    private func stopIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = nil
    }

    func resetPending() {
        pendingChars = 0
        totalOutputChars = 0
    }

    func handleOutput(_ charCount: Int) {
        lastOutputTime = Date()

        // Ignore during pause (expand/collapse transitions)
        if isPaused { return }
        // Ignore everything during grace period
        if Date().timeIntervalSince(startTime) < initGracePeriod { return }
        // Ignore during cooldown after command finished
        if Date() < cooldownUntil { return }
        guard charCount > 0 else { return }

        // Start polling for idle once we have output
        ensureIdleTimer()

        if commandRunning {
            totalOutputChars += charCount
        } else {
            // Accumulate chars — only trigger running after enough output
            pendingChars += charCount
            if pendingChars >= minCharsToTriggerRunning {
                commandRunning = true
                notified = false
                totalOutputChars = pendingChars
                pendingChars = 0
                onStatusChange?(.running)
            }
        }
    }

    private func checkIdle() {
        // Reset pending chars if no output for a while (wasn't a real command)
        if !commandRunning && pendingChars > 0 &&
           Date().timeIntervalSince(lastOutputTime) > idleThreshold {
            pendingChars = 0
            stopIdleTimer()
        }

        if Date() < cooldownUntil { return }
        guard commandRunning, !notified,
              Date().timeIntervalSince(lastOutputTime) > idleThreshold else { return }

        commandRunning = false
        notified = true
        cooldownUntil = Date().addingTimeInterval(postCommandCooldown)
        stopIdleTimer()
        onStatusChange?(.idle)

        if totalOutputChars >= minCharsForDone {
            onCommandFinished?()
        }
        totalOutputChars = 0
    }
}
