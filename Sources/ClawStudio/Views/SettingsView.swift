import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedSettingsTab = 0
    @State private var workspacePath = "~/.openclaw/workspace"
    @State private var defaultModel = "anthropic/claude-sonnet-4-6"
    @State private var thinkingLevel = "medium"
    @State private var autoSave = true
    @State private var showTokenCost = true
    @State private var darkMode = true
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
            .background(Color.white.opacity(0.7))

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
                .background(Color.white.opacity(0.7))

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
                    TextField("Path", text: $workspacePath)
                        .glassTextField()
                }
            }

            SettingsSection(title: "Defaults") {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Default Model")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(GlassTheme.textSecondary)

                        Picker("Model", selection: $defaultModel) {
                            Text("Claude Sonnet 4.6").tag("anthropic/claude-sonnet-4-6")
                            Text("Claude Opus 4.6").tag("anthropic/claude-opus-4-6")
                            Text("Claude Haiku 4.5").tag("anthropic/claude-haiku-4-5")
                        }
                        .pickerStyle(.menu)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Default Thinking Level")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(GlassTheme.textSecondary)

                        Picker("Thinking", selection: $thinkingLevel) {
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
                    Toggle("Auto-save sessions", isOn: $autoSave)
                    Toggle("Show token costs in chat", isOn: $showTokenCost)
                }
                .font(.system(size: 13))
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
                    ForEach(appState.apiKeys) { key in
                        HStack {
                            Text(key.service)
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                            Text(key.keyName)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(GlassTheme.textTertiary)
                            Circle()
                                .fill(key.isConfigured ? GlassTheme.accentSuccess : GlassTheme.textTertiary)
                                .frame(width: 8, height: 8)
                        }
                        .padding(10)
                        .glassCard()
                    }
                }
            }
        }
    }

    // MARK: - Appearance

    private var appearanceSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsSection(title: "Theme") {
                Toggle("Dark Mode", isOn: $darkMode)
                    .font(.system(size: 13))
            }

            SettingsSection(title: "Preview") {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        ColorSwatch(color: GlassTheme.accentPrimary, label: "Primary")
                        ColorSwatch(color: GlassTheme.accentSecondary, label: "Secondary")
                        ColorSwatch(color: GlassTheme.accentTertiary, label: "Tertiary")
                        ColorSwatch(color: GlassTheme.accentSuccess, label: "Success")
                        ColorSwatch(color: GlassTheme.accentWarning, label: "Warning")
                        ColorSwatch(color: GlassTheme.accentError, label: "Error")
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
                        Text(diagnosticOutput)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(GlassTheme.textSecondary)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassCard()
                    }
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

            Text("Version 1.0.0")
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
            .background(isSelected ? GlassTheme.accentPrimary.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
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

            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(GlassTheme.textTertiary)
        }
    }
}
