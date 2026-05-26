import SwiftUI
import UniformTypeIdentifiers

struct WidgetView: View {
    @EnvironmentObject var monitor: StatusMonitor
    @EnvironmentObject var dropHandler: FileDropHandler
    @EnvironmentObject var questionHandler: QuestionHandler
    @State private var isHovering = false
    @State private var showList = false
    @State private var isRefreshing = false
    @State private var showResult = false
    @State private var showQuitConfirm = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(dropHandler.isDropping ? Color.accentColor : borderColor, lineWidth: dropHandler.isDropping ? 2 : 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)

            if showResult && dropHandler.droppedFile != nil {
                fileResultView
            } else if monitor.tasks.count > 1 && showList {
                multiTaskListView
            } else {
                singleTaskView
            }

            if dropHandler.isDropping {
                dropOverlay
            }

            // Quit confirmation overlay
            if showQuitConfirm {
                quitConfirmOverlay
            }

            // Error overlay
            if let err = dropHandler.error ?? questionHandler.error {
                errorBanner(err)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(8)
        .onDrop(of: [.fileURL], isTargeted: $dropHandler.isDropping) { providers in
            let serialQueue = DispatchQueue(label: "com.heavry.drop.urls")
            var urls: [URL] = []
            let group = DispatchGroup()
            for provider in providers {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        serialQueue.sync { urls.append(url) }
                    }
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                if !urls.isEmpty {
                    showResult = true
                    dropHandler.handleDrop(fileURLs: urls)
                }
            }
            return true
        }
    }

    // MARK: - Quit Confirmation
    private var quitConfirmOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)

            VStack(spacing: 14) {
                Image(systemName: "power")
                    .font(.system(size: 24))
                    .foregroundColor(.red)

                Text("确定退出 Hermes Monitor？")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)

                HStack(spacing: 16) {
                    Button(action: { withAnimation { showQuitConfirm = false } }) {
                        Text("取消")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.gray.opacity(0.15)))
                    }
                    .buttonStyle(.plain)

                    Button(action: { NSApp.terminate(nil) }) {
                        Text("退出")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.red))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .transition(.opacity)
    }

    // MARK: - Error Banner
    private func errorBanner(_ message: String) -> some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
                Text(message)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                Spacer()
                Button(action: {
                    dropHandler.error = nil
                    questionHandler.error = nil
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.orange.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.3), lineWidth: 0.5))
            )
            .padding(.horizontal, 10)
            .padding(.top, 6)

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Drop Overlay
    private var dropOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.accentColor.opacity(0.15))

            VStack(spacing: 10) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.accentColor)
                Text("松开发送给 Hermes")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.accentColor)
            }
        }
        .transition(.opacity)
    }

    // MARK: - File Result View
    private var fileResultView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)

                Text((dropHandler.droppedFile! as NSString).lastPathComponent)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()

                Button(action: {
                    withAnimation { showResult = false; dropHandler.clear() }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .semibold))
                        Text("返回")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            Divider().opacity(0.3).padding(.horizontal, 14).padding(.top, 6)

            if dropHandler.isProcessing {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                    Text("Hermes 正在阅读...")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else if let result = dropHandler.result {
                VStack(spacing: 0) {
                    if let kw = dropHandler.keyword {
                        HStack(spacing: 6) {
                            Image(systemName: "tag.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.purple)
                            Text("关键词")
                                .font(.system(size: 9, design: .rounded))
                                .foregroundColor(.secondary)
                            Text(kw)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.purple)
                                .textSelection(.enabled)
                            Spacer()

                            Button(action: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(kw, forType: .string)
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                            .help("复制关键词")
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.purple.opacity(0.08))
                        )
                        .padding(.horizontal, 14)
                        .padding(.top, 8)

                        Text("跟 Hermes 说这个关键词可继续分析")
                            .font(.system(size: 9, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.5))
                            .padding(.top, 3)
                            .padding(.horizontal, 14)
                    }

                    ScrollView {
                        Text(result)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                            .padding(14)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                    Text("无法读取")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Header
    private var headerBar: some View {
        HStack(spacing: 8) {
            ZStack {
                if monitor.selectedTask?.active == true {
                    Circle()
                        .fill(Color.green.opacity(0.3))
                        .frame(width: 14, height: 14)
                        .scaleEffect(pulse ? 1.5 : 1.0)
                        .opacity(pulse ? 0 : 0.6)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false), value: pulse)
                }
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
            }

            Text(headerTitle)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer()

            // Watcher status indicator
            if !monitor.watcherAlive && !monitor.tasks.isEmpty {
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 10))
                    .foregroundColor(.orange.opacity(0.7))
                    .help("Watcher 离线，正在尝试重启...")
            }

            // Refresh button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) { isRefreshing = true }
                monitor.forceRefresh()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation { isRefreshing = false }
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.6))
                    .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                    .animation(isRefreshing ? .linear(duration: 0.5) : .default, value: isRefreshing)
            }
            .buttonStyle(.plain)

            if monitor.tasks.count > 1 {
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showList.toggle() } }) {
                    HStack(spacing: 4) {
                        Text("\(monitor.tasks.count)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                        Image(systemName: showList ? "chevron.up" : "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.accentColor.opacity(0.2)))
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }

            // Close with confirmation
            Button(action: { withAnimation { showQuitConfirm = true } }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary.opacity(isHovering ? 0.6 : 0.2))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .onHover { isHovering = $0 }
    }

    @State private var pulse = false

    // MARK: - Single Task View
    private var singleTaskView: some View {
        VStack(spacing: 0) {
            headerBar

            ScrollView(.vertical, showsIndicators: true) {
                if let task = monitor.selectedTask {
                    taskDetailContent(task)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 12)
                } else if monitor.tasks.isEmpty {
                    idleContent.padding(.bottom, 12)
                } else {
                    taskDetailContent(monitor.tasks[0])
                        .padding(.horizontal, 14)
                        .padding(.bottom, 12)
                }
            }
        }
        .onAppear { pulse = true }
    }

    // MARK: - Task Detail
    private func taskDetailContent(_ task: TaskInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider().opacity(0.3)

            Text(task.task)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if task.active {
                if let stage = task.stage, !stage.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                        Text(stage)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.orange)
                            .lineLimit(1)
                    }
                }

                if task.toolCall != nil {
                    Text(monitor.formatToolName(task.toolCall))
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.secondary)
                }

                if let msg = task.message, !msg.isEmpty {
                    Text(msg)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.8))
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                    Text("进行中")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.green)
                }

                VStack(spacing: 4) {
                    HStack {
                        Text("进度")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(task.progressValue * 100))%")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.accentColor)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.gray.opacity(0.15))
                                .frame(height: 5)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * CGFloat(task.progressValue), height: 5)
                                .animation(.easeInOut(duration: 0.6), value: task.progressValue)
                        }
                    }
                    .frame(height: 5)
                }
            } else {
                HStack(spacing: 6) {
                    Circle().fill(Color.gray).frame(width: 6, height: 6)
                    Text("已结束")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 4) {
                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 9))
                Text("拖拽文件到此处发送给 Hermes")
                    .font(.system(size: 9, design: .rounded))
            }
            .foregroundColor(.secondary.opacity(0.4))
            .padding(.top, 4)

            Divider().opacity(0.3).padding(.top, 6)

            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    questionHandler.isShowing.toggle()
                    if !questionHandler.isShowing { questionHandler.clear() }
                    NotificationCenter.default.post(name: .resizeWidget, object: nil)
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: questionHandler.isShowing ? "questionmark.circle.fill" : "questionmark.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.cyan)
                    Text(questionHandler.isShowing ? "收起提问" : "提问：卡在哪了？")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.cyan)
                    Spacer()
                    if questionHandler.isShowing {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

            if questionHandler.isShowing {
                questionInputView
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Multi-Task List
    private var multiTaskListView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                Text("所有任务 (\(monitor.tasks.count))")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Spacer()
                Button(action: { withAnimation { showList = false } }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider().opacity(0.3).padding(.horizontal, 14)

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(Array(monitor.tasks.enumerated()), id: \.element.id) { idx, task in
                        taskRow(task, index: idx)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Task Row
    private func taskRow(_ task: TaskInfo, index: Int) -> some View {
        Button(action: {
            monitor.selectTask(task.sessionId)
            withAnimation { showList = false }
        }) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(task.active ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 24, height: 24)
                    Text("\(index + 1)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(task.active ? .white : .secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(monitor.shortTask(task.task, maxLen: 35))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        if task.active {
                            Circle().fill(Color.green).frame(width: 5, height: 5)
                            Text(monitor.formatToolName(task.toolCall))
                                .font(.system(size: 9, design: .rounded))
                                .foregroundColor(.green)
                        } else {
                            Circle().fill(Color.gray).frame(width: 5, height: 5)
                            Text("已结束")
                                .font(.system(size: 9, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                if monitor.selectedTaskId == task.sessionId || (monitor.selectedTaskId == nil && index == 0) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary.opacity(0.3))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        (monitor.selectedTaskId == task.sessionId)
                            ? Color.accentColor.opacity(0.08)
                            : Color.gray.opacity(0.04)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Idle
    private var idleContent: some View {
        VStack(spacing: 6) {
            Divider().opacity(0.3)
            HStack(spacing: 6) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary.opacity(0.4))
                Text("等待任务...")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Question Input
    private var questionInputView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                TextField("问 Hermes 当前情况...", text: $questionHandler.questionText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .rounded))
                    .onSubmit {
                        questionHandler.ask(task: monitor.selectedTask)
                    }

                Button(action: {
                    questionHandler.ask(task: monitor.selectedTask)
                }) {
                    if questionHandler.isAsking {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                            .scaleEffect(0.6)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.cyan)
                    }
                }
                .buttonStyle(.plain)
                .disabled(questionHandler.isAsking || questionHandler.questionText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.cyan.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
                    )
            )

            if let answer = questionHandler.answer {
                ScrollView {
                    Text(answer)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 120)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.cyan.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.cyan.opacity(0.15), lineWidth: 0.5)
                        )
                )
            }
        }
        .padding(.top, 6)
    }

    // MARK: - Helpers
    private var dotColor: Color {
        if monitor.selectedTask?.active == true { return .green }
        if monitor.tasks.contains(where: { $0.active }) { return .green }
        return .gray
    }

    private var headerTitle: String {
        let active = monitor.activeTasks.count
        let total = monitor.tasks.count
        if total == 0 { return "Hermes 空闲" }
        if total == 1 { return monitor.tasks[0].active ? "Hermes 工作中" : "Hermes 空闲" }
        return "Hermes \(active)/\(total) 活跃"
    }

    private var borderColor: Color {
        if monitor.activeTasks.count > 0 { return Color.green.opacity(0.3) }
        return Color.gray.opacity(0.15)
    }
}
