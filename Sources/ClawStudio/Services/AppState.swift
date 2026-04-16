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

// MARK: - User Preferences (persisted)

final class UserPreferences: ObservableObject {
    @AppStorage("workspacePath") var workspacePath = "~/.openclaw/workspace"
    @AppStorage("defaultModel") var defaultModel = "openrouter/anthropic/claude-haiku-4.5"
    @AppStorage("thinkingLevel") var thinkingLevel = "medium"
    @AppStorage("autoSave") var autoSave = true
    @AppStorage("showTokenCost") var showTokenCost = true
    @AppStorage("appearanceMode") var appearanceMode = "system" // "system", "light", "dark"

    var resolvedColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil // system
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
    let preferences = UserPreferences()

    var activeSession: AgentSession? {
        get { sessions.first { $0.id == activeSessionId } }
        set {
            if let newValue, let idx = sessions.firstIndex(where: { $0.id == newValue.id }) {
                sessions[idx] = newValue
            }
        }
    }

    // MARK: - Persistence paths

    private var stateDirectory: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ClawStudio", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var sessionsFile: URL { stateDirectory.appendingPathComponent("sessions.json") }
    private var agentsFile: URL { stateDirectory.appendingPathComponent("agents.json") }

    init() {
        loadPersistedState()
    }

    // MARK: - Persistence

    private func loadPersistedState() {
        // Load sessions
        if let data = try? Data(contentsOf: sessionsFile),
           let decoded = try? JSONDecoder().decode([AgentSession].self, from: data) {
            sessions = decoded
            activeSessionId = decoded.first?.id
        }

        // Load agents
        if let data = try? Data(contentsOf: agentsFile),
           let decoded = try? JSONDecoder().decode([Agent].self, from: data) {
            agents = decoded
        }

        // Ensure defaults if empty
        if sessions.isEmpty {
            let defaultSession = AgentSession(name: "Welcome")
            sessions = [defaultSession]
            activeSessionId = defaultSession.id
        }

        if agents.isEmpty {
            agents = Self.defaultAgents
        }

        apiKeys = OpenClawBridge.knownProviders.map { provider in
            APIKeyEntry(service: provider.name, keyName: provider.envKey)
        }
    }

    func saveState() {
        // Save sessions
        if let data = try? JSONEncoder().encode(sessions) {
            try? data.write(to: sessionsFile, options: .atomic)
        }
        // Save agents
        if let data = try? JSONEncoder().encode(agents) {
            try? data.write(to: agentsFile, options: .atomic)
        }
    }

    private func autoSaveIfEnabled() {
        if preferences.autoSave {
            saveState()
        }
    }

    static var defaultAgents: [Agent] {
        // Read the actual default model from OpenClaw config
        let configPath = "\(NSHomeDirectory())/.openclaw/openclaw.json"
        var defaultModel = "openrouter/anthropic/claude-haiku-4.5"
        if let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
           let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let agent = config["agent"] as? [String: Any],
           let model = agent["model"] as? String {
            defaultModel = model
        }

        return [
            Agent(name: "General Assistant", role: "General Purpose", description: "A versatile assistant for everyday tasks", model: defaultModel, icon: "sparkles"),
            Agent(name: "Code Reviewer", role: "Code Review", description: "Specialized in reviewing code and suggesting improvements", model: defaultModel, color: "purple", icon: "chevron.left.forwardslash.chevron.right"),
            Agent(name: "Research Agent", role: "Research", description: "Gathers and synthesizes information from multiple sources", model: defaultModel, color: "green", icon: "magnifyingglass"),
            Agent(name: "DevOps Monitor", role: "Infrastructure", description: "Monitors system health and assists with deployment", model: defaultModel, color: "orange", icon: "server.rack"),
        ]
    }

    // MARK: - Session Management

    func createSession(name: String, agentId: UUID? = nil) {
        let session = AgentSession(name: name, agentId: agentId)
        sessions.append(session)
        activeSessionId = session.id
        autoSaveIfEnabled()
    }

    func deleteSession(_ id: UUID) {
        sessions.removeAll { $0.id == id }
        if activeSessionId == id {
            activeSessionId = sessions.first?.id
        }
        autoSaveIfEnabled()
    }

    func duplicateSession(_ id: UUID) {
        guard let session = sessions.first(where: { $0.id == id }) else { return }
        var copy = session
        copy = AgentSession(
            name: "\(session.name) (Copy)",
            agentId: session.agentId,
            messages: session.messages,
            status: .idle,
            tokenUsage: session.tokenUsage,
            workspacePath: session.workspacePath
        )
        sessions.append(copy)
        activeSessionId = copy.id
        autoSaveIfEnabled()
    }

    func clearSession(_ id: UUID) {
        guard let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[idx].messages.removeAll()
        sessions[idx].status = .idle
        sessions[idx].updatedAt = Date()
        autoSaveIfEnabled()
    }

    func renameSession(_ id: UUID, newName: String) {
        guard let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[idx].name = newName
        autoSaveIfEnabled()
    }

    // MARK: - Initial Load

    func initialLoad() async {
        isLoading = true
        await bridge.refreshAll()
        isLoading = false
    }

    // MARK: - Chat

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

        await bridge.sendMessage(content, thinkingLevel: preferences.thinkingLevel) { @MainActor [weak self] output in
            guard let self else { return }
            let updatedMessage = ChatMessage(id: assistantId, role: .assistant, content: output, isStreaming: false)
            if var session = self.activeSession {
                if let idx = session.messages.firstIndex(where: { $0.id == assistantId }) {
                    session.messages[idx] = updatedMessage
                }
                session.status = .idle
                session.updatedAt = Date()
                self.activeSession = session
                self.autoSaveIfEnabled()
            }
        }
    }
}
