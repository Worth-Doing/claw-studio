import Foundation
import SwiftUI

// MARK: - Message

enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system
    case tool
}

struct ChatMessage: Identifiable, Codable, Sendable {
    let id: UUID
    var role: MessageRole
    var content: String
    var timestamp: Date
    var isThinking: Bool
    var toolCalls: [ToolCall]
    var isStreaming: Bool

    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        isThinking: Bool = false,
        toolCalls: [ToolCall] = [],
        isStreaming: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isThinking = isThinking
        self.toolCalls = toolCalls
        self.isStreaming = isStreaming
    }
}

// MARK: - Tool Call

struct ToolCall: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    var arguments: String
    var result: String?
    var status: ToolCallStatus

    init(id: UUID = UUID(), name: String, arguments: String, result: String? = nil, status: ToolCallStatus = .pending) {
        self.id = id
        self.name = name
        self.arguments = arguments
        self.result = result
        self.status = status
    }
}

enum ToolCallStatus: String, Codable, Sendable {
    case pending
    case running
    case completed
    case failed
}

// MARK: - Session

struct AgentSession: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    var agentId: UUID?
    var messages: [ChatMessage]
    var createdAt: Date
    var updatedAt: Date
    var status: SessionStatus
    var tokenUsage: TokenUsage
    var workspacePath: String

    init(
        id: UUID = UUID(),
        name: String = "New Session",
        agentId: UUID? = nil,
        messages: [ChatMessage] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        status: SessionStatus = .idle,
        tokenUsage: TokenUsage = TokenUsage(),
        workspacePath: String = "~/.openclaw/workspace"
    ) {
        self.id = id
        self.name = name
        self.agentId = agentId
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.status = status
        self.tokenUsage = tokenUsage
        self.workspacePath = workspacePath
    }
}

enum SessionStatus: String, Codable, Sendable {
    case idle
    case running
    case paused
    case completed
    case error
}

// MARK: - Token Usage

struct TokenUsage: Codable, Sendable {
    var inputTokens: Int
    var outputTokens: Int
    var totalCost: Double

    init(inputTokens: Int = 0, outputTokens: Int = 0, totalCost: Double = 0.0) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalCost = totalCost
    }

    var totalTokens: Int { inputTokens + outputTokens }
}

// MARK: - Agent

struct Agent: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    var role: String
    var description: String
    var model: String
    var soulMD: String
    var agentsMD: String
    var skills: [String]
    var isActive: Bool
    var color: String
    var icon: String

    init(
        id: UUID = UUID(),
        name: String = "Agent",
        role: String = "General Assistant",
        description: String = "",
        model: String = "anthropic/claude-sonnet-4-6",
        soulMD: String = "",
        agentsMD: String = "",
        skills: [String] = [],
        isActive: Bool = true,
        color: String = "blue",
        icon: String = "cpu"
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.description = description
        self.model = model
        self.soulMD = soulMD
        self.agentsMD = agentsMD
        self.skills = skills
        self.isActive = isActive
        self.color = color
        self.icon = icon
    }
}

// MARK: - Skill

struct Skill: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    var description: String
    var category: SkillCategory
    var isEnabled: Bool
    var configPath: String
    var version: String

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        category: SkillCategory = .general,
        isEnabled: Bool = false,
        configPath: String = "",
        version: String = "1.0"
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.isEnabled = isEnabled
        self.configPath = configPath
        self.version = version
    }
}

enum SkillCategory: String, Codable, CaseIterable, Sendable {
    case general = "General"
    case development = "Development"
    case research = "Research"
    case communication = "Communication"
    case filesystem = "File System"
    case web = "Web"
    case automation = "Automation"
}

// MARK: - Memory Entry

struct MemoryEntry: Identifiable, Codable, Sendable {
    let id: UUID
    var type: MemoryType
    var content: String
    var source: String
    var createdAt: Date
    var tags: [String]

    init(
        id: UUID = UUID(),
        type: MemoryType = .shortTerm,
        content: String,
        source: String = "",
        createdAt: Date = Date(),
        tags: [String] = []
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.source = source
        self.createdAt = createdAt
        self.tags = tags
    }
}

enum MemoryType: String, Codable, CaseIterable, Sendable {
    case shortTerm = "Short-Term"
    case longTerm = "Long-Term"
    case episodic = "Episodic"
}

// MARK: - File System Node

struct FileNode: Identifiable, Sendable {
    let id: UUID
    var name: String
    var path: String
    var isDirectory: Bool
    var children: [FileNode]
    var modifiedAt: Date?
    var size: Int64?

    init(
        id: UUID = UUID(),
        name: String,
        path: String,
        isDirectory: Bool = false,
        children: [FileNode] = [],
        modifiedAt: Date? = nil,
        size: Int64? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.children = children
        self.modifiedAt = modifiedAt
        self.size = size
    }
}

// MARK: - API Key

struct APIKeyEntry: Identifiable, Codable, Sendable {
    let id: UUID
    var service: String
    var keyName: String
    var maskedValue: String
    var isConfigured: Bool

    init(id: UUID = UUID(), service: String, keyName: String, maskedValue: String = "", isConfigured: Bool = false) {
        self.id = id
        self.service = service
        self.keyName = keyName
        self.maskedValue = maskedValue
        self.isConfigured = isConfigured
    }
}

// MARK: - Agent Pipeline

struct AgentPipeline: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    var nodes: [PipelineNode]
    var edges: [PipelineEdge]

    init(id: UUID = UUID(), name: String = "New Pipeline", nodes: [PipelineNode] = [], edges: [PipelineEdge] = []) {
        self.id = id
        self.name = name
        self.nodes = nodes
        self.edges = edges
    }
}

struct PipelineNode: Identifiable, Codable, Sendable {
    let id: UUID
    var agentId: UUID
    var position: CGPoint
    var label: String

    init(id: UUID = UUID(), agentId: UUID, position: CGPoint = .zero, label: String = "") {
        self.id = id
        self.agentId = agentId
        self.position = position
        self.label = label
    }

    enum CodingKeys: String, CodingKey {
        case id, agentId, label, x, y
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        agentId = try container.decode(UUID.self, forKey: .agentId)
        label = try container.decode(String.self, forKey: .label)
        let x = try container.decode(CGFloat.self, forKey: .x)
        let y = try container.decode(CGFloat.self, forKey: .y)
        position = CGPoint(x: x, y: y)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(agentId, forKey: .agentId)
        try container.encode(label, forKey: .label)
        try container.encode(position.x, forKey: .x)
        try container.encode(position.y, forKey: .y)
    }
}

struct PipelineEdge: Identifiable, Codable, Sendable {
    let id: UUID
    var fromNodeId: UUID
    var toNodeId: UUID
    var label: String

    init(id: UUID = UUID(), fromNodeId: UUID, toNodeId: UUID, label: String = "") {
        self.id = id
        self.fromNodeId = fromNodeId
        self.toNodeId = toNodeId
        self.label = label
    }
}

// MARK: - Cost Tracking

struct CostRecord: Identifiable, Codable, Sendable {
    let id: UUID
    var agentName: String
    var model: String
    var inputTokens: Int
    var outputTokens: Int
    var cost: Double
    var timestamp: Date

    init(
        id: UUID = UUID(),
        agentName: String,
        model: String,
        inputTokens: Int,
        outputTokens: Int,
        cost: Double,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.agentName = agentName
        self.model = model
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cost = cost
        self.timestamp = timestamp
    }
}
