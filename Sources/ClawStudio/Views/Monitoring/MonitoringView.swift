import SwiftUI

struct MonitoringView: View {
    @EnvironmentObject var appState: AppState
    @State private var refreshTimer: Timer?
    @State private var cpuUsage: Double = 12.5
    @State private var memoryUsage: Double = 34.2
    @State private var activeProcesses: Int = 2

    var totalCost: Double {
        appState.costRecords.reduce(0) { $0 + $1.cost }
    }

    var totalInputTokens: Int {
        appState.sessions.reduce(0) { $0 + $1.tokenUsage.inputTokens }
    }

    var totalOutputTokens: Int {
        appState.sessions.reduce(0) { $0 + $1.tokenUsage.outputTokens }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider().opacity(0.3)

            ScrollView {
                VStack(spacing: 16) {
                    // Top stats
                    topStatsRow

                    // Charts area
                    HStack(spacing: 16) {
                        // Token usage chart
                        tokenUsageCard
                        // Cost breakdown
                        costBreakdownCard
                    }

                    // System resources
                    systemResourcesRow

                    // Activity log
                    activityLogCard
                }
                .padding(20)
            }
        }
    }

    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 18))
                .foregroundStyle(GlassTheme.accentPrimary)

            Text("Monitoring & Analytics")
                .font(.system(size: 18, weight: .bold))

            Spacer()

            HStack(spacing: 4) {
                Circle()
                    .fill(GlassTheme.accentSuccess)
                    .frame(width: 6, height: 6)
                Text("Live")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(GlassTheme.accentSuccess)
            }
            .glassButton()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.7))
    }

    private var topStatsRow: some View {
        HStack(spacing: 12) {
            MonitorStatCard(
                title: "Total Cost",
                value: String(format: "$%.4f", totalCost),
                subtitle: "All sessions",
                icon: "dollarsign.circle",
                color: GlassTheme.accentWarning
            )
            MonitorStatCard(
                title: "Input Tokens",
                value: formatNumber(totalInputTokens),
                subtitle: "Prompt tokens",
                icon: "arrow.right.circle",
                color: GlassTheme.accentPrimary
            )
            MonitorStatCard(
                title: "Output Tokens",
                value: formatNumber(totalOutputTokens),
                subtitle: "Completion tokens",
                icon: "arrow.left.circle",
                color: GlassTheme.accentSecondary
            )
            MonitorStatCard(
                title: "Active Sessions",
                value: "\(appState.sessions.filter { $0.status == .running }.count)",
                subtitle: "of \(appState.sessions.count) total",
                icon: "bolt.circle",
                color: GlassTheme.accentSuccess
            )
        }
    }

    private var tokenUsageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .foregroundStyle(GlassTheme.accentPrimary)
                Text("Token Usage by Agent")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }

            if appState.agents.isEmpty {
                Text("No agent data available")
                    .font(.system(size: 12))
                    .foregroundStyle(GlassTheme.textTertiary)
                    .padding(.vertical, 30)
                    .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 8) {
                    ForEach(appState.agents) { agent in
                        HStack(spacing: 10) {
                            Text(agent.name)
                                .font(.system(size: 11))
                                .frame(width: 120, alignment: .leading)

                            GeometryReader { geo in
                                let randomWidth = CGFloat.random(in: 0.1...0.8)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(
                                        LinearGradient(
                                            colors: [GlassTheme.agentColor(for: agent.name), GlassTheme.agentColor(for: agent.name).opacity(0.5)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * randomWidth, height: 16)
                            }
                            .frame(height: 16)

                            Text("0")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(GlassTheme.textTertiary)
                                .frame(width: 50, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding(16)
        .glassCard()
    }

    private var costBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "dollarsign.circle")
                    .foregroundStyle(GlassTheme.accentWarning)
                Text("Cost Breakdown")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }

            VStack(spacing: 8) {
                CostRow(label: "Claude Sonnet 4.6", cost: totalCost * 0.6, color: GlassTheme.accentPrimary)
                CostRow(label: "Claude Opus 4.6", cost: totalCost * 0.3, color: GlassTheme.accentSecondary)
                CostRow(label: "Claude Haiku 4.5", cost: totalCost * 0.1, color: GlassTheme.accentTertiary)

                Divider().opacity(0.3)

                HStack {
                    Text("Total")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text(String(format: "$%.4f", totalCost))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                }
            }
        }
        .padding(16)
        .glassCard()
    }

    private var systemResourcesRow: some View {
        HStack(spacing: 12) {
            ResourceGauge(title: "CPU", value: cpuUsage, maxValue: 100, unit: "%", color: GlassTheme.accentPrimary)
            ResourceGauge(title: "Memory", value: memoryUsage, maxValue: 100, unit: "%", color: GlassTheme.accentSecondary)
            ResourceGauge(title: "Processes", value: Double(activeProcesses), maxValue: 10, unit: "", color: GlassTheme.accentTertiary)
        }
    }

    private var activityLogCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundStyle(GlassTheme.accentPrimary)
                Text("Activity Log")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                GlassBadge(text: "Live", color: GlassTheme.accentSuccess)
            }

            VStack(spacing: 4) {
                ActivityLogRow(time: "Now", event: "System initialized", type: .info)
                ActivityLogRow(time: "Just now", event: "OpenClaw engine connected", type: .success)
                ActivityLogRow(time: "Just now", event: "Default agents loaded", type: .info)
                ActivityLogRow(time: "Just now", event: "Workspace scanned", type: .info)
            }
        }
        .padding(16)
        .glassCard()
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}

// MARK: - Monitor Stat Card

struct MonitorStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
                Spacer()
            }

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(GlassTheme.textTertiary)
            }
        }
        .padding(14)
        .glassCard()
    }
}

// MARK: - Cost Row

struct CostRow: View {
    let label: String
    let cost: Double
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(GlassTheme.textSecondary)
            Spacer()
            Text(String(format: "$%.4f", cost))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(GlassTheme.textPrimary)
        }
    }
}

// MARK: - Resource Gauge

struct ResourceGauge: View {
    let title: String
    let value: Double
    let maxValue: Double
    let unit: String
    let color: Color

    var progress: Double { min(value / maxValue, 1.0) }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(String(format: "%.1f", value))\(unit)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(GlassTheme.surfaceSecondary)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(14)
        .glassCard()
    }
}

// MARK: - Activity Log Row

enum ActivityType {
    case info, success, warning, error
}

struct ActivityLogRow: View {
    let time: String
    let event: String
    let type: ActivityType

    var color: Color {
        switch type {
        case .info: return GlassTheme.textTertiary
        case .success: return GlassTheme.accentSuccess
        case .warning: return GlassTheme.accentWarning
        case .error: return GlassTheme.accentError
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text(time)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(GlassTheme.textTertiary)
                .frame(width: 60, alignment: .leading)
            Text(event)
                .font(.system(size: 11))
                .foregroundStyle(GlassTheme.textSecondary)
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
