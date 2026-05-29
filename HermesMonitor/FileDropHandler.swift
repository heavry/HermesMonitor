import Foundation
import AppKit
import CryptoKit

class FileDropHandler: ObservableObject {
    @Published var isDropping = false
    @Published var droppedFile: String? = nil
    @Published var isProcessing = false
    @Published var result: String? = nil
    @Published var keyword: String? = nil
    @Published var error: String? = nil

    private let triggerPath = NSHomeDirectory() + "/.hermes/drop_trigger.json"
    private let resultsDir = NSHomeDirectory() + "/.hermes/drop_results"
    private let maxResults = 50

    lazy var hermesBin: String = {
        let paths = [
            NSHomeDirectory() + "/.local/bin/hermes",
            "/usr/local/bin/hermes",
            "/opt/homebrew/bin/hermes",
        ]
        for p in paths {
            if FileManager.default.fileExists(atPath: p) { return p }
        }
        return ""
    }()

    var hasHermes: Bool { !hermesBin.isEmpty }

    func handleDrop(fileURLs: [URL]) {
        guard let url = fileURLs.first else { return }
        let path = url.path
        let fileName = (path as NSString).lastPathComponent

        guard hasHermes else {
            DispatchQueue.main.async {
                self.isDropping = false
                self.error = LanguageManager.shared.hermesNotFound
            }
            return
        }

        DispatchQueue.main.async {
            self.isDropping = false
            self.droppedFile = path
            self.isProcessing = true
            self.result = nil
            self.keyword = nil
            self.error = nil
        }

        let trigger: [String: Any] = [
            "action": "read_file",
            "path": path,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        if let data = try? JSONSerialization.data(withJSONObject: trigger, options: .prettyPrinted) {
            try? data.write(to: URL(fileURLWithPath: triggerPath))
        }

        callHermesCLI(path: path)
    }

    private func generateKeyword(fileName: String) -> String {
        let name = (fileName as NSString).deletingPathExtension
        let hash = Insecure.MD5.hash(data: Data((fileName + String(Date().timeIntervalSince1970)).utf8))
        let hex = hash.map { String(format: "%02x", $0) }.joined().prefix(4)
        let cleanName = name.prefix(8).replacingOccurrences(of: " ", with: "_")
        return "#\(cleanName)_\(hex)"
    }

    /// Clean ANSI escape codes, think tags, and control characters from output
    static func cleanOutput(_ raw: String) -> String {
        var output = raw
        // Strip ANSI escape codes
        output = output.replacingOccurrences(of: #"\x1B\[[0-9;]*[a-zA-Z]"#, with: "", options: .regularExpression)
        // Strip thinking/reasoning content
        output = output.replacingOccurrences(of: #"(?s)<think>.*?</think>"#, with: "", options: .regularExpression)
        output = output.replacingOccurrences(of: #"(?s)<reasoning>.*?</reasoning>"#, with: "", options: .regularExpression)
        // Replace carriage return
        output = output.replacingOccurrences(of: "\r", with: "\n")
        // Remove spinner/box drawing characters
        output = output.replacingOccurrences(of: "─", with: "")
        output = output.replacingOccurrences(of: "┊", with: "")
        return output
    }

    private func callHermesCLI(path: String) {
        let fileName = (path as NSString).lastPathComponent
        let kw = generateKeyword(fileName: fileName)

        let prompt = "请阅读并简要总结这个文件的内容。分析完后记住这个关键词「\(kw)」，用户下次提到这个关键词时调出本次分析结果。文件路径: \(path)"

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let proc = Process()
            let pipe = Pipe()

            proc.executableURL = URL(fileURLWithPath: self.hermesBin)
            proc.arguments = ["chat", "-q", prompt]
            proc.standardOutput = pipe
            proc.standardError = pipe
            proc.environment = ProcessInfo.processInfo.environment

            do {
                try proc.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                proc.waitUntilExit()

                var output = String(data: data, encoding: .utf8) ?? "无法读取结果"
                output = FileDropHandler.cleanOutput(output)

                let lines = output.components(separatedBy: .newlines)
                let trimmed = lines.suffix(80).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

                self.saveResult(keyword: kw, fileName: fileName, path: path, output: trimmed)
                self.cleanupOldResults()

                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.result = trimmed.isEmpty ? "（未获取到结果）" : trimmed
                    self.keyword = kw
                }
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.result = "启动失败: \(error.localizedDescription)"
                    self.keyword = kw
                }
            }
        }
    }

    private func saveResult(keyword: String, fileName: String, path: String, output: String) {
        try? FileManager.default.createDirectory(atPath: resultsDir, withIntermediateDirectories: true)

        let record: [String: Any] = [
            "keyword": keyword,
            "fileName": fileName,
            "filePath": path,
            "output": output,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        let safeName = keyword.replacingOccurrences(of: "#", with: "")
        let filePath = (resultsDir as NSString).appendingPathComponent("\(safeName).json")

        if let data = try? JSONSerialization.data(withJSONObject: record, options: .prettyPrinted) {
            try? data.write(to: URL(fileURLWithPath: filePath))
        }
    }

    private func cleanupOldResults() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            atPath: resultsDir
        ) else { return }

        let jsonFiles = files.filter { $0.hasSuffix(".json") }
        guard jsonFiles.count > maxResults else { return }

        // Sort by modification date, delete oldest
        let fullPath = jsonFiles.map { name -> (String, Date) in
            let p = (resultsDir as NSString).appendingPathComponent(name)
            let attrs = try? FileManager.default.attributesOfItem(atPath: p)
            return (p, attrs?[.modificationDate] as? Date ?? .distantPast)
        }.sorted { $0.1 < $1.1 }

        let toDelete = fullPath.prefix(fullPath.count - maxResults)
        for (p, _) in toDelete {
            try? FileManager.default.removeItem(atPath: p)
        }
    }

    func clear() {
        droppedFile = nil
        result = nil
        keyword = nil
        error = nil
        isProcessing = false
    }
}
