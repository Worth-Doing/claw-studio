import SwiftUI

struct SkillsManagerView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var selectedCategory: SkillCategory?
    @State private var showAPIKeys = false

    var filteredSkills: [Skill] {
        appState.skills.filter { skill in
            let matchesSearch = searchText.isEmpty || skill.name.localizedCaseInsensitiveContains(searchText)
            let matchesCategory = selectedCategory == nil || skill.category == selectedCategory
            return matchesSearch && matchesCategory
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider().opacity(0.3)

            HSplitView {
                // Skills grid
                skillsGrid
                    .frame(minWidth: 500)

                // API Keys panel
                if showAPIKeys {
                    apiKeysPanel
                        .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)
                }
            }
        }
    }

    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: "puzzlepiece.extension.fill")
                .font(.system(size: 18))
                .foregroundStyle(GlassTheme.accentPrimary)

            Text("Skills Manager")
                .font(.system(size: 18, weight: .bold))

            Spacer()

            // Search
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(GlassTheme.textTertiary)
                TextField("Search skills...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .glassTextField()
            .frame(width: 200)

            // Category filter
            Menu {
                Button("All Categories") { selectedCategory = nil }
                Divider()
                ForEach(SkillCategory.allCases, id: \.self) { category in
                    Button(category.rawValue) { selectedCategory = category }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "tag")
                    Text(selectedCategory?.rawValue ?? "All")
                }
                .font(.system(size: 12))
            }
            .glassButton()
            .buttonStyle(.plain)

            Button {
                showAPIKeys.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "key.fill")
                    Text("API Keys")
                }
                .font(.system(size: 12))
            }
            .glassButton(isActive: showAPIKeys)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.7))
    }

    private var skillsGrid: some View {
        ScrollView {
            // Stats row
            HStack(spacing: 12) {
                StatCard(title: "Total Skills", value: "\(appState.skills.count)", icon: "puzzlepiece.extension", color: GlassTheme.accentPrimary)
                StatCard(title: "Active", value: "\(appState.skills.filter { $0.isEnabled }.count)", icon: "checkmark.circle", color: GlassTheme.accentSuccess)
                StatCard(title: "Categories", value: "\(Set(appState.skills.map { $0.category }).count)", icon: "tag", color: GlassTheme.accentSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
            ], spacing: 12) {
                ForEach(Array(filteredSkills.enumerated()), id: \.element.id) { index, skill in
                    SkillCard(skill: $appState.skills[appState.skills.firstIndex(where: { $0.id == skill.id })!])
                }
            }
            .padding(20)
        }
    }

    private var apiKeysPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "key.fill")
                    .foregroundStyle(GlassTheme.accentWarning)
                Text("API Keys")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
            }
            .padding(14)
            .background(Color.white.opacity(0.7))

            Divider().opacity(0.3)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(appState.apiKeys) { key in
                        APIKeyCard(entry: key)
                    }

                    // Add new key
                    Button {} label: {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Add API Key")
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(GlassTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .glassCard()
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
            }
        }
        .background(Color.white.opacity(0.7))
    }
}

// MARK: - Skill Card

struct SkillCard: View {
    @Binding var skill: Skill

    var categoryIcon: String {
        switch skill.category {
        case .general: return "star"
        case .development: return "chevron.left.forwardslash.chevron.right"
        case .research: return "magnifyingglass"
        case .communication: return "bubble.left.and.bubble.right"
        case .filesystem: return "folder"
        case .web: return "globe"
        case .automation: return "gearshape.2"
        }
    }

    var categoryColor: Color {
        switch skill.category {
        case .general: return GlassTheme.accentPrimary
        case .development: return GlassTheme.accentSecondary
        case .research: return GlassTheme.accentTertiary
        case .communication: return .pink
        case .filesystem: return .orange
        case .web: return .cyan
        case .automation: return .indigo
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(categoryColor.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: categoryIcon)
                        .font(.system(size: 15))
                        .foregroundStyle(categoryColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(skill.name)
                        .font(.system(size: 13, weight: .semibold))
                    GlassBadge(text: skill.category.rawValue, color: categoryColor)
                }

                Spacer()

                Toggle("", isOn: $skill.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .scaleEffect(0.8)
            }

            Text(skill.description)
                .font(.system(size: 12))
                .foregroundStyle(GlassTheme.textSecondary)
                .lineLimit(2)

            HStack {
                Text("v\(skill.version)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(GlassTheme.textTertiary)
                Spacer()
                if skill.isEnabled {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(GlassTheme.accentSuccess)
                            .frame(width: 5, height: 5)
                        Text("Active")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(GlassTheme.accentSuccess)
                    }
                }
            }
        }
        .padding(14)
        .glassCard(isSelected: skill.isEnabled)
    }
}

// MARK: - API Key Card

struct APIKeyCard: View {
    let entry: APIKeyEntry
    @State private var isRevealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.service)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Circle()
                    .fill(entry.isConfigured ? GlassTheme.accentSuccess : GlassTheme.textTertiary)
                    .frame(width: 8, height: 8)
            }

            HStack {
                Text(entry.keyName)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(GlassTheme.textSecondary)
                Spacer()

                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .font(.system(size: 11))
                        .foregroundStyle(GlassTheme.textTertiary)
                }
                .buttonStyle(.plain)
            }

            if entry.isConfigured {
                Text(isRevealed ? entry.maskedValue : "••••••••••••")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(GlassTheme.textTertiary)
            } else {
                Text("Not configured")
                    .font(.system(size: 11))
                    .foregroundStyle(GlassTheme.accentWarning)
            }
        }
        .padding(12)
        .glassCard()
    }
}
