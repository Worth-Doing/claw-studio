import SwiftUI

struct ModelBrowserView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var selectedProvider = "All"
    @State private var showOnlyAvailable = false
    @State private var isLoading = false
    @State private var selectedModelKey: String?
    @State private var setDefaultResult: String?

    var allProviders: [String] {
        let providers = Set(appState.bridge.allModels.map { $0.provider })
        return ["All"] + providers.sorted()
    }

    var filteredModels: [OpenClawModelEntry] {
        appState.bridge.allModels.filter { model in
            let matchesSearch = searchText.isEmpty
                || model.name.localizedCaseInsensitiveContains(searchText)
                || model.key.localizedCaseInsensitiveContains(searchText)
            let matchesProvider = selectedProvider == "All" || model.provider == selectedProvider
            let matchesAvailable = !showOnlyAvailable || (model.available == true)
            return matchesSearch && matchesProvider && matchesAvailable
        }
    }

    var defaultModel: OpenClawModelEntry? {
        appState.bridge.allModels.first { $0.isDefault }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider().opacity(0.3)

            HSplitView {
                // Model list
                modelListPanel
                    .frame(minWidth: 500)

                // Model detail
                if let key = selectedModelKey,
                   let model = appState.bridge.allModels.first(where: { $0.key == key }) {
                    modelDetailPanel(model: model)
                        .frame(minWidth: 320, idealWidth: 380)
                } else {
                    emptyDetailState
                        .frame(minWidth: 320)
                }
            }
        }
        .task {
            if appState.bridge.allModels.isEmpty {
                isLoading = true
                await appState.bridge.loadModels()
                isLoading = false
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: "cube.fill")
                .font(.system(size: 18))
                .foregroundStyle(GlassTheme.accentSecondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Model Browser")
                    .font(.system(size: 18, weight: .bold))
                Text("\(appState.bridge.allModels.count) models from \(Set(appState.bridge.allModels.map { $0.provider }).count) providers")
                    .font(.system(size: 12))
                    .foregroundStyle(GlassTheme.textTertiary)
            }

            Spacer()

            if let def = defaultModel {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(GlassTheme.accentWarning)
                    Text("Default: \(def.name)")
                        .font(.system(size: 11, weight: .medium))
                }
                .glassButton()
            }

            Button {
                Task {
                    isLoading = true
                    await appState.bridge.loadModels()
                    isLoading = false
                }
            } label: {
                HStack(spacing: 4) {
                    if isLoading {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text("Reload")
                }
                .font(.system(size: 12))
            }
            .glassButton()
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(GlassTheme.headerBackground)
    }

    // MARK: - Model List

    private var modelListPanel: some View {
        VStack(spacing: 0) {
            // Filters
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(GlassTheme.textTertiary)
                    TextField("Search models...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                }
                .glassTextField()

                Picker("Provider", selection: $selectedProvider) {
                    ForEach(allProviders, id: \.self) { provider in
                        Text(provider).tag(provider)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 180)

                Toggle("Available only", isOn: $showOnlyAvailable)
                    .font(.system(size: 11))
                    .toggleStyle(.switch)
                    .scaleEffect(0.8)
            }
            .padding(10)
            .background(GlassTheme.headerBackground)

            Divider().opacity(0.3)

            // Stats
            HStack(spacing: 16) {
                ModelStatPill(label: "Total", value: filteredModels.count, color: GlassTheme.accentPrimary)
                ModelStatPill(label: "Available", value: filteredModels.filter { $0.available == true }.count, color: GlassTheme.accentSuccess)
                ModelStatPill(label: "Local", value: filteredModels.filter { $0.local == true }.count, color: GlassTheme.accentTertiary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider().opacity(0.3)

            // Model list
            if isLoading {
                VStack {
                    ProgressView("Loading models...")
                        .padding(40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredModels) { model in
                            ModelListRow(
                                model: model,
                                isSelected: selectedModelKey == model.key
                            ) {
                                selectedModelKey = model.key
                            }
                        }
                    }
                    .padding(8)
                }
            }
        }
    }

    // MARK: - Model Detail

    private func modelDetailPanel(model: OpenClawModelEntry) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Model header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(model.name)
                            .font(.system(size: 22, weight: .bold))
                        Spacer()
                        if model.isDefault {
                            GlassBadge(text: "Default", color: GlassTheme.accentWarning)
                        }
                        if model.available == true {
                            GlassBadge(text: "Available", color: GlassTheme.accentSuccess)
                        } else {
                            GlassBadge(text: "Needs Auth", color: GlassTheme.accentError)
                        }
                    }

                    Text(model.key)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(GlassTheme.accentPrimary)
                        .textSelection(.enabled)
                }

                Divider().opacity(0.3)

                // Properties
                VStack(spacing: 10) {
                    ModelDetailRow(label: "Provider", value: model.provider)
                    ModelDetailRow(label: "Model Key", value: model.key)
                    ModelDetailRow(label: "Input Type", value: model.input ?? "text")
                    if let ctx = model.contextWindow {
                        ModelDetailRow(label: "Context Window", value: formatContextWindow(ctx))
                    }
                    ModelDetailRow(label: "Local", value: model.local == true ? "Yes" : "No")
                    if let tags = model.tags, !tags.isEmpty {
                        ModelDetailRow(label: "Tags", value: tags.joined(separator: ", "))
                    }
                }
                .padding(16)
                .glassCard()

                // Actions
                VStack(spacing: 10) {
                    Button {
                        Task {
                            let success = await appState.bridge.setDefaultModel(model.key)
                            if success {
                                setDefaultResult = "Set \(model.name) as default model"
                                await appState.bridge.loadModels()
                            } else {
                                setDefaultResult = "Failed to set default model"
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "star.fill")
                            Text("Set as Default Model")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity)
                    }
                    .glassButton(isActive: true)
                    .buttonStyle(.plain)

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(model.key, forType: .string)
                    } label: {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("Copy Model Key")
                        }
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity)
                    }
                    .glassButton()
                    .buttonStyle(.plain)

                    if let result = setDefaultResult {
                        HStack(spacing: 6) {
                            Image(systemName: result.contains("Failed") ? "xmark.circle" : "checkmark.circle")
                                .foregroundStyle(result.contains("Failed") ? GlassTheme.accentError : GlassTheme.accentSuccess)
                            Text(result)
                                .font(.system(size: 11))
                        }
                        .padding(10)
                        .glassCard()
                    }
                }

                // Usage in config
                VStack(alignment: .leading, spacing: 8) {
                    Text("Configuration")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(GlassTheme.textSecondary)

                    Text("openclaw.json:")
                        .font(.system(size: 10))
                        .foregroundStyle(GlassTheme.textTertiary)

                    let configSnippet = """
                    {
                      "agent": {
                        "model": "\(model.key)"
                      }
                    }
                    """

                    Text(configSnippet)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(GlassTheme.accentTertiary)
                        .textSelection(.enabled)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(GlassTheme.terminalBg)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Text("CLI:")
                        .font(.system(size: 10))
                        .foregroundStyle(GlassTheme.textTertiary)

                    Text("openclaw models set \(model.key)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(GlassTheme.accentTertiary)
                        .textSelection(.enabled)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(GlassTheme.terminalBg)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(24)
        }
    }

    private var emptyDetailState: some View {
        VStack(spacing: 16) {
            Image(systemName: "cube")
                .font(.system(size: 40))
                .foregroundStyle(GlassTheme.textTertiary)
            Text("Select a model to view details")
                .font(.system(size: 14))
                .foregroundStyle(GlassTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func formatContextWindow(_ tokens: Int) -> String {
        if tokens >= 1_000_000 { return String(format: "%.0fM tokens", Double(tokens) / 1_000_000) }
        if tokens >= 1_000 { return String(format: "%.0fK tokens", Double(tokens) / 1_000) }
        return "\(tokens) tokens"
    }
}

// MARK: - Model List Row

struct ModelListRow: View {
    let model: OpenClawModelEntry
    var isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Availability indicator
                Circle()
                    .fill(model.available == true ? GlassTheme.accentSuccess : GlassTheme.textTertiary.opacity(0.5))
                    .frame(width: 6, height: 6)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(model.name)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        if model.isDefault {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(GlassTheme.accentWarning)
                        }
                    }
                    Text(model.key)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(GlassTheme.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                if let ctx = model.contextWindow {
                    Text(ctx >= 1000 ? "\(ctx / 1000)K" : "\(ctx)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(GlassTheme.textTertiary)
                }

                if model.input?.contains("image") == true {
                    Image(systemName: "photo")
                        .font(.system(size: 9))
                        .foregroundStyle(GlassTheme.accentTertiary)
                }

                Text(model.provider)
                    .font(.system(size: 9))
                    .foregroundStyle(GlassTheme.textTertiary)
                    .frame(width: 80, alignment: .trailing)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? GlassTheme.accentPrimary.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

struct ModelStatPill: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(value)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(GlassTheme.textTertiary)
        }
    }
}

struct ModelDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(GlassTheme.textTertiary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(.system(size: 11))
                .foregroundStyle(GlassTheme.textPrimary)
                .textSelection(.enabled)
            Spacer()
        }
    }
}
