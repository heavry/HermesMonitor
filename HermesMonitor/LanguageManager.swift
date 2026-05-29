import Foundation

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published var currentLanguage: String {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: "hermes_monitor_language")
        }
    }

    var isEnglish: Bool { currentLanguage == "en" }

    init() {
        let saved = UserDefaults.standard.string(forKey: "hermes_monitor_language")
        if let saved {
            self.currentLanguage = saved
        } else {
            // Default to system language
            let sysLang = Locale.current.language.languageCode?.identifier ?? "zh"
            self.currentLanguage = sysLang.hasPrefix("zh") ? "zh" : "en"
        }
    }

    func toggle() {
        currentLanguage = (currentLanguage == "zh") ? "en" : "zh"
    }

    // MARK: - Translations

    // Menu Bar
    var hideWindow: String { isEnglish ? "Hide Widget" : "隐藏浮窗" }
    var showWindow: String { isEnglish ? "Show Widget" : "显示浮窗" }
    var mute: String { isEnglish ? "Mute" : "静音" }
    var unmute: String { isEnglish ? "Unmute" : "取消静音" }
    var noActiveTasks: String { isEnglish ? "No active tasks" : "无进行中的任务" }
    var settings: String { isEnglish ? "Settings..." : "设置..." }
    var quit: String { isEnglish ? "Quit" : "退出" }

    // Widget Header
    var hermesIdle: String { isEnglish ? "Hermes Idle" : "Hermes 空闲" }
    var hermesWorking: String { isEnglish ? "Hermes Working" : "Hermes 工作中" }
    func hermesActive(_ active: Int, _ total: Int) -> String {
        isEnglish ? "Hermes \(active)/\(total) Active" : "Hermes \(active)/\(total) 活跃"
    }
    var refresh: String { isEnglish ? "Refresh" : "刷新" }
    var mutedHint: String { isEnglish ? "Muted, click to unmute" : "已静音，点击取消" }
    var clickToMute: String { isEnglish ? "Click to mute" : "点击静音" }

    // Task Detail
    var inProgress: String { isEnglish ? "Running" : "进行中" }
    var ended: String { isEnglish ? "Ended" : "已结束" }
    var progress: String { isEnglish ? "Progress" : "进度" }
    var dropFileHint: String { isEnglish ? "Drop files here for Hermes" : "拖拽文件到此处发送给 Hermes" }
    var askButton: String { isEnglish ? "Ask: What's stuck?" : "提问：卡在哪了？" }
    var collapseAsk: String { isEnglish ? "Collapse" : "收起提问" }
    var askPlaceholder: String { isEnglish ? "Ask Hermes about this task..." : "问 Hermes 当前情况..." }

    // File Drop
    var reading: String { isEnglish ? "Hermes is reading..." : "Hermes 正在阅读..." }
    var dropToSend: String { isEnglish ? "Release to send to Hermes" : "松开发送给 Hermes" }
    var back: String { isEnglish ? "Back" : "返回" }
    var keywordLabel: String { isEnglish ? "Keyword" : "关键词" }
    var keywordHint: String { isEnglish ? "Use this keyword to continue analysis" : "跟 Hermes 说这个关键词可继续分析" }
    var copyKeyword: String { isEnglish ? "Copy keyword" : "复制关键词" }
    var cannotRead: String { isEnglish ? "Cannot read" : "无法读取" }

    // Idle
    var waitingForTasks: String { isEnglish ? "Waiting for tasks..." : "等待任务..." }

    // Quit Confirm
    var confirmQuitTitle: String { isEnglish ? "Quit Hermes Monitor?" : "确定退出 Hermes Monitor？" }
    var cancel: String { isEnglish ? "Cancel" : "取消" }

    // Multi-task
    var allTasks: String { isEnglish ? "All Tasks" : "所有任务" }

    // Notification
    var taskCompleted: String { isEnglish ? "Task Completed" : "任务完成" }

    // Settings
    var generalTab: String { isEnglish ? "General" : "通用" }
    var aboutTab: String { isEnglish ? "About" : "关于" }
    var behaviorSection: String { isEnglish ? "Behavior" : "行为" }
    var autoHideLabel: String { isEnglish ? "Auto-hide when no tasks" : "无任务时自动隐藏浮窗" }
    var muteLabel: String { isEnglish ? "Mute task completion sound" : "任务完成时静音" }
    var windowSection: String { isEnglish ? "Window" : "窗口" }
    var windowPosition: String { isEnglish ? "Window position" : "浮窗位置" }
    var resetToDefault: String { isEnglish ? "Reset to default" : "重置为默认" }
    var languageLabel: String { isEnglish ? "Language" : "语言" }
    var appDescription: String { isEnglish ? "macOS floating widget\nReal-time Hermes Agent monitoring" : "macOS 浮窗桌面组件\n实时监控 Hermes Agent 任务状态" }

    // Error
    var hermesNotFound: String { isEnglish ? "hermes binary not found" : "找不到 hermes 二进制，请确认已安装" }

    // Tool Names
    func toolName(_ name: String?) -> String {
        guard let name else { return "" }
        if isEnglish {
            switch name {
            case "terminal":          return "🖥 Terminal"
            case "read_file":         return "📖 Read File"
            case "write_file":        return "✏️ Write File"
            case "patch":             return "🔧 Edit File"
            case "search_files":      return "🔍 Search"
            case "web_search":        return "🌐 Search"
            case "vision_analyze":    return "👁 Vision"
            case "delegate_task":     return "🤖 Subtask"
            case "execute_code":      return "⚡ Code"
            case "skill_view":        return "📚 Skill"
            case "skill_manage":      return "📚 Skill"
            case "memory":            return "💾 Memory"
            case "send_message":      return "💬 Message"
            default:                  return "⚙️ \(name)"
            }
        } else {
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
    }
}
