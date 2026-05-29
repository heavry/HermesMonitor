import Foundation
import Combine

struct TaskInfo: Identifiable, Codable, Equatable {
    let sessionId: String
    let task: String
    let active: Bool
    let toolCall: String?
    let message: String?
    let stage: String?
    let progress: Double?
    let toolCount: Int?
    let lastUpdate: String?
    let lastActivity: Int?

    var id: String { sessionId }
    var progressValue: Double { progress ?? (active ? 0.05 : 1.0) }
}

struct MultiStatus: Codable {
    let tasks: [TaskInfo]
    let activeTaskId: String?
    let lastUpdate: String?

    static let empty = MultiStatus(tasks: [], activeTaskId: nil, lastUpdate: nil)
}

class StatusMonitor: ObservableObject {
    @Published var status: MultiStatus = .empty
    @Published var selectedTaskId: String? = nil
    @Published var watcherAlive: Bool = false

    private var timer: Timer?
    private var watcherCheckTimer: Timer?
    private var fileMonitor: DispatchSourceFileSystemObject?
    private var monitoredFD: Int32 = -1
    private let statusPath = NSHomeDirectory() + "/.hermes/status.json"

    // Notification manager reference (set by AppDelegate)
    var notificationManager: NotificationManager?

    init() {
        readStatus()
        startMonitoring()
        startWatcherCheck()
    }

    var tasks: [TaskInfo] { status.tasks }
    var activeTasks: [TaskInfo] { status.tasks.filter { $0.active } }
    var inactiveTasks: [TaskInfo] { status.tasks.filter { !$0.active } }

    var selectedTask: TaskInfo? {
        let tid = selectedTaskId ?? status.activeTaskId
        return status.tasks.first { $0.sessionId == tid }
    }

    func selectTask(_ id: String) {
        selectedTaskId = id
    }

    // MARK: - File Monitoring (event-driven, no polling timer)

    func startMonitoring() {
        readStatus()
        setupFileMonitor()

        // Fallback timer: only fires every 10s as safety net for missed events
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.readStatus()
        }
    }

    private func setupFileMonitor() {
        // Clean up old monitor
        fileMonitor?.cancel()
        fileMonitor = nil
        if monitoredFD >= 0 {
            close(monitoredFD)
            monitoredFD = -1
        }

        let fd = open(statusPath, O_EVTONLY)
        guard fd >= 0 else { return }
        monitoredFD = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: [.write, .delete, .rename], queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.readStatus()
        }
        source.setCancelHandler { [weak self] in
            // File was deleted or renamed — schedule rebuild
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.setupFileMonitor()
            }
        }
        source.resume()
        fileMonitor = source
    }

    func stopMonitoring() {
        timer?.invalidate()
        watcherCheckTimer?.invalidate()
        fileMonitor?.cancel()
        fileMonitor = nil
        if monitoredFD >= 0 {
            close(monitoredFD)
            monitoredFD = -1
        }
    }

    // MARK: - Watcher Health Check

    private func startWatcherCheck() {
        checkWatcherAlive()
        watcherCheckTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.checkWatcherAlive()
            self?.restartWatcherIfNeeded()
        }
    }

    private func checkWatcherAlive() {
        let proc = Process()
        let pipe = Pipe()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-c", "pgrep -f 'activity_watcher.py' 2>/dev/null"]
        proc.standardOutput = pipe
        proc.standardError = pipe
        proc.environment = ProcessInfo.processInfo.environment
        try? proc.run()
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        DispatchQueue.main.async {
            self.watcherAlive = !output.isEmpty
        }
    }

    private func restartWatcherIfNeeded() {
        guard !watcherAlive else { return }
        let scriptPath = NSHomeDirectory() + "/.hermes/activity_watcher.py"
        guard FileManager.default.fileExists(atPath: scriptPath) else { return }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = ["python3", scriptPath]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        proc.environment = ProcessInfo.processInfo.environment
        try? proc.run()
        proc.processIdentifier // detach — don't wait
    }

    // MARK: - Status Reading with auto-switch and completion detection

    private func readStatus() {
        guard let data = FileManager.default.contents(atPath: statusPath),
              let s = try? JSONDecoder().decode(MultiStatus.self, from: data)
        else { return }
        DispatchQueue.main.async {
            let previousTasks = self.status.tasks
            self.status = s
            self.autoSelectTask()

            // Check for newly completed tasks
            self.notificationManager?.checkForCompletedTasks(tasks: s.tasks)
        }
    }

    private func autoSelectTask() {
        // If selected task is still active, keep it
        if let tid = selectedTaskId, let task = status.tasks.first(where: { $0.sessionId == tid }), task.active {
            return
        }
        // Otherwise switch to first active task
        if let first = status.tasks.first(where: { $0.active }) {
            selectedTaskId = first.sessionId
        }
    }

    // MARK: - Helpers

    func formatToolName(_ name: String?) -> String {
        guard let name = name else { return "" }
        switch name {
        case "terminal":          return "🖥 终端"
        case "read_file":         return "📖 读文件"
        case "write_file":        return "✏️ 写文件"
        case "patch":             return "🔧 改文件"
        case "search_files":      return "🔍 搜索"
        case "web_search":        return "🌐 搜索"
        case "vision_analyze":    return "👁 图像"
        case "delegate_task":     return "🤖 子任务"
        case "execute_code":      return "⚡ 代码"
        case "skill_view":        return "📚 技能"
        case "skill_manage":      return "📚 技能"
        case "memory":            return "💾 记忆"
        case "send_message":      return "💬 消息"
        default:                  return "⚙️ \(name)"
        }
    }

    func shortTask(_ task: String, maxLen: Int = 28) -> String {
        task.count > maxLen ? String(task.prefix(maxLen)) + "..." : task
    }

    func forceRefresh() {
        readStatus()
    }
}
