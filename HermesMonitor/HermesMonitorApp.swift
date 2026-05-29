import SwiftUI
import AppKit

// MARK: - Shared App Manager

class AppManager: ObservableObject {
    static let shared = AppManager()

    @Published var isWindowVisible: Bool = true

    var floatingWindow: FloatingWindow?
    var monitor = StatusMonitor()
    var dropHandler = FileDropHandler()
    var questionHandler = QuestionHandler()
    var notificationManager = NotificationManager()
    var lang = LanguageManager.shared

    let windowFrameKey = "hermes_monitor_window_frame"

    init() {
        monitor.notificationManager = notificationManager
    }

    // MARK: - Window visibility

    func toggleWindow() {
        if isWindowVisible {
            hideWindow()
        } else {
            showWindow()
        }
    }

    func showWindow() {
        guard let win = floatingWindow else { return }
        win.alphaValue = 0
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isWindowVisible = true
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            win.animator().alphaValue = 1
        }
    }

    func hideWindow() {
        guard let win = floatingWindow else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            win.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            win.orderOut(nil)
            self?.isWindowVisible = false
        })
    }

    func autoHideCheck() {
        guard UserDefaults.standard.bool(forKey: "hermes_monitor_auto_hide") else { return }
        if monitor.tasks.isEmpty && isWindowVisible {
            hideWindow()
        }
    }

    func resetWindowPosition() {
        UserDefaults.standard.removeObject(forKey: windowFrameKey)
    }
}

// MARK: - App Entry

@main
struct HermesMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarMenuView()
        } label: {
            MenuBarIcon()
        }

        Settings {
            SettingsView()
        }
    }
}

// MARK: - Menu Bar Icon

struct MenuBarIcon: View {
    @ObservedObject var monitor = AppManager.shared.monitor

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
    @ObservedObject var app = AppManager.shared
    @ObservedObject var monitor = AppManager.shared.monitor
    @ObservedObject var notificationManager = AppManager.shared.notificationManager
    @ObservedObject var lang = AppManager.shared.lang

    var body: some View {
        Button(action: { app.toggleWindow() }) {
            Label(app.isWindowVisible ? lang.hideWindow : lang.showWindow,
                  systemImage: app.isWindowVisible ? "eye.slash" : "eye")
        }

        Divider()

        Button(action: { notificationManager.toggleMute() }) {
            Label(notificationManager.isMuted ? lang.unmute : lang.mute,
                  systemImage: notificationManager.isMuted ? "speaker.slash" : "speaker.wave.2")
        }

        Divider()

        if monitor.activeTasks.isEmpty {
            Text(lang.noActiveTasks)
                .foregroundColor(.secondary)
        } else {
            ForEach(monitor.activeTasks) { task in
                Button(action: {
                    monitor.selectTask(task.sessionId)
                    app.showWindow()
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
            Label(lang.settings, systemImage: "gear")
        }

        Button(action: { NSApp.terminate(nil) }) {
            Label(lang.quit, systemImage: "power")
        }
    }
}

// MARK: - Floating Window

class FloatingWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var hostingView: NSHostingView<AnyView>!
    let app = AppManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupFloatingWindow()

        if app.monitor.tasks.isEmpty && UserDefaults.standard.bool(forKey: "hermes_monitor_auto_hide") {
            app.hideWindow()
        }
    }

    private func setupFloatingWindow() {
        let width: CGFloat = 320
        let height: CGFloat = 200

        let frame: NSRect
        if let saved = UserDefaults.standard.string(forKey: app.windowFrameKey),
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

        let win = FloatingWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.level = .floating
        win.collectionBehavior = [.canJoinAllSpaces, .stationary]
        win.isMovableByWindowBackground = true
        win.animationBehavior = .utilityWindow
        win.registerForDraggedTypes([.fileURL])

        hostingView = NSHostingView(
            rootView: AnyView(
                WidgetView()
                    .environmentObject(app.monitor)
                    .environmentObject(app.dropHandler)
                    .environmentObject(app.questionHandler)
                    .environmentObject(app.notificationManager)
            )
        )

        win.contentView = hostingView
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        app.floatingWindow = win
        app.isWindowVisible = true

        // Save window position on move
        NotificationCenter.default.addObserver(
            self, selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification, object: win
        )

        // Listen for resize requests
        NotificationCenter.default.addObserver(
            self, selector: #selector(resizeWindow),
            name: .resizeWidget, object: nil
        )

        // Auto-hide check every 3s
        Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.app.autoHideCheck()
        }
    }

    @objc private func windowDidMove() {
        guard let win = app.floatingWindow else { return }
        let f = win.frame
        let dict: [String: CGFloat] = ["x": f.origin.x, "y": f.origin.y, "w": f.width, "h": f.height]
        if let data = try? JSONSerialization.data(withJSONObject: dict),
           let str = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(str, forKey: app.windowFrameKey)
        }
    }

    @objc private func resizeWindow() {
        guard let win = app.floatingWindow, let screen = win.screen else { return }
        let fittingSize = hostingView.fittingSize
        let width: CGFloat = 320
        let height = max(200, fittingSize.height)

        let screenFrame = screen.visibleFrame
        let currentFrame = win.frame
        let newY = currentFrame.maxY - height
        let clampedY = max(screenFrame.minY, newY)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            win.animator().setFrame(
                NSRect(x: currentFrame.origin.x, y: clampedY, width: width, height: height),
                display: true
            )
        }
    }
}

extension Notification.Name {
    static let resizeWidget = Notification.Name("resizeWidget")
}
