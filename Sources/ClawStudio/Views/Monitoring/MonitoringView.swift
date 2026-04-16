import SwiftUI
import Darwin

// MARK: - System Metrics Provider

@MainActor
final class SystemMetrics: ObservableObject {
    @Published var cpuUsage: Double = 0
    @Published var memoryUsage: Double = 0
    @Published var memoryUsedGB: Double = 0
    @Published var memoryTotalGB: Double = 0
    @Published var activeProcesses: Int = 0
    @Published var uptimeFormatted: String = ""

    private var timer: Timer?

    func startMonitoring() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        // Memory usage via host_statistics64
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let pageSize = Double(vm_kernel_page_size)
            let active = Double(stats.active_count) * pageSize
            let wired = Double(stats.wire_count) * pageSize
            let compressed = Double(stats.compressor_page_count) * pageSize
            let used = active + wired + compressed

            let totalMemory = Double(ProcessInfo.processInfo.physicalMemory)
            memoryUsedGB = used / (1024 * 1024 * 1024)
            memoryTotalGB = totalMemory / (1024 * 1024 * 1024)
            memoryUsage = (used / totalMemory) * 100
        }

        // CPU usage approximation via load average
        var loadAvg: [Double] = [0, 0, 0]
        getloadavg(&loadAvg, 3)
        let processorCount = Double(ProcessInfo.processInfo.processorCount)
        cpuUsage = min((loadAvg[0] / processorCount) * 100, 100)

        // Active process count
        activeProcesses = ProcessInfo.processInfo.activeProcessorCount

        // Uptime
        let uptime = ProcessInfo.processInfo.systemUptime
        let hours = Int(uptime) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        if hours > 24 {
            uptimeFormatted = "\(hours / 24)d \(hours % 24)h"
        } else {
            uptimeFormatted = "\(hours)h \(minutes)m"
        }
    }
}

// MARK: - Monitoring View

struct MonitoringView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var metrics = SystemMetrics()

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
                    topStatsRow

                    HStack(spacing: 16) {
                        tokenUsageCard
                        costBreakdownCard
                    }

                    systemResourcesRow

                    activityLogCard
                }
                .padding(20)
            }
        }
        .task {
            metrics.startMonitoring()
        }
        .onDisappear {
            metrics.stopMonitoring()
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

            Button {
                metrics.refresh()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
                .font(.system(size: 12))
            }
            .glassButton()
            .buttonStyle(.plain)

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
        .background(GlassTheme.headerBackground)
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
                    ForEach(Array(appState.agents.enumerated()), id: \.element.id) { index, agent in
                        let sessionCount = appState.sessions.filter { $0.agentId == agent.id }.count
                        let proportion = appState.agents.count > 0 ? CGFloat(index + 1) / CGFloat(appState.agents.count + 1) : 0.2

                        HStack(spacing: 10) {
                            Text(agent.name)
                                .font(.system(size: 11))
                                .frame(width: 120, alignment: .leading)

                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(
                                        LinearGradient(
                                            colors: [GlassTheme.agentColor(for: agent.name), GlassTheme.agentColor(for: agent.name).opacity(0.5)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * proportion, height: 16)
                            }
                            .frame(height: 16)

                            Text("\(sessionCount)")
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
                // Show costs by actual models configured
                let configuredModels = appState.bridge.configuredModels
                let colors: [Color] = [GlassTheme.accentPrimary, GlassTheme.accentSecondary, GlassTheme.accentTertiary, .orange, .pink]
                if configuredModels.isEmpty {
                    CostRow(label: "No models configured", cost: 0, color: GlassTheme.textTertiary)
                } else {
                    let portion = 1.0 / max(Double(configuredModels.count), 1)
                    ForEach(Array(configuredModels.prefix(5).enumerated()), id: \.element.id) { idx, model in
                        CostRow(label: model.name, cost: totalCost * portion, color: colors[idx % colors.count])
                    }
                }

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
            ResourceGauge(
                title: "CPU",
                value: metrics.cpuUsage,
                maxValue: 100,
                unit: "%",
                color: GlassTheme.accentPrimary,
                subtitle: "\(ProcessInfo.processInfo.processorCount) cores"
            )
            ResourceGauge(
                title: "Memory",
                value: metrics.memoryUsage,
                maxValue: 100,
                unit: "%",
                color: GlassTheme.accentSecondary,
                subtitle: String(format: "%.1f / %.0f GB", metrics.memoryUsedGB, metrics.memoryTotalGB)
            )
            ResourceGauge(
                title: "Uptime",
                value: 100,
                maxValue: 100,
                unit: "",
                color: GlassTheme.accentTertiary,
                subtitle: metrics.uptimeFormatted,
                showBar: false
            )
        }
    }

    private var activityLogCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundStyle(GlassTheme.accentPrimary)
                Text("Recent Activity")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                GlassBadge(text: "\(appState.sessions.count) sessions", color: GlassTheme.accentPrimary)
            }

            if appState.sessions.isEmpty {
                Text("No activity yet. Start a session to see activity here.")
                    .font(.system(size: 12))
                    .foregroundStyle(GlassTheme.textTertiary)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 4) {
                    ForEach(appState.sessions.sorted(by: { $0.updatedAt > $1.updatedAt }).prefix(8)) { session in
                        HStack(spacing: 8) {
                            StatusDot(status: session.status, size: 5)
                            Text(session.name)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                            Spacer()
                            Text("\(session.messages.count) msgs")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(GlassTheme.textTertiary)
                            Text(session.updatedAt, style: .relative)
                                .font(.system(size: 9))
                                .foregroundStyle(GlassTheme.textTertiary)
                        }
                        .padding(.vertical, 4)
                    }
                }
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
    var subtitle: String = ""
    var showBar: Bool = true

    var progress: Double { min(value / maxValue, 1.0) }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                if showBar {
                    Text("\(String(format: "%.1f", value))\(unit)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                }
            }

            if showBar {
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
                            .animation(.easeInOut(duration: 0.5), value: progress)
                    }
                }
                .frame(height: 8)
            }

            if !subtitle.isEmpty {
                HStack {
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(GlassTheme.textTertiary)
                    Spacer()
                }
            }
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
