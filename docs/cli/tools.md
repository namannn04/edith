# `ed tools`

`ed tools` answers one question: does this Mac have the command line programs
Edith's extensions shell out to, and where are they? Three tools are in the
catalogue, and the catalogue is fixed in the binary: `yt-dlp`, which the Music
extension and the whole download queue run, and `claude` and `codex`, the agent
CLIs behind Agent Usage.

`ls` looks for each one and asks it for its version. `install` reports the tool
when it is already there and otherwise fetches it itself, in this process, the
command line counterpart of the Install button on the tool's row in Settings.
Neither verb needs Edith to be running, neither writes a setting, and neither
can remove a tool: uninstalling stays with Homebrew, npm or `rm`.

`ed tools` with nothing after it runs `ed tools ls`, and `ed tools list` is the
same command.

## At a glance

| Command | What it does |
| --- | --- |
| `ed tools` | Runs `ed tools ls`, which is the default subcommand. |
| `ed tools ls` | Lists all three tools with whether each is installed, its version, and why Edith wants it. |
| `ed tools install <tool>` | Reports the tool when it is already installed, otherwise fetches it here and checks it landed on PATH. |

## The tools

Every tool `ed` can report on or install, in the order `ls` prints them. All
three are listed on every run, whether or not the extension that wants them is
switched on.

| `id` | Name | Wanted by | Present when | `install` fetches it from |
| --- | --- | --- | --- | --- |
| `yt-dlp` | yt-dlp | The Music extension, and everything under `ed download` | an executable called `yt-dlp` is on the assembled PATH | the official release asset `https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos`, downloaded with `curl --fail --location --progress-bar`, made executable, and moved to `~/Library/Application Support/Edith/bin/yt-dlp` |
| `claude` | Claude Code | The Agent Usage extension | an executable called `claude` is on the assembled PATH | `brew install --cask claude-code`, falling back to `npm install -g @anthropic-ai/claude-code` |
| `codex` | Codex | The Agent Usage extension, and only while `codexLimitsEnabled` is on, which it is unless you turn it off | an executable called `codex` is on the assembled PATH | `brew install --cask codex`, falling back to `npm install -g @openai/codex` |

The version string in every case is the first line the tool prints for
`--version`: stdout alone when `ls` reads it, stdout and stderr together when
`install` verifies what it just did.

Only `yt-dlp` lands somewhere Edith owns. The two agent CLIs go wherever
Homebrew or npm puts them, so the `path` field of `ed tools ls --json` is the
only reliable answer to which binary is being used. The fallback order is
Homebrew first and npm second: npm is tried both when `brew --version` fails
and when the `brew` install itself exits non-zero, and an install with neither
manager available fails with `Neither Homebrew nor npm is available for
installing Claude Code.`

When an install fails, `ed` prints the tool's manual instruction as the hint,
which is the line to run by hand:

```
yt-dlp   Download yt-dlp_macos from the official yt-dlp release and place it in a folder on PATH.
claude   Install with `brew install --cask claude-code` or `npm install -g @anthropic-ai/claude-code`.
codex    Install with `brew install --cask codex` or `npm install -g @openai/codex`.
```

`ed` does not search your shell's `PATH`. It builds its own, in this order,
and looks in each directory for a file with the tool's name that the operating
system considers executable:

```
~/Library/Application Support/Edith/bin
$HOME/.local/bin
~/.local/bin
~/.nvm/current/bin
~/.nvm/versions/node/<version>/bin
/opt/homebrew/bin
/usr/local/bin
/usr/bin
/bin
/usr/sbin
/sbin
<every directory already in your PATH, in its own order>
```

Duplicates are dropped keeping the first occurrence, paths are standardised
before they are compared, the nvm version directories are sorted by name and
then reversed so the lexicographically last one is searched first, and anything
under `/Volumes` is thrown away because a disk that may not be mounted must not
decide whether a tool exists. The home directory wins that test: a path inside
it is kept even when the home itself sits on an external volume.
`$HOME/.local/bin` is the same directory as `~/.local/bin` unless the
`HOME` variable in the environment says otherwise, in which case both are
searched. The same assembled PATH is handed to the tool as its environment when
`ed` runs it, and it is the same one Edith itself uses to run yt-dlp and to
read Codex limits, so what `ed tools ls` reports is what the app will find.

## Commands

### `ed tools ls`

Lists the three tools with their state, version and reason.

Usage:

```
ed tools ls [--json]
```

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emits one JSON document on stdout. |

There are no positional arguments, and there is nothing to filter or sort by:
the order is always `yt-dlp`, `claude`, `codex`.

`--json` shape, an array with one object per tool:

```json
[
  {
    "id": "yt-dlp",
    "installed": true,
    "name": "yt-dlp",
    "path": "/Users/pulkit/Library/Application Support/Edith/bin/yt-dlp",
    "version": "2026.07.04",
    "why": "Downloads YouTube audio into your Music library."
  },
  {
    "id": "claude",
    "installed": true,
    "name": "Claude Code",
    "path": "/Users/pulkit/.local/bin/claude",
    "version": "2.1.226 (Claude Code)",
    "why": "Includes Claude Code cloud sessions in Agent Usage."
  },
  {
    "id": "codex",
    "installed": true,
    "name": "Codex",
    "path": "/Users/pulkit/.local/bin/codex",
    "version": "codex-cli 0.146.0-alpha.9.2",
    "why": "Reads Codex session and weekly limits when that provider is enabled."
  }
]
```

`id` is what `install` takes. `name` is the display name the Settings row shows,
which differs from the id for two of the three. `why` is the sentence under that
name in the same row. A tool that is not installed keeps every key and nulls the
two that have no answer:

```json
{
  "id": "yt-dlp",
  "installed": false,
  "name": "yt-dlp",
  "path": null,
  "version": null,
  "why": "Downloads YouTube audio into your Music library."
}
```

`version` is also `null` when the tool is installed but printed nothing on
stdout for `--version`.

Examples:

```
ed tools ls
ed tools ls --json
ed tools ls --json | jq -r '.[] | select(.installed | not) | .id'
```

The table is four columns, and the last one is not padded:

```
$ ed tools ls
ID      STATE      VERSION                      WHY
yt-dlp  installed  2026.07.04                   Downloads YouTube audio into your Music library.
claude  installed  2.1.226 (Claude Code)        Includes Claude Code cloud sessions in Agent Usage.
codex   installed  codex-cli 0.146.0-alpha.9.2  Reads Codex session and weekly limits when that provider is enabled.
```

`STATE` is `installed` or `missing`, and a missing tool leaves `VERSION` blank
rather than printing a placeholder:

```
$ ed tools ls
ID      STATE      VERSION                      WHY
yt-dlp  missing                                 Downloads YouTube audio into your Music library.
claude  installed  2.1.226 (Claude Code)        Includes Claude Code cloud sessions in Agent Usage.
codex   installed  codex-cli 0.146.0-alpha.9.2  Reads Codex session and weekly limits when that provider is enabled.
```

Behaviour: `ls` reads no settings, posts no notification and needs neither the
main window nor the menu bar helper. It writes
`~/Library/Application Support/Edith`, which assembling the PATH creates when it
is not already there, and `tool-versions.json` inside it, which is the version
cache. The three tools are probed concurrently, one task each, and a tool with
no cached version, or one whose cached stamp no longer matches the binary's size
and modification time, is run once, with stdin on `/dev/null` and stderr
discarded, and waited for, so a cold run is only as slow as the slowest
`--version` on the machine and there is no timeout. A tool's exit status is ignored: presence is decided by the file being
executable, and the version is whatever first line came back.

While it probes it says so. A single spinner line on stderr reads
`probing 3 tools`, carries the seconds elapsed, is rewritten in place and is
erased before the table lands, so it leaves nothing in the transcript. It is
skipped entirely when stderr is not a terminal, when `--json` is passed, or when
`NO_COLOR` is set or `TERM` is `dumb`: stdout is the same either way.

### `ed tools install`

Installs one tool, or reports that it is already there.

Usage:

```
ed tools install <tool> [--json]
```

Arguments:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<tool>` | one of `yt-dlp`, `claude`, `codex`, or a display name: `yt-dlp`, `Claude Code`, `Codex` | required | Which tool to install. Matched case-insensitively against the id first, then against the display name. |

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emits one JSON document on stdout. |

Matching is exact, not by prefix: `CODEX` and `Claude Code` both resolve, `cla`
and `ytdlp` do not and exit 3 with the three ids as the hint. A display name
with a space in it has to be quoted, or the shell hands `ed` a second
positional and ArgumentParser rejects it with exit 2 before any id is looked
up.

`--json` shape when the tool is already installed:

```json
{
  "changed": false,
  "id": "yt-dlp",
  "installed": true,
  "path": "/Users/pulkit/Library/Application Support/Edith/bin/yt-dlp"
}
```

`--json` shape when it was missing and the install ran:

```json
{
  "changed": true,
  "id": "yt-dlp",
  "installed": true,
  "version": "2026.07.04"
}
```

The two shapes are not the same object with different values. `path` exists only
on the already-installed branch and `version` only on the branch that did the
work, so branch on `changed`: `installed` is `true` in both, because a failed
install prints no JSON at all, only the error and the hint on stderr.

Examples:

```
ed tools install yt-dlp
ed tools install codex --json
ed tools install "Claude Code"
```

A tool that is already present is reported and left alone. The line goes to
stderr, so stdout stays empty and the exit code is 0:

```
$ ed tools install yt-dlp
yt-dlp is already at /Users/pulkit/Library/Application Support/Edith/bin/yt-dlp
```

A missing tool is fetched here, and the command stays until it has landed,
printing each line the download or the package manager produces:

```
$ ed tools install yt-dlp

  EDITH · install yt-dlp
  ────────────────────────────────────────────────────
  · Downloading https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos
  · #####################                                                    29.4%
  · ######################################################################## 100.0%
  · Saved /Users/pulkit/Library/Application Support/Edith/bin/yt-dlp
  · 2026.07.04
  ✓ yt-dlp is ready

installed yt-dlp (2026.07.04)
```

Only the last line is on stdout. The header, the `·` rows and the `✓` are the
progress facility writing to stderr, and they are gone when stderr is not a
terminal or `--json` is passed. An install that cannot finish says why and what
to run instead:

```
$ ed tools install claude

  EDITH · install Claude Code
  ────────────────────────────────────────────────────
  · env: brew: No such file or directory
  · Homebrew was not found, checking npm.
  · env: npm: No such file or directory
  ✖ Neither Homebrew nor npm is available for installing Claude Code.
error: Neither Homebrew nor npm is available for installing Claude Code.
hint: Install with `brew install --cask claude-code` or `npm install -g @anthropic-ai/claude-code`.
```

An id that is not in the catalogue never reaches an install:

```
$ ed tools install ffmpeg
error: no tool called ffmpeg
hint: tools: yt-dlp, claude, codex
```

Behaviour: the presence check runs first, so an already-installed tool is
reported and exits 0 without touching the network. Only the other branch does
any work, and it does it here: `ToolInstaller` runs `curl`, `chmod` and a move
for yt-dlp, or `brew` and then `npm` for the two agent CLIs, in this process.
Nothing is posted at Edith and no part of it has to be running. Every line those
commands print is echoed as a `·` row as it arrives, which for the curl progress
bar is one row per redraw. When they finish, `ed` runs the tool's own
`--version` through the assembled PATH to prove it landed: a tool that cannot be
run there fails with `Installation finished, but <name> could not be verified.`
however well the install itself went. Any failure exits 4 with the reason as the
error and the tool's manual instruction as the hint, and writes nothing to
stdout, `--json` included.

## Exit codes

| Code | When this group produces it |
| --- | --- |
| 0 | The listing printed; the tool was already installed; the install finished and the tool answered `--version`. Also `--help` on the group or on either verb. |
| 2 | The command line was wrong in ArgumentParser's own terms: `ed tools install` with no tool, an unknown flag, or an extra argument (`ed tools ls extra` and `ed tools bogus` both land here, because the unmatched word is offered to the default subcommand `ls`, which takes none). |
| 3 | `install` was given something that is not one of `yt-dlp`, `claude` or `codex`, under either its id or its display name. |
| 4 | `install` ran and could not finish: neither Homebrew nor npm available, a `curl`, `chmod`, `brew` or `npm` that exited non-zero, or a tool that could not be verified afterwards. |

Nothing here exits 1. The only failures are a name that does not resolve and an
install that did not land.

## Notes and gotchas

- The PATH `ed` searches is assembled, not inherited, so `ed tools ls` and your
  shell can disagree in both directions. On this Mac yt-dlp is invisible to zsh
  and perfectly visible to `ed`, because it lives in the directory Edith
  installs into:

  ```
  $ yt-dlp --version
  zsh: command not found: yt-dlp

  $ ed tools ls --json | jq -r '.[] | select(.id == "yt-dlp") | .path'
  /Users/pulkit/Library/Application Support/Edith/bin/yt-dlp
  ```

  The reverse also happens: a tool that only exists in a directory under
  `/Volumes` is reported as missing however well it works in your shell.
- `ls` is not free the first time. It launches every installed tool to read a
  version, and the standalone macOS build of yt-dlp takes seconds to answer,
  which dominates the whole command:

  ```
  $ time ed tools ls > /dev/null
  ed tools ls > /dev/null  0.49s user 0.28s system 9% cpu 8.393 total
  ```

  Each answer is then kept in
  `~/Library/Application Support/Edith/tool-versions.json` against that binary's
  size and modification time, so the next run reads the file and launches
  nothing:

  ```
  $ time ed tools ls > /dev/null
  ed tools ls > /dev/null  0.02s user 0.01s system 126% cpu 0.019 total
  ```

  Update or replace a tool and its stamp stops matching, so the next `ls` probes
  that one again. The three probes run concurrently, so a cold run costs the
  slowest tool rather than the sum, and there is still no timeout around the
  call: a tool whose `--version` hangs hangs `ed tools ls` with it.
- `installed` means a file with that name is executable on the assembled PATH.
  It is not a claim that the tool runs. The exit status of `--version` is
  ignored here, while the app's own provisioner treats a non-zero status as
  missing, so a broken install can read `installed` in `ed tools ls` and still
  show as missing in Settings.
- `install` is not fire and forget. It runs the download or the package manager
  itself and does not return until the tool has answered `--version`, so a zero
  exit means the tool is there and `ed tools ls` will say so. The Extensions
  pane, its setup sheet and the onboarding flow drive the same `ToolInstaller`
  from the app. The app keeps one install per tool at a time; `ed` knows nothing
  about those, so do not start the same tool from both at once.
- A failure reads twice in a terminal, once as the red `✖` row and once as the
  `error:` line. The progress rows are skipped when stderr is not a terminal or
  when `--json` is passed, and the `error:` line never is, so a piped run shows
  the reason exactly once.
- There is no uninstall and no `--yes` guard. `install` never touches a tool
  that is already on PATH, and the only file it removes is a leftover at
  `~/Library/Application Support/Edith/bin/yt-dlp` that the fresh download
  replaces, so the worst a wrong id can do is exit 3.
- `codexLimitsEnabled` decides whether the Agent Usage sheet insists on `codex`
  before it considers itself set up. It has no effect on `ed tools`, which
  lists and installs all three regardless. Turning the Music or Agent Usage
  extension off does not remove anything either: tools stay installed when the
  extension that wanted them is disabled.
- The relation between tools and extensions is readable from the other side:
  `ed extensions info music --json` reports `"requiredTools": ["yt-dlp"]` and
  `ed extensions info usage --json` reports `["claude", "codex"]`.
- `ed download tool` is the second view of the same yt-dlp. It prints the
  version and path of the binary found on the same assembled PATH, and
  `ed download tool --update` runs `yt-dlp -U` on it. The two disagree on tone
  when the tool is absent: `ed tools ls` prints a `missing` row and exits 0,
  `ed download tool` exits 4 with `yt-dlp is not installed`.
- The `why` column is the tool spec's own sentence, not a summary written for
  the CLI, so it is word for word what the setup sheet shows under the tool's
  name. The Settings row shows the same sentence until it has checked, then
  replaces it with `Installed, <version>` or with the failure and its manual
  instruction.
- Completion knows the verbs but not the tools. `ed tools <TAB>` offers `ls`
  and `install`; `ed tools install <TAB>` offers nothing at all, because the
  completion tree marks that argument free rather than pointing it at the
  catalogue. Type the id.
- Both verbs take `--json` in its usual form, long only, declared per verb.
  There is no `-j`, and `ed tools --json` works only because the bare group
  falls through to `ls`.

## Where to go next

- [`ed download`](./download.md), the queue yt-dlp serves, and the
  `ed download tool` verb for updating it in place.
- [`ed extensions`](./extensions.md), which is where `requiredTools` comes from
  and where turning a feature on can want a tool.
- [`ed usage`](./usage.md), the numbers `claude` and `codex` make possible.
- [All `ed` commands](./README.md).
