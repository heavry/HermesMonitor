import SwiftUI
import AppKit

@main
struct HermesMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

class FloatingWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var floatingWindow: FloatingWindow!
    var hostingView: NSHostingView<AnyView>!
    var monitor = StatusMonitor()
    var dropHandler = FileDropHandler()
    var questionHandler = QuestionHandler()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupFloatingWindow()
    }

    private func setupFloatingWindow() {
        let width: CGFloat = 320
        let height: CGFloat = 200

        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let x = screenFrame.maxX - width - 24
        let y = screenFrame.maxY - height - 12

        floatingWindow = FloatingWindow(
            contentRect: NSRect(x: x, y: y, width: width, height: height),
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
            )
        )

        floatingWindow.contentView = hostingView
        floatingWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Listen for resize requests
        NotificationCenter.default.addObserver(
            self, selector: #selector(resizeWindow),
            name: .resizeWidget, object: nil
        )
    }

    @objc private func resizeWindow() {
        guard let screen = floatingWindow.screen else { return }
        let fittingSize = hostingView.fittingSize
        let width: CGFloat = 320
        let height = max(200, fittingSize.height)
        
        let screenFrame = screen.visibleFrame
        let currentFrame = floatingWindow.frame
        // Keep top-right corner fixed, grow downward
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
