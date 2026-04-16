import Foundation
import SwiftUI

// MARK: - JSON Response Models

struct OpenClawModelEntry: Codable, Identifiable, Sendable {
    var id: String { key }
    let key: String
    let name: String
    let input: String?
    let contextWindow: Int?
    let local: Bool?
    let available: Bool?
    let tags: [String]?
    let missing: Bool?

    var provider: String {
        let parts = key.split(separator: "/", maxSplits: 1)
        return parts.count > 1 ? String(parts[0]) : "unknown"
    }

    var isDefault: Bool {
        tags?.contains("default") ?? false
    }
}

struct OpenClawModelsResponse: Codable, Sendable {
    let count: Int
    let models: [OpenClawModelEntry]
}

struct OpenClawSkillEntry: Identifiable, Sendable {
    var id: String { name }
    let status: String
    let icon: String
    let name: String
    let description: String
    let source: String

    var isReady: Bool { status.contains("ready") }
    var needsSetup: Bool { status.contains("needs setup") }
}

struct OpenClawChannelEntry: Identifiable, Sendable {
    var id: String { name }
    let name: String
    let enabled: Bool
    let state: String
    let detail: String
}

struct ProviderAuthEntry: Identifiable, Sendable {
    var id: String { provider }
    let provider: String
    let isConfigured: Bool
    let keySource: String
}

struct GatewayStatus: Sendable {
    var isReachable: Bool = false
    var address: String = "ws://127.0.0.1:18789"
    var serviceInstalled: Bool = false
    var agentCount: Int = 0
    var sessionCount: Int = 0
    var memoryStatus: String = "unknown"
    var securityIssues: [String] = []
    var rawOutput: String = ""
}

// MARK: - OpenClaw Engine Bridge

@MainActor
final class OpenClawBridge: ObservableObject {
    @Published var isRunning = false
    @Published var lastOutput = ""
    @Published var engineVersion = "Unknown"
    @Published var isEngineAvailable = false

    @Published var allModels: [OpenClawModelEntry] = []
    @Published var configuredModels: [OpenClawModelEntry] = []
    @Published var skills: [OpenClawSkillEntry] = []
    @Published var channels: [OpenClawChannelEntry] = []
    @Published var providers: [ProviderAuthEntry] = []
    @Published var gatewayStatus = GatewayStatus()
    @Published var configFilePath: String = "~/.openclaw/openclaw.json"
    @Published var currentConfig: [String: Any] = [:]
    @Published var statusOutput: String = ""

    private var process: Process?

    static let knownProviders: [(name: String, envKey: String, docURL: String)] = [
        ("Anthropic", "ANTHROPIC_API_KEY", "https://console.anthropic.com/"),
        ("OpenAI", "OPENAI_API_KEY", "https://platform.openai.com/api-keys"),
        ("Google AI (Gemini)", "GOOGLE_API_KEY", "https://aistudio.google.com/apikey"),
        ("OpenRouter", "OPENROUTER_API_KEY", "https://openrouter.ai/keys"),
        ("Groq", "GROQ_API_KEY", "https://console.groq.com/keys"),
        ("Mistral", "MISTRAL_API_KEY", "https://console.mistral.ai/api-keys"),
        ("Perplexity", "PERPLEXITY_API_KEY", "https://www.perplexity.ai/settings/api"),
        ("Together AI", "TOGETHER_API_KEY", "https://api.together.ai/settings/api-keys"),
        ("Fireworks AI", "FIREWORKS_API_KEY", "https://fireworks.ai/account/api-keys"),
        ("DeepSeek", "DEEPSEEK_API_KEY", "https://platform.deepseek.com/api_keys"),
        ("xAI (Grok)", "XAI_API_KEY", "https://console.x.ai/"),
        ("Cohere", "COHERE_API_KEY", "https://dashboard.cohere.com/api-keys"),
        ("GitHub Copilot", "GITHUB_TOKEN", "https://github.com/settings/tokens"),
        ("Amazon Bedrock", "AWS_ACCESS_KEY_ID", "https://console.aws.amazon.com/"),
        ("Azure OpenAI", "AZURE_OPENAI_API_KEY", "https://portal.azure.com/"),
    ]

    static let knownChannels: [(name: String, icon: String, description: String)] = [
        ("whatsapp", "phone.fill", "WhatsApp Web messaging"),
        ("telegram", "paperplane.fill", "Telegram Bot integration"),
        ("discord", "gamecontroller.fill", "Discord Bot integration"),
        ("slack", "number", "Slack workspace integration"),
        ("signal", "lock.shield.fill", "Signal messenger integration"),
        ("imessage", "message.fill", "iMessage / SMS integration"),
        ("bluebubbles", "bubble.left.and.bubble.right.fill", "BlueBubbles iMessage bridge"),
        ("irc", "chevron.left.forwardslash.chevron.right", "IRC client integration"),
        ("teams", "person.3.fill", "Microsoft Teams integration"),
        ("matrix", "square.grid.3x3.fill", "Matrix / Element integration"),
        ("google-chat", "bubble.left.fill", "Google Chat integration"),
        ("feishu", "ellipsis.message.fill", "Feishu / Lark integration"),
        ("line", "ellipsis.bubble.fill", "LINE messenger integration"),
        ("mattermost", "bubble.left.and.text.bubble.right.fill", "Mattermost integration"),
        ("nextcloud-talk", "cloud.fill", "Nextcloud Talk integration"),
        ("nostr", "antenna.radiowaves.left.and.right", "Nostr protocol integration"),
        ("synology-chat", "externaldrive.fill.badge.wifi", "Synology Chat integration"),
        ("twitch", "play.rectangle.fill", "Twitch chat integration"),
        ("zalo", "globe.asia.australia.fill", "Zalo messenger integration"),
        ("wechat", "ellipsis.message.fill", "WeChat integration"),
        ("qq", "person.2.fill", "QQ messenger integration"),
        ("webchat", "globe", "Web Chat widget"),
    ]

    // MARK: - Engine Check

    func checkEngine() async {
        let result = await runCommand(arguments: ["--version"])
        if let version = result {
            engineVersion = version.trimmingCharacters(in: .whitespacesAndNewlines)
            isEngineAvailable = true
        } else {
            isEngineAvailable = false
        }
    }

    // MARK: - Full Refresh

    func refreshAll() async {
        await checkEngine()
        async let m: () = loadModels()
        async let s: () = loadSkills()
        async let st: () = loadStatus()
        async let cf: () = loadConfigPath()
        async let p: () = loadProviders()
        _ = await (m, s, st, cf, p)
    }

    // MARK: - Models

    func loadModels() async {
        if let json = await runCommand(arguments: ["models", "list", "--all", "--json"]) {
            if let data = json.data(using: .utf8),
               let response = try? JSONDecoder().decode(OpenClawModelsResponse.self, from: data) {
                allModels = response.models
                configuredModels = response.models.filter { $0.available == true }
            }
        }
    }

    func setDefaultModel(_ modelKey: String) async -> Bool {
        let result = await runCommand(arguments: ["models", "set", modelKey])
        return result != nil
    }

    // MARK: - Skills

    func loadSkills() async {
        if let output = await runCommand(arguments: ["skills", "list"]) {
            skills = parseSkillsList(output)
        }
    }

    private func parseSkillsList(_ output: String) -> [OpenClawSkillEntry] {
        var entries: [OpenClawSkillEntry] = []
        let lines = output.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("\u{2502}") && !trimmed.contains("Status") && !trimmed.contains("\u{2500}\u{2500}\u{2500}") else { continue }

            let columns = trimmed.split(separator: "\u{2502}", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            guard columns.count >= 4 else { continue }

            let statusRaw = columns[0]
            let nameField = columns[1]
            let desc = columns[2]
            let source = columns[3]

            let status = statusRaw.contains("ready") ? "ready" : "needs setup"

            var icon = ""
            var name = nameField
            if let firstSpace = nameField.firstIndex(of: " "),
               nameField.startIndex < firstSpace {
                let prefix = String(nameField[nameField.startIndex..<firstSpace])
                if prefix.unicodeScalars.contains(where: { $0.value > 127 }) {
                    icon = prefix
                    name = String(nameField[nameField.index(after: firstSpace)...]).trimmingCharacters(in: .whitespaces)
                }
            }

            entries.append(OpenClawSkillEntry(
                status: status,
                icon: icon,
                name: name,
                description: desc,
                source: source
            ))
        }
        return entries
    }

    // MARK: - Status

    func loadStatus() async {
        if let output = await runCommand(arguments: ["status"]) {
            statusOutput = output
            gatewayStatus = parseStatus(output)
        }
    }

    private func parseStatus(_ output: String) -> GatewayStatus {
        var status = GatewayStatus()
        status.rawOutput = output

        if output.contains("unreachable") {
            status.isReachable = false
        } else if output.contains("ws://") || output.contains("wss://") {
            status.isReachable = true
        }

        if let range = output.range(of: "ws://[^ ]+", options: .regularExpression) {
            status.address = String(output[range])
        }

        status.serviceInstalled = !output.contains("not installed")

        let lines = output.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("CRITICAL") || trimmed.hasPrefix("WARN") {
                status.securityIssues.append(trimmed)
            }
        }

        for line in lines {
            if line.contains("Agents") {
                if let match = line.range(of: "\\d+", options: .regularExpression) {
                    status.agentCount = Int(line[match]) ?? 0
                }
            }
            if line.contains("Sessions") && line.contains("active") {
                if let match = line.range(of: "\\d+", options: .regularExpression) {
                    status.sessionCount = Int(line[match]) ?? 0
                }
            }
            if line.contains("Memory") {
                status.memoryStatus = line.contains("enabled") ? "enabled" : "disabled"
            }
        }

        return status
    }

    // MARK: - Config

    func loadConfigPath() async {
        if let path = await runCommand(arguments: ["config", "file"]) {
            configFilePath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    func getConfigValue(_ path: String) async -> String? {
        return await runCommand(arguments: ["config", "get", path])
    }

    func setConfigValue(_ path: String, value: String) async -> Bool {
        let result = await runCommand(arguments: ["config", "set", path, value])
        return result != nil
    }

    func setEnvVar(_ key: String, value: String) async -> Bool {
        let result = await runCommand(arguments: ["config", "set", "env.vars.\(key)", value])
        return result != nil
    }

    // MARK: - Providers / Auth (parallel loading)

    func loadProviders() async {
        let knownProviders = Self.knownProviders

        // Check env vars locally (fast, no subprocess)
        var envResults: [String: Bool] = [:]
        for provider in knownProviders {
            let envValue = ProcessInfo.processInfo.environment[provider.envKey]
            envResults[provider.name] = envValue != nil && !(envValue?.isEmpty ?? true)
        }

        // Check config for providers not found in env (parallel)
        // Uses static method so no [weak self] issues with @MainActor
        let unconfiguredNames = knownProviders.filter { envResults[$0.name] != true }

        var configResults: [String: Bool] = [:]
        await withTaskGroup(of: (String, Bool).self) { group in
            for provider in unconfiguredNames {
                group.addTask {
                    let (output, exitCode) = await OpenClawBridge.runCommandWithStatus(
                        arguments: ["config", "get", "env.vars.\(provider.envKey)"]
                    )
                    // Only consider configured if command succeeded (exit 0) AND output is a real value
                    guard exitCode == 0, let value = output, !value.isEmpty else {
                        return (provider.name, false)
                    }
                    // Reject error messages that slip through
                    let lower = value.lowercased()
                    if lower.contains("not found") || lower.contains("error") || lower.contains("config path") {
                        return (provider.name, false)
                    }
                    return (provider.name, true)
                }
            }
            for await (name, hasConfig) in group {
                configResults[name] = hasConfig
            }
        }

        var entries: [ProviderAuthEntry] = []
        for provider in knownProviders {
            let hasEnv = envResults[provider.name] ?? false
            let hasConfig = configResults[provider.name] ?? false
            let isConfigured = hasEnv || hasConfig
            let source = hasEnv ? "env" : (hasConfig ? "config" : "none")

            entries.append(ProviderAuthEntry(
                provider: provider.name,
                isConfigured: isConfigured,
                keySource: source
            ))
        }

        providers = entries
    }

    func configureAPIKey(envKey: String, value: String) async -> Bool {
        return await setEnvVar(envKey, value: value)
    }

    // MARK: - Gateway

    func startGateway() async -> String {
        return await runCommand(arguments: ["gateway", "--port", "18789"]) ?? "Failed to start gateway"
    }

    func runOnboard() async -> String {
        return await runCommand(arguments: ["onboard"]) ?? "Onboarding failed"
    }

    func runConfigure() async -> String {
        return await runCommand(arguments: ["configure"]) ?? "Configuration failed"
    }

    // MARK: - Doctor

    func runDoctor() async -> String {
        return await runCommand(arguments: ["doctor"]) ?? "Doctor check failed"
    }

    func runDoctor(onOutput: @escaping @MainActor @Sendable (String) -> Void) async {
        let result = await runCommand(arguments: ["doctor"])
        if let output = result {
            await MainActor.run {
                onOutput(output)
            }
        }
    }

    // MARK: - Agent Message (direct API call)

    /// Read the OpenClaw config to find the API key and model
    private static func readOpenClawConfig() -> (apiKey: String, model: String, provider: String)? {
        let configPath = "\(NSHomeDirectory())/.openclaw/openclaw.json"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
              let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // Get default model
        let agentConfig = config["agent"] as? [String: Any]
        let modelKey = (agentConfig?["model"] as? String) ?? "openrouter/anthropic/claude-3.5-haiku"

        // Parse provider from model key (e.g. "openrouter/anthropic/claude-3.5-haiku")
        let parts = modelKey.split(separator: "/", maxSplits: 1)
        let provider = parts.count > 1 ? String(parts[0]) : "openrouter"
        let modelId = parts.count > 1 ? String(parts[1]) : modelKey

        // Find the right API key
        let envVars = (config["env"] as? [String: Any])?["vars"] as? [String: String] ?? [:]

        let keyMapping: [String: String] = [
            "openrouter": "OPENROUTER_API_KEY",
            "anthropic": "ANTHROPIC_API_KEY",
            "openai": "OPENAI_API_KEY",
            "google": "GOOGLE_API_KEY",
            "groq": "GROQ_API_KEY",
            "mistral": "MISTRAL_API_KEY",
            "deepseek": "DEEPSEEK_API_KEY",
            "together": "TOGETHER_API_KEY",
            "fireworks": "FIREWORKS_API_KEY",
            "xai": "XAI_API_KEY",
            "cohere": "COHERE_API_KEY",
            "perplexity": "PERPLEXITY_API_KEY",
        ]

        let envKeyName = keyMapping[provider] ?? "OPENROUTER_API_KEY"

        // Check config first, then environment
        let apiKey = envVars[envKeyName]
            ?? ProcessInfo.processInfo.environment[envKeyName]
            ?? ""

        guard !apiKey.isEmpty else { return nil }

        return (apiKey: apiKey, model: modelId, provider: provider)
    }

    /// Resolve the API base URL for a provider
    private static func apiBaseURL(for provider: String) -> String {
        switch provider {
        case "openrouter": return "https://openrouter.ai/api/v1"
        case "anthropic": return "https://api.anthropic.com/v1"
        case "openai", "codex": return "https://api.openai.com/v1"
        case "groq": return "https://api.groq.com/openai/v1"
        case "mistral": return "https://api.mistral.ai/v1"
        case "deepseek": return "https://api.deepseek.com/v1"
        case "together": return "https://api.together.xyz/v1"
        case "fireworks": return "https://api.fireworks.ai/inference/v1"
        case "xai": return "https://api.x.ai/v1"
        case "cohere": return "https://api.cohere.ai/v1"
        case "perplexity": return "https://api.perplexity.ai"
        default: return "https://openrouter.ai/api/v1"
        }
    }

    /// System prompt that defines the agent's identity
    private static let systemPrompt = """
    You are a helpful AI assistant running inside Claw Studio, an Agent Operating System for macOS. \
    You are powered by OpenClaw and can help users with a wide range of tasks including coding, analysis, \
    research, writing, problem-solving, and general questions. \
    Be concise, direct, and helpful. Use markdown formatting when appropriate. \
    You are having a conversation — remember context from earlier messages.
    """

    func sendMessage(
        _ message: String,
        history: [ChatMessage] = [],
        modelOverride: String? = nil,
        thinkingLevel: String = "medium",
        onOutput: @escaping @MainActor @Sendable (String) -> Void
    ) async {
        isRunning = true
        defer { isRunning = false }

        guard let config = Self.readOpenClawConfig() else {
            await MainActor.run {
                onOutput("Error: No API key configured. Go to API Keys to set one up, then set a default model in the Models tab.")
            }
            return
        }

        // Use model override from app preferences if provided
        let finalModel: String
        let finalProvider: String
        if let override = modelOverride, !override.isEmpty {
            let parts = override.split(separator: "/", maxSplits: 1)
            finalProvider = parts.count > 1 ? String(parts[0]) : config.provider
            finalModel = parts.count > 1 ? String(parts[1]) : override
        } else {
            finalModel = config.model
            finalProvider = config.provider
        }

        let baseURL = Self.apiBaseURL(for: finalProvider)

        // Build messages array with system prompt + conversation history
        var messages: [[String: String]] = [
            ["role": "system", "content": Self.systemPrompt]
        ]

        // Add conversation history (last 20 messages for context window)
        for msg in history.suffix(20) {
            let role: String
            switch msg.role {
            case .user: role = "user"
            case .assistant: role = "assistant"
            case .system: role = "system"
            case .tool: continue
            }
            if !msg.content.isEmpty && !msg.isStreaming {
                messages.append(["role": role, "content": msg.content])
            }
        }

        // Add the current message
        messages.append(["role": "user", "content": message])

        let requestBody: [String: Any] = [
            "model": finalModel,
            "messages": messages,
            "max_tokens": 4096
        ]

        guard let url = URL(string: "\(baseURL)/chat/completions"),
              let bodyData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            await MainActor.run {
                onOutput("Error: Failed to build API request.")
            }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120

        if finalProvider == "openrouter" {
            request.setValue("ClawStudio/2.0", forHTTPHeaderField: "HTTP-Referer")
            request.setValue("Claw Studio", forHTTPHeaderField: "X-Title")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                await MainActor.run { onOutput("Error: Invalid response from API.") }
                return
            }

            if httpResponse.statusCode != 200 {
                let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
                await MainActor.run {
                    onOutput("Error (\(httpResponse.statusCode)): \(errorText)")
                }
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let messageObj = firstChoice["message"] as? [String: Any],
               let content = messageObj["content"] as? String {
                await MainActor.run {
                    onOutput(content)
                    self.lastOutput = content
                }
            } else {
                let raw = String(data: data, encoding: .utf8) ?? "No response"
                await MainActor.run { onOutput("Error parsing response: \(raw.prefix(500))") }
            }
        } catch {
            await MainActor.run {
                onOutput("Error: \(error.localizedDescription)")
            }
        }
    }

    private var urlSessionTask: URLSessionTask?

    func stopCurrentProcess() {
        urlSessionTask?.cancel()
        process?.terminate()
        process = nil
        isRunning = false
    }

    // MARK: - Skills Commands

    func installSkill(_ slug: String) async -> String {
        return await runCommand(arguments: ["skills", "install", slug]) ?? "Installation failed"
    }

    func searchSkills(_ query: String) async -> String {
        return await runCommand(arguments: ["skills", "search", query]) ?? "Search failed"
    }

    // MARK: - Channels Commands

    func addChannel(_ channel: String, token: String) async -> String {
        return await runCommand(arguments: ["channels", "add", "--channel", channel, "--token", token]) ?? "Failed to add channel"
    }

    func removeChannel(_ channel: String) async -> String {
        return await runCommand(arguments: ["channels", "remove", channel]) ?? "Failed to remove channel"
    }

    // MARK: - Private (non-blocking)

    private func runCommand(arguments: [String]) async -> String? {
        let path = CLIPathResolver.openclawPath

        return await Task.detached { () -> String? in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments

            let pipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = pipe
            process.standardError = errPipe

            process.environment = CLIPathResolver.processEnvironment()

            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                // Only return stdout for successful commands
                if process.terminationStatus == 0,
                   let output = String(data: data, encoding: .utf8), !output.isEmpty {
                    return output
                }
                // For failed commands, still return output for display purposes
                // but callers should check context
                if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                    return output
                }
                if let errOutput = String(data: errData, encoding: .utf8), !errOutput.isEmpty {
                    return errOutput
                }
                return nil
            } catch {
                return nil
            }
        }.value
    }

    /// Run a command and return (output, exitCode) — used for config checks
    private static func runCommandWithStatus(arguments: [String]) async -> (String?, Int32) {
        let path = CLIPathResolver.openclawPath

        return await Task.detached { () -> (String?, Int32) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments

            let pipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = pipe
            process.standardError = errPipe

            process.environment = CLIPathResolver.processEnvironment()

            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                return (output, process.terminationStatus)
            } catch {
                return (nil, -1)
            }
        }.value
    }
}

// MARK: - Session File Manager

final class SessionFileManager {
    static let shared = SessionFileManager()
    private let baseDir: String

    private init() {
        baseDir = "\(NSHomeDirectory())/.openclaw/workspace"
    }

    var sessionsDirectory: URL {
        URL(fileURLWithPath: "\(baseDir)/sessions")
    }

    func createSessionDirectory(sessionId: UUID) throws -> URL {
        let sessionDir = sessionsDirectory.appendingPathComponent(sessionId.uuidString)
        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        return sessionDir
    }

    func saveConfig(_ config: [String: Any], for sessionId: UUID) throws {
        let sessionDir = sessionsDirectory.appendingPathComponent(sessionId.uuidString)
        let configURL = sessionDir.appendingPathComponent("config.json")
        let data = try JSONSerialization.data(withJSONObject: config, options: .prettyPrinted)
        try data.write(to: configURL)
    }

    func loadWorkspaceFiles(at path: String) -> [FileNode] {
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        return scanDirectory(url, depth: 0, maxDepth: 3)
    }

    private func scanDirectory(_ url: URL, depth: Int, maxDepth: Int) -> [FileNode] {
        guard depth < maxDepth else { return [] }
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return contents.compactMap { itemURL in
            let resourceValues = try? itemURL.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey])
            let isDir = resourceValues?.isDirectory ?? false
            let modDate = resourceValues?.contentModificationDate
            let size = Int64(resourceValues?.fileSize ?? 0)

            return FileNode(
                name: itemURL.lastPathComponent,
                path: itemURL.path,
                isDirectory: isDir,
                children: isDir ? scanDirectory(itemURL, depth: depth + 1, maxDepth: maxDepth) : [],
                modifiedAt: modDate,
                size: size
            )
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func readMemoryFile() -> String {
        let memoryPath = "\(baseDir)/MEMORY.md"
        return (try? String(contentsOfFile: memoryPath, encoding: .utf8)) ?? "# Memory\n\nNo memory entries yet."
    }

    func writeMemoryFile(_ content: String) throws {
        let memoryPath = "\(baseDir)/MEMORY.md"
        try content.write(toFile: memoryPath, atomically: true, encoding: .utf8)
    }
}
