import Foundation
import SwiftUI

// MARK: - Shared CLI Path Resolution

enum CLIPathResolver {
    static let openclawPath: String = {
        let possiblePaths = [
            "/opt/homebrew/bin/openclaw",
            "/usr/local/bin/openclaw",
            "\(NSHomeDirectory())/.npm-global/bin/openclaw"
        ]
        return possiblePaths.first { FileManager.default.fileExists(atPath: $0) } ?? "openclaw"
    }()
}

// MARK: - Command Execution Record

struct CommandRecord: Identifiable, Sendable {
    let id: UUID
    let command: String
    let arguments: [String]
    let startedAt: Date
    var finishedAt: Date?
    var output: String
    var exitCode: Int32?
    var status: CommandStatus

    init(command: String, arguments: [String]) {
        self.id = UUID()
        self.command = command
        self.arguments = arguments
        self.startedAt = Date()
        self.output = ""
        self.status = .running
    }

    var displayCommand: String {
        "openclaw " + arguments.joined(separator: " ")
    }
}

enum CommandStatus: Sendable {
    case running
    case success
    case failed
    case cancelled
}

// MARK: - Command Runner (non-blocking)

@MainActor
final class CommandRunner: ObservableObject {
    @Published var currentRecord: CommandRecord?
    @Published var history: [CommandRecord] = []
    @Published var isRunning = false

    private var process: Process?

    /// Run a command asynchronously without blocking the main thread
    func run(_ arguments: [String]) async -> CommandRecord {
        cancel()

        var record = CommandRecord(command: CLIPathResolver.openclawPath, arguments: arguments)
        currentRecord = record
        isRunning = true

        let result = await Task.detached { [path = CLIPathResolver.openclawPath] () -> (String, Int32) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            var env = ProcessInfo.processInfo.environment
            env["TERM"] = "dumb"
            env["NO_COLOR"] = "1"
            env["FORCE_COLOR"] = "0"
            process.environment = env

            do {
                try process.run()

                let stdoutData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                var fullOutput = ""
                if let stdout = String(data: stdoutData, encoding: .utf8), !stdout.isEmpty {
                    fullOutput += stdout
                }
                if let stderr = String(data: stderrData, encoding: .utf8), !stderr.isEmpty {
                    if !fullOutput.isEmpty { fullOutput += "\n" }
                    fullOutput += stderr
                }

                return (fullOutput.trimmingCharacters(in: .whitespacesAndNewlines), process.terminationStatus)
            } catch {
                return ("Error launching command: \(error.localizedDescription)", -1)
            }
        }.value

        record.output = result.0
        record.exitCode = result.1
        record.finishedAt = Date()
        record.status = result.1 == 0 ? .success : .failed

        currentRecord = record
        isRunning = false
        process = nil

        history.insert(record, at: 0)
        if history.count > 50 { history = Array(history.prefix(50)) }

        return record
    }

    /// Run and return just the output string (convenience)
    func runQuiet(_ arguments: [String]) async -> String {
        let record = await run(arguments)
        return record.output
    }

    func cancel() {
        if let process, process.isRunning {
            process.terminate()
        }
        if var record = currentRecord, record.status == .running {
            record.status = .cancelled
            record.finishedAt = Date()
            currentRecord = record
        }
        process = nil
        isRunning = false
    }
}

// MARK: - Live Terminal View (reusable component)

struct LiveTerminalView: View {
    let record: CommandRecord?
    var maxHeight: CGFloat = 300
    var showCommand: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let record {
                if showCommand {
                    HStack(spacing: 8) {
                        Image(systemName: statusIcon(record.status))
                            .font(.system(size: 11))
                            .foregroundStyle(statusColor(record.status))

                        Text("$ " + record.displayCommand)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(GlassTheme.terminalGreen)
                            .lineLimit(1)

                        Spacer()

                        if record.status == .running {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else if let exitCode = record.exitCode {
                            Text("exit \(exitCode)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(GlassTheme.terminalText.opacity(0.5))
                        }

                        if let elapsed = record.finishedAt {
                            Text(formatDuration(from: record.startedAt, to: elapsed))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(GlassTheme.terminalText.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(GlassTheme.terminalBg.opacity(0.8))
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if record.output.isEmpty && record.status == .running {
                            HStack(spacing: 6) {
                                ProgressView().scaleEffect(0.6)
                                Text("Running...")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(GlassTheme.terminalText.opacity(0.5))
                            }
                            .padding(12)
                        } else {
                            Text(record.output)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(GlassTheme.terminalText)
                                .textSelection(.enabled)
                                .lineSpacing(2)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxHeight: maxHeight)
            } else {
                HStack {
                    Text("No command output")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(GlassTheme.terminalText.opacity(0.5))
                }
                .padding(12)
            }
        }
        .background(GlassTheme.terminalBg)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color(white: 0.3, opacity: 0.4), lineWidth: 0.5)
        )
    }

    private func statusIcon(_ status: CommandStatus) -> String {
        switch status {
        case .running: return "circle.fill"
        case .success: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "stop.circle.fill"
        }
    }

    private func statusColor(_ status: CommandStatus) -> Color {
        switch status {
        case .running: return GlassTheme.accentWarning
        case .success: return GlassTheme.accentSuccess
        case .failed: return GlassTheme.accentError
        case .cancelled: return GlassTheme.terminalText.opacity(0.5)
        }
    }

    private func formatDuration(from start: Date, to end: Date) -> String {
        let interval = end.timeIntervalSince(start)
        if interval < 1 { return "<1s" }
        if interval < 60 { return String(format: "%.1fs", interval) }
        return String(format: "%.0fm%.0fs", interval / 60, interval.truncatingRemainder(dividingBy: 60))
    }
}

// MARK: - Action Button with Terminal

struct ActionButtonWithTerminal: View {
    let title: String
    let icon: String
    let color: Color
    let arguments: [String]
    var subtitle: String? = nil

    @StateObject private var runner = CommandRunner()
    @State private var showOutput = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                showOutput = true
                Task {
                    _ = await runner.run(arguments)
                }
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(color.opacity(0.15))
                            .frame(width: 36, height: 36)

                        if runner.isRunning {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: icon)
                                .font(.system(size: 15))
                                .foregroundStyle(color)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 13, weight: .medium))
                        if let subtitle {
                            Text(subtitle)
                                .font(.system(size: 10))
                                .foregroundStyle(GlassTheme.textTertiary)
                        }
                    }

                    Spacer()

                    if let record = runner.currentRecord, record.status != .running {
                        Image(systemName: record.status == .success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(record.status == .success ? GlassTheme.accentSuccess : GlassTheme.accentError)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundStyle(GlassTheme.textTertiary)
                }
                .padding(12)
                .glassCard()
            }
            .buttonStyle(.plain)
            .disabled(runner.isRunning)

            if showOutput, runner.currentRecord != nil {
                LiveTerminalView(record: runner.currentRecord, maxHeight: 200)
                    .padding(.top, 4)
            }
        }
    }
}
