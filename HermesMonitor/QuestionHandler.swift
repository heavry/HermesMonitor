import Foundation

class QuestionHandler: ObservableObject {
    @Published var isShowing = false
    @Published var questionText = ""
    @Published var isAsking = false
    @Published var answer: String? = nil
    @Published var error: String? = nil

    private var hermesBin: String {
        let paths = [
            NSHomeDirectory() + "/.local/bin/hermes",
            "/usr/local/bin/hermes",
            "/opt/homebrew/bin/hermes",
        ]
        for p in paths {
            if FileManager.default.fileExists(atPath: p) { return p }
        }
        return ""
    }

    var hasHermes: Bool { !hermesBin.isEmpty }

    // MARK: - Load session context from session JSON file

    private func loadSessionContext(sessionId: String) -> String {
        let sessionPath = NSHomeDirectory() + "/.hermes/sessions/session_\(sessionId).json"
        guard let data = FileManager.default.contents(atPath: sessionPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messages = json["messages"] as? [[String: Any]]
        else {
            return ""
        }

        // Extract last assistant messages (up to 8) for context
        var contextLines: [String] = []
        let assistantMsgs = messages.filter { ($0["role"] as? String) == "assistant" }
        let recent = assistantMsgs.suffix(8)

        for msg in recent {
            if let content = msg["content"] as? String, !content.isEmpty {
                // Truncate long messages to keep prompt manageable
                let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.count > 300 {
                    contextLines.append(String(trimmed.prefix(300)) + "...")
                } else if !trimmed.isEmpty {
                    contextLines.append(trimmed)
                }
            }
        }

        if contextLines.isEmpty { return "" }
        return "任务最近的对话记录:\n" + contextLines.joined(separator: "\n---\n")
    }

    // MARK: - Ask

    func ask(task: TaskInfo?) {
        let q = questionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }

        guard hasHermes else {
            error = "找不到 hermes 二进制，请确认已安装"
            return
        }

        isAsking = true
        answer = nil
        error = nil

        var context = ""
        if let t = task {
            context = "当前任务: \(t.task)\n"
            if let s = t.stage, !s.isEmpty { context += "阶段: \(s)\n" }
            if let tc = t.toolCall { context += "正在执行: \(tc)\n" }
            if let m = t.message, !m.isEmpty { context += "最新消息: \(m)\n" }
            context += "进度: \(Int(t.progressValue * 100))%\n"

            // Load actual session conversation history
            let sessionHistory = loadSessionContext(sessionId: t.sessionId)
            if !sessionHistory.isEmpty {
                context += "\n\(sessionHistory)\n"
            }
        }

        let prompt = """
        你是一个任务监控助手。以下是一个正在进行中的AI Agent任务的上下文信息，包括任务描述和最近的对话记录。请根据这些信息回答用户的问题。

        \(context)

        用户问题: \(q)

        请基于上述上下文信息简洁回答。如果上下文中确实没有相关信息，请说明。回答控制在200字以内。用中文回答。
        """

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let proc = Process()
            let pipe = Pipe()

            proc.executableURL = URL(fileURLWithPath: self.hermesBin)
            proc.arguments = ["chat", "-q", prompt, "-Q"]
            proc.standardOutput = pipe
            proc.standardError = pipe
            proc.environment = ProcessInfo.processInfo.environment

            do {
                try proc.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                proc.waitUntilExit()

                var output = String(data: data, encoding: .utf8) ?? ""
                output = FileDropHandler.cleanOutput(output)

                let lines = output.components(separatedBy: .newlines)
                var resultLines: [String] = []
                var skipMeta = true

                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)

                    if skipMeta {
                        if trimmed.hasPrefix("Query:") { continue }
                        if trimmed.hasPrefix("Initializing") { continue }
                        if trimmed.isEmpty { continue }
                        skipMeta = false
                    }

                    if trimmed.hasPrefix("Resume this session") { break }
                    if trimmed.hasPrefix("Session:") { break }
                    if trimmed.hasPrefix("Duration:") { break }
                    if trimmed.hasPrefix("Messages:") { break }
                    if trimmed.hasPrefix("[Subdirectory") { break }
                    if trimmed.hasPrefix("─") { continue }
                    if trimmed.hasPrefix("⚕") { continue }
                    if trimmed.isEmpty && resultLines.isEmpty { continue }

                    resultLines.append(trimmed)
                }

                let cleaned = resultLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

                DispatchQueue.main.async {
                    self.isAsking = false
                    self.answer = cleaned.isEmpty ? "（未获取到回答）" : cleaned
                    NotificationCenter.default.post(name: .resizeWidget, object: nil)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isAsking = false
                    self.answer = "错误: \(error.localizedDescription)"
                }
            }
        }
    }

    func clear() {
        questionText = ""
        answer = nil
        error = nil
        isShowing = false
        isAsking = false
    }
}
