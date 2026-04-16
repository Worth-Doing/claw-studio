import SwiftUI

struct AgentConfigView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedAgentId: UUID?
    @State private var showNewAgent = false
    @State private var showPipelineEditor = false

    var selectedAgent: Agent? {
        appState.agents.first { $0.id == selectedAgentId }
    }

    var body: some View {
        HSplitView {
            // Agent list
            agentListPanel
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)

            // Agent detail / pipeline
            if showPipelineEditor {
                PipelineEditorView()
            } else if let agent = selectedAgent,
                      let index = appState.agents.firstIndex(where: { $0.id == agent.id }) {
                AgentDetailView(agent: $appState.agents[index])
            } else {
                emptyState
            }
        }
    }

    private var agentListPanel: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "cpu.fill")
                    .foregroundStyle(GlassTheme.accentPrimary)
                Text("Agents")
                    .font(.system(size: 16, weight: .bold))
                Spacer()

                Button {
                    showPipelineEditor.toggle()
                } label: {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 13))
                }
                .glassButton(isActive: showPipelineEditor)
                .buttonStyle(.plain)
                .help("Pipeline Editor")

                Button {
                    let agent = Agent(name: "Agent \(appState.agents.count + 1)")
                    appState.agents.append(agent)
                    selectedAgentId = agent.id
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13))
                }
                .glassButton()
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(GlassTheme.headerBackground)

            Divider().opacity(0.3)

            // Agent cards
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(appState.agents) { agent in
                        AgentListCard(agent: agent, isSelected: agent.id == selectedAgentId) {
                            selectedAgentId = agent.id
                            showPipelineEditor = false
                        }
                    }
                }
                .padding(12)
            }
        }
        .background(GlassTheme.sidebarBackground)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "cpu")
                .font(.system(size: 40))
                .foregroundStyle(GlassTheme.textTertiary)
            Text("Select an agent to configure")
                .font(.system(size: 14))
                .foregroundStyle(GlassTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Agent List Card

struct AgentListCard: View {
    let agent: Agent
    var isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(GlassTheme.agentColor(for: agent.name).opacity(0.2))
                        .frame(width: 36, height: 36)

                    Image(systemName: agent.icon)
                        .font(.system(size: 15))
                        .foregroundStyle(GlassTheme.agentColor(for: agent.name))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(agent.name)
                        .font(.system(size: 13, weight: .semibold))
                    Text(agent.role)
                        .font(.system(size: 11))
                        .foregroundStyle(GlassTheme.textTertiary)
                }

                Spacer()

                Circle()
                    .fill(agent.isActive ? GlassTheme.accentSuccess : GlassTheme.textTertiary)
                    .frame(width: 8, height: 8)
            }
            .padding(12)
            .glassCard(isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Agent Detail View

struct AgentDetailView: View {
    @Binding var agent: Agent
    @State private var activeDetailTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Agent header
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [GlassTheme.agentColor(for: agent.name), GlassTheme.agentColor(for: agent.name).opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: agent.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    TextField("Agent Name", text: $agent.name)
                        .font(.system(size: 18, weight: .bold))
                        .textFieldStyle(.plain)

                    TextField("Role", text: $agent.role)
                        .font(.system(size: 13))
                        .foregroundStyle(GlassTheme.textSecondary)
                        .textFieldStyle(.plain)
                }

                Spacer()

                Toggle("Active", isOn: $agent.isActive)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            .padding(20)
            .background(GlassTheme.headerBackground)

            Divider().opacity(0.3)

            // Tabs
            Picker("Detail", selection: $activeDetailTab) {
                Text("Configuration").tag(0)
                Text("SOUL.md").tag(1)
                Text("AGENTS.md").tag(2)
                Text("Skills").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            // Tab content
            ScrollView {
                VStack(spacing: 16) {
                    switch activeDetailTab {
                    case 0:
                        configurationTab
                    case 1:
                        soulMDTab
                    case 2:
                        agentsMDTab
                    case 3:
                        skillsTab
                    default:
                        EmptyView()
                    }
                }
                .padding(20)
            }
        }
    }

    private var configurationTab: some View {
        VStack(spacing: 16) {
            // Model selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Model")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(GlassTheme.textSecondary)

                Picker("Model", selection: $agent.model) {
                    Text("Claude Sonnet 4.6").tag("anthropic/claude-sonnet-4-6")
                    Text("Claude Opus 4.6").tag("anthropic/claude-opus-4-6")
                    Text("Claude Haiku 4.5").tag("anthropic/claude-haiku-4-5")
                    Text("GPT-4o").tag("openai/gpt-4o")
                    Text("GPT-4o Mini").tag("openai/gpt-4o-mini")
                }
                .pickerStyle(.menu)
                .glassCard()
            }

            // Description
            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(GlassTheme.textSecondary)

                TextEditor(text: $agent.description)
                    .font(.system(size: 13))
                    .frame(height: 80)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .glassCard()
            }

            // Icon picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Icon")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(GlassTheme.textSecondary)

                let icons = ["cpu", "sparkles", "brain", "server.rack", "magnifyingglass",
                             "chevron.left.forwardslash.chevron.right", "doc.text", "globe",
                             "shield", "bolt", "wrench", "chart.bar"]

                LazyVGrid(columns: Array(repeating: GridItem(.fixed(44)), count: 6), spacing: 8) {
                    ForEach(icons, id: \.self) { icon in
                        Button {
                            agent.icon = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.system(size: 16))
                                .frame(width: 40, height: 40)
                                .foregroundStyle(agent.icon == icon ? GlassTheme.accentPrimary : GlassTheme.textSecondary)
                        }
                        .glassCard(isSelected: agent.icon == icon)
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var soulMDTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SOUL.md — Personality & Boundaries")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(GlassTheme.textSecondary)
                Spacer()
                GlassBadge(text: "Markdown", color: GlassTheme.accentTertiary)
            }

            TextEditor(text: $agent.soulMD)
                .font(.system(size: 12, design: .monospaced))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 300)
                .padding(12)
                .glassCard()

            Text("Define the agent's personality, communication style, and behavioral boundaries.")
                .font(.system(size: 11))
                .foregroundStyle(GlassTheme.textTertiary)
        }
    }

    private var agentsMDTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("AGENTS.md — Operational Instructions")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(GlassTheme.textSecondary)
                Spacer()
                GlassBadge(text: "Markdown", color: GlassTheme.accentTertiary)
            }

            TextEditor(text: $agent.agentsMD)
                .font(.system(size: 12, design: .monospaced))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 300)
                .padding(12)
                .glassCard()

            Text("Define routing rules, task delegation patterns, and operational procedures.")
                .font(.system(size: 11))
                .foregroundStyle(GlassTheme.textTertiary)
        }
    }

    private var skillsTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Assigned Skills")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(GlassTheme.textSecondary)

            Text("Skills this agent can use during execution.")
                .font(.system(size: 11))
                .foregroundStyle(GlassTheme.textTertiary)

            VStack(spacing: 6) {
                ForEach(["Shell Access", "File Operations", "Web Browsing", "Git Integration", "Code Analysis"], id: \.self) { skill in
                    HStack {
                        Text(skill)
                            .font(.system(size: 13))
                        Spacer()
                        Toggle("", isOn: .constant(agent.skills.contains(skill)))
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                    .padding(10)
                    .glassCard()
                }
            }
        }
    }
}

// MARK: - Pipeline Editor View

struct PipelineEditorView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .foregroundStyle(GlassTheme.accentPrimary)
                Text("Agent Pipeline")
                    .font(.system(size: 16, weight: .bold))
                Spacer()

                Button {
                    let pipeline = AgentPipeline(name: "Pipeline \(appState.pipelines.count + 1)")
                    appState.pipelines.append(pipeline)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("New Pipeline")
                    }
                    .font(.system(size: 12))
                }
                .glassButton(isActive: true)
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(GlassTheme.headerBackground)

            Divider().opacity(0.3)

            // Pipeline canvas
            ZStack {
                // Grid background
                PipelineGridBackground()

                // Agent nodes
                VStack(spacing: 40) {
                    HStack(spacing: 60) {
                        ForEach(appState.agents.prefix(4)) { agent in
                            PipelineNodeView(agent: agent)
                        }
                    }
                }

                if appState.agents.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                            .font(.system(size: 36))
                            .foregroundStyle(GlassTheme.textTertiary)
                        Text("Create agents to build pipelines")
                            .font(.system(size: 13))
                            .foregroundStyle(GlassTheme.textSecondary)
                    }
                }
            }
        }
    }
}

struct PipelineGridBackground: View {
    var body: some View {
        Canvas { context, size in
            let gridSize: CGFloat = 30
            let dotSize: CGFloat = 1.5

            for x in stride(from: CGFloat(0), to: size.width, by: gridSize) {
                for y in stride(from: CGFloat(0), to: size.height, by: gridSize) {
                    let rect = CGRect(x: x - dotSize / 2, y: y - dotSize / 2, width: dotSize, height: dotSize)
                    context.fill(Path(ellipseIn: rect), with: .color(GlassTheme.textTertiary.opacity(0.15)))
                }
            }
        }
    }
}

struct PipelineNodeView: View {
    let agent: Agent
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(GlassTheme.agentColor(for: agent.name).opacity(0.15))
                    .frame(width: 80, height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(GlassTheme.agentColor(for: agent.name).opacity(0.4), lineWidth: 1.5)
                    )
                    .shadow(color: GlassTheme.agentColor(for: agent.name).opacity(isHovered ? 0.3 : 0.1), radius: isHovered ? 12 : 4)

                Image(systemName: agent.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(GlassTheme.agentColor(for: agent.name))
            }

            Text(agent.name)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)

            Text(agent.role)
                .font(.system(size: 9))
                .foregroundStyle(GlassTheme.textTertiary)
                .lineLimit(1)
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
