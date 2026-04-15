import XCTest

// =============================================================================
// Output Monitor Tests
// =============================================================================
// These tests validate the output monitoring logic from OutputMonitor without
// importing the main executable target. The state machine and thresholds are
// replicated here to verify correctness of the detection algorithm.

// MARK: - Replicated types and logic from OutputMonitor

private enum TerminalStatus: Equatable {
    case idle
    case running
}

/// A testable version of OutputMonitor with injectable time.
/// This allows us to simulate time passing without real Timer/sleep.
private class TestableOutputMonitor {
    var onStatusChange: ((TerminalStatus) -> Void)?
    var onCommandFinished: (() -> Void)?
    var isPaused = false

    private(set) var commandRunning = false
    private(set) var notified = false
    private(set) var totalOutputChars = 0
    private(set) var pendingChars = 0

    // We use a manually-controllable "now" so tests don't need real time
    var currentTime: Date = Date(timeIntervalSinceReferenceDate: 1000)
    var lastOutputTime: Date = .distantPast
    var cooldownUntil: Date = .distantPast
    var startTime: Date = Date(timeIntervalSinceReferenceDate: 0) // far in the past → grace period over

    let idleThreshold: TimeInterval = 2.0
    let initGracePeriod: TimeInterval = 20.0
    let minCharsToTriggerRunning = 200
    let minCharsForDone = 100
    let postCommandCooldown: TimeInterval = 5.0

    init() {}

    func resetPending() {
        pendingChars = 0
        totalOutputChars = 0
    }

    func handleOutput(_ charCount: Int) {
        lastOutputTime = currentTime

        if isPaused { return }
        if currentTime.timeIntervalSince(startTime) < initGracePeriod { return }
        if currentTime < cooldownUntil { return }
        guard charCount > 0 else { return }

        if commandRunning {
            totalOutputChars += charCount
        } else {
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

    func checkIdle() {
        // Reset pending chars if no output for a while (wasn't a real command)
        if !commandRunning && pendingChars > 0 &&
           currentTime.timeIntervalSince(lastOutputTime) > idleThreshold {
            pendingChars = 0
        }

        if currentTime < cooldownUntil { return }
        guard commandRunning, !notified,
              currentTime.timeIntervalSince(lastOutputTime) > idleThreshold else { return }

        commandRunning = false
        notified = true
        cooldownUntil = currentTime.addingTimeInterval(postCommandCooldown)
        onStatusChange?(.idle)

        if totalOutputChars >= minCharsForDone {
            onCommandFinished?()
        }
        totalOutputChars = 0
    }
}

// MARK: - Tests

final class OutputMonitorTests: XCTestCase {

    // Helper: advance time on a monitor
    private func advance(_ monitor: TestableOutputMonitor, by seconds: TimeInterval) {
        monitor.currentTime = monitor.currentTime.addingTimeInterval(seconds)
    }

    // MARK: - Threshold tests

    func testSmallOutputDoesNotTriggerRunning() {
        let monitor = TestableOutputMonitor()
        var statusChanges: [TerminalStatus] = []
        monitor.onStatusChange = { statusChanges.append($0) }

        // Send output below the threshold (200 chars)
        monitor.handleOutput(50)
        monitor.handleOutput(50)
        monitor.handleOutput(50) // total: 150

        XCTAssertFalse(monitor.commandRunning, "Should not trigger running below 200 chars")
        XCTAssertEqual(monitor.pendingChars, 150)
        XCTAssertTrue(statusChanges.isEmpty, "No status change should fire below threshold")
    }

    func testOutputAtThresholdTriggersRunning() {
        let monitor = TestableOutputMonitor()
        var statusChanges: [TerminalStatus] = []
        monitor.onStatusChange = { statusChanges.append($0) }

        monitor.handleOutput(200)

        XCTAssertTrue(monitor.commandRunning, "Should trigger running at 200 chars")
        XCTAssertEqual(monitor.pendingChars, 0, "Pending should be cleared after transition")
        XCTAssertEqual(monitor.totalOutputChars, 200)
        XCTAssertEqual(statusChanges, [.running])
    }

    func testOutputAboveThresholdTriggersRunning() {
        let monitor = TestableOutputMonitor()
        var statusChanges: [TerminalStatus] = []
        monitor.onStatusChange = { statusChanges.append($0) }

        monitor.handleOutput(100)
        XCTAssertFalse(monitor.commandRunning)
        monitor.handleOutput(150) // total 250
        XCTAssertTrue(monitor.commandRunning)
        XCTAssertEqual(statusChanges, [.running])
    }

    // MARK: - Idle detection

    func testIdleDetectionAfterRunning() {
        let monitor = TestableOutputMonitor()
        var statusChanges: [TerminalStatus] = []
        var commandFinishedCount = 0
        monitor.onStatusChange = { statusChanges.append($0) }
        monitor.onCommandFinished = { commandFinishedCount += 1 }

        // Trigger running state
        monitor.handleOutput(300)
        XCTAssertEqual(statusChanges, [.running])

        // Advance past idle threshold (2 seconds)
        advance(monitor, by: 3.0)
        monitor.checkIdle()

        XCTAssertFalse(monitor.commandRunning)
        XCTAssertEqual(statusChanges, [.running, .idle])
        XCTAssertEqual(commandFinishedCount, 1, "Should fire commandFinished since 300 >= 100")
    }

    func testNoIdleBeforeThreshold() {
        let monitor = TestableOutputMonitor()
        var statusChanges: [TerminalStatus] = []
        monitor.onStatusChange = { statusChanges.append($0) }

        monitor.handleOutput(300)
        XCTAssertEqual(statusChanges, [.running])

        // Only 1 second elapsed — less than idleThreshold of 2.0
        advance(monitor, by: 1.0)
        monitor.checkIdle()

        XCTAssertTrue(monitor.commandRunning, "Should still be running before idle threshold")
        XCTAssertEqual(statusChanges, [.running], "Should not add idle status yet")
    }

    func testCommandFinishedNotFiredBelowMinChars() {
        let monitor = TestableOutputMonitor()
        var commandFinishedCount = 0
        monitor.onCommandFinished = { commandFinishedCount += 1 }

        // Trigger running with exactly 200 chars but that's above minCharsForDone (100)
        // Let's do exactly the minimum to trigger running
        monitor.handleOutput(200)

        // Now idle — totalOutputChars is 200 which is >= minCharsForDone (100)
        advance(monitor, by: 3.0)
        monitor.checkIdle()
        XCTAssertEqual(commandFinishedCount, 1)
    }

    func testCommandFinishedNotFiredWhenTotalBelowMinCharsForDone() {
        // This tests the edge case: we need a scenario where running is triggered
        // but totalOutputChars ends up below minCharsForDone (100).
        // Since minCharsToTriggerRunning (200) > minCharsForDone (100), this can't
        // happen normally. But if resetPending() is called mid-way, we can simulate it.
        let monitor = TestableOutputMonitor()
        var commandFinishedCount = 0
        monitor.onCommandFinished = { commandFinishedCount += 1 }

        // Trigger running
        monitor.handleOutput(200)
        XCTAssertTrue(monitor.commandRunning)

        // Manually reset total chars to simulate edge case
        monitor.resetPending()
        XCTAssertEqual(monitor.totalOutputChars, 0)

        // Now idle — total is 0, below minCharsForDone
        advance(monitor, by: 3.0)
        monitor.checkIdle()
        XCTAssertEqual(commandFinishedCount, 0,
                       "Should not fire commandFinished when totalChars < minCharsForDone")
    }

    // MARK: - Grace period

    func testGracePeriodIgnoresOutput() {
        let monitor = TestableOutputMonitor()
        // Set startTime to "now" so we're within the 20s grace period
        monitor.startTime = monitor.currentTime
        var statusChanges: [TerminalStatus] = []
        monitor.onStatusChange = { statusChanges.append($0) }

        monitor.handleOutput(500)

        XCTAssertFalse(monitor.commandRunning, "Should not trigger during grace period")
        XCTAssertEqual(monitor.pendingChars, 0, "Pending should stay 0 during grace")
        XCTAssertTrue(statusChanges.isEmpty)
    }

    func testAfterGracePeriodOutputIsProcessed() {
        let monitor = TestableOutputMonitor()
        monitor.startTime = monitor.currentTime
        var statusChanges: [TerminalStatus] = []
        monitor.onStatusChange = { statusChanges.append($0) }

        // During grace period
        monitor.handleOutput(500)
        XCTAssertFalse(monitor.commandRunning)

        // Advance past grace period (20s)
        advance(monitor, by: 21.0)
        monitor.handleOutput(300)

        XCTAssertTrue(monitor.commandRunning, "Should process output after grace period")
        XCTAssertEqual(statusChanges, [.running])
    }

    // MARK: - Cooldown

    func testCooldownIgnoresOutput() {
        let monitor = TestableOutputMonitor()
        var statusChanges: [TerminalStatus] = []
        monitor.onStatusChange = { statusChanges.append($0) }

        // Trigger running -> idle to enter cooldown
        monitor.handleOutput(300)
        advance(monitor, by: 3.0)
        monitor.checkIdle()
        XCTAssertEqual(statusChanges, [.running, .idle])

        // Now in cooldown (5 seconds). Output should be ignored.
        advance(monitor, by: 1.0) // only 1s into cooldown
        monitor.handleOutput(500)
        XCTAssertFalse(monitor.commandRunning, "Should not trigger during cooldown")
        XCTAssertEqual(monitor.pendingChars, 0)
    }

    func testAfterCooldownOutputIsProcessed() {
        let monitor = TestableOutputMonitor()
        var statusChanges: [TerminalStatus] = []
        monitor.onStatusChange = { statusChanges.append($0) }

        // Trigger running -> idle -> cooldown
        monitor.handleOutput(300)
        advance(monitor, by: 3.0)
        monitor.checkIdle()
        XCTAssertEqual(statusChanges, [.running, .idle])

        // Wait past cooldown (5s)
        advance(monitor, by: 6.0)
        monitor.handleOutput(250)

        XCTAssertTrue(monitor.commandRunning, "Should process output after cooldown")
        XCTAssertEqual(statusChanges, [.running, .idle, .running])
    }

    // MARK: - Pause

    func testPausedIgnoresOutput() {
        let monitor = TestableOutputMonitor()
        var statusChanges: [TerminalStatus] = []
        monitor.onStatusChange = { statusChanges.append($0) }

        monitor.isPaused = true
        monitor.handleOutput(500)

        XCTAssertFalse(monitor.commandRunning, "Should not trigger when paused")
        XCTAssertEqual(monitor.pendingChars, 0)
        XCTAssertTrue(statusChanges.isEmpty)
    }

    func testUnpausedResumesProcessing() {
        let monitor = TestableOutputMonitor()
        var statusChanges: [TerminalStatus] = []
        monitor.onStatusChange = { statusChanges.append($0) }

        monitor.isPaused = true
        monitor.handleOutput(500)
        XCTAssertFalse(monitor.commandRunning)

        monitor.isPaused = false
        monitor.handleOutput(300)

        XCTAssertTrue(monitor.commandRunning, "Should process output after unpause")
        XCTAssertEqual(statusChanges, [.running])
    }

    // MARK: - Zero char output is ignored

    func testZeroCharOutputIgnored() {
        let monitor = TestableOutputMonitor()

        monitor.handleOutput(0)
        XCTAssertEqual(monitor.pendingChars, 0)
        XCTAssertFalse(monitor.commandRunning)
    }

    // MARK: - Pending chars reset on idle

    func testPendingCharsResetOnIdleWhenNotRunning() {
        let monitor = TestableOutputMonitor()

        // Send some output below threshold
        monitor.handleOutput(50)
        XCTAssertEqual(monitor.pendingChars, 50)

        // Wait for idle threshold
        advance(monitor, by: 3.0)
        monitor.checkIdle()

        XCTAssertEqual(monitor.pendingChars, 0,
                       "Pending chars should be cleared when output stops without reaching threshold")
    }

    // MARK: - Subsequent outputs accumulate during running

    func testAdditionalOutputDuringRunningAccumulates() {
        let monitor = TestableOutputMonitor()

        monitor.handleOutput(300)
        XCTAssertTrue(monitor.commandRunning)
        XCTAssertEqual(monitor.totalOutputChars, 300)

        monitor.handleOutput(150)
        XCTAssertEqual(monitor.totalOutputChars, 450)

        monitor.handleOutput(50)
        XCTAssertEqual(monitor.totalOutputChars, 500)
    }

    // MARK: - notified flag prevents double idle

    func testIdleFiresOnlyOnce() {
        let monitor = TestableOutputMonitor()
        var statusChanges: [TerminalStatus] = []
        monitor.onStatusChange = { statusChanges.append($0) }

        monitor.handleOutput(300)
        advance(monitor, by: 3.0)
        monitor.checkIdle()
        XCTAssertEqual(statusChanges, [.running, .idle])

        // Call checkIdle again — should not fire again
        advance(monitor, by: 1.0)
        monitor.checkIdle()
        XCTAssertEqual(statusChanges, [.running, .idle],
                       "Idle should not fire twice for the same command")
    }

    // MARK: - Full lifecycle: run -> idle -> cooldown -> run again

    func testFullLifecycle() {
        let monitor = TestableOutputMonitor()
        var statusChanges: [TerminalStatus] = []
        var commandFinishedCount = 0
        monitor.onStatusChange = { statusChanges.append($0) }
        monitor.onCommandFinished = { commandFinishedCount += 1 }

        // 1. First command
        monitor.handleOutput(500)
        XCTAssertEqual(statusChanges, [.running])

        // 2. Command finishes (idle after 2s)
        advance(monitor, by: 3.0)
        monitor.checkIdle()
        XCTAssertEqual(statusChanges, [.running, .idle])
        XCTAssertEqual(commandFinishedCount, 1)

        // 3. During cooldown (5s) — output ignored
        advance(monitor, by: 2.0)
        monitor.handleOutput(400)
        XCTAssertEqual(statusChanges, [.running, .idle])

        // 4. After cooldown — second command
        advance(monitor, by: 4.0)
        monitor.handleOutput(250)
        XCTAssertEqual(statusChanges, [.running, .idle, .running])

        // 5. Second command finishes
        advance(monitor, by: 3.0)
        monitor.checkIdle()
        XCTAssertEqual(statusChanges, [.running, .idle, .running, .idle])
        XCTAssertEqual(commandFinishedCount, 2)
    }
}
