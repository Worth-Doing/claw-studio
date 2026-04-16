import SwiftUI

struct MemoryManagerView: View {
    @EnvironmentObject var appState: AppState
    @State private var memoryMDContent = ""
    @State private var searchText = ""
    @State private var selectedType: MemoryType?
    @State private var showEditor = false
    @State private var newEntryContent = ""

    var filteredEntries: [MemoryEntry] {
        appState.memoryEntries.filter { entry in
            let matchesSearch = searchText.isEmpty || entry.content.localizedCaseInsensitiveContains(searchText)
            let matchesType = selectedType == nil || entry.type == selectedType
            return matchesSearch && matchesType
        }
    }

    var body: some View {
        HSplitView {
            // Memory entries
            entriesPanel
                .frame(minWidth: 400)

            // MEMORY.md editor
            memoryEditorPanel
                .frame(minWidth: 350, idealWidth: 400, maxWidth: 500)
        }
        .task {
            memoryMDContent = SessionFileManager.shared.readMemoryFile()
        }
    }

    private var entriesPanel: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "brain.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(GlassTheme.accentSecondary)

                Text("Memory System")
                    .font(.system(size: 18, weight: .bold))

                Spacer()

                // Search
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(GlassTheme.textTertiary)
                    TextField("Search memories...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                }
                .glassTextField()
                .frame(width: 200)

                // Type filter
                Menu {
                    Button("All Types") { selectedType = nil }
                    Divider()
                    ForEach(MemoryType.allCases, id: \.self) { type in
                        Button(type.rawValue) { selectedType = type }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text(selectedType?.rawValue ?? "All")
                    }
                    .font(.system(size: 12))
                }
                .glassButton()
                .buttonStyle(.plain)

                Button {
                    let entry = MemoryEntry(content: "New memory entry...")
                    appState.memoryEntries.append(entry)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add")
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .glassButton(isActive: true)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(GlassTheme.headerBackground)

            Divider().opacity(0.3)

            // Memory tier stats
            HStack(spacing: 12) {
                MemoryTierCard(
                    title: "Short-Term",
                    count: appState.memoryEntries.filter { $0.type == .shortTerm }.count,
                    icon: "clock",
                    color: GlassTheme.accentWarning,
                    description: "Today's session context"
                )
                MemoryTierCard(
                    title: "Long-Term",
                    count: appState.memoryEntries.filter { $0.type == .longTerm }.count,
                    icon: "brain",
                    color: GlassTheme.accentSecondary,
                    description: "Persistent knowledge"
                )
                MemoryTierCard(
                    title: "Episodic",
                    count: appState.memoryEntries.filter { $0.type == .episodic }.count,
                    icon: "clock.arrow.circlepath",
                    color: GlassTheme.accentTertiary,
                    description: "Historical events"
                )
            }
            .padding(16)

            Divider().opacity(0.3)

            // Entries list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredEntries) { entry in
                        MemoryEntryCard(entry: entry)
                    }

                    if filteredEntries.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "brain")
                                .font(.system(size: 32))
                                .foregroundStyle(GlassTheme.textTertiary)
                            Text("No memory entries yet")
                                .font(.system(size: 13))
                                .foregroundStyle(GlassTheme.textSecondary)
                            Text("Memories will be captured as agents interact with the system.")
                                .font(.system(size: 11))
                                .foregroundStyle(GlassTheme.textTertiary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 40)
                    }
                }
                .padding(16)
            }
        }
    }

    private var memoryEditorPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundStyle(GlassTheme.accentTertiary)
                Text("MEMORY.md")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()

                Button {
                    memoryMDContent = SessionFileManager.shared.readMemoryFile()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .glassButton()
                .buttonStyle(.plain)

                Button {
                    try? SessionFileManager.shared.writeMemoryFile(memoryMDContent)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.down")
                        Text("Save")
                    }
                    .font(.system(size: 12))
                }
                .glassButton(isActive: true)
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(GlassTheme.headerBackground)

            Divider().opacity(0.3)

            TextEditor(text: $memoryMDContent)
                .font(.system(size: 12, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(12)
        }
        .background(GlassTheme.sidebarBackground)
    }
}

// MARK: - Memory Tier Card

struct MemoryTierCard: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(color)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }

            Text(title)
                .font(.system(size: 12, weight: .semibold))

            Text(description)
                .font(.system(size: 10))
                .foregroundStyle(GlassTheme.textTertiary)
        }
        .padding(12)
        .glassCard()
    }
}

// MARK: - Memory Entry Card

struct MemoryEntryCard: View {
    let entry: MemoryEntry
    @State private var isExpanded = false

    var typeColor: Color {
        switch entry.type {
        case .shortTerm: return GlassTheme.accentWarning
        case .longTerm: return GlassTheme.accentSecondary
        case .episodic: return GlassTheme.accentTertiary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                GlassBadge(text: entry.type.rawValue, color: typeColor)

                Spacer()

                Text(entry.createdAt, style: .relative)
                    .font(.system(size: 10))
                    .foregroundStyle(GlassTheme.textTertiary)

                Button {
                    withAnimation { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(GlassTheme.textTertiary)
                }
                .buttonStyle(.plain)
            }

            Text(isExpanded ? entry.content : String(entry.content.prefix(120)))
                .font(.system(size: 12))
                .foregroundStyle(GlassTheme.textSecondary)
                .lineLimit(isExpanded ? nil : 2)

            if !entry.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(entry.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(GlassTheme.accentPrimary)
                    }
                }
            }
        }
        .padding(12)
        .glassCard()
    }
}
