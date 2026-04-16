import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            ZStack {
                GlassTheme.subtleGradient
                    .ignoresSafeArea()

                mainContent
            }
        }
        .task {
            await appState.initialLoad()
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch appState.selectedTab {
        case .chat:
            ChatView()
        case .sessions:
            SessionManagerView()
        case .agents:
            AgentConfigView()
        case .gateway:
            GatewayView()
        case .apiKeys:
            APIKeysView()
        case .models:
            ModelBrowserView()
        case .integrations:
            IntegrationsView()
        case .skills:
            SkillsManagerView()
        case .filesystem:
            FilesystemView()
        case .memory:
            MemoryManagerView()
        case .monitoring:
            MonitoringView()
        case .settings:
            SettingsView()
        }
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @EnvironmentObject var appState: AppState

    private let workspaceTabs: [NavigationTab] = [.chat, .sessions, .agents]
    private let openclawTabs: [NavigationTab] = [.gateway, .apiKeys, .models, .integrations, .skills]
    private let systemTabs: [NavigationTab] = [.filesystem, .memory, .monitoring, .settings]

    var body: some View {
        VStack(spacing: 0) {
            appHeader
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider().opacity(0.3)

            ScrollView {
                VStack(spacing: 2) {
                    // Workspace section
                    GlassSectionHeader(title: "Workspace", icon: "square.grid.2x2")
                    ForEach(workspaceTabs) { tab in
                        SidebarButton(
                            title: tab.rawValue,
                            icon: tab.icon,
                            isSelected: appState.selectedTab == tab,
                            badge: badgeCount(for: tab)
                        ) {
                            appState.selectedTab = tab
                        }
                    }

                    // OpenClaw section
                    GlassSectionHeader(title: "OpenClaw Engine", icon: "bolt.fill")
                    ForEach(openclawTabs) { tab in
                        SidebarButton(
                            title: tab.rawValue,
                            icon: tab.icon,
                            isSelected: appState.selectedTab == tab,
                            badge: badgeCount(for: tab)
                        ) {
                            appState.selectedTab = tab
                        }
                    }

                    // System section
                    GlassSectionHeader(title: "System", icon: "desktopcomputer")
                    ForEach(systemTabs) { tab in
                        SidebarButton(
                            title: tab.rawValue,
                            icon: tab.icon,
                            isSelected: appState.selectedTab == tab,
                            badge: badgeCount(for: tab)
                        ) {
                            appState.selectedTab = tab
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 6)

                Divider().opacity(0.3).padding(.vertical, 8)

                // Active sessions
                GlassSectionHeader(title: "Active Sessions", icon: "bolt.fill") {
                    appState.createSession(name: "Session \(appState.sessions.count + 1)")
                }

                VStack(spacing: 2) {
                    ForEach(appState.sessions) { session in
                        SessionSidebarItem(session: session, isActive: session.id == appState.activeSessionId)
                            .onTapGesture {
                                appState.activeSessionId = session.id
                                appState.selectedTab = .chat
                            }
                    }
                }
                .padding(.horizontal, 10)

                Divider().opacity(0.3).padding(.vertical, 8)

                // Agents
                GlassSectionHeader(title: "Agents", icon: "cpu.fill")
                VStack(spacing: 2) {
                    ForEach(appState.agents.filter { $0.isActive }) { agent in
                        AgentSidebarItem(agent: agent)
                    }
                }
                .padding(.horizontal, 10)
            }

            Divider().opacity(0.3)

            engineStatus
                .padding(12)
        }
        .background(Color.white.opacity(0.7))
    }

    private var appHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [GlassTheme.accentPrimary, GlassTheme.accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)

                Image(systemName: "wand.and.stars")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Claw Studio")
                    .font(.system(size: 15, weight: .bold))
                Text("Agent OS")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(GlassTheme.textTertiary)
            }

            Spacer()
        }
    }

    private var engineStatus: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(appState.bridge.isEngineAvailable ? GlassTheme.accentSuccess : GlassTheme.accentError)
                .frame(width: 6, height: 6)

            Text(appState.bridge.isEngineAvailable ? "Engine Online" : "Engine Offline")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(GlassTheme.textSecondary)

            Spacer()

            if appState.bridge.isEngineAvailable {
                Text(appState.bridge.engineVersion)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(GlassTheme.textTertiary)
            }
        }
    }

    private func badgeCount(for tab: NavigationTab) -> Int? {
        switch tab {
        case .sessions: return appState.sessions.filter { $0.status == .running }.count
        case .agents: return appState.agents.filter { $0.isActive }.count
        case .apiKeys:
            let configured = appState.bridge.providers.filter { $0.isConfigured }.count
            return configured > 0 ? configured : nil
        case .skills:
            let ready = appState.bridge.skills.filter { $0.isReady }.count
            return ready > 0 ? ready : nil
        case .integrations:
            let connected = appState.bridge.channels.count
            return connected > 0 ? connected : nil
        default: return nil
        }
    }
}

// MARK: - Sidebar Components

struct SidebarButton: View {
    let title: String
    let icon: String
    var isSelected: Bool = false
    var badge: Int? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? GlassTheme.accentPrimary : GlassTheme.textSecondary)
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? GlassTheme.textPrimary : GlassTheme.textSecondary)

                Spacer()

                if let badge, badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(GlassTheme.accentPrimary)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(isSelected ? GlassTheme.accentPrimary.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

struct SessionSidebarItem: View {
    let session: AgentSession
    var isActive: Bool

    var body: some View {
        HStack(spacing: 8) {
            StatusDot(status: session.status)
            Text(session.name)
                .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? GlassTheme.textPrimary : GlassTheme.textSecondary)
                .lineLimit(1)
            Spacer()
            Text(session.messages.count.description)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(GlassTheme.textTertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isActive ? GlassTheme.surfaceHover : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct AgentSidebarItem: View {
    let agent: Agent

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: agent.icon)
                .font(.system(size: 11))
                .foregroundStyle(GlassTheme.agentColor(for: agent.name))
                .frame(width: 18)
            Text(agent.name)
                .font(.system(size: 12))
                .foregroundStyle(GlassTheme.textSecondary)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }
}
