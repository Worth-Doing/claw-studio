import Foundation
import SwiftUI

// MARK: - Navigation

enum NavigationTab: String, CaseIterable, Identifiable {
    case chat = "Chat"
    case sessions = "Sessions"
    case agents = "Agents"
    case gateway = "Gateway"
    case apiKeys = "API Keys"
    case models = "Models"
    case integrations = "Integrations"
    case skills = "Skills"
    case filesystem = "Files"
    case memory = "Memory"
    case monitoring = "Monitoring"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right.fill"
        case .sessions: return "rectangle.stack.fill"
        case .agents: return "cpu.fill"
        case .gateway: return "server.rack"
        case .apiKeys: return "key.fill"
        case .models: return "cube.fill"
        case .integrations: return "link"
        case .skills: return "puzzlepiece.extension.fill"
        case .filesystem: return "folder.fill"
        case .memory: return "brain.fill"
        case .monitoring: return "chart.bar.fill"
        case .settings: return "gearshape.fill"
        }
    }

    var section: String {
        switch self {
        case .chat, .sessions, .agents: return "workspace"
        case .gateway, .apiKeys, .models, .integrations, .skills: return "openclaw"
        case .filesystem, .memory, .monitoring, .settings: return "system"
        }
    }
}

// MARK: - App State

@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab: NavigationTab = .chat
    @Published var sessions: [AgentSession] = []
    @Published var activeSessionId: UUID?
    @Published var agents: [Agent] = []
    @Published var skills: [Skill] = []
    @Published var apiKeys: [APIKeyEntry] = []
    @Published var costRecords: [CostRecord] = []
    @Published var pipelines: [AgentPipeline] = []
    @Published var memoryEntries: [MemoryEntry] = []
    @Published var isSidebarExpanded = true
    @Published var isLoading = false

    let bridge = OpenClawBridge()

    var activeSession: AgentSession? {
        get { sessions.first { $0.id == activeSessionId } }
        set {
            if let newValue, let idx = sessions.firstIndex(where: { $0.id == newValue.id }) {
                sessions[idx] = newValue
            }
        }
    }

    init() {
        loadDefaults()
    }

    private func loadDefaults() {
        let defaultSession = AgentSession(name: "Welcome")
        sessions = [defaultSession]
        activeSessionId = defaultSession.id

        agents = [
            Agent(name: "General Assistant", role: "General Purpose", description: "A versatile assistant for everyday tasks", model: "anthropic/claude-sonnet-4-6", icon: "sparkles"),
            Agent(name: "Code Reviewer", role: "Code Review", description: "Specialized in reviewing code and suggesting improvements", model: "anthropic/claude-sonnet-4-6", color: "purple", icon: "chevron.left.forwardslash.chevron.right"),
            Agent(name: "Research Agent", role: "Research", description: "Gathers and synthesizes information from multiple sources", model: "anthropic/claude-sonnet-4-6", color: "green", icon: "magnifyingglass"),
            Agent(name: "DevOps Monitor", role: "Infrastructure", description: "Monitors system health and assists with deployment", model: "anthropic/claude-sonnet-4-6", color: "orange", icon: "server.rack"),
        ]

        apiKeys = OpenClawBridge.knownProviders.map { provider in
            APIKeyEntry(service: provider.name, keyName: provider.envKey)
        }
    }

    func createSession(name: String, agentId: UUID? = nil) {
        let session = AgentSession(name: name, agentId: agentId)
        sessions.append(session)
        activeSessionId = session.id
    }

    func deleteSession(_ id: UUID) {
        sessions.removeAll { $0.id == id }
        if activeSessionId == id {
            activeSessionId = sessions.first?.id
        }
    }

    func initialLoad() async {
        isLoading = true
        await bridge.refreshAll()
        isLoading = false
    }

    func sendMessage(_ content: String) async {
        guard var session = activeSession else { return }

        let userMessage = ChatMessage(role: .user, content: content)
        session.messages.append(userMessage)
        session.status = .running
        session.updatedAt = Date()
        activeSession = session

        let assistantId = UUID()
        let assistantMessage = ChatMessage(id: assistantId, role: .assistant, content: "", isStreaming: true)
        session.messages.append(assistantMessage)
        activeSession = session

        await bridge.sendMessage(content) { @MainActor [weak self] output in
            guard let self else { return }
            let updatedMessage = ChatMessage(id: assistantId, role: .assistant, content: output, isStreaming: false)
            if var session = self.activeSession {
                if let idx = session.messages.firstIndex(where: { $0.id == assistantId }) {
                    session.messages[idx] = updatedMessage
                }
                session.status = .idle
                session.updatedAt = Date()
                self.activeSession = session
            }
        }
    }
}
