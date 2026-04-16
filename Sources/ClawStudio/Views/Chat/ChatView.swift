import SwiftUI

struct ChatView: View {
    @EnvironmentObject var appState: AppState
    @State private var messageText = ""
    @State private var showThinkingPanel = false
    @State private var thinkingLevel = "medium"
    @FocusState private var isInputFocused: Bool

    var body: some View {
        HSplitView {
            // Main chat area
            VStack(spacing: 0) {
                chatHeader
                Divider().opacity(0.3)
                chatMessages
                Divider().opacity(0.3)
                inputArea
            }
            .frame(minWidth: 500)

            // Side panel (thinking / tool calls)
            if showThinkingPanel {
                ThinkingPanel(messages: appState.activeSession?.messages ?? [])
                    .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)
            }
        }
    }

    // MARK: - Header

    private var chatHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(appState.activeSession?.name ?? "No Session")
                    .font(.system(size: 16, weight: .semibold))

                if let session = appState.activeSession {
                    HStack(spacing: 8) {
                        StatusDot(status: session.status, size: 6)
                        Text(session.status.rawValue.capitalized)
                            .font(.system(size: 11))
                            .foregroundStyle(GlassTheme.textTertiary)

                        Text("·")
                            .foregroundStyle(GlassTheme.textTertiary)

                        Text("\(session.messages.count) messages")
                            .font(.system(size: 11))
                            .foregroundStyle(GlassTheme.textTertiary)
                    }
                }
            }

            Spacer()

            // Thinking level picker
            Picker("Thinking", selection: $thinkingLevel) {
                Text("Low").tag("low")
                Text("Medium").tag("medium")
                Text("High").tag("high")
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            Button {
                showThinkingPanel.toggle()
            } label: {
                Image(systemName: showThinkingPanel ? "sidebar.right" : "sidebar.right")
                    .font(.system(size: 14))
                    .foregroundStyle(showThinkingPanel ? GlassTheme.accentPrimary : GlassTheme.textSecondary)
            }
            .glassButton(isActive: showThinkingPanel)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.7))
    }

    // MARK: - Messages

    private var chatMessages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if let session = appState.activeSession {
                        if session.messages.isEmpty {
                            welcomeView
                        } else {
                            ForEach(session.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .onChange(of: appState.activeSession?.messages.count) { _, _ in
                if let lastId = appState.activeSession?.messages.last?.id {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var welcomeView: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 60)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [GlassTheme.accentPrimary.opacity(0.3), GlassTheme.accentSecondary.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "wand.and.stars")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(GlassTheme.accentPrimary)
            }

            Text("Welcome to Claw Studio")
                .font(.system(size: 24, weight: .bold))

            Text("Your Agent Operating System powered by OpenClaw")
                .font(.system(size: 14))
                .foregroundStyle(GlassTheme.textSecondary)

            // Quick action cards
            HStack(spacing: 12) {
                QuickActionCard(icon: "terminal.fill", title: "Run a Command", subtitle: "Execute shell commands") {
                    messageText = "Run `ls -la` in the current directory"
                    isInputFocused = true
                }
                QuickActionCard(icon: "doc.text.fill", title: "Analyze Code", subtitle: "Review and analyze code") {
                    messageText = "Analyze the code in this workspace"
                    isInputFocused = true
                }
                QuickActionCard(icon: "magnifyingglass", title: "Research", subtitle: "Search and gather info") {
                    messageText = "Research the latest trends in "
                    isInputFocused = true
                }
            }
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: 600)
    }

    // MARK: - Input Area

    private var inputArea: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 12) {
                // Attachment button
                Button {
                    // Future: file attachment
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(GlassTheme.textTertiary)
                }
                .buttonStyle(.plain)

                // Text input
                TextField("Message your agent...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .lineLimit(1...8)
                    .focused($isInputFocused)
                    .onSubmit {
                        if !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            sendMessage()
                        }
                    }

                // Send button
                Button(action: sendMessage) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: messageText.isEmpty
                                        ? [GlassTheme.surfaceSecondary, GlassTheme.surfaceSecondary]
                                        : [GlassTheme.accentPrimary, GlassTheme.accentSecondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 32, height: 32)

                        if appState.bridge.isRunning {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !appState.bridge.isRunning)
            }
            .padding(16)
            .background(Color.white.opacity(0.7))
        }
    }

    private func sendMessage() {
        if appState.bridge.isRunning {
            appState.bridge.stopCurrentProcess()
            return
        }

        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        messageText = ""

        Task {
            await appState.sendMessage(content)
        }
    }
}

// MARK: - Quick Action Card

struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(GlassTheme.accentPrimary)

                Text(title)
                    .font(.system(size: 12, weight: .semibold))

                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(GlassTheme.textTertiary)
            }
            .frame(width: 150, height: 100)
            .glassCard()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .assistant {
                agentAvatar
            } else {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                // Role label
                HStack(spacing: 6) {
                    Text(message.role == .user ? "You" : "Agent")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(GlassTheme.textSecondary)

                    Text(message.timestamp, style: .time)
                        .font(.system(size: 10))
                        .foregroundStyle(GlassTheme.textTertiary)
                }

                // Content
                if message.isStreaming && message.content.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(GlassTheme.accentPrimary)
                                .frame(width: 6, height: 6)
                                .opacity(0.6)
                        }
                    }
                    .padding(12)
                    .glassCard()
                } else {
                    Text(message.content)
                        .font(.system(size: 13.5))
                        .lineSpacing(4)
                        .textSelection(.enabled)
                        .padding(14)
                        .background {
                            if message.role == .user {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(GlassTheme.accentPrimary.opacity(0.12))
                            } else {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.9))
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(GlassTheme.borderSubtle, lineWidth: 0.5)
                        )
                }

                // Tool calls
                if !message.toolCalls.isEmpty {
                    ForEach(message.toolCalls) { toolCall in
                        ToolCallView(toolCall: toolCall)
                    }
                }
            }

            if message.role == .user {
                userAvatar
            } else {
                Spacer(minLength: 60)
            }
        }
    }

    private var agentAvatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [GlassTheme.accentPrimary, GlassTheme.accentSecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 30, height: 30)

            Image(systemName: "cpu")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private var userAvatar: some View {
        ZStack {
            Circle()
                .fill(GlassTheme.surfaceElevated)
                .frame(width: 30, height: 30)

            Image(systemName: "person.fill")
                .font(.system(size: 13))
                .foregroundStyle(GlassTheme.textSecondary)
        }
    }
}

// MARK: - Tool Call View

struct ToolCallView: View {
    let toolCall: ToolCall
    @State private var isExpanded = false

    var statusColor: Color {
        switch toolCall.status {
        case .pending: return GlassTheme.textTertiary
        case .running: return GlassTheme.accentWarning
        case .completed: return GlassTheme.accentSuccess
        case .failed: return GlassTheme.accentError
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "wrench.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(statusColor)

                    Text(toolCall.name)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(GlassTheme.textPrimary)

                    GlassBadge(text: toolCall.status.rawValue, color: statusColor)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9))
                        .foregroundStyle(GlassTheme.textTertiary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Arguments:")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(GlassTheme.textTertiary)
                    Text(toolCall.arguments)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(GlassTheme.textSecondary)

                    if let result = toolCall.result {
                        Divider().opacity(0.3)
                        Text("Result:")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(GlassTheme.textTertiary)
                        Text(result)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(GlassTheme.textSecondary)
                            .lineLimit(10)
                    }
                }
                .padding(8)
                .background(GlassTheme.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(10)
        .glassCard(cornerRadius: 10)
    }
}

// MARK: - Thinking Panel

struct ThinkingPanel: View {
    let messages: [ChatMessage]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(GlassTheme.accentSecondary)
                Text("Agent Thinking")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            .padding(14)
            .background(Color.white.opacity(0.7))

            Divider().opacity(0.3)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages.filter { $0.role == .assistant }) { message in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(message.timestamp, style: .time)
                                .font(.system(size: 10))
                                .foregroundStyle(GlassTheme.textTertiary)

                            Text(message.content.prefix(500))
                                .font(.system(size: 11))
                                .foregroundStyle(GlassTheme.textSecondary)
                                .lineSpacing(3)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(GlassTheme.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(12)
            }
        }
        .background(Color.white.opacity(0.7))
    }
}

