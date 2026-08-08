# Getting started with `ed`

`ed` is the command line for Edith, the macOS menu bar app. It ships inside the
app bundle, links itself onto your `PATH` the first time the app runs, and
reaches everything the UI reaches: settings, extensions, permissions, agent
usage, this Mac's metrics, playback, your calendar, and the machines Edith can
talk to over SSH.

`ed`, `edh` and `edith` are one command line under three names. `ed` and
`edith` are symlinks to the same binary, `edh` is a second executable built from
the same sources, and all three run the same entry point with the same
arguments, so every example on this page and everywhere else works with any of
them. Pick whichever name your shell leaves free.

This page covers the commands you meet before any of the others: getting the
links in place, reading the built-in manual, printing the config schema,
checking the version, and wiring up shell completion. None of it needs Edith to
be running.

## At a glance

| Command | What it does |
| --- | --- |
| `ed install` | Link `ed`, `edh` and `edith` into a directory on `PATH` |
| `ed uninstall` | Remove those three links again, and nothing else |
| `ed guide` | Print the built-in manual, written for agents and humans alike |
| `ed guide claude` | Print a `CLAUDE.md` snippet that makes another repo `ed`-aware |
| `ed schema` | Print the JSON Schema for the configuration document |
| `ed version` | Print the CLI version, and with `--json` whether the app is running |
| `ed completions` | The completion group; with no subcommand it runs `install` |
| `ed completions install` | Write completion scripts for the shells found on this Mac |
| `ed completions zsh` | Print the zsh completion script on stdout |
| `ed completions bash` | Print the bash completion script on stdout |
| `ed completions fish` | Print the fish completion script on stdout |
| `ed __complete` | Hidden: the candidate generator every completion script calls |

## Installing and linking

Installing Edith installs the CLI. On launch the menu bar app links `ed`, `edh`
and `edith` into `/usr/local/bin` when that directory is writable, and into
`~/.local/bin` otherwise, and it only redoes the work when the links do not
already point at the copies inside the bundle.

The directory rule is the same wherever it is applied: `/usr/local/bin` if the
current user can write to it, `~/.local/bin` if not. `ed install --directory`
overrides it and creates the directory when it is missing. `ed uninstall` does
not take the flag at all, and only ever looks in the default one.

The three links are not identical. `ed` and `edith` both point at the bundled
`ed` binary; `edh` points at the separate `edh` binary beside it. That is why a
build that produced only one of them links some names and skips others.

Building from source without the app bundle:

```
make cli
```

That builds `ed` and `edh` in release configuration, runs
`.build/release/ed install --directory $HOME/.local/bin`, and then
`.build/release/ed completions install`. It is the supported way to get a
working `ed` out of a checkout, and running `install` from the build product
rather than from a link is the part that matters, for the reason in
[`ed install`](#ed-install) below.

## Commands

### `ed install`

Links `ed`, `edh` and `edith` into a directory on your `PATH`.

```
ed install [--json] [--directory <directory>]
```

Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of a sentence |
| `--directory <directory>` | path, `~` expanded | `/usr/local/bin` when writable, otherwise `~/.local/bin` | Link into this directory instead of the default |

`--json` shape:

```json
{
  "directory": "/Users/pulkit/.local/bin",
  "linked": [
    "ed",
    "edh",
    "edith"
  ],
  "message": null,
  "onPath": true,
  "skipped": []
}
```

Examples

```
ed install
ed install --directory ~/bin
ed install --json
/Applications/Edith.app/Contents/MacOS/ed install
```

A name that is already linked to the right binary is left alone and appears in
neither `linked` nor `skipped`, so a second `ed install` in a row reports an
empty list and still exits 0. A name occupied by a real file is left alone and
listed in `skipped`, because the installer never overwrites something it did not
create. A name occupied by a symlink is replaced whatever it points at, which is
how a stale link from an older install gets repaired.

`onPath` compares the target directory against the entries of `PATH` after
standardising both, so a match is exact rather than textual. When it is false
the human output adds `note: <directory> is not on PATH` on stderr and still
exits 0, because the links were made either way.

`message` is the one failure this command reports: when no `ed` binary can be
found near the running executable it says `the ed binary is not present in this
build`. With `--json` that lands in the `message` field and the command exits 0;
without `--json` it becomes an error and exits 1. Read `message` if you are
gating on this in a script.

The installer finds the binaries to link by walking up from the directory of the
executable that is running and taking the first directory that holds an
executable called `ed`, checking `Contents/MacOS` at each step. Run it through a
link that is already on your `PATH` and that search stops at the link directory
itself, so `ed` and `edh` are relinked onto themselves and stop working, and
`edith` is then reported as skipped because its source no longer resolves. Run
it from the copy inside the app, or from the build product, never through the
link:

```
/Applications/Edith.app/Contents/MacOS/ed install
apps/macos/.build/release/ed install --directory $HOME/.local/bin
```

That second line is what `make cli` runs. If the self-link has already happened,
the first line puts everything back.

### `ed uninstall`

Removes the `ed`, `edh` and `edith` links, and leaves everything else in place.

```
ed uninstall [--json]
```

Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of a sentence |

`--json` shape:

```json
{
  "directory": "/Users/pulkit/.local/bin",
  "removed": [
    "ed",
    "edh",
    "edith"
  ]
}
```

Examples

```
ed uninstall
ed uninstall --json
```

The key is `removed`, not `linked`; `install` and `uninstall` do not share a
field name for the list of names they touched.

There is no `--directory` here. Uninstall always looks in the same preferred
directory `install` would have chosen, so links you placed elsewhere with
`ed install --directory ~/bin` are not removed and have to be deleted by hand.
Only symlinks are removed, and any symlink at one of those three names goes
whatever it points at. A regular file called `ed` is left alone.

Nothing about it can fail: an empty directory prints `nothing to remove in
<directory>` and exits 0.

### `ed guide`

Prints the built-in manual, the same text the app ships to explain itself.

```
ed guide [<topic>]
```

Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<topic>` | `claude`, case-insensitive | none, meaning the full manual | Which text to print |

There is no `--json`. The output is prose, it is static, and it needs neither
the app, the network, nor a machine.

Examples

```
ed guide
ed guide claude
ed guide | less
```

`ed guide claude` prints a section you can paste into any repository's
`CLAUDE.md` so an agent working there knows `ed` exists, knows every read
command takes `--json`, and knows the exit codes are worth gating on.

Any topic other than `claude` exits 3 and says what the two options are:

```
$ ed guide nope
error: no guide topic named nope
hint: try `ed guide` or `ed guide claude`
```

### `ed schema`

Prints the JSON Schema for the whole configuration document.

```
ed schema
```

It declares no options of its own. `--help` and `--version` come from the
argument parser. There is no `--json` flag because the output is already a JSON
document, always pretty printed with two-space indentation and sorted object
keys.

Shape, with one property per writable setting. Three real ones shown:

```json
{
  "$id": "https://edith.pulkit.page/schema/config.json",
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "additionalProperties": false,
  "description": "Every setting the Edith UI exposes, as accepted by `ed config import`. Keys map one to one onto the preferences the app reads at runtime.",
  "properties": {
    "clipboardIgnoredApps": {
      "description": "Comma separated bundle identifiers never captured.",
      "type": "string",
      "x-format": "comma-separated",
      "x-group": "clipboard",
      "x-scope": "shared"
    },
    "limitsProvider": {
      "default": "claude",
      "description": "Provider shown first in the limits UI.",
      "enum": [
        "claude",
        "codex"
      ],
      "type": "string",
      "x-group": "limits",
      "x-scope": "shared"
    },
    "musicFavourites": {
      "description": "Relative paths of favourited tracks.",
      "items": {
        "type": "string"
      },
      "type": "array",
      "x-group": "music",
      "x-scope": "shared"
    }
  },
  "title": "Edith configuration",
  "type": "object"
}
```

Every property carries `description`, `x-group` and `x-scope`, where the scope
is `shared` for the suite both surfaces read and `standard` for the app's own
defaults. `type` is `boolean`, `integer`, `number`, `string`, `array` or
`object`. A comma-separated setting is typed as `string` and marked
`x-format: comma-separated`; a list setting is typed as `array` with
`items: {"type": "string"}`. `enum` appears only when the setting has an allowed
set, and `default` only when it has a fallback, so a setting with no fallback
simply has no `default` key rather than a null one.

Read-only settings are left out of the document entirely, and there are more of
them than the `perm*Granted` mirror of macOS permission state and the
`last*BackupAt` timestamps: everything the app records about itself is read-only
too, `micMuted`, `musicLastTrack`, `presenterAutoActive` and `notifSessionLevel`
among them. `ed config import` would refuse all of it anyway.

Examples

```
ed schema > edith-config.schema.json
ed schema | jq '.properties.limitsProvider'
ed schema | jq -r '.properties | keys[]'
```

### `ed version`

Prints the CLI version, and with `--json` whether Edith is running.

```
ed version [--json]
```

Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the bare version string |

`--json` shape:

```json
{
  "appRunning": true,
  "version": "1.0.0"
}
```

Examples

```
ed version
ed version --json
ed --version
```

`appRunning` is about the menu bar helper, bundle id
`com.pulkit.edith.statusbar`, not the main window, because the helper is what
answers the commands that need the app. This is the polite way to find out: it
reports the state and exits 0 either way, where a command that actually needs
the app exits 4.

`ed --version` prints the same string through the argument parser. The version
is declared on the root command, so it is inherited: `ed schema --version` and
`ed machines ls --version` also print `1.0.0` and exit 0.

### `ed completions`

The group that generates and installs shell completion.

```
ed completions [install|zsh|bash|fish]
```

`install` is the default subcommand, so a bare `ed completions` writes the
scripts rather than printing help. Ask for `ed completions --help` if that is
what you wanted.

### `ed completions install`

Writes completion scripts for the shells found on this Mac, and wires them into
the shell profile.

```
ed completions install [--json] [--shell <zsh|bash|fish>]
```

Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of one line per shell |
| `--shell <shell>` | `zsh`, `bash` or `fish`, lowercased before matching | unset, meaning every detected shell | Install for one shell instead of all of them |

`--json` shape:

```json
{
  "installed": [
    {
      "hint": null,
      "path": "/Users/pulkit/.zsh/completions/_ed",
      "shell": "zsh"
    },
    {
      "hint": "add to ~/.bashrc: source /Users/pulkit/.local/share/bash-completion/completions/ed",
      "path": "/Users/pulkit/.local/share/bash-completion/completions/ed",
      "shell": "bash"
    }
  ]
}
```

Examples

```
ed completions install
ed completions install --shell zsh
ed completions install --json
```

Detection is by evidence on disk. zsh is always included. bash is included when
`~/.bashrc` or `~/.bash_profile` exists. fish is included when `~/.config/fish`
exists.

Where each script lands:

```
zsh    the first writable directory under $HOME in an interactive shell's
       $fpath, else ~/.local/share/zsh/site-functions/_ed
bash   ~/.local/share/bash-completion/completions/ed
fish   ~/.config/fish/completions/ed.fish
```

The zsh case really does ask zsh: it runs `/bin/zsh -ic 'print -l -- $fpath'`
and takes the first entry under your home directory that exists, is a directory
and is writable, which is why a machine with `~/.zsh/completions` on `$fpath`
gets the script there instead of in the fallback location.

Installing does three things beyond writing the file. It records the path in the
shared defaults under `completionScriptPaths`, which is what lets the app
rewrite an out-of-date script on launch when `completionsAutoRefresh` is on, and
that refresh only ever overwrites a file that already contains `__complete`. It
adds a managed block to `~/.zshrc` for zsh and `~/.bashrc` for bash, with
`$HOME` substituted back into the path:

```
# >>> edith completions >>>
source $HOME/.zsh/completions/_ed
# <<< edith completions <<<
```

And it prints the one line you may still need to add yourself, as `hint`. zsh
gets `add to ~/.zshrc, before compinit: fpath=(<directory> $fpath)` unless the
script went into a directory zsh already searches, in which case the hint is
null. bash gets `add to ~/.bashrc: source <directory>/ed`. fish never gets a
hint and never gets a profile edit, because fish loads that directory by itself.

The human output is one `shell: path` line per shell, with the hint indented two
spaces underneath it.

A `--shell` value that is not one of the three exits 3 before anything is
written:

```
$ ed completions install --shell nope
error: nope is not a supported shell
```

The shell is an option, not a positional, and completion offers the three names
in the positional slot as well. `ed completions install zsh` is rejected by the
parser and exits 2; write `--shell zsh`.

### `ed completions zsh`

Prints the zsh completion script on stdout so you can place it yourself.

```
ed completions zsh
```

No options of its own; `--help` and `--version` are generated. What it prints is
byte for byte what `install` would have written, so redirecting it into the
right directory is a complete substitute for installing, minus the profile edit
and the recorded path.

Examples

```
ed completions zsh
ed completions zsh > ~/.zsh/completions/_ed
```

The script starts with `#compdef ed edh edith` and defines `_ed_complete`, which
shells out to `ed __complete --index $((CURRENT-1)) -- "${words[@]}"`, treats a
line of `#files` as a call to `_files`, and passes everything else to `compadd`.
It handles being loaded either as an autoloaded function or sourced directly.

### `ed completions bash`

Prints the bash completion script on stdout.

```
ed completions bash
```

No options of its own; `--help` and `--version` are generated.

Examples

```
ed completions bash
ed completions bash > ~/.local/share/bash-completion/completions/ed
```

It defines `_ed_complete`, calls `ed __complete --index "$COMP_CWORD" --
"${COMP_WORDS[@]}"`, expands a `#files` line with `compgen -f`, and ends with
`complete -o bashdefault -F _ed_complete ed edh edith`.

### `ed completions fish`

Prints the fish completion script on stdout.

```
ed completions fish
```

No options of its own; `--help` and `--version` are generated.

Examples

```
ed completions fish
ed completions fish > ~/.config/fish/completions/ed.fish
```

It defines `__ed_complete`, calls `ed __complete --index (count $tokens) --
$tokens $current`, expands `#files` with `__fish_complete_path`, and registers
the function for all three command names.

### `ed __complete`

The hidden command every completion script calls. It takes the command line you
are typing and prints the candidates for one word of it.

```
ed __complete [--index <n>] [--] <words>...
```

Arguments and options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--index <n>` | integer, zero based | `0` | Which word of `<words>` is being completed |
| `<words>` | everything else, captured verbatim | empty | The whole command line, including the program name at index 0. A leading `--` is dropped |

It is marked as not displayed, so it never appears in `ed --help`, but it is a
reserved name, so a machine called `__complete` can never shadow it. It has no
`--json`: the output is one candidate per line, and the literal line `#files`
means "also offer local file names here". No candidates means no output, and it
exits 0 either way.

It is also the one command with no working `--help`. Everything that is not
`--index` is captured verbatim, so `ed __complete --help` completes the word
`--help` and prints it straight back rather than printing help, and
`ed __complete --version` does the same instead of printing the version.

Examples

```
$ ed __complete --index 1 -- ed co
completions
config
color

$ ed __complete --index 4 -- ed config set limitsProvider ""
claude
codex

$ ed __complete --index 3 -- ed shelf add ""
#files
```

## How completion is wired

Completion is dynamic rather than a static word list. Each shell script is a
thin shim: it hands the words and the cursor position to `ed __complete` and
prints back whatever comes out, so the candidates are computed by the same
binary you are running and cannot drift out of date with it.

The path to `ed` is baked into the script when it is generated. The generator
uses the installed copy in the preferred directory when that is executable,
otherwise the copy inside the app bundle, otherwise the bare word `ed`, and the
script falls back to `ed` on `PATH` at runtime if the baked path is not
executable. That is what keeps completion working when the app moves.

What `__complete` offers, in the order it decides:

- If the first word after `ed` names a configured machine and is not a command,
  the whole thing is handed to that machine. See below.
- If the word being completed starts with `-`, the candidates are that command's
  options plus `--json` and `--help`.
- Otherwise the candidates are the subcommand names at that point, plus every
  configured machine name at the top level, plus the values for whichever
  positional slot the cursor is in.

The typed slots are what make it useful: machine names where a machine goes,
setting keys where a key goes, that setting's allowed values where its value
goes (`ed config set limitsProvider <TAB>` gives `claude codex`, and a boolean
setting gives `true false`), extension ids, permission ids, shell names, config
groups, usage ranges, app action names, cleaner category ids, colour formats and
docker prune targets in their own slots, and `#files` where a local path goes.
Matching is a case-sensitive prefix, and duplicates are dropped while the order
is kept.

Remote completion is the interesting one. `ed tuf docker <TAB>` does not consult
a list of docker subcommands baked into `ed`; it asks the machine. At the first
word after the machine name `ed` runs `compgen -c` there, so you get commands
from the remote `PATH`. After `cd`, `pushd` or `rmdir` it runs `compgen -d`, so
you get directories. Anywhere else it runs a small bash harness that sources the
machine's own bash-completion, calls `_completion_loader` for the command you
are typing, finds the function registered with `complete -F`, and runs it, so
`ed tuf systemctl sta<TAB>` and `ed tuf apt <TAB>` complete against the tools
installed there, including ones `ed` has never heard of. Whichever of the three
runs, it is prefixed with the directory that machine's `cd` last left you in and
given six seconds; the command and directory lookups are also capped at 2000
entries. Whatever comes back is filtered by the prefix you have typed.

Remote completion only runs when a ControlMaster socket for that machine is
already open. Pressing TAB never dials a sleeping host and never blocks the
shell; with no open connection you get no candidates at all, silently and
immediately:

```
$ ed __complete --index 2 -- ed tuf upt
$ echo $?
0
```

One caveat worth knowing: the tree `__complete` walks is a hand-maintained
mirror of the command surface rather than something derived from the parser. A
new flag completes only once it has been added there too, and a group command
can be offered `--json` and `--help` even where only its subcommands take them.

## The machine shorthand

Naming a machine as the first word runs the rest of the line there:

```
ed tuf uptime
ed tuf docker compose up -d
ed tuf systemctl status nginx
ed tuf 'ls -la /srv | head'
```

This happens before the parser sees anything. The raw arguments are rewritten
against the machine list loaded from Edith's own machines file, and the rules
are short:

- A first word starting with `-` is left alone, so `ed --help` and `ed
  --version` behave normally.
- A first word that is one of Edith's own command names is left alone. The
  reserved set is every top-level command name and alias, plus `help` and
  `__complete`, so `music`, `np`, `dl`, `colour` and the rest all win.
- A first word that equals a configured machine's display name or its ssh config
  alias, ignoring case, is a machine. It has to be the whole name: a prefix does
  not trigger the shorthand, even though a prefix does resolve once the command
  is running.
- With something other than flags after it, the line becomes
  `ed machines exec <machine> -- <rest>`. With nothing after it, or only flags,
  it becomes `ed machines show <machine>`.

`ed machines <machine> <subcommand...>` is reshuffled the same way, so the
machine can come second and read naturally. The rewriter consumes subcommand
names from the machines subtree until it hits a flag or a word that is not a
subcommand, then puts the machine after them:

| What you type | What actually runs |
| --- | --- |
| `ed tuf` | `ed machines show tuf` |
| `ed tuf --json` | `ed machines show tuf --json` |
| `ed tuf uptime` | `ed machines exec tuf -- uptime` |
| `ed machines tuf` | `ed machines show tuf` |
| `ed machines tuf metrics --follow` | `ed machines metrics tuf --follow` |
| `ed machines tuf docker ps` | `ed machines docker ps tuf` |
| `ed machines tuf files ls /var/log` | `ed machines files ls tuf /var/log` |

Edith's own command names win over machine names, in both positions. A machine
called `usage` still needs `ed machines exec usage -- ...`, and a machine called
`ls` or `docker` needs `ed machines show ls`, because after `ed machines` a word
that is a subcommand of `machines` is read as that subcommand. A machine name
with spaces needs quoting, and quoting is enough: `ed "Asus TUF 7" uptime`
works.

The reserved list comes from the same hand-maintained tree that drives
completion, not from the parser, so it is the tree that decides which names a
machine can never take.

## Exit codes

Only the codes this page's commands produce.

| Code | What produced it |
| --- | --- |
| 0 | The command did what it says, including `ed install` reporting a problem in the `message` field of `--json`, `ed uninstall` finding nothing to remove, and `--help` or `--version` on any command but `__complete`, which captures both as words and still exits 0 |
| 1 | `ed install` without `--json` when no `ed` binary can be found near the running executable, or a write that fails while `ed completions install` is creating a script |
| 2 | The command line was wrong: an unknown flag, a missing value, or a positional the command does not take, such as `ed completions install zsh` |
| 3 | `ed guide <topic>` for any topic other than `claude`, or `ed completions install --shell <anything but zsh, bash or fish>` |

Nothing on this page returns 4. None of these commands needs Edith to be
running, which is the point: they are what you run before, or instead of,
anything that does.

## Notes and gotchas

- Every command here works with Edith closed. `ed version --json` reports
  `appRunning` as a fact rather than failing on it, and the rest do not care.
- Diagnostics go to stderr as `error:` and `hint:` lines, and notes such as
  `note: <directory> is not on PATH` go there too, so stdout stays exactly one
  document you can pipe.
- Object keys in every JSON document are sorted, indentation is two spaces, and
  a field with no value is present as `null` rather than dropped. `ed install
  --json` always has a `message` key even when nothing went wrong.
- Run `ed install` from the app's own copy or from a fresh build, never through
  a link already on your `PATH`, or you will relink `ed` and `edh` onto
  themselves. `make cli` gets this right.
- `ed uninstall` looks only in the default directory. Links placed with
  `ed install --directory` survive it.
- `ed install` replaces any symlink at those names, and `ed uninstall` removes
  any symlink at those names, in both cases without asking where it points. A
  regular file with one of those names is never touched.
- The menu bar app relinks the CLI on launch when the links are wrong, and
  rewrites the completion scripts when `completionsAutoRefresh` is set and the
  script it wrote is stale. It does both on a background queue, and neither ever
  overwrites a regular file: relinking only ever replaces a symlink, and the
  refresh only rewrites a script that already contains `__complete`.
- `ed completions install` edits `~/.zshrc` and `~/.bashrc`, inside a marked
  block it can find again. Removing the block by hand is enough to undo it.
- `ed completions` with no subcommand installs. It does not print help.
- `ed schema` output is what `ed config import` accepts, so it is worth keeping
  next to any configuration you generate.

## Where to go next

- [`ed config`](./config.md), which is what `ed schema` describes and what
  `ed guide` points at first.
- [`ed machines`](./machines.md), for everything the machine shorthand is
  shorthand for.
- [All the command pages](./README.md).
