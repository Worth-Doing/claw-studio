import SwiftUI

struct ChatView: View {
    @EnvironmentObject var appState: AppState
    @State private var messageText = ""
    @State private var showThinkingPanel = false
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

                        Text("\u{00B7}")
                            .foregroundStyle(GlassTheme.textTertiary)

                        Text("\(session.messages.count) messages")
                            .font(.system(size: 11))
                            .foregroundStyle(GlassTheme.textTertiary)
                    }
                }
            }

            Spacer()

            // Thinking level picker
            Picker("Thinking", selection: Binding(
                get: { appState.preferences.thinkingLevel },
                set: { appState.preferences.thinkingLevel = $0 }
            )) {
                Text("Low").tag("low")
                Text("Medium").tag("medium")
                Text("High").tag("high")
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showThinkingPanel.toggle()
                }
            } label: {
                Image(systemName: "sidebar.right")
                    .font(.system(size: 14))
                    .foregroundStyle(showThinkingPanel ? GlassTheme.accentPrimary : GlassTheme.textSecondary)
            }
            .glassButton(isActive: showThinkingPanel)
            .buttonStyle(.plain)
            .help("Toggle Thinking Panel")

            Menu {
                Button("Clear Messages") {
                    if let id = appState.activeSessionId {
                        appState.clearSession(id)
                    }
                }
                Button("Duplicate Session") {
                    if let id = appState.activeSessionId {
                        appState.duplicateSession(id)
                    }
                }
                Divider()
                Button("Export as Text") {
                    exportSession()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(GlassTheme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(GlassTheme.headerBackground)
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
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                                        removal: .opacity
                                    ))
                            }
                        }
                    }
                }
                .padding(20)
                .animation(.easeOut(duration: 0.25), value: appState.activeSession?.messages.count)
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
                    messageText = "Help me research "
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
                .help("Attach file")

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
                                    colors: messageText.isEmpty && !appState.bridge.isRunning
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
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(16)
            .background(GlassTheme.headerBackground)
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

    private func exportSession() {
        guard let session = appState.activeSession else { return }
        let text = session.messages.map { msg in
            let role = msg.role == .user ? "You" : "Agent"
            return "[\(role)] \(msg.content)"
        }.joined(separator: "\n\n---\n\n")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - Quick Action Card

struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    @State private var isHovered = false

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
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
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
                    StreamingDotsView()
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
                                    .fill(GlassTheme.cardBackground)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(GlassTheme.borderSubtle, lineWidth: 0.5)
                        )
                        .contextMenu {
                            Button("Copy") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(message.content, forType: .string)
                            }
                            Button("Select All") {}
                        }
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
                .overlay(
                    Circle()
                        .strokeBorder(GlassTheme.borderSubtle, lineWidth: 0.5)
                )

            Image(systemName: "person.fill")
                .font(.system(size: 13))
                .foregroundStyle(GlassTheme.textSecondary)
        }
    }
}

// MARK: - Streaming Dots Animation

struct StreamingDotsView: View {
    @State private var animationPhase: Int = 0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(GlassTheme.accentPrimary)
                    .frame(width: 7, height: 7)
                    .scaleEffect(animationPhase == i ? 1.3 : 0.7)
                    .opacity(animationPhase == i ? 1.0 : 0.4)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: false)) {
                startAnimation()
            }
        }
    }

    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                animationPhase = (animationPhase + 1) % 3
            }
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
                .transition(.opacity.combined(with: .move(edge: .top)))
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
            .background(GlassTheme.headerBackground)

            Divider().opacity(0.3)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if messages.filter({ $0.role == .assistant }).isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "brain")
                                .font(.system(size: 24))
                                .foregroundStyle(GlassTheme.textTertiary)
                            Text("Agent thoughts will appear here")
                                .font(.system(size: 12))
                                .foregroundStyle(GlassTheme.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
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
                }
                .padding(12)
            }
        }
        .background(GlassTheme.sidebarBackground)
    }
}
