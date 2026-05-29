import SwiftUI
import AppKit

@main
struct HermesMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var notificationManager = NotificationManager()
    @StateObject var appManager = AppManager()

    var body: some Scene {
        // Menu bar icon
        MenuBarExtra {
            MenuBarMenuView()
                .environmentObject(appDelegate.monitor)
                .environmentObject(notificationManager)
                .environmentObject(appManager)
        } label: {
            MenuBarIcon()
                .environmentObject(appDelegate.monitor)
        }

        // Settings window
        Settings {
            SettingsView()
                .environmentObject(notificationManager)
                .environmentObject(appManager)
        }
    }
}

// MARK: - App Manager (shared state for window control)

class AppManager: ObservableObject {
    @Published var isWindowVisible: Bool = true
    var appDelegate: AppDelegate?

    func toggleWindow() {
        appDelegate?.toggleWindow()
    }

    func showWindow() {
        appDelegate?.showWindow()
    }

    func resetWindowPosition() {
        UserDefaults.standard.removeObject(forKey: "hermes_monitor_window_frame")
    }
}

// MARK: - Menu Bar Icon

struct MenuBarIcon: View {
    @EnvironmentObject var monitor: StatusMonitor

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkle")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.accentColor)

            if !monitor.activeTasks.isEmpty {
                Text("\(monitor.activeTasks.count)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.accentColor))
            }
        }
    }
}

// MARK: - Menu Bar Menu

struct MenuBarMenuView: View {
    @EnvironmentObject var monitor: StatusMonitor
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var appManager: AppManager

    var body: some View {
        Button(action: { appManager.toggleWindow() }) {
            Label(appManager.isWindowVisible ? "隐藏浮窗" : "显示浮窗",
                  systemImage: appManager.isWindowVisible ? "eye.slash" : "eye")
        }

        Divider()

        Button(action: { notificationManager.toggleMute() }) {
            Label(notificationManager.isMuted ? "取消静音" : "静音",
                  systemImage: notificationManager.isMuted ? "speaker.slash" : "speaker.wave.2")
        }

        Divider()

        if monitor.activeTasks.isEmpty {
            Text("无进行中的任务")
                .foregroundColor(.secondary)
        } else {
            ForEach(monitor.activeTasks) { task in
                Button(action: {
                    monitor.selectTask(task.sessionId)
                    appManager.showWindow()
                }) {
                    HStack {
                        Circle().fill(Color.green).frame(width: 6, height: 6)
                        Text(monitor.shortTask(task.task))
                        Spacer()
                        Text("\(Int(task.progressValue * 100))%")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }

        Divider()

        SettingsLink {
            Label("设置...", systemImage: "gear")
        }

        Button(action: { NSApp.terminate(nil) }) {
            Label("退出", systemImage: "power")
        }
    }
}

// MARK: - Floating Window

class FloatingWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var floatingWindow: FloatingWindow!
    var hostingView: NSHostingView<AnyView>!
    var monitor = StatusMonitor()
    var dropHandler = FileDropHandler()
    var questionHandler = QuestionHandler()
    var notificationManager = NotificationManager()
    var appManager = AppManager()

    private let windowFrameKey = "hermes_monitor_window_frame"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Wire up managers
        monitor.notificationManager = notificationManager
        appManager.appDelegate = self

        setupFloatingWindow()

        // Auto-hide if no tasks on launch
        if monitor.tasks.isEmpty && UserDefaults.standard.bool(forKey: "hermes_monitor_auto_hide") {
            hideWindowAnimated()
        }
    }

    private func setupFloatingWindow() {
        let width: CGFloat = 320
        let height: CGFloat = 200

        // Restore saved position or use default
        let frame: NSRect
        if let saved = UserDefaults.standard.string(forKey: windowFrameKey),
           let data = saved.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: CGFloat],
           let x = dict["x"], let y = dict["y"], let w = dict["w"], let h = dict["h"] {
            frame = NSRect(x: x, y: y, width: w, height: h)
        } else {
            let screenFrame = NSScreen.main?.visibleFrame ?? .zero
            frame = NSRect(
                x: screenFrame.maxX - width - 24,
                y: screenFrame.maxY - height - 12,
                width: width, height: height
            )
        }

        floatingWindow = FloatingWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        floatingWindow.isOpaque = false
        floatingWindow.backgroundColor = .clear
        floatingWindow.hasShadow = true
        floatingWindow.level = .floating
        floatingWindow.collectionBehavior = [.canJoinAllSpaces, .stationary]
        floatingWindow.isMovableByWindowBackground = true
        floatingWindow.animationBehavior = .utilityWindow
        floatingWindow.registerForDraggedTypes([.fileURL])

        hostingView = NSHostingView(
            rootView: AnyView(
                WidgetView()
                    .environmentObject(monitor)
                    .environmentObject(dropHandler)
                    .environmentObject(questionHandler)
                    .environmentObject(notificationManager)
            )
        )

        floatingWindow.contentView = hostingView
        floatingWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        appManager.isWindowVisible = true

        // Save window position on move
        NotificationCenter.default.addObserver(
            self, selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification, object: floatingWindow
        )

        // Listen for resize requests
        NotificationCenter.default.addObserver(
            self, selector: #selector(resizeWindow),
            name: .resizeWidget, object: nil
        )

        // Auto-hide check
        Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.autoHideCheck()
        }
    }

    @objc private func windowDidMove() {
        saveWindowFrame()
    }

    private func saveWindowFrame() {
        let f = floatingWindow.frame
        let dict: [String: CGFloat] = ["x": f.origin.x, "y": f.origin.y, "w": f.width, "h": f.height]
        if let data = try? JSONSerialization.data(withJSONObject: dict),
           let str = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(str, forKey: windowFrameKey)
        }
    }

    private func autoHideCheck() {
        guard UserDefaults.standard.bool(forKey: "hermes_monitor_auto_hide") else { return }
        if monitor.tasks.isEmpty && appManager.isWindowVisible {
            hideWindowAnimated()
        }
    }

    // MARK: - Window visibility

    func toggleWindow() {
        if appManager.isWindowVisible {
            hideWindowAnimated()
        } else {
            showWindow()
        }
    }

    func showWindow() {
        floatingWindow.alphaValue = 0
        floatingWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        appManager.isWindowVisible = true
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            floatingWindow.animator().alphaValue = 1
        }
    }

    func hideWindowAnimated() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            floatingWindow.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.floatingWindow.orderOut(nil)
            self?.appManager.isWindowVisible = false
        })
    }

    @objc private func resizeWindow() {
        guard let screen = floatingWindow.screen else { return }
        let fittingSize = hostingView.fittingSize
        let width: CGFloat = 320
        let height = max(200, fittingSize.height)

        let screenFrame = screen.visibleFrame
        let currentFrame = floatingWindow.frame
        let newY = currentFrame.maxY - height
        let clampedY = max(screenFrame.minY, newY)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            floatingWindow.animator().setFrame(
                NSRect(x: currentFrame.origin.x, y: clampedY, width: width, height: height),
                display: true
            )
        }
    }
}

extension Notification.Name {
    static let resizeWidget = Notification.Name("resizeWidget")
}
