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
    let status: String       // "ready", "needs setup"
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
    let keySource: String // "env", "config", "none"
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

    // Real data from OpenClaw
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
    private let openclawPath: String

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

    init() {
        let possiblePaths = [
            "/opt/homebrew/bin/openclaw",
            "/usr/local/bin/openclaw",
            "\(NSHomeDirectory())/.npm-global/bin/openclaw"
        ]
        self.openclawPath = possiblePaths.first { FileManager.default.fileExists(atPath: $0) } ?? "openclaw"
    }

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
            // Parse table rows: │ Status │ Icon+Name │ Description │ Source │
            guard trimmed.hasPrefix("│") && !trimmed.contains("Status") && !trimmed.contains("───") else { continue }

            let columns = trimmed.split(separator: "│", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            guard columns.count >= 4 else { continue }

            let statusRaw = columns[0]
            let nameField = columns[1]
            let desc = columns[2]
            let source = columns[3]

            let status = statusRaw.contains("ready") ? "ready" : "needs setup"

            // Extract icon (emoji) and name
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

        // Parse gateway address
        if let range = output.range(of: "ws://[^ ]+", options: .regularExpression) {
            status.address = String(output[range])
        }

        // Parse service status
        status.serviceInstalled = !output.contains("not installed")

        // Parse security issues
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("CRITICAL") || trimmed.hasPrefix("WARN") {
                status.securityIssues.append(trimmed)
            }
        }

        // Parse session/agent counts
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
                if line.contains("enabled") {
                    status.memoryStatus = "enabled"
                } else {
                    status.memoryStatus = "disabled"
                }
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

    // MARK: - Providers / Auth

    func loadProviders() async {
        var entries: [ProviderAuthEntry] = []
        for provider in Self.knownProviders {
            // Check environment variable first
            let envValue = ProcessInfo.processInfo.environment[provider.envKey]
            let hasEnv = envValue != nil && !(envValue?.isEmpty ?? true)

            // Then check openclaw config for the key
            var hasConfig = false
            if !hasEnv {
                if let configVal = await runCommand(arguments: ["config", "get", "env.vars.\(provider.envKey)"]) {
                    let trimmed = configVal.trimmingCharacters(in: .whitespacesAndNewlines)
                    hasConfig = !trimmed.isEmpty && !trimmed.contains("not found") && !trimmed.contains("Config path")
                }
            }

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

    func runDoctor(onOutput: @escaping @Sendable (String) -> Void) async {
        let result = await runCommand(arguments: ["doctor"])
        if let output = result {
            await MainActor.run {
                onOutput(output)
            }
        }
    }

    // MARK: - Agent Message

    func sendMessage(_ message: String, thinkingLevel: String = "medium", onOutput: @escaping @Sendable (String) -> Void) async {
        isRunning = true
        defer { isRunning = false }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: openclawPath)
        process.arguments = ["agent", "--message", message, "--thinking", thinkingLevel]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "dumb"
        env["NO_COLOR"] = "1"
        process.environment = env

        do {
            try process.run()
            self.process = process

            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let cleaned = output.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty {
                    await MainActor.run {
                        onOutput(cleaned)
                        self.lastOutput = cleaned
                    }
                }
            }

            process.waitUntilExit()
        } catch {
            await MainActor.run {
                onOutput("Error: \(error.localizedDescription)")
            }
        }
    }

    func stopCurrentProcess() {
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

    // MARK: - Private

    private func runCommand(arguments: [String]) async -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: openclawPath)
        process.arguments = arguments

        let pipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errPipe

        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "dumb"
        env["NO_COLOR"] = "1"
        process.environment = env

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

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
