import Foundation

class PTY {
    private(set) var pid: pid_t = 0
    private(set) var masterFd: Int32 = -1
    private(set) var running = false

    private var dispatchIO: DispatchIO?
    private var processMonitor: DispatchSourceProcess?
    private let readQueue = DispatchQueue(label: "pty.read", qos: .userInteractive)
    private let callbackQueue: DispatchQueue

    var onData: ((Data) -> Void)?
    var onExit: ((Int32) -> Void)?

    init(callbackQueue: DispatchQueue = .main) {
        self.callbackQueue = callbackQueue
    }

    deinit { terminate() }

    func start(
        executable: String? = nil,
        cols: UInt16 = 80,
        rows: UInt16 = 24
    ) {
        guard !running else { return }

        let shell = executable ?? ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let shellName = "-" + (shell as NSString).lastPathComponent

        let env = PTY.defaultEnvironment()
        var size = winsize(ws_row: rows, ws_col: cols, ws_xpixel: 0, ws_ypixel: 0)

        // forkpty
        var master: Int32 = 0
        let childPid = forkpty(&master, nil, nil, &size)

        if childPid < 0 { return }

        if childPid == 0 {
            // Child process
            let cArgs = [strdup(shellName), nil]
            let cEnv = env.map { strdup($0) } + [nil]
            var mArgs = cArgs
            var mEnv = cEnv
            execve(strdup(shell), &mArgs, &mEnv)
            _exit(127)
        }

        // Parent
        self.pid = childPid
        self.masterFd = master
        self.running = true

        // Monitor child exit
        let monitor = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit, queue: callbackQueue)
        monitor.setEventHandler { [weak self] in
            var status: Int32 = 0
            waitpid(self?.pid ?? 0, &status, WNOHANG)
            self?.running = false
            self?.processMonitor?.cancel()
            self?.onExit?(status)
        }
        monitor.activate()
        self.processMonitor = monitor

        // Async read
        let fd = masterFd
        let io = DispatchIO(type: .stream, fileDescriptor: fd, queue: callbackQueue) { _ in
            close(fd)
        }
        io.setLimit(lowWater: 1)
        self.dispatchIO = io
        scheduleRead()
    }

    func write(_ data: Data) {
        guard running, masterFd >= 0 else { return }
        data.withUnsafeBytes { ptr in
            let dd = DispatchData(bytes: ptr)
            DispatchIO.write(toFileDescriptor: masterFd, data: dd, runningHandlerOn: .global()) { _, _ in }
        }
    }

    func write(_ string: String) {
        if let data = string.data(using: .utf8) { write(data) }
    }

    func resize(cols: UInt16, rows: UInt16) {
        guard masterFd >= 0 else { return }
        var size = winsize(ws_row: rows, ws_col: cols, ws_xpixel: 0, ws_ypixel: 0)
        _ = ioctl(masterFd, TIOCSWINSZ, &size)
    }

    func terminate() {
        guard running else { return }
        running = false
        dispatchIO?.close()
        dispatchIO = nil
        if pid > 0 { kill(pid, SIGTERM) }
        processMonitor?.cancel()
        processMonitor = nil
    }

    private func scheduleRead() {
        dispatchIO?.read(offset: 0, length: 128 * 1024, queue: readQueue) { [weak self] done, data, _ in
            guard let self = self else { return }
            if let data = data, data.count > 0 {
                let bytes = Data(data)
                self.callbackQueue.async { self.onData?(bytes) }
            }
            if self.running { self.scheduleRead() }
        }
    }

    static func defaultEnvironment() -> [String] {
        var env = ["TERM=xterm-256color", "COLORTERM=truecolor",
                   "LANG=\(Locale.current.identifier).UTF-8"]
        for key in ["HOME", "USER", "LOGNAME", "PATH", "SHELL", "TMPDIR"] {
            if let val = ProcessInfo.processInfo.environment[key] { env.append("\(key)=\(val)") }
        }
        return env
    }
}
