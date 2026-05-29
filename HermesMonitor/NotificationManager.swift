import Foundation
import AppKit
import UserNotifications

class NotificationManager: ObservableObject {
    @Published var isMuted: Bool {
        didSet {
            UserDefaults.standard.set(isMuted, forKey: "hermes_monitor_muted")
        }
    }

    private var previousActiveTaskIds: Set<String> = []

    init() {
        self.isMuted = UserDefaults.standard.bool(forKey: "hermes_monitor_muted")
        requestNotificationPermission()
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Call this when tasks update. Detects newly completed tasks and triggers notification.
    func checkForCompletedTasks(tasks: [TaskInfo]) {
        let currentActiveIds = Set(tasks.filter { $0.active }.map { $0.sessionId })

        // Find tasks that were active last check but are no longer active
        let completedIds = previousActiveTaskIds.subtracting(currentActiveIds)

        if !completedIds.isEmpty {
            for id in completedIds {
                if let task = tasks.first(where: { $0.sessionId == id }) {
                    notifyTaskCompleted(task: task)
                }
            }
        }

        previousActiveTaskIds = currentActiveIds
    }

    private func notifyTaskCompleted(task: TaskInfo) {
        // Play sound unless muted
        if !isMuted {
            NSSound(named: "Glass")?.play()
        }

        // Show system notification
        let content = UNMutableNotificationContent()
        content.title = LanguageManager.shared.taskCompleted
        content.body = task.task.count > 50 ? String(task.task.prefix(50)) + "..." : task.task
        content.sound = isMuted ? nil : .default

        let request = UNNotificationRequest(
            identifier: "task_done_\(task.sessionId)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func toggleMute() {
        isMuted.toggle()
    }
}
