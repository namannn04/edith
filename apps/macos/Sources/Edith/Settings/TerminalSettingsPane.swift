import AppKit
import EdithKit
import SwiftUI

struct TerminalSettingsPane: View {
    @AppStorage(CompletionScripts.autoRefreshKey, store: SharedDefaults.store)
    private var autoRefresh = true
    @State private var tools = CLIToolStatus(directory: "")
    @State private var completions: [CompletionStatus] = []
    @State private var working = false
    @State private var note: String?

    var body: some View {
        Form {
            Section {
                LabeledContent("Tools") {
                    Text(toolSummary).foregroundStyle(.secondary)
                }
                LabeledContent("Location") {
                    Text(tools.directory.isEmpty ? "-" : abbreviate(tools.directory))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                HStack(spacing: UIScale.pt(10)) {
                    Button(tools.isComplete ? "Reinstall" : "Install") { installTools() }
                        .pointerCursor()
                        .disabled(working || !tools.bundled)
                    Button("Remove") { removeTools() }
                        .pointerCursor()
                        .disabled(working || tools.linked.isEmpty)
                }
            } header: {
                Text("Command line tools")
            } footer: {
                if !tools.bundled {
                    Text("This build does not carry the ed binary.")
                        .font(.system(size: UIScale.pt(10)))
                } else if !tools.onPath, !tools.directory.isEmpty {
                    Text(
                        "\(abbreviate(tools.directory)) is not on your PATH, so the shell cannot find ed yet."
                    )
                    .font(.system(size: UIScale.pt(10)))
                } else {
                    Text("ed, edh and edith are the same tool under three names.")
                        .font(.system(size: UIScale.pt(10)))
                }
            }

            Section {
                if completions.isEmpty {
                    Text("Looking for shells...").foregroundStyle(.secondary)
                } else {
                    ForEach(completions, id: \.shell) { status in
                        completionRow(status)
                    }
                }
                Button("Install completions") { installCompletions() }
                    .pointerCursor()
                    .disabled(working)
            } header: {
                Text("Shell completion")
            } footer: {
                Text(
                    "A shell reads its completions once, when it starts. Run  exec zsh  in a terminal you already have open, or open a new tab."
                )
                .font(.system(size: UIScale.pt(10)))
            }

            Section {
                Text(sourceLine)
                    .font(.system(size: UIScale.pt(11), design: .monospaced))
                    .textSelection(.enabled)
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(sourceLine, forType: .string)
                    note = "Copied. Paste it at the end of ~/.zshrc."
                }
                .pointerCursor()
                if let hint = completions.compactMap(\.hint).first {
                    Text(hint)
                        .font(.system(size: UIScale.pt(10)))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            } header: {
                Text("If a shell still does not complete")
            } footer: {
                Text(
                    "Adding this to ~/.zshrc loads the completion directly, the way the ac CLI does, instead of waiting for compinit to find it."
                )
                .font(.system(size: UIScale.pt(10)))
            }

            Section {
                Toggle(isOn: $autoRefresh) {
                    HStack(spacing: UIScale.pt(6)) {
                        Text("Keep completions up to date")
                        InfoDot(
                            "Rewrites the completion script when Edith starts, so an update never leaves an old one behind. Only touches a file Edith wrote."
                        )
                    }
                }
                .pointerCursor()
            } header: {
                Text("On launch")
            } footer: {
                if let note {
                    Text(note).font(.system(size: UIScale.pt(10)))
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Terminal")
        .task { await refresh() }
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
        ) { _ in
            Task { await refresh() }
        }
    }

    private func completionRow(_ status: CompletionStatus) -> some View {
        LabeledContent(status.shell.rawValue) {
            VStack(alignment: .trailing, spacing: UIScale.pt(2)) {
                HStack(spacing: UIScale.pt(6)) {
                    Circle()
                        .fill(color(for: status.state))
                        .frame(width: UIScale.pt(7), height: UIScale.pt(7))
                    Text(label(for: status.state)).foregroundStyle(.secondary)
                }
                Text(abbreviate(status.path.path))
                    .font(.system(size: UIScale.pt(10)))
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
        }
    }

    private func label(for state: CompletionInstallState) -> String {
        switch state {
        case .current: return "up to date"
        case .outdated: return "out of date"
        case .missing: return "not installed"
        case .foreign: return "not ours, left alone"
        }
    }

    private func color(for state: CompletionInstallState) -> Color {
        switch state {
        case .current: return .green
        case .outdated: return .orange
        case .missing: return .secondary
        case .foreign: return .yellow
        }
    }

    private var sourceLine: String { CompletionScripts.sourceLine(for: .zsh) }

    private var toolSummary: String {
        guard tools.bundled else { return "not in this build" }
        guard !tools.linked.isEmpty else { return "not installed" }
        return tools.missing.isEmpty
            ? tools.linked.joined(separator: ", ")
            : "\(tools.linked.joined(separator: ", ")) (missing \(tools.missing.joined(separator: ", ")))"
    }

    private func abbreviate(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    private func refresh() async {
        let found = await Task.detached(priority: .userInitiated) {
            (CLIInstaller.status(), CompletionScripts.statuses())
        }.value
        tools = found.0
        completions = found.1
    }

    private func installTools() {
        working = true
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                CLIInstaller.install()
            }.value
            note =
                result.linked.isEmpty
                ? "Nothing to link in \(abbreviate(result.directory))."
                : "Linked \(result.linked.joined(separator: ", ")) in \(abbreviate(result.directory))."
            await refresh()
            working = false
        }
    }

    private func removeTools() {
        working = true
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                CLIInstaller.uninstall()
            }.value
            note =
                result.linked.isEmpty
                ? "Nothing to remove." : "Removed \(result.linked.joined(separator: ", "))."
            await refresh()
            working = false
        }
    }

    private func installCompletions() {
        working = true
        Task {
            let written = await Task.detached(priority: .userInitiated) {
                CompletionScripts.detectShells().compactMap {
                    try? CompletionScripts.install($0)
                }
            }.value
            note =
                written.isEmpty
                ? "Could not write the completion scripts."
                : "Wrote \(written.count == 1 ? "1 script" : "\(written.count) scripts"). Run  exec zsh  in any open terminal."
            await refresh()
            working = false
        }
    }
}
