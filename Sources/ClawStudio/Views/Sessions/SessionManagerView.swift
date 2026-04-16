import SwiftUI

struct SessionManagerView: View {
    @EnvironmentObject var appState: AppState
    @State private var showNewSession = false
    @State private var newSessionName = ""
    @State private var selectedAgentId: UUID?
    @State private var searchText = ""
    @State private var filterStatus: SessionStatus?

    var filteredSessions: [AgentSession] {
        appState.sessions.filter { session in
            let matchesSearch = searchText.isEmpty || session.name.localizedCaseInsensitiveContains(searchText)
            let matchesFilter = filterStatus == nil || session.status == filterStatus
            return matchesSearch && matchesFilter
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider().opacity(0.3)

            // Content
            ScrollView {
                LazyVStack(spacing: 12) {
                    // Stats cards
                    statsRow

                    // Session list
                    ForEach(filteredSessions) { session in
                        SessionCard(session: session, isActive: session.id == appState.activeSessionId) {
                            appState.activeSessionId = session.id
                            appState.selectedTab = .chat
                        } onDelete: {
                            appState.deleteSession(session.id)
                        }
                    }
                }
                .padding(20)
            }
        }
        .sheet(isPresented: $showNewSession) {
            newSessionSheet
        }
    }

    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 18))
                .foregroundStyle(GlassTheme.accentPrimary)

            Text("Session Manager")
                .font(.system(size: 18, weight: .bold))

            Spacer()

            // Search
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(GlassTheme.textTertiary)
                TextField("Search sessions...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .glassTextField()
            .frame(width: 200)

            // Filter
            Menu {
                Button("All") { filterStatus = nil }
                Divider()
                ForEach([SessionStatus.idle, .running, .paused, .completed, .error], id: \.self) { status in
                    Button(status.rawValue.capitalized) { filterStatus = status }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text(filterStatus?.rawValue.capitalized ?? "All")
                }
                .font(.system(size: 12))
            }
            .glassButton()
            .buttonStyle(.plain)

            Button {
                showNewSession = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("New Session")
                }
                .font(.system(size: 12, weight: .medium))
            }
            .glassButton(isActive: true)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(GlassTheme.headerBackground)
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatCard(title: "Total", value: "\(appState.sessions.count)", icon: "rectangle.stack", color: GlassTheme.accentPrimary)
            StatCard(title: "Running", value: "\(appState.sessions.filter { $0.status == .running }.count)", icon: "bolt.fill", color: GlassTheme.accentSuccess)
            StatCard(title: "Messages", value: "\(appState.sessions.reduce(0) { $0 + $1.messages.count })", icon: "bubble.fill", color: GlassTheme.accentSecondary)
            StatCard(title: "Tokens Used", value: formatNumber(appState.sessions.reduce(0) { $0 + $1.tokenUsage.totalTokens }), icon: "number", color: GlassTheme.accentWarning)
        }
    }

    private var newSessionSheet: some View {
        VStack(spacing: 20) {
            Text("Create New Session")
                .font(.system(size: 16, weight: .bold))

            VStack(alignment: .leading, spacing: 8) {
                Text("Session Name")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(GlassTheme.textSecondary)
                TextField("My Session", text: $newSessionName)
                    .glassTextField()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Assign Agent (Optional)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(GlassTheme.textSecondary)

                ForEach(appState.agents) { agent in
                    Button {
                        selectedAgentId = agent.id
                    } label: {
                        HStack {
                            Image(systemName: agent.icon)
                                .foregroundStyle(GlassTheme.agentColor(for: agent.name))
                            Text(agent.name)
                            Spacer()
                            if selectedAgentId == agent.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(GlassTheme.accentSuccess)
                            }
                        }
                        .padding(8)
                        .glassCard(isSelected: selectedAgentId == agent.id)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Button("Cancel") {
                    showNewSession = false
                }
                .glassButton()
                .buttonStyle(.plain)

                Spacer()

                Button("Create") {
                    let name = newSessionName.isEmpty ? "Session \(appState.sessions.count + 1)" : newSessionName
                    appState.createSession(name: name, agentId: selectedAgentId)
                    newSessionName = ""
                    selectedAgentId = nil
                    showNewSession = false
                }
                .glassButton(isActive: true)
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .frame(width: 400)
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}

// MARK: - Session Card

struct SessionCard: View {
    let session: AgentSession
    var isActive: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                StatusDot(status: session.status, size: 10)

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.name)
                        .font(.system(size: 14, weight: .semibold))
                    HStack(spacing: 8) {
                        Text("\(session.messages.count) messages")
                        Text("·")
                        Text(session.updatedAt, style: .relative)
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(GlassTheme.textTertiary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    GlassBadge(text: session.status.rawValue.capitalized)

                    if session.tokenUsage.totalTokens > 0 {
                        Text("\(session.tokenUsage.totalTokens) tokens")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(GlassTheme.textTertiary)
                    }
                }

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(GlassTheme.accentError.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .glassCard(isSelected: isActive)
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(color)
                Spacer()
            }

            HStack {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Spacer()
            }

            HStack {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(GlassTheme.textTertiary)
                Spacer()
            }
        }
        .padding(14)
        .glassCard()
    }
}
