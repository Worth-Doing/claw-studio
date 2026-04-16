import SwiftUI

struct APIKeysView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var runner = CommandRunner()
    @State private var selectedProvider: Int?
    @State private var apiKeyInput = ""
    @State private var isSaving = false
    @State private var saveStatus: SaveStatus?
    @State private var searchText = ""

    enum SaveStatus {
        case success(String)
        case error(String)
    }

    var filteredProviders: [(offset: Int, element: (name: String, envKey: String, docURL: String))] {
        let indexed = Array(OpenClawBridge.knownProviders.enumerated())
        if searchText.isEmpty { return indexed }
        return indexed.filter { $0.element.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider().opacity(0.3)

            HSplitView {
                providerListPanel
                    .frame(minWidth: 340, idealWidth: 400, maxWidth: 500)

                if let idx = selectedProvider {
                    providerDetailPanel(providerIndex: idx)
                } else {
                    emptyDetailState
                }
            }
        }
        .task {
            await appState.bridge.loadProviders()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: "key.fill")
                .font(.system(size: 18))
                .foregroundStyle(GlassTheme.accentWarning)

            VStack(alignment: .leading, spacing: 2) {
                Text("API Keys & Authentication")
                    .font(.system(size: 18, weight: .bold))
                Text("Configure provider credentials — saved directly to OpenClaw")
                    .font(.system(size: 12))
                    .foregroundStyle(GlassTheme.textTertiary)
            }

            Spacer()

            let configuredCount = appState.bridge.providers.filter { $0.isConfigured }.count
            let totalCount = OpenClawBridge.knownProviders.count

            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text("\(configuredCount)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(GlassTheme.accentSuccess)
                    Text("Configured")
                        .font(.system(size: 9))
                        .foregroundStyle(GlassTheme.textTertiary)
                }
                VStack(spacing: 2) {
                    Text("\(totalCount - configuredCount)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(GlassTheme.textTertiary)
                    Text("Pending")
                        .font(.system(size: 9))
                        .foregroundStyle(GlassTheme.textTertiary)
                }
            }

            Button {
                Task { await appState.bridge.loadProviders() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
            }
            .glassButton()
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(GlassTheme.headerBackground)
    }

    // MARK: - Provider List

    private var providerListPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(GlassTheme.textTertiary)
                TextField("Search providers...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(10)
            .background(GlassTheme.headerBackground)

            Divider().opacity(0.3)

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(filteredProviders, id: \.offset) { index, provider in
                        let authEntry = appState.bridge.providers.first { $0.provider == provider.name }
                        let isConfigured = authEntry?.isConfigured ?? false

                        ProviderListCard(
                            name: provider.name,
                            envKey: provider.envKey,
                            isConfigured: isConfigured,
                            keySource: authEntry?.keySource ?? "none",
                            isSelected: selectedProvider == index
                        ) {
                            selectedProvider = index
                            apiKeyInput = ""
                            saveStatus = nil
                        }
                    }
                }
                .padding(12)
            }
        }
        .background(GlassTheme.sidebarBackground)
    }

    // MARK: - Provider Detail

    private func providerDetailPanel(providerIndex: Int) -> some View {
        let provider = OpenClawBridge.knownProviders[providerIndex]
        let authEntry = appState.bridge.providers.first { $0.provider == provider.name }
        let isConfigured = authEntry?.isConfigured ?? false

        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Provider header
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(isConfigured
                                ? GlassTheme.accentSuccess.opacity(0.15)
                                : GlassTheme.accentWarning.opacity(0.15))
                            .frame(width: 60, height: 60)

                        Image(systemName: isConfigured ? "checkmark.shield.fill" : "key")
                            .font(.system(size: 26))
                            .foregroundStyle(isConfigured ? GlassTheme.accentSuccess : GlassTheme.accentWarning)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(provider.name)
                            .font(.system(size: 22, weight: .bold))

                        HStack(spacing: 8) {
                            GlassBadge(
                                text: isConfigured ? "Configured" : "Not Configured",
                                color: isConfigured ? GlassTheme.accentSuccess : GlassTheme.accentWarning
                            )
                            if isConfigured, let source = authEntry?.keySource {
                                GlassBadge(text: "via \(source)", color: GlassTheme.accentPrimary)
                            }
                        }
                    }

                    Spacer()
                }

                Divider().opacity(0.3)

                // API Key Input
                VStack(alignment: .leading, spacing: 12) {
                    Text("Enter API Key")
                        .font(.system(size: 14, weight: .semibold))

                    Text("Your key will be securely stored in the OpenClaw configuration file. It never leaves your machine.")
                        .font(.system(size: 12))
                        .foregroundStyle(GlassTheme.textSecondary)

                    SecureField("Paste your \(provider.name) API key here...", text: $apiKeyInput)
                        .glassTextField()
                        .font(.system(size: 14, design: .monospaced))

                    Button {
                        saveKey(provider: provider)
                    } label: {
                        HStack(spacing: 8) {
                            if isSaving {
                                ProgressView().scaleEffect(0.7)
                            } else {
                                Image(systemName: "square.and.arrow.down.fill")
                            }
                            Text(isConfigured ? "Update API Key" : "Save API Key")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .glassButton(isActive: true)
                    .buttonStyle(.plain)
                    .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)

                    // Status feedback
                    if let status = saveStatus {
                        switch status {
                        case .success(let msg):
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(GlassTheme.accentSuccess)
                                Text(msg)
                                    .font(.system(size: 12))
                                    .foregroundStyle(GlassTheme.accentSuccess)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(GlassTheme.accentSuccess.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        case .error(let msg):
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(GlassTheme.accentError)
                                Text(msg)
                                    .font(.system(size: 12))
                                    .foregroundStyle(GlassTheme.accentError)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(GlassTheme.accentError.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    // Command output
                    if runner.currentRecord != nil {
                        LiveTerminalView(record: runner.currentRecord, maxHeight: 120)
                    }
                }

                Divider().opacity(0.3)

                // Auth flow button (interactive login for providers that support it)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Alternative: Provider Login")
                        .font(.system(size: 13, weight: .semibold))

                    Text("Some providers support interactive login flows. Click below to start one.")
                        .font(.system(size: 11))
                        .foregroundStyle(GlassTheme.textTertiary)

                    ActionButtonWithTerminal(
                        title: "Start Auth Flow",
                        icon: "person.badge.key.fill",
                        color: GlassTheme.accentSecondary,
                        arguments: ["models", "auth", "add"],
                        subtitle: "Interactive provider authentication"
                    )
                }

                Divider().opacity(0.3)

                // Get API key button
                VStack(alignment: .leading, spacing: 8) {
                    Text("Get an API Key")
                        .font(.system(size: 13, weight: .semibold))

                    Button {
                        if let url = URL(string: provider.docURL) {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.up.right.square.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(GlassTheme.accentPrimary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Open \(provider.name) Dashboard")
                                    .font(.system(size: 13, weight: .medium))
                                Text("Get or manage your API keys in your browser")
                                    .font(.system(size: 10))
                                    .foregroundStyle(GlassTheme.textTertiary)
                            }

                            Spacer()

                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12))
                                .foregroundStyle(GlassTheme.textTertiary)
                        }
                        .padding(14)
                        .glassCard()
                    }
                    .buttonStyle(.plain)
                }

                // Available models preview
                let providerModels = appState.bridge.allModels.filter {
                    $0.provider.lowercased().hasPrefix(provider.name.lowercased().prefix(4).lowercased())
                }

                if !providerModels.isEmpty {
                    Divider().opacity(0.3)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Available Models")
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            GlassBadge(text: "\(providerModels.count) models", color: GlassTheme.accentPrimary)
                        }

                        ForEach(providerModels.prefix(6)) { model in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(model.available == true ? GlassTheme.accentSuccess : GlassTheme.textTertiary)
                                    .frame(width: 6, height: 6)
                                Text(model.name)
                                    .font(.system(size: 12))
                                Spacer()
                                if let ctx = model.contextWindow {
                                    Text(ctx >= 1000 ? "\(ctx / 1000)K" : "\(ctx)")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(GlassTheme.textTertiary)
                                }
                                if model.isDefault {
                                    GlassBadge(text: "Default", color: GlassTheme.accentWarning)
                                }
                            }
                            .padding(8)
                            .glassCard()
                        }

                        if providerModels.count > 6 {
                            Text("+ \(providerModels.count - 6) more — view in Models tab")
                                .font(.system(size: 11))
                                .foregroundStyle(GlassTheme.textTertiary)
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    private var emptyDetailState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(GlassTheme.accentWarning.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "key.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(GlassTheme.textTertiary)
            }
            Text("Select a provider to configure")
                .font(.system(size: 15, weight: .medium))
            Text("API keys are required to use AI models through OpenClaw.\nSelect a provider from the list to set up authentication.")
                .font(.system(size: 12))
                .foregroundStyle(GlassTheme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Save Logic

    private func saveKey(provider: (name: String, envKey: String, docURL: String)) {
        let key = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }

        isSaving = true
        Task {
            let record = await runner.run(["config", "set", "env.vars.\(provider.envKey)", key])

            if record.status == .success {
                saveStatus = .success("\(provider.name) API key saved successfully!")
                apiKeyInput = ""
                await appState.bridge.loadProviders()
            } else {
                saveStatus = .error("Failed to save. Output: \(record.output.prefix(200))")
            }
            isSaving = false
        }
    }
}

// MARK: - Provider List Card

struct ProviderListCard: View {
    let name: String
    let envKey: String
    let isConfigured: Bool
    let keySource: String
    var isSelected: Bool
    let onTap: () -> Void
    @State private var isHovered = false

    var providerIcon: String {
        switch name.lowercased() {
        case let n where n.contains("anthropic"): return "brain"
        case let n where n.contains("openai"): return "sparkles"
        case let n where n.contains("google"): return "globe"
        case let n where n.contains("openrouter"): return "arrow.triangle.branch"
        case let n where n.contains("groq"): return "bolt"
        case let n where n.contains("mistral"): return "wind"
        case let n where n.contains("perplexity"): return "magnifyingglass"
        case let n where n.contains("together"): return "person.3"
        case let n where n.contains("fireworks"): return "flame"
        case let n where n.contains("deepseek"): return "water.waves"
        case let n where n.contains("xai") || n.contains("grok"): return "xmark.circle"
        case let n where n.contains("cohere"): return "waveform"
        case let n where n.contains("github"): return "chevron.left.forwardslash.chevron.right"
        case let n where n.contains("amazon") || n.contains("bedrock"): return "cloud"
        case let n where n.contains("azure"): return "icloud"
        default: return "key"
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isConfigured
                            ? GlassTheme.accentSuccess.opacity(0.15)
                            : GlassTheme.surfaceSecondary)
                        .frame(width: 36, height: 36)

                    Image(systemName: providerIcon)
                        .font(.system(size: 14))
                        .foregroundStyle(isConfigured ? GlassTheme.accentSuccess : GlassTheme.textTertiary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(GlassTheme.textPrimary)
                    Text(envKey)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(GlassTheme.textTertiary)
                }

                Spacer()

                if isConfigured {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(GlassTheme.accentSuccess)
                } else {
                    Image(systemName: "circle.dashed")
                        .font(.system(size: 16))
                        .foregroundStyle(GlassTheme.textTertiary)
                }
            }
            .padding(12)
            .glassCard(isSelected: isSelected)
            .background(isHovered && !isSelected ? GlassTheme.surfaceHover.opacity(0.5) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
    }
}
