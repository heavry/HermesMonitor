import SwiftUI

struct SettingsView: View {
    @ObservedObject var app = AppManager.shared
    @ObservedObject var notificationManager = AppManager.shared.notificationManager
    @ObservedObject var lang = AppManager.shared.lang

    @AppStorage("hermes_monitor_auto_hide") private var autoHide = false

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label(lang.generalTab, systemImage: "gear")
                }

            AboutTab()
                .tabItem {
                    Label(lang.aboutTab, systemImage: "info.circle")
                }
        }
        .frame(width: 400, height: 280)
    }
}

// MARK: - General Settings

struct GeneralSettingsTab: View {
    @ObservedObject var app = AppManager.shared
    @ObservedObject var notificationManager = AppManager.shared.notificationManager
    @ObservedObject var lang = AppManager.shared.lang
    @AppStorage("hermes_monitor_auto_hide") private var autoHide = false

    var body: some View {
        Form {
            Section {
                Toggle(lang.autoHideLabel, isOn: $autoHide)
                    .onChange(of: autoHide) { _ in
                        app.autoHideCheck()
                    }

                Toggle(lang.muteLabel, isOn: $notificationManager.isMuted)
            } header: {
                Text(lang.behaviorSection)
            }

            Section {
                Picker(lang.languageLabel, selection: $lang.currentLanguage) {
                    Text("中文").tag("zh")
                    Text("English").tag("en")
                }
            } header: {
                Text(lang.languageLabel)
            }

            Section {
                HStack {
                    Text(lang.windowPosition)
                    Spacer()
                    Button(lang.resetToDefault) {
                        app.resetWindowPosition()
                    }
                }
            } header: {
                Text(lang.windowSection)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - About Tab

struct AboutTab: View {
    @ObservedObject var lang = AppManager.shared.lang

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

            Text(lang.appDescription)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Link("GitHub", destination: URL(string: "https://github.com/heavry/HermesMonitor")!)
                .font(.system(size: 12))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
