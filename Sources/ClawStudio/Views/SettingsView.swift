import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedSettingsTab = 0
    @State private var diagnosticOutput = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(GlassTheme.accentPrimary)

                Text("Settings")
                    .font(.system(size: 18, weight: .bold))

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(GlassTheme.headerBackground)

            Divider().opacity(0.3)

            HSplitView {
                // Settings tabs
                VStack(spacing: 2) {
                    SettingsTabButton(title: "General", icon: "gearshape", isSelected: selectedSettingsTab == 0) {
                        selectedSettingsTab = 0
                    }
                    SettingsTabButton(title: "Engine", icon: "cpu", isSelected: selectedSettingsTab == 1) {
                        selectedSettingsTab = 1
                    }
                    SettingsTabButton(title: "Appearance", icon: "paintbrush", isSelected: selectedSettingsTab == 2) {
                        selectedSettingsTab = 2
                    }
                    SettingsTabButton(title: "Diagnostics", icon: "stethoscope", isSelected: selectedSettingsTab == 3) {
                        selectedSettingsTab = 3
                    }
                    SettingsTabButton(title: "About", icon: "info.circle", isSelected: selectedSettingsTab == 4) {
                        selectedSettingsTab = 4
                    }
                    Spacer()
                }
                .frame(width: 180)
                .padding(10)
                .background(GlassTheme.sidebarBackground)

                // Settings content
                ScrollView {
                    VStack(spacing: 20) {
                        switch selectedSettingsTab {
                        case 0: generalSettings
                        case 1: engineSettings
                        case 2: appearanceSettings
                        case 3: diagnosticsSettings
                        case 4: aboutSection
                        default: EmptyView()
                        }
                    }
                    .padding(24)
                }
            }
        }
    }

    // MARK: - General

    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsSection(title: "Workspace") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Workspace Path")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(GlassTheme.textSecondary)
                    TextField("Path", text: Binding(
                        get: { appState.preferences.workspacePath },
                        set: { appState.preferences.workspacePath = $0 }
                    ))
                    .glassTextField()
                }
            }

            SettingsSection(title: "Defaults") {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Default Model")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(GlassTheme.textSecondary)

                        Picker("Model", selection: Binding(
                            get: { appState.preferences.defaultModel },
                            set: { appState.preferences.defaultModel = $0 }
                        )) {
                            let available = appState.bridge.allModels.filter { $0.available == true }
                            if available.isEmpty {
                                Text(appState.preferences.defaultModel).tag(appState.preferences.defaultModel)
                            } else {
                                ForEach(available) { model in
                                    Text(model.name).tag(model.key)
                                }
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Default Thinking Level")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(GlassTheme.textSecondary)

                        Picker("Thinking", selection: Binding(
                            get: { appState.preferences.thinkingLevel },
                            set: { appState.preferences.thinkingLevel = $0 }
                        )) {
                            Text("Low").tag("low")
                            Text("Medium").tag("medium")
                            Text("High").tag("high")
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }

            SettingsSection(title: "Behavior") {
                VStack(spacing: 12) {
                    Toggle("Auto-save sessions", isOn: Binding(
                        get: { appState.preferences.autoSave },
                        set: { appState.preferences.autoSave = $0 }
                    ))
                    Toggle("Show token costs in chat", isOn: Binding(
                        get: { appState.preferences.showTokenCost },
                        set: { appState.preferences.showTokenCost = $0 }
                    ))
                }
                .font(.system(size: 13))
            }

            SettingsSection(title: "Data") {
                VStack(spacing: 10) {
                    Button {
                        appState.saveState()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down")
                            Text("Save State Now")
                        }
                        .font(.system(size: 12))
                        .frame(maxWidth: .infinity)
                    }
                    .glassButton(isActive: true)
                    .buttonStyle(.plain)

                    Button {
                        appState.agents = AppState.defaultAgents
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset Agents to Default")
                        }
                        .font(.system(size: 12))
                        .frame(maxWidth: .infinity)
                    }
                    .glassButton()
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Engine

    private var engineSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsSection(title: "OpenClaw Engine") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Status")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(GlassTheme.textSecondary)
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(appState.bridge.isEngineAvailable ? GlassTheme.accentSuccess : GlassTheme.accentError)
                                .frame(width: 8, height: 8)
                            Text(appState.bridge.isEngineAvailable ? "Connected" : "Disconnected")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(appState.bridge.isEngineAvailable ? GlassTheme.accentSuccess : GlassTheme.accentError)
                        }
                    }

                    HStack {
                        Text("Version")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(GlassTheme.textSecondary)
                        Spacer()
                        Text(appState.bridge.engineVersion)
                            .font(.system(size: 12, design: .monospaced))
                    }

                    HStack {
                        Text("CLI Path")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(GlassTheme.textSecondary)
                        Spacer()
                        Text(CLIPathResolver.openclawPath)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(GlassTheme.textTertiary)
                            .textSelection(.enabled)
                    }

                    Divider().opacity(0.3)

                    Button {
                        Task { await appState.bridge.checkEngine() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("Reconnect Engine")
                        }
                        .font(.system(size: 12))
                        .frame(maxWidth: .infinity)
                    }
                    .glassButton()
                    .buttonStyle(.plain)
                }
            }

            SettingsSection(title: "API Keys") {
                VStack(spacing: 8) {
                    ForEach(appState.bridge.providers) { provider in
                        HStack {
                            Text(provider.provider)
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                            if provider.isConfigured {
                                HStack(spacing: 4) {
                                    Text("via \(provider.keySource)")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(GlassTheme.textTertiary)
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(GlassTheme.accentSuccess)
                                }
                            } else {
                                Image(systemName: "circle.dashed")
                                    .font(.system(size: 12))
                                    .foregroundStyle(GlassTheme.textTertiary)
                            }
                        }
                        .padding(10)
                        .glassCard()
                    }

                    if appState.bridge.providers.isEmpty {
                        Text("Refresh engine to load provider status")
                            .font(.system(size: 12))
                            .foregroundStyle(GlassTheme.textTertiary)
                    }
                }
            }
        }
    }

    // MARK: - Appearance

    private var appearanceSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsSection(title: "Theme") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Appearance Mode")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(GlassTheme.textSecondary)

                    Picker("Appearance", selection: Binding(
                        get: { appState.preferences.appearanceMode },
                        set: { appState.preferences.appearanceMode = $0 }
                    )) {
                        Label("System", systemImage: "laptopcomputer").tag("system")
                        Label("Light", systemImage: "sun.max.fill").tag("light")
                        Label("Dark", systemImage: "moon.fill").tag("dark")
                    }
                    .pickerStyle(.segmented)
                }
            }

            SettingsSection(title: "Color Palette Preview") {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        ColorSwatch(color: GlassTheme.accentPrimary, label: "Primary")
                        ColorSwatch(color: GlassTheme.accentSecondary, label: "Secondary")
                        ColorSwatch(color: GlassTheme.accentTertiary, label: "Tertiary")
                        ColorSwatch(color: GlassTheme.accentSuccess, label: "Success")
                        ColorSwatch(color: GlassTheme.accentWarning, label: "Warning")
                        ColorSwatch(color: GlassTheme.accentError, label: "Error")
                    }

                    Divider().opacity(0.3)

                    HStack(spacing: 12) {
                        VStack(spacing: 4) {
                            Text("Primary Text")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(GlassTheme.textPrimary)
                            Text("Secondary Text")
                                .font(.system(size: 11))
                                .foregroundStyle(GlassTheme.textSecondary)
                            Text("Tertiary Text")
                                .font(.system(size: 11))
                                .foregroundStyle(GlassTheme.textTertiary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .glassCard()

                        VStack(spacing: 4) {
                            Text("Glass Card")
                                .font(.system(size: 11, weight: .medium))
                            GlassBadge(text: "Badge", color: GlassTheme.accentPrimary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .glassCard(isSelected: true)
                    }
                }
            }
        }
    }

    // MARK: - Diagnostics

    private var diagnosticsSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsSection(title: "OpenClaw Doctor") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Run diagnostics to check your OpenClaw configuration.")
                        .font(.system(size: 12))
                        .foregroundStyle(GlassTheme.textSecondary)

                    Button {
                        Task {
                            await appState.bridge.runDoctor { @MainActor output in
                                diagnosticOutput = output
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "stethoscope")
                            Text("Run Diagnostics")
                        }
                        .font(.system(size: 12))
                        .frame(maxWidth: .infinity)
                    }
                    .glassButton(isActive: true)
                    .buttonStyle(.plain)

                    if !diagnosticOutput.isEmpty {
                        ScrollView {
                            Text(diagnosticOutput)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(GlassTheme.terminalText)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 300)
                        .background(GlassTheme.terminalBg)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            SettingsSection(title: "App Info") {
                VStack(spacing: 8) {
                    InfoRow(label: "App Version", value: "2.0.0")
                    InfoRow(label: "Swift", value: "5.9+")
                    InfoRow(label: "Platform", value: "macOS 14+")
                    InfoRow(label: "State Path", value: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("ClawStudio").path ?? "N/A")
                }
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [GlassTheme.accentPrimary.opacity(0.3), GlassTheme.accentSecondary.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "wand.and.stars")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(GlassTheme.accentPrimary)
            }

            Text("Claw Studio")
                .font(.system(size: 24, weight: .bold))

            Text("The Ultimate Agent Operating System")
                .font(.system(size: 14))
                .foregroundStyle(GlassTheme.textSecondary)

            Text("Version 2.0.0")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(GlassTheme.textTertiary)

            Divider().opacity(0.3)

            VStack(spacing: 6) {
                Text("Built with Swift & SwiftUI")
                    .font(.system(size: 12))
                    .foregroundStyle(GlassTheme.textSecondary)
                Text("Powered by OpenClaw Runtime")
                    .font(.system(size: 12))
                    .foregroundStyle(GlassTheme.textSecondary)
                Text("Dark Mode + Adaptive UI")
                    .font(.system(size: 12))
                    .foregroundStyle(GlassTheme.accentTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}

// MARK: - Settings Helpers

struct SettingsTabButton: View {
    let title: String
    let icon: String
    var isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? GlassTheme.accentPrimary : GlassTheme.textSecondary)
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                isSelected
                    ? GlassTheme.accentPrimary.opacity(0.12)
                    : (isHovered ? GlassTheme.surfaceHover : Color.clear)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))

            content
                .padding(16)
                .glassCard()
        }
    }
}

struct ColorSwatch: View {
    let color: Color
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(width: 40, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                )

            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(GlassTheme.textTertiary)
        }
    }
}
