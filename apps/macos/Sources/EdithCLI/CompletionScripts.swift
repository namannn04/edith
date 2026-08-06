import Foundation

public enum CompletionShell: String, CaseIterable, Sendable {
    case zsh
    case bash
    case fish

    public var scriptName: String {
        switch self {
        case .zsh: return "_ed"
        case .bash: return "ed"
        case .fish: return "ed.fish"
        }
    }
}

public enum CompletionScripts {
    public static func script(for shell: CompletionShell) -> String {
        switch shell {
        case .zsh: return zsh
        case .bash: return bash
        case .fish: return fish
        }
    }

    public static let zsh = """
        #compdef ed edh edith

        _ed_complete() {
          local -a lines matches
          local line
          local -i wants_files=0
          lines=("${(@f)$(command ed __complete --index $((CURRENT-1)) -- "${words[@]}" 2>/dev/null)}")
          for line in "${lines[@]}"; do
            [[ -z "$line" ]] && continue
            if [[ "$line" == '#files' ]]; then
              wants_files=1
              continue
            fi
            matches+=("$line")
          done
          (( wants_files )) && _files
          (( ${#matches} )) && compadd -- "${matches[@]}"
        }

        compdef _ed_complete ed edh edith
        """

    public static let bash = """
        _ed_complete() {
          local IFS=$'\\n'
          local line
          local -a out
          COMPREPLY=()
          out=($(command ed __complete --index "$COMP_CWORD" -- "${COMP_WORDS[@]}" 2>/dev/null))
          for line in "${out[@]}"; do
            [ -z "$line" ] && continue
            if [ "$line" = '#files' ]; then
              COMPREPLY+=($(compgen -f -- "${COMP_WORDS[COMP_CWORD]}"))
              continue
            fi
            COMPREPLY+=("$line")
          done
        }

        complete -o bashdefault -F _ed_complete ed edh edith
        """

    public static let fish = """
        function __ed_complete
            set -l tokens (commandline -opc)
            set -l current (commandline -ct)
            set -l out (command ed __complete --index (count $tokens) -- $tokens $current 2>/dev/null)
            for line in $out
                if test "$line" = '#files'
                    __fish_complete_path $current
                else
                    echo $line
                end
            end
        end

        complete -c ed -f -a '(__ed_complete)'
        complete -c edh -f -a '(__ed_complete)'
        complete -c edith -f -a '(__ed_complete)'
        """

    public static func installDirectory(
        for shell: CompletionShell, home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        switch shell {
        case .zsh: return home.appendingPathComponent(".local/share/zsh/site-functions")
        case .bash: return home.appendingPathComponent(".local/share/bash-completion/completions")
        case .fish: return home.appendingPathComponent(".config/fish/completions")
        }
    }

    public static func rcHint(for shell: CompletionShell, directory: URL) -> String? {
        switch shell {
        case .zsh:
            return "add to ~/.zshrc, before compinit: fpath=(\(directory.path) $fpath)"
        case .bash:
            return "add to ~/.bashrc: source \(directory.path)/ed"
        case .fish:
            return nil
        }
    }

    @discardableResult
    public static func install(
        _ shell: CompletionShell, home: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default
    ) throws -> URL {
        let directory = installDirectory(for: shell, home: home)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent(shell.scriptName)
        try Data((script(for: shell) + "\n").utf8).write(to: file, options: .atomic)
        return file
    }

    public static func detectShells(
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default
    ) -> [CompletionShell] {
        var found: [CompletionShell] = [.zsh]
        if fileManager.fileExists(atPath: home.appendingPathComponent(".bashrc").path)
            || fileManager.fileExists(atPath: home.appendingPathComponent(".bash_profile").path)
        {
            found.append(.bash)
        }
        if fileManager.fileExists(atPath: home.appendingPathComponent(".config/fish").path) {
            found.append(.fish)
        }
        return found
    }
}
