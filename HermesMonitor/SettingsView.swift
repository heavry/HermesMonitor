import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var appManager: AppManager

    @AppStorage("hermes_monitor_auto_hide") private var autoHide = false

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .environmentObject(notificationManager)
                .tabItem {
                    Label("通用", systemImage: "gear")
                }

            AboutTab()
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
        }
        .frame(width: 400, height: 280)
    }
}

// MARK: - General Settings

struct GeneralSettingsTab: View {
    @EnvironmentObject var notificationManager: NotificationManager
    @AppStorage("hermes_monitor_auto_hide") private var autoHide = false

    var body: some View {
        Form {
            Section {
                Toggle("无任务时自动隐藏浮窗", isOn: $autoHide)
                    .onChange(of: autoHide) { _ in
                        NotificationCenter.default.post(name: .autoHideSettingChanged, object: nil)
                    }

                Toggle("任务完成时静音", isOn: $notificationManager.isMuted)
            } header: {
                Text("行为")
            }

            Section {
                HStack {
                    Text("浮窗位置")
                    Spacer()
                    Button("重置为默认") {
                        UserDefaults.standard.removeObject(forKey: "hermes_monitor_window_frame")
                    }
                }
            } header: {
                Text("窗口")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - About Tab

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkle")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("Hermes Monitor")
                .font(.system(size: 20, weight: .bold, design: .rounded))

            Text("v2.0.0")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.secondary)

            Text("macOS 浮窗桌面组件\n实时监控 Hermes Agent 任务状态")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Link("GitHub", destination: URL(string: "https://github.com/heavry/HermesMonitor")!)
                .font(.system(size: 12))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
