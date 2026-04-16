import SwiftUI

struct GatewayView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var runner = CommandRunner()
    @State private var isRefreshing = false

    var status: GatewayStatus {
        appState.bridge.gatewayStatus
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider().opacity(0.3)

            ScrollView {
                VStack(spacing: 16) {
                    connectionHeroCard
                    actionsGrid
                    statusPanels
                    outputPanel
                    commandHistory
                }
                .padding(20)
            }
        }
        .task {
            await refresh()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(.system(size: 18))
                .foregroundStyle(GlassTheme.accentPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Gateway & Engine")
                    .font(.system(size: 18, weight: .bold))
                Text("Manage the OpenClaw runtime directly from the app")
                    .font(.system(size: 12))
                    .foregroundStyle(GlassTheme.textTertiary)
            }

            Spacer()

            Button {
                Task { await refresh() }
            } label: {
                HStack(spacing: 4) {
                    if isRefreshing {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text("Refresh Status")
                }
                .font(.system(size: 12))
            }
            .glassButton()
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(GlassTheme.headerBackground)
    }

    // MARK: - Connection Hero

    private var connectionHeroCard: some View {
        HStack(spacing: 20) {
            StatusHeroItem(
                icon: appState.bridge.isEngineAvailable ? "checkmark.circle.fill" : "xmark.circle.fill",
                title: appState.bridge.isEngineAvailable ? "Engine Online" : "Engine Offline",
                subtitle: appState.bridge.engineVersion,
                color: appState.bridge.isEngineAvailable ? GlassTheme.accentSuccess : GlassTheme.accentError
            )

            Divider().frame(height: 80).opacity(0.3)

            StatusHeroItem(
                icon: status.isReachable ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash",
                title: status.isReachable ? "Gateway Reachable" : "Gateway Unreachable",
                subtitle: status.address,
                color: status.isReachable ? GlassTheme.accentSuccess : GlassTheme.accentWarning
            )

            Divider().frame(height: 80).opacity(0.3)

            StatusHeroItem(
                icon: status.serviceInstalled ? "gearshape.circle.fill" : "gearshape.circle",
                title: status.serviceInstalled ? "Service Installed" : "No Service",
                subtitle: "LaunchAgent",
                color: status.serviceInstalled ? GlassTheme.accentPrimary : GlassTheme.textTertiary
            )

            Divider().frame(height: 80).opacity(0.3)

            StatusHeroItem(
                icon: "shield.fill",
                title: status.securityIssues.isEmpty ? "Secure" : "\(status.securityIssues.count) Issues",
                subtitle: "Security",
                color: status.securityIssues.isEmpty ? GlassTheme.accentSuccess : GlassTheme.accentWarning
            )
        }
        .padding(24)
        .glassCard()
    }

    // MARK: - Actions Grid

    private var actionsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Actions")
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 4)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
            ], spacing: 10) {
                RunActionCard(
                    icon: "play.fill", title: "Start Gateway",
                    subtitle: "Launch on port 18789",
                    color: GlassTheme.accentSuccess, runner: runner,
                    arguments: ["gateway", "--port", "18789"]
                )
                RunActionCard(
                    icon: "stethoscope", title: "Run Doctor",
                    subtitle: "Diagnose config and health",
                    color: GlassTheme.accentPrimary, runner: runner,
                    arguments: ["doctor"]
                )
                RunActionCard(
                    icon: "arrow.triangle.2.circlepath", title: "Run Setup Wizard",
                    subtitle: "Guided onboarding",
                    color: GlassTheme.accentSecondary, runner: runner,
                    arguments: ["configure"]
                )
                RunActionCard(
                    icon: "shield.checkered", title: "Security Audit",
                    subtitle: "Full security scan",
                    color: GlassTheme.accentWarning, runner: runner,
                    arguments: ["security", "audit"]
                )
                RunActionCard(
                    icon: "heart.text.clipboard", title: "Health Check",
                    subtitle: "Ping gateway health endpoint",
                    color: GlassTheme.accentTertiary, runner: runner,
                    arguments: ["health"]
                )
                RunActionCard(
                    icon: "globe", title: "Open Dashboard",
                    subtitle: "Control UI in browser",
                    color: .cyan, runner: nil,
                    arguments: [],
                    customAction: {
                        if let url = URL(string: "http://127.0.0.1:18789/") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                )
                RunActionCard(
                    icon: "rectangle.and.text.magnifyingglass", title: "View Logs",
                    subtitle: "Tail gateway logs",
                    color: .indigo, runner: runner,
                    arguments: ["logs"]
                )
                RunActionCard(
                    icon: "arrow.up.circle", title: "Check Updates",
                    subtitle: "Check for new version",
                    color: .mint, runner: runner,
                    arguments: ["update", "status"]
                )
            }
        }
    }

    // MARK: - Status Panels

    private var statusPanels: some View {
        HStack(alignment: .top, spacing: 16) {
            // Gateway info
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(GlassTheme.accentPrimary)
                    Text("Runtime Info")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                }

                VStack(spacing: 8) {
                    InfoRow(label: "Address", value: status.address)
                    InfoRow(label: "Agents", value: "\(status.agentCount)")
                    InfoRow(label: "Sessions", value: "\(status.sessionCount)")
                    InfoRow(label: "Memory", value: status.memoryStatus.capitalized)
                    InfoRow(label: "Skills Ready", value: "\(appState.bridge.skills.filter { $0.isReady }.count) / \(appState.bridge.skills.count)")
                    InfoRow(label: "Config File", value: appState.bridge.configFilePath)
                }
            }
            .padding(16)
            .glassCard()

            // Security
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "shield.fill")
                        .foregroundStyle(status.securityIssues.isEmpty ? GlassTheme.accentSuccess : GlassTheme.accentWarning)
                    Text("Security")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    if !status.securityIssues.isEmpty {
                        GlassBadge(text: "\(status.securityIssues.count) issues", color: GlassTheme.accentWarning)
                    }
                }

                if status.securityIssues.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(GlassTheme.accentSuccess)
                        Text("No security issues detected")
                            .font(.system(size: 12))
                            .foregroundStyle(GlassTheme.textSecondary)
                    }
                    .padding(10)
                } else {
                    VStack(spacing: 6) {
                        ForEach(status.securityIssues, id: \.self) { issue in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: issue.hasPrefix("CRITICAL")
                                    ? "exclamationmark.triangle.fill"
                                    : "exclamationmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(issue.hasPrefix("CRITICAL") ? GlassTheme.accentError : GlassTheme.accentWarning)
                                Text(issue)
                                    .font(.system(size: 11))
                                    .foregroundStyle(GlassTheme.textSecondary)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassCard()
                        }
                    }
                }
            }
            .padding(16)
            .glassCard()
        }
    }

    // MARK: - Output Panel

    private var outputPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "terminal.fill")
                    .foregroundStyle(GlassTheme.accentTertiary)
                Text("Command Output")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()

                if runner.isRunning {
                    Button { runner.cancel() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "stop.fill")
                            Text("Stop")
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(GlassTheme.accentError)
                    }
                    .glassButton()
                    .buttonStyle(.plain)
                }
            }

            LiveTerminalView(record: runner.currentRecord, maxHeight: 350)
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Command History

    private var commandHistory: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundStyle(GlassTheme.textTertiary)
                Text("Recent Commands")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()

                if !runner.history.isEmpty {
                    Button {
                        runner.history.removeAll()
                    } label: {
                        Text("Clear")
                            .font(.system(size: 11))
                            .foregroundStyle(GlassTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if runner.history.isEmpty {
                Text("No commands run yet — use the actions above to get started.")
                    .font(.system(size: 12))
                    .foregroundStyle(GlassTheme.textTertiary)
                    .padding(12)
            } else {
                VStack(spacing: 4) {
                    ForEach(runner.history.prefix(10)) { record in
                        HStack(spacing: 8) {
                            Image(systemName: record.status == .success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(record.status == .success ? GlassTheme.accentSuccess : GlassTheme.accentError)

                            Text(record.displayCommand)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(GlassTheme.textSecondary)
                                .lineLimit(1)

                            Spacer()

                            Text(record.startedAt, style: .relative)
                                .font(.system(size: 9))
                                .foregroundStyle(GlassTheme.textTertiary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                    }
                }
            }
        }
        .padding(16)
        .glassCard()
    }

    private func refresh() async {
        isRefreshing = true
        await appState.bridge.loadStatus()
        await appState.bridge.checkEngine()
        isRefreshing = false
    }
}

// MARK: - Status Hero Item

struct StatusHeroItem: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 60, height: 60)
                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundStyle(color)
            }
            Text(title)
                .font(.system(size: 12, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(GlassTheme.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Run Action Card

struct RunActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    var runner: CommandRunner?
    let arguments: [String]
    var customAction: (() -> Void)?
    @State private var isHovered = false

    var body: some View {
        Button {
            if let customAction {
                customAction()
            } else if let runner {
                Task {
                    _ = await runner.run(arguments)
                }
            }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(isHovered ? 0.25 : 0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: 15))
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(GlassTheme.textTertiary)
                }

                Spacer()

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(color.opacity(isHovered ? 0.8 : 0.5))
            }
            .padding(12)
            .glassCard()
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(GlassTheme.textTertiary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(GlassTheme.textPrimary)
                .textSelection(.enabled)
            Spacer()
        }
    }
}
