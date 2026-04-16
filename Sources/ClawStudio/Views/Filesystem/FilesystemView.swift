import SwiftUI

struct FilesystemView: View {
    @EnvironmentObject var appState: AppState
    @State private var workspacePath = "~/.openclaw/workspace"
    @State private var fileNodes: [FileNode] = []
    @State private var selectedFilePath: String?
    @State private var fileContent = ""
    @State private var isLoading = false

    var body: some View {
        HSplitView {
            // File tree
            fileTreePanel
                .frame(minWidth: 260, idealWidth: 300, maxWidth: 400)

            // File content viewer
            fileContentPanel
        }
        .task {
            loadFiles()
        }
    }

    private var fileTreePanel: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundStyle(GlassTheme.accentPrimary)
                Text("Workspace")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()

                Button {
                    loadFiles()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .glassButton()
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(GlassTheme.headerBackground)

            Divider().opacity(0.3)

            // Path bar
            HStack(spacing: 6) {
                Image(systemName: "folder.badge.gear")
                    .font(.system(size: 10))
                    .foregroundStyle(GlassTheme.textTertiary)
                TextField("Workspace path", text: $workspacePath)
                    .font(.system(size: 11, design: .monospaced))
                    .textFieldStyle(.plain)
                    .onSubmit { loadFiles() }
            }
            .padding(8)
            .background(GlassTheme.surfaceSecondary)

            Divider().opacity(0.3)

            // File tree
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(fileNodes) { node in
                            FileNodeRow(node: node, selectedPath: $selectedFilePath, depth: 0) { path in
                                loadFileContent(path)
                            }
                        }
                    }
                    .padding(8)
                }
            }
        }
        .background(GlassTheme.sidebarBackground)
    }

    private var fileContentPanel: some View {
        VStack(spacing: 0) {
            // File header
            HStack {
                if let path = selectedFilePath {
                    Image(systemName: fileIcon(for: path))
                        .foregroundStyle(fileColor(for: path))
                    Text(URL(fileURLWithPath: path).lastPathComponent)
                        .font(.system(size: 13, weight: .semibold))

                    Text(path)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(GlassTheme.textTertiary)
                        .lineLimit(1)
                } else {
                    Text("No file selected")
                        .font(.system(size: 13))
                        .foregroundStyle(GlassTheme.textSecondary)
                }
                Spacer()
            }
            .padding(14)
            .background(GlassTheme.headerBackground)

            Divider().opacity(0.3)

            // Content
            if selectedFilePath != nil {
                ScrollView([.horizontal, .vertical]) {
                    Text(fileContent)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .lineSpacing(3)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 36))
                        .foregroundStyle(GlassTheme.textTertiary)
                    Text("Select a file to view its contents")
                        .font(.system(size: 13))
                        .foregroundStyle(GlassTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func loadFiles() {
        isLoading = true
        fileNodes = SessionFileManager.shared.loadWorkspaceFiles(at: workspacePath)
        isLoading = false
    }

    private func loadFileContent(_ path: String) {
        selectedFilePath = path
        fileContent = (try? String(contentsOfFile: path, encoding: .utf8)) ?? "Unable to read file"
    }

    private func fileIcon(for path: String) -> String {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "js", "ts": return "chevron.left.forwardslash.chevron.right"
        case "py": return "chevron.left.forwardslash.chevron.right"
        case "md": return "doc.text"
        case "json": return "curlybraces"
        case "yaml", "yml": return "list.bullet"
        case "sh": return "terminal"
        default: return "doc"
        }
    }

    private func fileColor(for path: String) -> Color {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        switch ext {
        case "swift": return .orange
        case "js", "ts": return .yellow
        case "py": return .blue
        case "md": return GlassTheme.accentPrimary
        case "json": return .green
        default: return GlassTheme.textSecondary
        }
    }
}

// MARK: - File Node Row

struct FileNodeRow: View {
    let node: FileNode
    @Binding var selectedPath: String?
    let depth: Int
    let onSelect: (String) -> Void
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                if node.isDirectory {
                    isExpanded.toggle()
                } else {
                    selectedPath = node.path
                    onSelect(node.path)
                }
            } label: {
                HStack(spacing: 6) {
                    if node.isDirectory {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8))
                            .foregroundStyle(GlassTheme.textTertiary)
                            .frame(width: 10)
                    } else {
                        Spacer().frame(width: 10)
                    }

                    Image(systemName: node.isDirectory ? (isExpanded ? "folder.fill" : "folder") : "doc")
                        .font(.system(size: 11))
                        .foregroundStyle(node.isDirectory ? .yellow : GlassTheme.textSecondary)

                    Text(node.name)
                        .font(.system(size: 12))
                        .foregroundStyle(selectedPath == node.path ? GlassTheme.accentPrimary : GlassTheme.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    if let size = node.size, !node.isDirectory {
                        Text(formatSize(size))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(GlassTheme.textTertiary)
                    }
                }
                .padding(.leading, CGFloat(depth * 16))
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .background(selectedPath == node.path ? GlassTheme.accentPrimary.opacity(0.1) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(node.children) { child in
                    FileNodeRow(node: child, selectedPath: $selectedPath, depth: depth + 1, onSelect: onSelect)
                }
            }
        }
    }

    private func formatSize(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
    }
}
