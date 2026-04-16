import SwiftUI

@main
struct ClawStudioApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 1100, minHeight: 700)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1400, height: 900)
        .commands {
            // File menu
            CommandGroup(replacing: .newItem) {
                Button("New Session") {
                    appState.createSession(name: "Session \(appState.sessions.count + 1)")
                }
                .keyboardShortcut("n", modifiers: .command)

                Divider()

                Button("Save Session") {
                    appState.saveState()
                }
                .keyboardShortcut("s", modifiers: .command)
            }

            // Navigation shortcuts
            CommandMenu("Navigate") {
                Button("Chat") { appState.selectedTab = .chat }
                    .keyboardShortcut("1", modifiers: .command)
                Button("Sessions") { appState.selectedTab = .sessions }
                    .keyboardShortcut("2", modifiers: .command)
                Button("Agents") { appState.selectedTab = .agents }
                    .keyboardShortcut("3", modifiers: .command)
                Button("Gateway") { appState.selectedTab = .gateway }
                    .keyboardShortcut("4", modifiers: .command)
                Button("API Keys") { appState.selectedTab = .apiKeys }
                    .keyboardShortcut("5", modifiers: .command)
                Button("Models") { appState.selectedTab = .models }
                    .keyboardShortcut("6", modifiers: .command)

                Divider()

                Button("Monitoring") { appState.selectedTab = .monitoring }
                    .keyboardShortcut("m", modifiers: [.command, .shift])
                Button("Settings") { appState.selectedTab = .settings }
                    .keyboardShortcut(",", modifiers: .command)
            }

            // Agent actions
            CommandMenu("Agent") {
                Button("Stop Current Process") {
                    appState.bridge.stopCurrentProcess()
                }
                .keyboardShortcut(".", modifiers: .command)

                Button("Refresh Engine Status") {
                    Task { await appState.bridge.checkEngine() }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
