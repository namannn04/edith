import EdithKit
import Foundation

public enum RemoteCompletion {
    public static let harness = """
        __ed_rc() {
          local cword=$1
          shift
          COMP_WORDS=("$@")
          COMP_CWORD=$cword
          COMP_LINE="${COMP_WORDS[*]}"
          COMP_POINT=${#COMP_LINE}
          local cmd="${COMP_WORDS[0]}"
          local cur="${COMP_WORDS[$cword]}"
          local prev=""
          if [ "$cword" -gt 0 ]; then prev="${COMP_WORDS[$((cword-1))]}"; fi
          local f
          for f in /usr/share/bash-completion/bash_completion /etc/bash_completion; do
            if [ -r "$f" ]; then . "$f" >/dev/null 2>&1; break; fi
          done
          if declare -F _completion_loader >/dev/null 2>&1; then
            _completion_loader "$cmd" >/dev/null 2>&1
          fi
          local fn
          fn=$(complete -p "$cmd" 2>/dev/null | sed -n 's/.*-F \\([^ ][^ ]*\\).*/\\1/p')
          COMPREPLY=()
          if [ -n "$fn" ] && declare -F "$fn" >/dev/null 2>&1; then
            "$fn" "$cmd" "$cur" "$prev" >/dev/null 2>&1
          fi
          if [ ${#COMPREPLY[@]} -eq 0 ]; then
            compgen -o default -- "$cur" 2>/dev/null
          else
            printf '%s\\n' "${COMPREPLY[@]}"
          fi
        }
        __ed_rc "$@"
        """

    public static func commandNamesCommand(prefix: String) -> String {
        "compgen -c -- " + ShellQuote.quote(prefix) + " 2>/dev/null | sort -u | head -2000"
    }

    public static func harnessCommand(words: [String], cursor: Int) -> String {
        var argv = ["bash", "-c", harness, "ed-complete", String(cursor)]
        argv += words
        return ShellQuote.command(argv) + " 2>/dev/null"
    }

    public static func candidates(machine: Machine, request: CompletionRequest) async -> [String] {
        let words = Array(request.words.dropFirst(2))
        let cursor = request.index - 2
        guard cursor >= 0 else { return [] }
        guard MachineDirectory.hasLiveControlSocket(machine) else { return [] }
        let connection = SSHConnection(machine: machine)
        let command = MachineWorkingDirectory.prefixed(
            cursor == 0
                ? commandNamesCommand(prefix: request.current)
                : harnessCommand(words: words, cursor: cursor),
            directory: MachineWorkingDirectory.load(machineID: machine.id))
        guard let result = try? await connection.run(command, timeout: 6), result.succeeded else {
            return []
        }
        let lines = result.stdoutText.split(separator: "\n").map(String.init)
        return CompletionEngine.filtered(lines, request.current)
    }
}
