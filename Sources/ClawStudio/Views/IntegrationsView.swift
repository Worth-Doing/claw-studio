import SwiftUI

struct IntegrationsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var selectedChannel: (name: String, icon: String, description: String)?
    @State private var channelToken = ""
    @State private var isLoadingSkills = false
    @State private var skillSearchQuery = ""

    @StateObject private var runner = CommandRunner()

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider().opacity(0.3)

            // Tab bar
            HStack(spacing: 0) {
                IntegrationTabButton(title: "Channels", icon: "antenna.radiowaves.left.and.right",
                                     count: OpenClawBridge.knownChannels.count, isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                IntegrationTabButton(title: "Skills", icon: "puzzlepiece.extension",
                                     count: appState.bridge.skills.count, isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
                IntegrationTabButton(title: "ClawHub", icon: "square.grid.2x2",
                                     count: nil, isSelected: selectedTab == 2) {
                    selectedTab = 2
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.7))

            Divider().opacity(0.3)

            switch selectedTab {
            case 0: channelsPanel
            case 1: skillsPanel
            case 2: clawHubPanel
            default: EmptyView()
            }
        }
        .task {
            if appState.bridge.skills.isEmpty {
                isLoadingSkills = true
                await appState.bridge.loadSkills()
                isLoadingSkills = false
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: "link")
                .font(.system(size: 18))
                .foregroundStyle(GlassTheme.accentTertiary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Integrations")
                    .font(.system(size: 18, weight: .bold))
                Text("Connect channels and manage skills — all from the app")
                    .font(.system(size: 12))
                    .foregroundStyle(GlassTheme.textTertiary)
            }

            Spacer()

            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text("\(OpenClawBridge.knownChannels.count)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("Channels")
                        .font(.system(size: 9))
                        .foregroundStyle(GlassTheme.textTertiary)
                }
                VStack(spacing: 2) {
                    Text("\(appState.bridge.skills.count)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("Skills")
                        .font(.system(size: 9))
                        .foregroundStyle(GlassTheme.textTertiary)
                }
                VStack(spacing: 2) {
                    Text("\(appState.bridge.skills.filter { $0.isReady }.count)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(GlassTheme.accentSuccess)
                    Text("Ready")
                        .font(.system(size: 9))
                        .foregroundStyle(GlassTheme.textTertiary)
                }
            }

            Button {
                Task {
                    isLoadingSkills = true
                    await appState.bridge.loadSkills()
                    isLoadingSkills = false
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                    Text("Reload")
                }
                .font(.system(size: 12))
            }
            .glassButton()
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.7))
    }

    // MARK: - Channels Panel

    private var channelsPanel: some View {
        HSplitView {
            ScrollView {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(GlassTheme.textTertiary)
                    TextField("Search channels...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                }
                .glassTextField()
                .padding(.horizontal, 16)
                .padding(.top, 12)

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                ], spacing: 12) {
                    ForEach(filteredChannels, id: \.name) { channel in
                        ChannelCard(
                            name: channel.name,
                            icon: channel.icon,
                            description: channel.description,
                            isConnected: appState.bridge.channels.contains { $0.name == channel.name },
                            isSelected: selectedChannel?.name == channel.name
                        ) {
                            selectedChannel = channel
                        }
                    }
                }
                .padding(16)
            }
            .frame(minWidth: 500)

            if let channel = selectedChannel {
                channelDetailPanel(channel: channel)
                    .frame(minWidth: 340, idealWidth: 380)
            }
        }
    }

    private var filteredChannels: [(name: String, icon: String, description: String)] {
        if searchText.isEmpty { return OpenClawBridge.knownChannels }
        return OpenClawBridge.knownChannels.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
            || $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func channelDetailPanel(channel: (name: String, icon: String, description: String)) -> some View {
        let isConnected = appState.bridge.channels.contains { $0.name == channel.name }
        let needsToken = ["telegram", "discord", "slack", "teams", "mattermost"].contains(channel.name)

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isConnected ? GlassTheme.accentSuccess.opacity(0.15) : GlassTheme.accentPrimary.opacity(0.15))
                            .frame(width: 52, height: 52)

                        Image(systemName: channel.icon)
                            .font(.system(size: 22))
                            .foregroundStyle(isConnected ? GlassTheme.accentSuccess : GlassTheme.accentPrimary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(channel.name.capitalized)
                            .font(.system(size: 20, weight: .bold))
                        HStack(spacing: 6) {
                            Circle()
                                .fill(isConnected ? GlassTheme.accentSuccess : GlassTheme.textTertiary)
                                .frame(width: 6, height: 6)
                            Text(isConnected ? "Connected" : "Not connected")
                                .font(.system(size: 11))
                                .foregroundStyle(isConnected ? GlassTheme.accentSuccess : GlassTheme.textTertiary)
                        }
                    }
                    Spacer()
                }

                Text(channel.description)
                    .font(.system(size: 12))
                    .foregroundStyle(GlassTheme.textSecondary)

                Divider().opacity(0.3)

                // Token-based setup
                if needsToken {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Connect with Bot Token")
                            .font(.system(size: 13, weight: .semibold))

                        Text("Paste your \(channel.name.capitalized) bot token below to connect it to OpenClaw.")
                            .font(.system(size: 11))
                            .foregroundStyle(GlassTheme.textTertiary)

                        SecureField("Bot token...", text: $channelToken)
                            .glassTextField()

                        Button {
                            Task {
                                _ = await runner.run(["channels", "add", "--channel", channel.name, "--token", channelToken])
                                channelToken = ""
                                await appState.bridge.loadSkills()
                            }
                        } label: {
                            HStack {
                                if runner.isRunning {
                                    ProgressView().scaleEffect(0.7)
                                } else {
                                    Image(systemName: "plus.circle.fill")
                                }
                                Text("Connect \(channel.name.capitalized)")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                        }
                        .glassButton(isActive: true)
                        .buttonStyle(.plain)
                        .disabled(channelToken.isEmpty || runner.isRunning)
                    }
                }

                // Quick actions
                VStack(alignment: .leading, spacing: 10) {
                    Text("Actions")
                        .font(.system(size: 13, weight: .semibold))

                    // Login button (for session-based channels like WhatsApp)
                    if ["whatsapp", "bluebubbles", "imessage"].contains(channel.name) {
                        ActionButtonWithTerminal(
                            title: "Login to \(channel.name.capitalized)",
                            icon: "person.badge.key.fill",
                            color: GlassTheme.accentPrimary,
                            arguments: ["channels", "login", "--channel", channel.name],
                            subtitle: "Start authentication flow"
                        )
                    }

                    // Check status
                    ActionButtonWithTerminal(
                        title: "Check Status",
                        icon: "antenna.radiowaves.left.and.right",
                        color: GlassTheme.accentTertiary,
                        arguments: ["channels", "status"],
                        subtitle: "Probe channel connectivity"
                    )

                    // Remove channel
                    if isConnected {
                        ActionButtonWithTerminal(
                            title: "Disconnect \(channel.name.capitalized)",
                            icon: "minus.circle",
                            color: GlassTheme.accentError,
                            arguments: ["channels", "remove", channel.name],
                            subtitle: "Remove this channel"
                        )
                    }
                }

                // Last command output
                if runner.currentRecord != nil {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Output")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(GlassTheme.textTertiary)
                        LiveTerminalView(record: runner.currentRecord, maxHeight: 200)
                    }
                }
            }
            .padding(20)
        }
        .background(Color.white.opacity(0.7))
    }

    // MARK: - Skills Panel

    private var skillsPanel: some View {
        ScrollView {
            if isLoadingSkills {
                VStack {
                    ProgressView("Loading skills from OpenClaw...")
                        .padding(40)
                }
            } else {
                // Stats
                HStack(spacing: 12) {
                    SkillStatCard(title: "Total", value: appState.bridge.skills.count,
                                  icon: "puzzlepiece.extension", color: GlassTheme.accentPrimary)
                    SkillStatCard(title: "Ready", value: appState.bridge.skills.filter { $0.isReady }.count,
                                  icon: "checkmark.circle", color: GlassTheme.accentSuccess)
                    SkillStatCard(title: "Needs Setup", value: appState.bridge.skills.filter { $0.needsSetup }.count,
                                  icon: "wrench", color: GlassTheme.accentWarning)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                LazyVStack(spacing: 8) {
                    ForEach(appState.bridge.skills) { skill in
                        RealSkillCard(skill: skill)
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: - ClawHub Panel

    private var clawHubPanel: some View {
        VStack(spacing: 16) {
            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(GlassTheme.textTertiary)
                TextField("Search ClawHub for skills...", text: $skillSearchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onSubmit { searchClawHub() }

                Button {
                    searchClawHub()
                } label: {
                    HStack(spacing: 4) {
                        if runner.isRunning { ProgressView().scaleEffect(0.6) }
                        else { Image(systemName: "magnifyingglass") }
                        Text("Search")
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .glassButton(isActive: true)
                .buttonStyle(.plain)
                .disabled(skillSearchQuery.isEmpty || runner.isRunning)
            }
            .glassTextField()
            .padding(.horizontal, 20)
            .padding(.top, 16)

            // Skill install
            HStack(spacing: 8) {
                @State var installSlug = ""
                TextField("Skill slug to install...", text: $installSlug)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))

                Button {
                    Task {
                        _ = await runner.run(["skills", "install", installSlug])
                        await appState.bridge.loadSkills()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.down")
                        Text("Install")
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .glassButton(isActive: true)
                .buttonStyle(.plain)
            }
            .glassTextField()
            .padding(.horizontal, 20)

            // Quick actions
            HStack(spacing: 12) {
                ActionButtonWithTerminal(
                    title: "Update All Skills",
                    icon: "arrow.triangle.2.circlepath",
                    color: GlassTheme.accentPrimary,
                    arguments: ["skills", "update"],
                    subtitle: "Sync all installed skills to latest"
                )
                ActionButtonWithTerminal(
                    title: "List Installed",
                    icon: "list.bullet",
                    color: GlassTheme.accentTertiary,
                    arguments: ["skills", "list"],
                    subtitle: "Show all skills and status"
                )
            }
            .padding(.horizontal, 20)

            // Output
            if runner.currentRecord != nil {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Results")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(GlassTheme.textSecondary)
                    LiveTerminalView(record: runner.currentRecord, maxHeight: 400)
                }
                .padding(.horizontal, 20)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 36))
                        .foregroundStyle(GlassTheme.textTertiary)
                    Text("ClawHub Skill Registry")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Search and install community skills directly from here.")
                        .font(.system(size: 12))
                        .foregroundStyle(GlassTheme.textTertiary)
                }
                .padding(.vertical, 40)
            }

            Spacer()
        }
    }

    private func searchClawHub() {
        guard !skillSearchQuery.isEmpty else { return }
        Task {
            _ = await runner.run(["skills", "search", skillSearchQuery])
        }
    }
}

// MARK: - Reusable Sub-views

struct IntegrationTabButton: View {
    let title: String
    let icon: String
    let count: Int?
    var isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                if let count {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(isSelected ? GlassTheme.accentPrimary : GlassTheme.textTertiary)
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(isSelected ? GlassTheme.accentPrimary : GlassTheme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? GlassTheme.accentPrimary.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

struct ChannelCard: View {
    let name: String
    let icon: String
    let description: String
    let isConnected: Bool
    var isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isConnected
                                ? GlassTheme.accentSuccess.opacity(0.15)
                                : GlassTheme.surfaceSecondary)
                            .frame(width: 36, height: 36)

                        Image(systemName: icon)
                            .font(.system(size: 15))
                            .foregroundStyle(isConnected ? GlassTheme.accentSuccess : GlassTheme.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(name.capitalized)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        Text(isConnected ? "Connected" : "Not connected")
                            .font(.system(size: 10))
                            .foregroundStyle(isConnected ? GlassTheme.accentSuccess : GlassTheme.textTertiary)
                    }

                    Spacer()

                    Circle()
                        .fill(isConnected ? GlassTheme.accentSuccess : GlassTheme.textTertiary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }

                Text(description)
                    .font(.system(size: 10))
                    .foregroundStyle(GlassTheme.textTertiary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .glassCard(isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }
}

struct RealSkillCard: View {
    let skill: OpenClawSkillEntry
    @State private var isExpanded = false
    @StateObject private var runner = CommandRunner()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(skill.icon)
                    .font(.system(size: 18))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(skill.name)
                            .font(.system(size: 13, weight: .semibold))
                        GlassBadge(
                            text: skill.isReady ? "Ready" : "Needs Setup",
                            color: skill.isReady ? GlassTheme.accentSuccess : GlassTheme.accentWarning
                        )
                    }
                    Text(skill.source)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(GlassTheme.textTertiary)
                }

                Spacer()

                // Setup button for skills that need it
                if skill.needsSetup {
                    Button {
                        isExpanded = true
                        Task {
                            _ = await runner.run(["skills", "install", skill.name])
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if runner.isRunning {
                                ProgressView().scaleEffect(0.6)
                            } else {
                                Image(systemName: "wrench.fill")
                            }
                            Text("Setup")
                        }
                        .font(.system(size: 11, weight: .medium))
                    }
                    .glassButton(isActive: true)
                    .buttonStyle(.plain)
                    .disabled(runner.isRunning)
                }

                Button {
                    withAnimation { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(GlassTheme.textTertiary)
                }
                .buttonStyle(.plain)
            }

            Text(skill.description)
                .font(.system(size: 11))
                .foregroundStyle(GlassTheme.textSecondary)
                .lineLimit(isExpanded ? nil : 2)
                .lineSpacing(3)

            if isExpanded && runner.currentRecord != nil {
                LiveTerminalView(record: runner.currentRecord, maxHeight: 150)
            }
        }
        .padding(14)
        .glassCard(isSelected: skill.isReady)
    }
}

struct SkillStatCard: View {
    let title: String
    let value: Int
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(value)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text(title)
                    .font(.system(size: 10))
                    .foregroundStyle(GlassTheme.textTertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}
