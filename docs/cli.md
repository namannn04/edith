# The `ed` command line

`ed` is the command line for Edith. It ships inside the app, links itself onto
your `PATH` the first time the app runs, and reaches everything the UI reaches:
settings, extensions, permissions, agent usage, this Mac's metrics, playback,
your calendar, and the machines Edith can talk to over SSH.

`edh` and `edith` are the same binary under different names. Every example below
works with any of the three.

The built-in manual is `ed guide`, which is written for agents and humans alike
and is the shortest path to being useful. This page is the complete reference.

## Contents

- [Install](#install)
- [Conventions](#conventions)
- [Shell completion](#shell-completion)
- [`ed guide`, `ed schema`, `ed version`](#ed-guide-ed-schema-ed-version)
- [`ed config`](#ed-config)
- [`ed extensions`](#ed-extensions)
- [`ed permissions`](#ed-permissions)
- [`ed usage`](#ed-usage)
- [`ed system`](#ed-system)
- [`ed music`](#ed-music)
- [`ed calendar`](#ed-calendar)
- [`ed machines`](#ed-machines)
- [Running a command on a machine](#running-a-command-on-a-machine)
- [What needs the app running](#what-needs-the-app-running)

## Install

Installing Edith installs the CLI. On launch the app links `ed`, `edh` and
`edith` into `/usr/local/bin` when that directory is writable, and into
`~/.local/bin` otherwise. It only ever replaces links it owns; a real file of
the same name is left alone and reported as skipped.

To place the links yourself:

```
ed install                       link into the default directory
ed install --directory ~/bin     link somewhere specific
ed install --json                the directory, what was linked, and whether it is on PATH
ed uninstall                     remove the links, leave everything else
```

Building from source without the app bundle:

```
make cli                         builds ed and edh, links them, installs completions
```

## Conventions

These hold for every command, and they are the contract an agent should rely on.

- **`--json` on every read command.** stdout is exactly one JSON document.
  Object keys are sorted, so output diffs cleanly.
- **stdout is data, stderr is commentary.** Errors, hints and notes go to
  stderr. On failure stdout may be empty.
- **Exit codes are the contract.**

  | Code | Meaning |
  | --- | --- |
  | 0 | success |
  | 1 | the command failed |
  | 2 | the command line was wrong (unknown flag, missing argument) |
  | 3 | the thing you named does not exist (machine, setting, extension) |
  | 4 | unavailable: the app is not running, a machine is down, a permission is missing |

  `ed machines exec` is the exception in a useful way: it propagates the remote
  command's own exit code.
- **Discover, then act.** `ed machines ls`, `ed config ls`, `ed extensions ls`
  and `ed usage sources` are cheap and tell you the exact names every other
  command expects.
- **Names are forgiving.** Machines resolve by display name, SSH alias, id, or
  any unambiguous prefix, case-insensitively. An ambiguous prefix fails with the
  list of matches rather than guessing.

## Shell completion

```
ed completions install              write scripts for every shell found
ed completions install --shell zsh  just one
ed completions zsh                  print the script, place it yourself
ed completions bash
ed completions fish
```

`install` writes to `~/.local/share/zsh/site-functions/_ed`,
`~/.local/share/bash-completion/completions/ed` and
`~/.config/fish/completions/ed.fish`, and prints the one line you may need to
add to your shell's rc file. `make cli` runs it for you.

Completion is dynamic, not a static word list. It offers:

- command names at the top level, plus every configured machine
- setting keys where a key goes, and that setting's allowed values where a value
  goes (`ed config set limitsProvider <TAB>` gives `claude codex`)
- extension ids, permission ids, usage ranges, config groups and shell names in
  their own slots
- file paths where a local path goes
- **after a machine name, whatever that machine would have completed**

That last one is the interesting one. `ed tuf docker <TAB>` does not consult a
list of docker subcommands baked into `ed`; it asks the machine. `ed` runs the
remote shell's own programmable completion for the command you are typing and
returns what it produced, so `ed tuf docker compose <TAB>`, `ed tuf systemctl
sta<TAB>` and `ed tuf apt <TAB>` all complete against the tools installed there,
including ones `ed` has never heard of. At the first word after the machine name
it completes command names from the remote `PATH` instead.

Remote completion only runs when a ControlMaster socket for that machine is
already open. Pressing TAB never dials a sleeping host and never blocks the
shell; with no open connection you simply get no remote candidates.

## `ed guide`, `ed schema`, `ed version`

```
ed guide            the built-in manual
ed guide claude     a CLAUDE.md snippet that makes another repo ed-aware
ed schema           JSON Schema for the configuration document
ed version [--json] the CLI version, and whether the app is running
```

`ed guide claude` prints a section you can paste into any repository's
`CLAUDE.md` so an agent working there knows `ed` exists and how to use it.

## `ed config`

Every preference the UI writes is a key in the same defaults suite the app
reads. A change made here reaches the running app immediately: `ed` posts the
same `settingsChanged` notification the app posts to itself.

```
ed config ls [prefix] [--group <g>] [--changed] [--json]
ed config get <key> [--json]
ed config set <key> <value> [--json]
ed config unset <key> [--json]
ed config describe <key> [--json]
ed config export [--defaults] > edith.json
ed config import <file|-> [--dry-run] [--json]
```

`ls` prints key, group, type and current value. `--group` narrows to one of:
`appearance panel usage limits menubar alerts budget dashboard machines finder
system cleaner music calendar clipboard notch focusdim presenter colorpicker
micmute backup permissions`. `--changed` shows only settings with a stored
value.

`describe` is what to read before writing something you are unsure of:

```
$ ed config describe limitsProvider
limitsProvider
  Provider shown first in the limits UI.
  type     string
  group    limits
  scope    shared
  allowed  claude, codex
  default  claude
  value    claude
```

`set` validates before it writes. An unknown key exits 3 with near matches; a
value of the wrong type or outside the allowed set exits 1 and nothing is
written. Booleans accept `true/false`, `yes/no`, `on/off`, `1/0`,
`enabled/disabled`. List settings take a comma-separated value.

A handful of keys are read only, because the app owns them: the
`perm*Granted` mirror of macOS permission state and the `last*BackupAt`
timestamps. Writing one exits 1.

`export` emits only the settings you have actually changed, which is exactly
what `import` accepts, so moving your setup to another Mac is a two-command
operation. `--defaults` includes everything at its current effective value.
`--dry-run` reports what would change without writing.

Useful ones:

```
ed config set preventSleep true          Keep Awake on
ed config set presenterMode true         Presenter mode on right now
ed config set presenterAutoEnabled true  and turn it on automatically when sharing
ed config set warnPercent 70             amber threshold for rate limits
ed config set limitsInMenuBar false      hide the menu bar percentages
ed config set appearance dark
```

## `ed extensions`

Extensions are settings, but they get their own verbs because turning one on can
need a macOS permission.

```
ed extensions ls [--json]
ed extensions enable <id> [--json]
ed extensions disable <id> [--json]
ed extensions info <id> [--json]
```

Ids are `usage system machines systemStats micMute music calendar notchShelf
clipboard focusDim presenter colorPicker`. Enabling one whose required
permission is missing still enables it and prints, on stderr, which permission
to request. `info --json` includes `missingRequiredPermissions` so an agent can
check without parsing prose.

## `ed permissions`

A command line process cannot read another application's TCC state, and it must
not try: the grants belong to the Edith bundle, not to `ed`. So `ed` reports
what the app itself last observed and mirrored into its preferences, and asks
the app to do anything that needs a real prompt.

```
ed permissions ls [--attention] [--json]
ed permissions refresh [--json]
ed permissions request <permission> [--json]
```

`refresh` asks the running app to re-read the real state and then reports it;
run it if you suspect the mirror is stale. `request` asks the app to raise the
system prompt, waits, and reports whether the grant landed. Both need the app
running and exit 4 otherwise.

`ls --json` includes `appRunning` so you can tell a stale mirror from a live
one. Bluetooth and Automation are granted by macOS on first use and cannot be
requested ahead of time; asking exits 4 and says so.

## `ed usage`

Numbers come from the same `usage.json` the dashboard reads and the same
`limits-history.jsonl` the rings read. `ed` does not re-derive anything, so the
CLI and the UI cannot disagree.

```
ed usage limits [--json]
ed usage summary [--range <r>] [--source <s>]... [--json]
ed usage daily   [--range <r>] [--source <s>]... [--json]
ed usage models  [--range <r>] [--source <s>]... [--json]
ed usage projects [--range <r>] [--limit <n>] [--json]
ed usage sources [--json]
ed usage refresh [--no-wait] [--json]
```

`--range` is `today`, `week` (last 7 days), `month` (last 30) or `all`, and
defaults to `all`. `--source` filters to one agent and repeats;
`ed usage sources` lists the valid values.

```
$ ed usage limits
PROVIDER  SESSION  WEEKLY  SESSION RESETS  OBSERVED
Codex     -        100.0%  -               2026-08-06T22:57:22Z
Claude    46.0%    34.0%   3h 27m          2026-08-06T23:02:21Z
```

`limits --json` gives each provider a `session` and `weekly` object with
`percent`, `resetsAt` and `resetsInSeconds`, or `null` where the provider has
never reported that window.

`refresh` asks the running app to re-collect, and waits for it to finish so you
can gate on the exit code; `--no-wait` returns as soon as the request is sent.
It needs the app running. Everything else reads files and works whether the app
is running or not, though it exits 4 if the Agent Usage extension has never
collected anything.

## `ed system`

```
ed system stats [--follow] [--interval <s>] [--processes <n>] [--json]
ed system disks [--json]
```

`stats` samples CPU, memory, load, uptime and network for this Mac using the
same sampler the app's local machine view uses. `--follow` keeps sampling until
interrupted; with `--json` each sample is one compact JSON document per line, so
it pipes into `jq` cleanly. `--processes n` includes the top n processes by CPU.

## `ed music`

```
ed music status [--json]
ed music play | pause | toggle | next | previous
ed music volume <0..1>
```

Playback lives in the menu bar app, so these talk to it over the app's own
notification bus. `status --json` reports the track's relative path, title,
play state, elapsed and total seconds, volume, and the loop and shuffle flags.
They exit 4 when the app is not running or the Music extension is off.

## `ed calendar`

```
ed calendar ls [--days <n>] [--json]
```

Events come from the running app, because the calendar grant belongs to the
Edith bundle. `--days` limits to events starting within that window, default 7.
Output carries title, calendar name, start, end, all-day flag, location and a
detected meeting link.

This exits 4 with a specific reason when it cannot answer: the app is not
running, the Calendar extension is off, or macOS has not granted Edith calendar
access.

## `ed machines`

Machines come from Edith's own machine list, so `ed` never asks you to re-enter
a host. Transport is `/usr/bin/ssh` over a ControlMaster socket shared with the
app: if the app already holds a connection, `ed` reuses it and each command is
one round trip on an open channel. If it does not, `ed` opens one, and that
socket outlives the process so the next command is fast.
`ed machines disconnect` closes it.

```
ed machines ls [--json]
ed machines show <machine> [--json]
ed machines metrics <machine> [--follow] [--interval <s>] [--processes <n>] [--json]
ed machines exec <machine> [--] <command...>
ed machines services <machine> [--failed] [--json]
ed machines connect <machine> [--json]
ed machines disconnect <machine> [--json]
```

`metrics` streams the same collector the app's Machines view uses, over stdin,
so nothing is installed on the machine. Without `--follow` it prints one sample
and exits; with it, a sample every `--interval` seconds. `--json` gives cpu
(total, steal, per core), memory (including swap and buff/cache), load, tasks,
uptime, per-device disk throughput, per-interface network throughput, and
optionally the top processes.

`services` parses `systemctl list-units`; `--failed` narrows to failed units.
On a machine without systemd it reports nothing rather than failing.

### Files

```
ed machines files ls  <machine> [path] [--all] [--json]
ed machines files get <machine> <remote> [local] [--json]
ed machines files put <machine> <local> <remote> [--json]
```

`ls` defaults to the remote home directory and hides dotfiles unless `--all`.
`get` defaults the local name to the remote file's name. Transfers stream over
the shared connection.

### Docker

```
ed machines docker ps      <machine> [--all] [--json]
ed machines docker images  <machine> [--json]
ed machines docker volumes <machine> [--json]
ed machines docker networks <machine> [--json]
ed machines docker df      <machine> [--json]
ed machines docker logs    <machine> <container> [--tail <n>] [--follow]
ed machines docker inspect <machine> <container>
ed machines docker start | stop | restart | rm <machine> <container> [--json]
```

`ps` merges `docker ps` with `docker stats`, so a container row carries live CPU
and memory alongside its state and ports. `--all` includes stopped containers.

```
$ ed machines docker ps tuf
ID            NAME                          IMAGE                               STATE    CPU    PORTS
b556d7fef23e  lobe-chat                     lobehub/lobe-chat:latest            running  0.0%
f8968a8b81e5  open-webui                    ghcr.io/open-webui/open-webui:main  running  0.3%   3000 → 8080/tcp
47e37ace9821  noveum-local-db-postgres-1    postgres:17-alpine                  running  2.7%   5433 → 5432/tcp
```

If docker is missing, the daemon is down, or the user cannot reach the socket,
these exit 4 and say which.

Anything not covered here goes through the raw form below; `ed tuf docker
compose up -d` is a normal thing to type.

## Running a command on a machine

```
ed <machine> <command...>
```

Naming a machine as the first word runs the rest of the line there. It is
shorthand for `ed machines exec <machine> -- <command...>`, and it is the
general escape hatch: stdin is forwarded, stdout and stderr stay separate, and
the remote exit code becomes yours.

```
ed tuf uptime
ed tuf docker compose up -d
ed tuf systemctl status nginx
ed tuf tail -f /var/log/syslog
ed tuf 'ls -la /srv | head'
```

Arguments are quoted individually before they are sent, so an argument
containing spaces survives. Shell metacharacters do not: to use a pipe,
redirection or a glob on the machine, quote the whole line as in the last
example.

A bare `ed <machine>` with nothing after it is `ed machines show <machine>`.

Edith's own command names win over machine names, so a machine called `usage`
still needs `ed machines exec usage -- ...`.

## What needs the app running

| Command | Needs the app? |
| --- | --- |
| `config`, `extensions`, `schema`, `guide`, `version`, `install` | no, but changes reach the app live when it is running |
| `usage limits`, `summary`, `daily`, `models`, `projects`, `sources` | no, they read the collected files |
| `usage refresh` | yes |
| `system stats`, `system disks` | no |
| `machines` and `ed <machine> ...` | no |
| `music`, `calendar` | yes |
| `permissions ls` | no, but it reports what the app last observed |
| `permissions refresh`, `permissions request` | yes |

Commands that need the app exit 4 and say so, which is a signal to start Edith
rather than to retry.
