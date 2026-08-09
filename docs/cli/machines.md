# `ed machines`

`ed machines` is the directory of computers Edith can reach over SSH, and the
verbs that keep it: list them, inspect one, add, rename, remove, open and close
the shared connection, sample a machine's load, run a command there, and keep
the saved port forwards and command snippets each machine offers.

The directory is three JSON files under
`~/Library/Application Support/Edith/machines`: `machines.json`,
`forwards.json` and `snippets.json`. Passwords and key passphrases live in the
login keychain, never in those files. Nothing here talks to the Edith app, so
every command on this page works whether or not Edith is running; every
mutation posts the same `machinesChanged` notification the app posts to itself,
so an open Machines window updates immediately when it is there to hear it.

Transport is `/usr/bin/ssh` over a ControlMaster socket shared with the app. If
the app already holds a connection, `ed` lands on it and the command is one
round trip on an open channel. If it does not, `ed` opens one, and
`ControlPersist=10m` keeps that socket alive for ten idle minutes so the next
command is fast. `ed machines disconnect` closes it early.

## Resource behaviour

The app keeps one metrics stream per connected remote machine. That stream
samples every two seconds and sends one record back over the shared SSH
connection. It does not open a new SSH process for every measurement. The
remote collector reads the block-device list once when it starts and obtains
the process list with one `ps` invocation per sample. CPU and memory details for
the selected processes still come from `/proc`, so the values retain their
per-process accuracy without launching a command for every row.

Local monitoring also samples every two seconds, but the more expensive process
table is refreshed every fifth sample and reused between refreshes. Each sample
updates the current metrics and all six chart histories as one published value,
so one machine sample causes one metrics view update.

Connection health uses a 30 second latency probe while a connection is healthy.
The shared socket is checked separately only after a failed probe or a wake
event. Docker container state refreshes every 30 seconds in the background and
every four seconds while a Docker window is visible. Opening the window or
performing an action still refreshes immediately. Overlapping container and
inventory refreshes are coalesced into one run.

Long-running stdout and stderr readers unregister when they reach end of file,
and completed SSH commands cancel their pending timeout work. A new connection
waits for its fresh control socket instead of repeatedly launching `ssh -O
check` while the master is starting. Streaming CLI commands suspend until the
SSH process reports completion or the command is cancelled. They do not poll
the process state between metric records.

## At a glance

| Command | What it does |
| --- | --- |
| `ed machines ls` | Lists every configured machine with its target, auth method and whether the shared connection is open. Runs when you type `ed machines` with no subcommand. |
| `ed machines show` | One machine: the stored record plus a live `uname`, `uptime` and login list. |
| `ed machines add` | Adds a machine to the directory, optionally storing a password or key passphrase from stdin. |
| `ed machines edit` | Changes a machine already on the list: name, host, port, user, auth, wake address. |
| `ed machines rm` | Forgets a machine, its forwards, its machine-scoped snippets and its keychain entries. |
| `ed machines forwards ls` | Lists the port forwards saved for a machine, numbered from 1. |
| `ed machines forwards add` | Saves a port forward. Does not open it. |
| `ed machines forwards rm` | Forgets one saved forward. |
| `ed machines forwards on` | Opens a saved forward on the shared connection. |
| `ed machines forwards off` | Closes a saved forward. |
| `ed machines snippets ls` | Lists the snippets a machine offers, its own and the shared ones. |
| `ed machines snippets add` | Saves a command against one machine, or against every machine with `--shared`. |
| `ed machines snippets rm` | Forgets one snippet. |
| `ed machines metrics` | Samples CPU, memory, load, disk and network on a machine, once or continuously. |
| `ed machines exec` | Runs a command there, passing both streams and the remote exit code through. |
| `ed machines connect` | Opens the shared SSH connection and reports the round trip time. |
| `ed machines disconnect` | Closes the shared SSH connection and removes its socket. |
| `ed machines mount` | Mounts a machine's file system on this Mac, so Finder and every local tool can read it. |
| `ed machines unmount` | Unmounts it again and tidies the folder away. Aliased `umount`. |
| `ed machines mounts` | Lists every machine file system mounted here right now. |

Seven more subcommands live under `ed machines` and are documented on four
further pages: [`docker`](./machines-docker.md), [`files`](./machines-files.md),
[`power`](./machines-power.md), [`services`](./machines-power.md),
[`kill`](./machines-power.md), [`broadcast`](./machines-power.md) and
[`workspace`](./machines-workspace.md).

## The machine record

Every command that reports a machine reports the same object, built by one
function, so `ls`, `show`, `add`, `edit` and `rm` cannot disagree about a field.
Nine of these are stored in `machines.json`; four are derived on every read.

| Field | Type | Stored? | What it is |
| --- | --- | --- | --- |
| `id` | string, uppercase UUID | stored | The machine's identity. Stable across renames, and what forwards, snippets, keychain items, the control socket and the remembered working directory are keyed by. |
| `name` | string | stored | What you call it. Unique, case-insensitively, across the directory. |
| `host` | string | stored | Hostname or address. May be empty for a machine that came from your `ssh config`. |
| `port` | integer, 1 to 65535 | stored | SSH port. `22` unless you set another. |
| `username` | string, may be empty | stored | Who to log in as. Empty means ssh decides, which is your local user unless `ssh config` says otherwise. |
| `auth` | `"SSH agent"`, `"Key file"` or `"Password"` | stored | How the connection authenticates. The key path and the "has a passphrase" flag are stored with it but are not reported. |
| `source` | `"manual"` or `"sshConfigAlias"` | stored | Whether you typed the host or picked an entry out of your `ssh config`. |
| `sshAlias` | string or `null` | derived | The `ssh config` alias when `source` is `sshConfigAlias`, `null` when it is `manual`. It is projected out of `source`, not a field of its own. |
| `wakeMACAddress` | string or `null` | stored | The MAC address `ed machines power wake` sends its magic packet to. Edith learns it the first time it sees the machine up. |
| `createdAt` | ISO 8601 timestamp | stored | When the machine was added. |
| `sshTarget` | string | derived | What is handed to `ssh`: the alias for an `ssh config` machine, otherwise `user@host`, or bare `host` when `username` is empty. |
| `controlSocket` | absolute path | derived | The ControlMaster socket for this machine, named from the first ten hex digits of `id` with a `.sk` suffix. |
| `connected` | boolean | derived | Whether that socket exists and answers `ssh -O check` right now. |

```json
{
  "auth": "SSH agent",
  "connected": true,
  "controlSocket": "/Users/pulkit/Library/Application Support/Edith/machines/sockets/4303DCF152.sk",
  "createdAt": "2026-08-06T12:11:49Z",
  "host": "192.168.1.12",
  "id": "4303DCF1-52D8-4075-AE9B-C2FD86D3821A",
  "name": "Asus TUF 7",
  "port": 22,
  "source": "sshConfigAlias",
  "sshAlias": "tuf",
  "sshTarget": "tuf",
  "username": "pulkit",
  "wakeMACAddress": "be:f0:86:8d:58:12"
}
```

The human output has one more derived string, the TARGET column, which the app
calls the machine's subtitle. For a manual machine it is `user@host`, with
`:port` appended when the port is not 22. For an `ssh config` machine it is the
alias, followed by ` · user@host` when the resolved target differs from the
alias.

A stored password or passphrase is not part of the record and no command prints
it. It lives in the login keychain under service `com.pulkit.edith.machines`,
account `<id>.password` or `<id>.passphrase`, which is the same item the app
reads and writes.

## Commands

### `ed machines ls`

Lists every configured machine. It is the default subcommand, so `ed machines`
on its own runs it, and `list` is an accepted alias.

```
ed machines ls [--json]
```

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the table. Long form only, there is no `-j`. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

Four columns, one row per machine, in the order they appear in `machines.json`,
which is the order they were added. Nothing is sorted:

```
$ ed machines ls
NAME        TARGET                     AUTH       STATE
Asus TUF 7  tuf · pulkit@192.168.1.12  SSH agent  connected
```

STATE is `connected` when the ControlMaster socket answers, and `-` when it does
not. With no machines configured, stdout stays empty, stderr carries
`no machines are configured; add one in Edith under Machines`, and the exit code
is 0.

#### `--json` shape

A top-level array of machine records, empty when nothing is configured:

```json
[
  {
    "auth": "SSH agent",
    "connected": false,
    "controlSocket": "/Users/pulkit/Library/Application Support/Edith/machines/sockets/4303DCF152.sk",
    "createdAt": "2026-08-06T12:11:49Z",
    "host": "192.168.1.12",
    "id": "4303DCF1-52D8-4075-AE9B-C2FD86D3821A",
    "name": "Asus TUF 7",
    "port": 22,
    "source": "sshConfigAlias",
    "sshAlias": "tuf",
    "sshTarget": "tuf",
    "username": "pulkit",
    "wakeMACAddress": "be:f0:86:8d:58:12"
  }
]
```

#### Examples

```
ed machines ls
ed machines ls --json
ed machines ls --json | jq -r '.[] | select(.connected) | .name'
```

#### Behaviour notes

Read only. It reads one file and dials nothing, so an unreachable machine still
appears, with STATE `-`. The one cost is the `connected` field: for every
machine whose socket file exists, `ed` runs `ssh -S <socket> -O check <target>`,
so a directory of twenty connected machines is twenty short subprocesses. A
machine with no socket file is answered from the filesystem alone.

This is one of the handful of commands that does not run inside the CLI's
failure wrapper. Nothing observable changes; the top level reports and codes a
failure identically.

### `ed machines show`

One machine, with live facts. It opens the shared connection, then runs three
commands there: `uname -srm`, `uptime` and `who | head -20`.

```
ed machines show <machine> [--json]
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | string, required | none | Machine name, ssh alias, id, or any unambiguous prefix of a name or alias, case-insensitively. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the indented block. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

```
$ ed machines show tuf
Asus TUF 7
  target   tuf · pulkit@192.168.1.12
  auth     SSH agent
  system   Linux 7.0.0-28-generic x86_64
  uptime   22:19:53 up  9:11,  5 users,  load average: 0.19, 0.16, 0.28
  session  pulkit on seat0 since 2026-08-08 13:08 (login screen)
  session  pulkit on tty2 since 2026-08-08 13:08 (tty2)
```

#### `--json` shape

Four keys, always all four:

```json
{
  "machine": {
    "auth": "SSH agent",
    "connected": true,
    "controlSocket": "/Users/pulkit/Library/Application Support/Edith/machines/sockets/4303DCF152.sk",
    "createdAt": "2026-08-06T12:11:49Z",
    "host": "192.168.1.12",
    "id": "4303DCF1-52D8-4075-AE9B-C2FD86D3821A",
    "name": "Asus TUF 7",
    "port": 22,
    "source": "sshConfigAlias",
    "sshAlias": "tuf",
    "sshTarget": "tuf",
    "username": "pulkit",
    "wakeMACAddress": "be:f0:86:8d:58:12"
  },
  "sessions": [
    "pulkit on seat0 since 2026-08-08 13:08 (login screen)",
    "pulkit on tty2 since 2026-08-08 13:08 (tty2)"
  ],
  "uname": "Linux 7.0.0-28-generic x86_64",
  "uptime": "22:18:08 up  9:10,  5 users,  load average: 0.07, 0.13, 0.30"
}
```

`machine` is the record described above. `uname` and `uptime` are the remote
command's stdout, trimmed, and `sessions` is `who` reformatted one entry per
line as `<user> on <tty> since <the rest of the line>`; a `who` line with fewer
than three fields is dropped rather than guessed at.

#### Examples

```
ed machines show tuf
ed machines tuf
ed tuf
ed machines show tuf --json | jq -r .uname
```

#### Behaviour notes

Nothing is written to the directory, but the command does open the shared
connection when one is not already up, which leaves a socket behind for the next
command.

Each of the three remote commands is best effort with its own timeout: 20
seconds for `uname`, 15 each for `uptime` and `who`. A command that fails or
times out contributes an empty string rather than failing the whole report,
which is why a machine with no `who` still prints its `uname` line.

An unknown or ambiguous name exits 3 before anything is dialled. A machine that
cannot be reached exits 4 and says why, in ssh's words.

`ed machines <machine>` with nothing after it, and `ed <machine>` with nothing
after it, are both rewritten to this command. See
[running commands on a machine](./machines-remote.md).

### `ed machines add`

Adds a machine to Edith's list. It appears in the app straight away.

```
ed machines add <name> --host <host> [--port <n>] [--user <u>] [--key <path>]
                       [--alias <sshAlias>] [--mac <address>]
                       [--password-stdin | --key-passphrase-stdin] [--json]
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<name>` | string, required | none | What to call it. Must not match an existing machine's name, case-insensitively. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--host` | string, **required** | none | Hostname or address to reach it at. Omitting it exits 2. |
| `--port` | integer, 1 to 65535 | `22` | SSH port. |
| `--user` | string | `""` | Username to log in as. Left empty, the ssh target is the bare host. |
| `--key` | path | none | Private key to authenticate with, instead of the SSH agent. `~` is expanded, and the file must exist. |
| `--alias` | string | none | Record this as an entry from your `ssh config` with this alias, which is what the app's picker writes when you choose a host from there. |
| `--mac` | string | none | MAC address for `ed machines power wake` to send its packet to. |
| `--password-stdin` | flag | off | Read one line of login password from stdin and store it in the keychain. Sets `auth` to `Password`. |
| `--key-passphrase-stdin` | flag | off | Read the key file's passphrase from stdin instead of a password. Only meaningful with `--key`. |
| `--json` | flag | off | Emit JSON on stdout instead of the confirmation block. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

Auth is resolved in one order and the first match wins: `--password-stdin` gives
`Password`, then `--key` gives `Key file`, and everything else gives
`SSH agent`. Passing both `--password-stdin` and `--key` therefore stores the
password and ignores the key.

```
$ ed machines add box --host 10.0.0.4 --user pi
added box
  target   pi@10.0.0.4
  auth     SSH agent
```

#### `--json` shape

The new machine's record, exactly as `ed machines ls` reports it.

#### Examples

```
ed machines add box --host 10.0.0.4 --user pi
ed machines add box --host 10.0.0.4 --user pi --key ~/.ssh/id_ed25519
ed machines add shed --host 10.0.0.9 --mac be:f0:86:8d:58:12 --json
printf '%s' "$PASS" | ed machines add box --host 10.0.0.4 --user pi --password-stdin
printf '%s' "$PHRASE" | ed machines add box --host 10.0.0.4 --key ~/.ssh/id_ed25519 --key-passphrase-stdin
```

#### Behaviour notes

Writes one entry to `machines.json`, writes the secret to the keychain when one
was piped, and posts `machinesChanged`. It never dials the machine, so adding a
host that is switched off succeeds.

Secrets are only ever read from stdin, so they cannot land in a process listing
or your shell history. `ed` takes the first line, stripped of its newline; an
empty line is a failure rather than an empty password:

```
$ printf '' | ed machines add box --host 10.0.0.4 --password-stdin
error: no password arrived on stdin
hint: pipe it, for example: printf '%s' "$PASS" | ed machines add ...
```

Everything is checked before anything is written, so a rejected `add` leaves the
directory untouched. The refusals, with their codes:

```
$ ed machines add "Asus TUF 7" --host 10.0.0.4
error: a machine called Asus TUF 7 already exists
hint: pick another name, or edit the existing one with `ed machines edit Asus TUF 7`

$ ed machines add box --host 10.0.0.4 --port 70000
error: --port must be between 1 and 65535

$ ed machines add box --host 10.0.0.4 --key /tmp/no-such-key
error: there is no key file at /tmp/no-such-key
hint: point --key at a private key, or pass --agent to use the SSH agent

$ ed machines add box --host 10.0.0.4 --password-stdin --key-passphrase-stdin
error: a machine has either a password or a key passphrase, not both

$ ed machines add box --host 10.0.0.4 --key-passphrase-stdin
error: --key-passphrase-stdin only means something with --key
```

The missing key file exits 3, because it is a thing you named that does not
exist. The other four exit 1. A missing `--host` exits 2, from the parser.

`--alias` changes how the machine is dialled, not just how it is labelled. An
`ssh config` machine is handed to `ssh` as the bare alias, so `--port`, `--user`
and `--key` are recorded on the record but never reach the command line;
whatever your `~/.ssh/config` says for that host is what applies.

### `ed machines edit`

Changes a machine already on the list. `--name` renames it; every other option
replaces one field and everything you leave out is untouched.

```
ed machines edit <machine> [--name <n>] [--host <h>] [--port <n>] [--user <u>]
                           [--key <path>] [--agent] [--mac <address>]
                           [--password-stdin | --key-passphrase-stdin]
                           [--sudo-password-stdin | --forget-sudo-password] [--json]
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | string, required | none | Machine name, ssh alias, id or unambiguous prefix. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--name` | string | unchanged | Rename it. Refused if another machine already holds that name. |
| `--host` | string | unchanged | Hostname or address to reach it at. |
| `--port` | integer, 1 to 65535 | unchanged | SSH port. |
| `--user` | string | unchanged | Username to log in as. An empty value is accepted and means "no user". |
| `--key` | path | unchanged | Private key to authenticate with. Sets `auth` to `Key file`. |
| `--agent` | flag | off | Authenticate with the SSH agent instead of a key file. Cannot be combined with `--key`. |
| `--mac` | string | unchanged | MAC address for wake-on-LAN. Pass an empty value, `--mac ""`, to clear it. |
| `--password-stdin` | flag | off | Read a new login password from stdin, store it in the keychain, and set `auth` to `Password`. |
| `--key-passphrase-stdin` | flag | off | Read the key file's passphrase from stdin and store it. |
| `--sudo-password-stdin` | flag | off | Read this account's sudo password from stdin and store it in the keychain. It is what `power reboot`, `power shutdown` and the unit verbs use to become root. Cannot be combined with `--forget-sudo-password`. |
| `--forget-sudo-password` | flag | off | Delete the stored sudo password. The privileged verbs go back to trying `sudo -n` and plain `systemctl`. |
| `--json` | flag | off | Emit JSON on stdout instead of the confirmation block. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

#### `--json` shape

The updated machine's record. Neither sudo flag appears in it: a stored secret
lives in the keychain, never in `machines.json`.

#### Examples

```
ed machines edit box --name shed
ed machines edit shed --host 10.0.0.9 --port 2222
ed machines edit shed --key ~/.ssh/id_ed25519
ed machines edit shed --agent
ed machines edit shed --mac ""
printf '%s' "$PHRASE" | ed machines edit shed --key ~/.ssh/id_ed25519 --key-passphrase-stdin
printf '%s' "$SUDO" | ed machines edit shed --sudo-password-stdin
ed machines edit shed --forget-sudo-password
```

#### Behaviour notes

Rewrites the entry in `machines.json`, writes the keychain item when a secret
was piped, and posts `machinesChanged`. Like `add`, everything is validated
before the write, so a refused edit changes nothing.

`--password-stdin` is applied last and wins outright: passing it alongside
`--key` stores the password and sets `auth` to `Password`. The key path lives
inside `auth` and nowhere else, so it is dropped rather than kept; pass `--key`
again when you want the key file back.

Two shapes surprise people:

- `--key-passphrase-stdin` on its own, with no `--key` and no `--agent`, is not
  refused here the way it is in `add`. The passphrase is written to the keychain
  and `auth` is left exactly as it was, so a machine on the SSH agent gains a
  stored passphrase that nothing reads. Pass `--key` in the same command when
  you mean to switch to a key file.
- `ed machines edit <machine>` with no options at all is legal. It rewrites the
  record with the values it already had and posts `machinesChanged`, so it is a
  no-op with a notification.

```
$ ed machines edit tuf --agent --key ~/.ssh/id_ed25519
error: --agent and --key are different answers to the same question
```

That exits 1, as do a duplicate `--name` and an out-of-range `--port`. A `--key`
pointing at nothing exits 3. An unknown machine exits 3, but note the ordering:
stdin is read before the machine is resolved, so a piped secret is consumed even
when the name turns out to be wrong.

### `ed machines rm`

Forgets a machine and everything saved against it. `remove` is an accepted
alias.

```
ed machines rm <machine> [--yes] [--json]
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | string, required | none | Machine name, ssh alias, id or unambiguous prefix. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--yes` | flag | off | Actually remove it. Without this nothing is touched. |
| `--json` | flag | off | Emit JSON on stdout instead of the lines. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

Without `--yes` it reports what it would take with it, changes nothing, and
exits 0:

```
$ ed machines rm tuf
would remove Asus TUF 7, 1 forward(s) and 0 snippet(s)
nothing was removed; pass --yes to go ahead
```

The second line is on stderr. With `--yes` the output is one line,
`removed Asus TUF 7`.

#### `--json` shape

The same four keys either way, with `removed` telling you which run this was:

```json
{
  "forwards": 1,
  "machine": {
    "auth": "SSH agent",
    "connected": true,
    "controlSocket": "/Users/pulkit/Library/Application Support/Edith/machines/sockets/4303DCF152.sk",
    "createdAt": "2026-08-06T12:11:49Z",
    "host": "192.168.1.12",
    "id": "4303DCF1-52D8-4075-AE9B-C2FD86D3821A",
    "name": "Asus TUF 7",
    "port": 22,
    "source": "sshConfigAlias",
    "sshAlias": "tuf",
    "sshTarget": "tuf",
    "username": "pulkit",
    "wakeMACAddress": "be:f0:86:8d:58:12"
  },
  "removed": false,
  "snippets": 0
}
```

`forwards` and `snippets` are counts of what goes with the machine, and they are
reported on the dry run so you can gate on them.

#### Examples

```
ed machines rm shed
ed machines rm shed --json
ed machines rm shed --yes
```

#### Behaviour notes

With `--yes` it removes the machine from `machines.json`, every forward whose
`machineID` is this machine from `forwards.json`, every machine-scoped snippet
from `snippets.json`, and both keychain items, password and passphrase. Then it
posts `machinesChanged`.

Shared snippets survive, because they belong to every machine rather than to
this one. That is also why the `snippets` count here can be lower than what
`ed machines snippets ls` shows for the same machine: this counts only the ones
that die with it.

The control socket file is left where it is. It is named from the machine's id
and nothing else claims that name, so it is harmless; `ed machines disconnect`
before removing if you want it gone.

### `ed machines forwards ls`

Lists the port forwards saved for a machine. These are the rows the machine's
Tools tab shows. `list` is an accepted alias, and `ls` is the group's default,
so `ed machines forwards <machine>` runs it. The group itself answers to
`forward` as well as `forwards`.

```
ed machines forwards ls <machine> [--json]
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | string, required | none | Machine name, ssh alias, id or unambiguous prefix. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the table. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

Forwards are sorted by local port ascending and numbered from 1 in that order.
That number is what `on`, `off` and `rm` take:

```
$ ed machines forwards ls tuf
#  TITLE  LOCAL  REMOTE
1         3000   localhost:3000
```

A machine with none prints `Asus TUF 7 has no saved forwards` on stderr and
exits 0 with an empty stdout.

#### `--json` shape

A top-level array, empty when there are none:

```json
[
  {
    "id": "9017538C-E5A7-433A-9CCC-3BB55B7B57AA",
    "index": 1,
    "localPort": 3000,
    "remoteHost": "localhost",
    "remotePort": 3000,
    "spec": "127.0.0.1:3000:localhost:3000",
    "title": "localhost:3000 → localhost:3000"
  }
]
```

`index` is the number you pass to the other verbs. `spec` is the exact
`-L` argument `ed` hands to ssh. `title` is the display name, so an untitled
forward reports a generated `localhost:<local> → <host>:<remote>` string here
while the table's TITLE column shows the raw title and stays blank.

#### Examples

```
ed machines forwards ls tuf
ed machines forwards tuf
ed machines forwards ls tuf --json | jq -r '.[] | "\(.index) \(.spec)"'
```

#### Behaviour notes

Read only, and it reads `forwards.json` without dialling the machine, so it says
nothing about whether a forward is currently open. Only `on` and `off` know
that, and they do not record it.

### `ed machines forwards add`

Saves a port forward against a machine. It saves only; use `on` to open it.

```
ed machines forwards add <machine> --local <n> --remote <n>
                                   [--remote-host <h>] [--title <t>] [--json]
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | string, required | none | Machine name, ssh alias, id or unambiguous prefix. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--local` | integer 1 to 65535, **required** | none | Port to open on this Mac. Bound to `127.0.0.1`, not to every interface. |
| `--remote` | integer 1 to 65535, **required** | none | Port to reach on the far side. |
| `--remote-host` | string | `localhost` | The host the far side should connect to, resolved on the machine. Point it at another box on that network to reach through. |
| `--title` | string | `""` | What to call it in the list. |
| `--json` | flag | off | Emit JSON on stdout instead of the line. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

```
$ ed machines forwards add tuf --local 8080 --remote 80 --title "web"
added 127.0.0.1:8080:localhost:80 on Asus TUF 7
```

#### `--json` shape

The same object `forwards ls` emits, with one difference worth knowing:

```json
{
  "id": "1E0B4C4A-5D3B-4F5B-9D2E-0F1A2B3C4D5E",
  "index": 0,
  "localPort": 8080,
  "remoteHost": "localhost",
  "remotePort": 80,
  "spec": "127.0.0.1:8080:localhost:80",
  "title": "web"
}
```

`index` is `0` here, not the new row's position. The number is only meaningful
in a listing, so run `ed machines forwards ls <machine> --json` afterwards if
you need the position to pass to `on`.

#### Examples

```
ed machines forwards add tuf --local 8080 --remote 80
ed machines forwards add tuf --local 5433 --remote 5432 --title postgres
ed machines forwards add tuf --local 9000 --remote 9000 --remote-host 10.0.0.7
```

#### Behaviour notes

Appends to `forwards.json` and posts `machinesChanged`. Two forwards on one
machine cannot claim the same local port:

```
$ ed machines forwards add tuf --local 3000 --remote 3000
error: Asus TUF 7 already forwards local port 3000
hint: run `ed machines forwards ls Asus TUF 7` to see them
```

That exits 1, as does a port outside 1 to 65535. The check is per machine, so
two different machines may both save local port 3000; only one of them can have
it open at a time, and the second `on` is what fails.

### `ed machines forwards rm`

Forgets one saved forward. `remove` is an accepted alias.

```
ed machines forwards rm <machine> <index> [--json]
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | string, required | none | Machine name, ssh alias, id or unambiguous prefix. |
| `<index>` | integer, counting from 1 | none | The forward's position in `ed machines forwards ls`, which is its rank by local port. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the line. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

#### `--json` shape

```json
{
  "remaining": 0,
  "removed": {
    "id": "9017538C-E5A7-433A-9CCC-3BB55B7B57AA",
    "index": 1,
    "localPort": 3000,
    "remoteHost": "localhost",
    "remotePort": 3000,
    "spec": "127.0.0.1:3000:localhost:3000",
    "title": "localhost:3000 → localhost:3000"
  }
}
```

#### Examples

```
ed machines forwards rm tuf 1
ed machines forwards rm tuf 2 --json
```

#### Behaviour notes

Removes the row from `forwards.json` and posts `machinesChanged`. It does not
close the tunnel: a forward you opened with `on` keeps running on the shared
connection until you close it or the connection goes. Run `off` first if you
want it down.

An index outside the range exits 3 and tells you the range:

```
$ ed machines forwards rm tuf 4
error: there is no forward 4 on Asus TUF 7
hint: it has 1, numbered from 1
```

### `ed machines forwards on`

Opens a saved forward on the shared connection, which is the switch on each row
of the Tools tab.

```
ed machines forwards on <machine> <index> [--json]
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | string, required | none | Machine name, ssh alias, id or unambiguous prefix. |
| `<index>` | integer, counting from 1 | none | The forward's position in `ed machines forwards ls`. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the line. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

```
$ ed machines forwards on tuf 1
localhost:3000 now reaches localhost:3000
```

#### `--json` shape

The forward object with one extra key:

```json
{
  "id": "9017538C-E5A7-433A-9CCC-3BB55B7B57AA",
  "index": 1,
  "localPort": 3000,
  "open": true,
  "remoteHost": "localhost",
  "remotePort": 3000,
  "spec": "127.0.0.1:3000:localhost:3000",
  "title": "localhost:3000 → localhost:3000"
}
```

#### Examples

```
ed machines forwards on tuf 1
ed machines forwards on tuf 1 --json
```

#### Behaviour notes

Opens the shared connection if it is not already up, then sends
`ssh -O forward -L 127.0.0.1:<local>:<remoteHost>:<remotePort>` down the control
socket. Nothing is written to disk, so the open state is not remembered: the
tunnel lives as long as the connection does and `ed machines disconnect` takes
it with it.

The local end is bound to `127.0.0.1` only, so nothing else on your network can
reach through it.

A refusal from ssh, most often a local port already in use, exits 1 with ssh's
own message as the hint. An index outside the range exits 3; an unreachable
machine exits 4.

### `ed machines forwards off`

Closes a saved forward.

```
ed machines forwards off <machine> <index> [--json]
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | string, required | none | Machine name, ssh alias, id or unambiguous prefix. |
| `<index>` | integer, counting from 1 | none | The forward's position in `ed machines forwards ls`. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the line. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

```
$ ed machines forwards off tuf 1
closed 127.0.0.1:3000:localhost:3000
```

#### `--json` shape

The same object `on` emits, with `"open": false`.

#### Examples

```
ed machines forwards off tuf 1
ed machines forwards off tuf 1 --json
```

#### Behaviour notes

Sends `ssh -O cancel -L <spec>` and ignores what ssh says about it, so closing a
forward that was never open is reported as closed and exits 0 rather than being
treated as an error.

Like `on`, it opens the shared connection first. Closing a forward on a machine
that is currently disconnected therefore dials the machine to do nothing, and
exits 4 if it cannot.

### `ed machines snippets ls`

Lists the saved commands a machine offers: the ones saved against it, plus every
shared one. `list` is an accepted alias, and `ls` is the group's default, so
`ed machines snippets <machine>` runs it. The group itself answers to `snippet`
as well as `snippets`.

```
ed machines snippets ls <machine> [--json]
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | string, required | none | Machine name, ssh alias, id or unambiguous prefix. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the table. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

Snippets are numbered from 1 in the order they were saved. Nothing is sorted,
and shared snippets sit in the same numbering as this machine's own:

```
$ ed machines snippets ls tuf
#  TITLE  SCOPE    COMMAND
1  logs   machine  journalctl -xe --no-pager
```

A machine with none prints `Asus TUF 7 has no snippets` on stderr and exits 0.

#### `--json` shape

```json
[
  {
    "command": "journalctl -xe --no-pager",
    "id": "F8D5CE93-C9B4-4A05-9109-9AEB1BD806BA",
    "index": 1,
    "sharedAcrossMachines": false,
    "title": "logs"
  }
]
```

`sharedAcrossMachines` is `true` for a snippet with no machine of its own, which
is the `shared` value in the SCOPE column.

#### Examples

```
ed machines snippets ls tuf
ed machines snippets tuf
ed machines snippets ls tuf --json | jq -r '.[] | select(.sharedAcrossMachines) | .title'
```

#### Behaviour notes

Read only, straight out of `snippets.json`, with no connection opened. A snippet
is a saved string; nothing here runs it. To run one, pass it to
`ed machines exec` or the `ed <machine> ...` shorthand.

### `ed machines snippets add`

Saves a command against a machine, or against every machine.

```
ed machines snippets add [--shared] [--json] <machine> <title> <command...>
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | string, required | none | Machine name, ssh alias, id or unambiguous prefix. Still required with `--shared`, and still has to resolve. |
| `<title>` | string, required | none | What to call it. |
| `<command...>` | one or more words, required | none | The command to save, captured verbatim and joined with single spaces. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--shared` | flag | off | Offer it on every machine rather than just this one, which is what leaving the machine unset does in the UI. |
| `--json` | flag | off | Emit JSON on stdout instead of the line. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

```
$ ed machines snippets add tuf logs journalctl -xe --no-pager
saved logs on Asus TUF 7
```

#### `--json` shape

```json
{
  "command": "journalctl -xe --no-pager",
  "id": "F8D5CE93-C9B4-4A05-9109-9AEB1BD806BA",
  "index": 0,
  "sharedAcrossMachines": false,
  "title": "logs"
}
```

As with `forwards add`, `index` is `0` rather than the new row's position. List
the snippets afterwards if you need the number.

#### Examples

```
ed machines snippets add tuf logs journalctl -xe --no-pager
ed machines snippets add tuf disk df -h
ed machines snippets add --shared tuf uptime uptime
```

#### Behaviour notes

Appends to `snippets.json` and posts `machinesChanged`. Everything after the
title is the command, verbatim, so `--shared` and `--json` have to come before
the machine name; written after the title they are saved as part of the command
instead of read as flags.

The words are joined with single spaces, so the saved string is not
byte-identical to what you typed when you used several spaces or quoted an
argument containing them. A command that is empty or only whitespace exits 1
with `a snippet needs a command to run`.

A shared snippet has no machine of its own, so it survives
`ed machines rm` and shows up on every machine's list.

### `ed machines snippets rm`

Forgets one snippet. `remove` is an accepted alias.

```
ed machines snippets rm <machine> <index> [--json]
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | string, required | none | Machine name, ssh alias, id or unambiguous prefix. |
| `<index>` | integer, counting from 1 | none | The snippet's position in `ed machines snippets ls` for that machine. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the line. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

#### `--json` shape

```json
{
  "remaining": 0,
  "removed": {
    "command": "journalctl -xe --no-pager",
    "id": "F8D5CE93-C9B4-4A05-9109-9AEB1BD806BA",
    "index": 1,
    "sharedAcrossMachines": false,
    "title": "logs"
  }
}
```

`remaining` counts what that machine still offers, shared snippets included.

#### Examples

```
ed machines snippets rm tuf 1
ed machines snippets rm tuf 1 --json
```

#### Behaviour notes

Removes the snippet from `snippets.json` by id and posts `machinesChanged`.

The numbering includes shared snippets, so an index can name one that every
other machine also offers, and removing it removes it everywhere. Check
`sharedAcrossMachines` in the listing before you delete by number.

An index outside the range exits 3:

```
$ ed machines snippets rm tuf 1
error: there is no snippet 1 on Asus TUF 7
hint: it offers 0, numbered from 1
```

### `ed machines metrics`

Samples a machine, once or continuously. It is the same collector the app's
Machines view drives, fed to the machine on stdin, so nothing is installed
there and nothing is left behind.

```
ed machines metrics <machine> [--json] [--follow] [--interval <seconds>]
                              [--processes <n>]
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | string, required | none | Machine name, ssh alias, id or unambiguous prefix. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the human lines. |
| `--follow`, `-f` | flag | off | Keep streaming until interrupted. Also switches `--json` from one pretty document to one compact document per line. |
| `--interval` | integer seconds, greater than 0 | `2` | Seconds between samples when following. Ignored without `--follow`. |
| `--processes` | integer, 0 or more | `0` | Include this many of the processes each sample carries, out of the thirty at most that the collector sends. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

The first line is the collector's greeting, carrying the machine's own host
name, its OS string and its core count. Each later line is a sample:

```
$ ed machines metrics tuf
pulkit-tuf  Ubuntu 24.04.4 LTS  20 cores
cpu   1.0%   mem 5% of 67.0 GB   load 0.12 0.14 0.30   net down 132 B/s up 1.6 KB/s
```

Without `--follow` it prints exactly one sample and exits. With `--follow` the
greeting prints once and a sample line is added every `--interval` seconds until
you interrupt it.

#### `--json` shape

One object with a `host` half that never changes and a `sample` half that does.
This is a real document with the core list, the device list and the process list
trimmed:

```json
{
  "host": {
    "arch": "x86_64",
    "cores": 20,
    "cpuModel": "12th Gen Intel(R) Core(TM) i7-12700H",
    "host": "pulkit-tuf",
    "kernel": "7.0.0-28-generic",
    "memTotalKB": 65452140,
    "os": "Ubuntu 24.04.4 LTS",
    "osID": "ubuntu",
    "virtual": false
  },
  "sample": {
    "at": "2026-08-08T16:48:25Z",
    "cpu": {
      "corePercent": [0, 0, 1.8, 0, 2.7],
      "stealPercent": 0,
      "totalPercent": 0.9
    },
    "disk": {
      "devices": [
        {
          "busyPercent": 0,
          "name": "nvme0n1",
          "readBps": 0,
          "writeBps": 24576
        }
      ],
      "readBps": 0,
      "writeBps": 24576
    },
    "intervalSeconds": 1,
    "load": [0.12, 0.14, 0.3],
    "memory": {
      "availableKB": 62045152,
      "buffCacheKB": 56620508,
      "swapTotalKB": 8388604,
      "swapUsedKB": 376,
      "totalKB": 65452140,
      "usedKB": 3406988,
      "usedPercent": 5.205311850766072
    },
    "network": {
      "interfaces": [
        {
          "name": "wlo1",
          "rxBps": 316,
          "txBps": 1550,
          "virtual": false
        },
        {
          "name": "docker0",
          "rxBps": 0,
          "txBps": 0,
          "virtual": true
        }
      ],
      "rxBps": 316,
      "txBps": 1550
    },
    "processes": [
      {
        "command": "node /opt/unduck/node_modules/.bin/vite preview",
        "cpuPercent": 0,
        "memPercent": 0.1,
        "name": "MainThread",
        "pid": 1857,
        "rssKB": 91788,
        "user": "pulkit"
      }
    ],
    "tasks": {
      "runnable": 2,
      "total": 1117
    },
    "uptimeSeconds": 33029
  }
}
```

What the fields mean:

- `host.os` is what the machine calls itself, from `/etc/os-release`, and
  `host.osID` is its short id such as `ubuntu`. `host.virtual` is the
  collector's judgement about whether it is a VM.
- `sample.at` is the sample time, and `sample.intervalSeconds` is how long the
  window behind this sample actually was.
- `cpu.totalPercent` is 0 to 100 across the whole machine, `cpu.corePercent` has
  one entry per logical core in core order, and `cpu.stealPercent` is time the
  hypervisor took, which is 0 on bare metal.
- Every `*KB` number is kilobytes and every `*Bps` number is bytes per second.
  `memory.usedPercent` is `usedKB` over `totalKB`.
- `load` is the one, five and fifteen minute load averages, in that order.
- `disk.devices` is per block device with a `busyPercent`, and
  `network.interfaces` is per interface with a `virtual` flag that labels
  bridges and container interfaces. The flag is a label only: the `rxBps` and
  `txBps` totals add up every interface the machine reports except loopback,
  virtual ones included.
- `processes` is present even when it is empty, so the key never disappears
  between runs. With the default `--processes 0` it is always `[]`. The
  collector sends at most thirty processes, the busiest by CPU plus the largest
  by memory, in no particular order, so `--processes` trims that list rather
  than ranking it.

#### Examples

```
ed machines metrics tuf
ed machines metrics tuf --json
ed machines metrics tuf --processes 20
ed machines metrics tuf --follow --interval 5 --json | jq -c '{cpu: .sample.cpu.totalPercent}'
```

#### Behaviour notes

Nothing is written locally and nothing is installed remotely. `ed` opens the
shared connection, runs `sh -s -- --once` or `sh -s -- --stream -i <interval>`
there, and pipes the collector script into that shell's stdin. The script needs
a POSIX shell and `awk` and nothing else.

The collector's own stderr is discarded, so a warning on the machine never
pollutes the report.

Failures, with their codes:

- an unknown or ambiguous machine name exits 3
- a machine that cannot be reached exits 4
- a machine that connects but never emits a sample exits 4 with
  `<name> did not report metrics` and the hint that the collector needs a POSIX
  shell and awk
- `--interval 0` or a negative interval exits 2 with
  `--interval must be greater than zero`, and `--processes=-1` exits 2 with
  `--processes cannot be negative`; both are checked before the machine is
  dialled
- a build with the collector script missing exits 1

Write a negative process count as `--processes=-1`. Spelled `--processes -1` the
parser reads it as a missing value and exits 2 for that reason instead.

`--json --follow` writes one compact document per line, forever, repeating the
whole `host` object on every line so each line stands alone for `jq -c`, `head`
or a pipe. Without `--follow` you get a single pretty document.

The collector also emits a slower record carrying filesystems, temperatures,
battery and GPU. `ed machines metrics` decodes and discards it, so those never
appear here even though the app's Machines view shows them.

`ed system stats` is the same report for the Mac you are typing on, in the same
shape, so a script can treat local and remote the same way.

### `ed machines exec`

Runs a command on a machine, passing stdin, stdout, stderr and the remote exit
code straight through. `run` is an accepted alias.

```
ed machines exec [--tty] <machine> [--] <command...>
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | string, required | none | Machine name, ssh alias, id or unambiguous prefix. |
| `<command...>` | words, required in practice | empty | The command to run. Everything after the machine name is captured verbatim, flags included. A leading `--` is stripped. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--tty`, `-t` | flag | off | Run it on a terminal, so `vim`, `top`, a `sudo` password prompt and `docker exec -it` work. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

There is no `--json` here. The output is the remote command's output and nothing
else.

#### Examples

```
ed machines exec tuf -- uptime
ed tuf uptime
ed machines exec --tty tuf -- top
ed tuf 'ls -la /srv | head'
```

#### Behaviour notes

This is the one command on the page whose exit code is not Edith's. The remote
process's status becomes yours, so a `grep` that matched nothing exits 1 and a
missing command exits 127, neither of which means `ed` failed. The `--tty` path
returns ssh's own status the same way.

Arguments are quoted individually before they are sent, so an argument
containing spaces survives. Shell metacharacters do not: to use a pipe, a
redirection or a glob on the machine, quote the whole line as in the last
example. A single-word command is sent verbatim, unquoted.

`cd` is special when it is the whole command: `ed tuf cd Desktop` records a
working directory for that terminal rather than running anything, and later
commands are prefixed with it. `cd -` goes back, `cd` with no argument goes
home, and a path that does not exist exits 1 with the machine's own error and
leaves the current directory alone. The full model, including how the directory
is scoped to one terminal and how remote completion follows it, is on
[running commands on a machine](./machines-remote.md).

Naming no command at all exits 1:

```
$ ed machines exec tuf
error: name a command to run, for example `ed tuf uptime`
```

An unknown machine exits 3, an unreachable one exits 4.

### Subcommands documented elsewhere

Between `exec` and `connect`, `ed machines` declares seven more subcommands.
They are part of this group and resolve machines the same way, but they are
documented elsewhere:

```
ed machines files ...        browsing, transfers, the Finder operations and undo
ed machines docker ...       containers, images, volumes, networks, compose
ed machines services ...     systemd units: list, start, stop, restart
ed machines power ...        status, reboot, shutdown, wake-on-LAN
ed machines kill ...         end a process by pid
ed machines broadcast ...    one command on every configured machine
ed machines workspace ...    the saved multi-pane layouts
```

### `ed machines connect`

Opens the shared SSH connection to a machine and reports the round trip time.

```
ed machines connect <machine> [--json]
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | string, required | none | Machine name, ssh alias, id or unambiguous prefix. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the line. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

```
$ ed machines connect tuf
connected, 28 ms
```

#### `--json` shape

```json
{
  "connected": true,
  "latencyMillis": 26.595375,
  "machine": "Asus TUF 7"
}
```

`machine` here is the name, not the record. `latencyMillis` is `null`, and the
human line drops the timing and reads just `connected`, when the timing probe
did not come back.

#### Examples

```
ed machines connect tuf
ed machines connect tuf --json | jq .latencyMillis
```

#### Behaviour notes

If a live socket already exists, whether the app opened it or an earlier `ed`
call did, this reuses it and only measures. Otherwise it starts a ControlMaster
and waits up to 25 seconds for the socket to answer.

The latency is measured by running `true` on the machine and timing the round
trip, so it includes ssh's own overhead on an established channel rather than
being a network ping.

A machine that cannot be reached exits 4 with ssh's reason translated into a
sentence: a changed host key, a rejected credential, a refused connection, a
timeout or an unresolvable name each get their own wording. An unknown machine
name exits 3.

The socket outlives the process. `ControlPersist=10m` keeps it up for ten idle
minutes, which is what makes the next command on that machine fast.

### `ed machines disconnect`

Closes the shared SSH connection to a machine.

```
ed machines disconnect <machine> [--json]
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | string, required | none | Machine name, ssh alias, id or unambiguous prefix. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the line. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

```
$ ed machines disconnect tuf
disconnected
```

#### `--json` shape

```json
{
  "connected": false,
  "machine": "Asus TUF 7"
}
```

#### Examples

```
ed machines disconnect tuf
ed machines disconnect tuf --json
```

#### Behaviour notes

This is the one connection verb that does not dial: it resolves the machine,
sends `ssh -O exit` down the control socket, and deletes the socket file. A
machine that was not connected is reported as disconnected and exits 0, rather
than being treated as an error.

It closes the connection the app shares, so any port forwards opened with
`ed machines forwards on` go down with it, and the app's own Machines view
reconnects the next time it needs to.

An unknown machine name exits 3. Nothing else here can fail.

### `ed machines mount`

Hangs a machine's file system off a folder on this Mac. Finder shows it as a
disk and every local tool, an editor, `grep`, `rsync`, reads and writes it in
place.

```
ed machines mount <machine> [path] [--at <dir>] [--read-only] [--json]
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | string, required | none | Machine name, ssh alias, id or unambiguous prefix. |
| `[path]` | remote directory | the working directory `ed <machine> cd` remembers, else the login home | What to mount. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--at` | local directory, `~` expanded | `~/Edith/<machine name>` | Where to mount it. |
| `--read-only` | flag | off | Mount it `ro`, so nothing local can write to the machine. |
| `--json` | flag | off | Emit JSON on stdout instead of the line. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

```
$ ed machines mount tuf
pulkit@10.0.0.4:/home/pulkit  ->  /Users/pulkit/Edith/tuf
```

#### `--json` shape

```json
{
  "machine": "Asus TUF 7",
  "mountPoint": "/Users/pulkit/Edith/tuf",
  "readOnly": false,
  "remotePath": "/home/pulkit",
  "source": "pulkit@10.0.0.4:/home/pulkit"
}
```

#### Examples

```
ed machines mount tuf
ed machines mount tuf /srv --read-only
ed machines mount tuf --at ~/mnt/tuf --json
ed machines tuf mount /var/log
```

#### Behaviour notes

This needs an `sshfs` on this Mac, which Edith does not install:

```
$ ed machines mount tuf
error: sshfs is not installed on this Mac.
hint: install FUSE-T, which needs no kernel extension: brew install --cask macos-fuse-t/cask/fuse-t macos-fuse-t/cask/fuse-t-sshfs
```

Either FUSE works. FUSE-T is the one to reach for first because it is a user
space NFS server rather than a kernel extension, so it installs without loading
a kext, without Reduced Security on an Apple Silicon Mac, and without a restart.
macFUSE with `gromgit/fuse/sshfs-mac` works too, at the cost of approving a
kernel extension. Edith drives whichever `sshfs` is first on `PATH`, and it
tries the mount twice: once with the macFUSE-only options, `volname`,
`idmap=user`, `defer_permissions` and the Apple metadata switches, and then
without them, so an sshfs that rejects the first set still mounts.

The mount rides the same ControlMaster socket everything else on this page uses.
`ed` opens the connection first, then points `sshfs` at that socket with
`ControlPath`, `ControlMaster=no` and `BatchMode=yes`, so the mount is a second
channel on the connection already there and no password or passphrase is asked
for twice. The socket path is quoted inside the option, because it lives under
`Application Support` and `ssh` would otherwise stop at the space. Because it
never prompts, a mount attempted while the machine is unreachable fails rather
than hanging.

`sshfs` stays running as the mount's own process, so `ed` does not wait for it
to exit: it watches the mount table for up to 16 seconds and reports the mount
the moment it appears, or stops the process and reports what it printed.

Files show up owned by you: `idmap=user` maps the remote account to yours, and
`uid` and `gid` are this Mac's. The volume is named after the machine, so that
is the name in Finder's sidebar. `reconnect` is on, so the mount survives a
short network drop instead of turning into stale handles.

The default mount point is created if it is missing. A folder that already has
something in it is refused, and so is a machine that is already mounted, both
exiting 1:

```
$ ed machines mount tuf
error: That machine is already mounted at /Users/pulkit/Edith/tuf.
```

Mounting one directory rather than the whole machine is the same command with a
path, and `--read-only` is worth having on anything you only meant to read: a
mounted machine is as easy to delete from as a local disk.

The mount belongs to the login session, not to Edith. It stays up when Edith
quits, and it goes away on logout or restart. `ed machines disconnect` closes
the control socket; the mount then keeps itself alive on its own connection.

What Edith keeps is a small record in
`~/Library/Application Support/Edith/machines/mounts.json`, one line per mount
it made: the machine, the remote path and the mount point. That is what ties a
mount back to a machine, because not every FUSE reports the `user@host:/path`
source in the mount table. The record is checked against the live mount table on
every read, so one that has gone away, unmounted by hand or lost to a restart,
is dropped rather than believed.

### `ed machines unmount`

Unmounts a machine's file system again. Aliased `umount`.

```
ed machines unmount <machine> [--json]
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | string, required | none | Machine name, ssh alias, id or unambiguous prefix. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the line. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

```
$ ed machines unmount tuf
unmounted /Users/pulkit/Edith/tuf
```

#### `--json` shape

```json
{
  "machine": "Asus TUF 7",
  "mountPoint": "/Users/pulkit/Edith/tuf",
  "readOnly": false,
  "remotePath": "/home/pulkit",
  "source": "pulkit@10.0.0.4:/home/pulkit"
}
```

#### Examples

```
ed machines unmount tuf
ed machines umount tuf --json
```

#### Behaviour notes

The document describes the mount that was released, so it is the same shape
`mount` printed when it went up.

`umount` is tried first and `diskutil unmount force` second, which is what gets
a mount down when a shell is still sitting in it. The mount point is then
removed if it is empty and inside `~/Edith`, so the folders do not pile up; a
mount point you chose with `--at` is left where it is.

A machine that is not mounted exits 4 rather than pretending to have done
something:

```
$ ed machines unmount tuf
error: Asus TUF 7 is not mounted.
```

### `ed machines mounts`

Lists every machine file system mounted on this Mac.

```
ed machines mounts [--json]
```

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the table. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

```
$ ed machines mounts
MACHINE     REMOTE         AT                          MODE
Asus TUF 7  /home/pulkit   /Users/pulkit/Edith/tuf     rw
pi          /srv           /Users/pulkit/Edith/pi      ro
```

#### `--json` shape

```json
[
  {
    "machine": "Asus TUF 7",
    "mountPoint": "/Users/pulkit/Edith/tuf",
    "readOnly": false,
    "remotePath": "/home/pulkit",
    "source": "pulkit@10.0.0.4:/home/pulkit"
  }
]
```

#### Examples

```
ed machines mounts
ed machines mounts --json | jq -r '.[].mountPoint'
```

#### Behaviour notes

This reads `/sbin/mount` and reports what the system says is mounted, filtered
to the mounts Edith recorded plus any FUSE mount whose source reads
`user@host:/path`. So a machine mounted by hand with `sshfs` shows up here too,
matched to a name by its target, and an entry Edith cannot match to a machine is
listed under that target instead. Nothing here dials a machine, so it answers
instantly and works with every machine asleep.

## Exit codes

| Code | When |
| --- | --- |
| 0 | The command did what it says. A dry-run `rm` without `--yes`, an empty listing, and closing a forward that was not open all count as success. `--help` exits 0 too. |
| 1 | A duplicate machine name, a port outside 1 to 65535, `--agent` with `--key`, both stdin secret flags together, `--key-passphrase-stdin` without `--key` on `add`, no secret on stdin, a duplicate local port on `forwards add`, ssh refusing to open a forward, an empty snippet command, an empty `exec` command line, a `cd` to a path that does not exist, or a missing collector script. |
| 2 | The command line was wrong: an unknown flag, a missing `<machine>`, a missing `--host` on `add`, `--interval 0` or negative, or `--processes=-1`. |
| 3 | The thing you named does not exist: no machines configured at all, no machine by that name, a prefix that matches more than one machine, a `--key` path with no file, or a forward or snippet index outside the range. |
| 4 | The machine could not be reached, or it connected but never reported a metrics sample. |

`ed machines exec` is the exception, and deliberately so: it propagates the
remote command's own exit code, so any value from 0 to 255 can come back and
none of them mean what the table above says.

Nothing on this page needs the Edith app, so no command here exits 4 because the
app is closed.

## Notes and gotchas

- Names are forgiving and resolve in one fixed order: an exact name match, then
  an exact `ssh config` alias match, then the id, then a unique prefix of a name
  or alias. Every step is case-insensitive. A prefix matching more than one
  machine fails with the list of matches rather than guessing; an unknown name
  fails with the list of known machines. Both exit 3, and both hints end with
  every `ed machines` subcommand name.
- A subcommand name always wins over a machine name. A machine literally called
  `docker`, `ls` or `power` has to be named explicitly with
  `ed machines show docker`, and the error hint lists every subcommand name so
  you can see the collision.
- The machine name comes first, subject then verb: `ed machines tuf metrics`,
  `ed machines tuf files ls /etc`. The older order with the machine last,
  `ed machines metrics tuf`, still parses. `ed <machine> ...` is shorthand for
  `ed machines <machine> ...`, and `ed <machine>` alone is
  `ed machines show <machine>`.
- Every mutation posts `com.pulkit.edith.machinesChanged` on the distributed
  notification centre. That is fire and forget: nothing waits for a reply, and
  posting with Edith closed is harmless.
- The `machines` extension, the switch that decides whether the app shows the
  Machines tab, is never consulted by `ed`. These commands work with every
  extension turned off.
- Indexes are positions in a listing, not identities. Removing a forward or a
  snippet renumbers everything after it, so read the list again between two
  deletes rather than counting down.
- `forwards add` and `snippets add` both report `"index": 0` in JSON, because
  the number only means something in a listing. Follow with the matching `ls` if
  you need the position.
- Forwards are ordered by local port ascending. Snippets are in the order they
  were saved, with shared ones interleaved.
- Connection settings are the same on every command: host keys are checked
  against Edith's own `known_hosts` in the machines folder and yours in
  `~/.ssh/known_hosts`, with `StrictHostKeyChecking=accept-new`, so a new
  machine is trusted on first sight and a changed key is refused with a specific
  message. `ConnectTimeout` is 12 seconds, keepalives go every 15 seconds and
  give up after three.
- The control socket path is derived from the machine's id, the first ten hex
  digits with the dashes removed, plus `.sk`, under
  `~/Library/Application Support/Edith/machines/sockets`. It is reported as
  `controlSocket` on every machine record, which is what makes the app and `ed`
  share one connection.
- A stored password or passphrase is handed to ssh through `SSH_ASKPASS`, which
  points back at the `ed` binary itself with the keychain account in the
  environment. The secret never appears on a command line, and a host key
  confirmation prompt is answered by declining rather than by leaking it.
- An `ssh config` machine is dialled by alias alone. Its `port`, `username` and
  key are on the record and shown in the listing, but ssh never sees them;
  `~/.ssh/config` decides. Edit that file, not the machine, when an alias
  connects to the wrong place.
- Object keys are sorted in the JSON, in both the pretty and the compact form,
  so two runs diff cleanly. Every command here prints exactly one document
  except `metrics --follow --json`, which prints one compact document per line
  until interrupted.
- `ed machines ls` and `ed machines show` are the cheap way to learn the exact
  names every other command wants. Both take `--json`.

## Where to go next

- [Running commands on a machine](./machines-remote.md) for the `ed <machine>`
  shorthand, the remembered working directory and remote completion.
- [`ed machines files`](./machines-files.md) for browsing, transfers and the
  Finder window's operations.
- [`ed machines docker`](./machines-docker.md) for containers, images, volumes
  and compose projects.
- [`ed machines power`](./machines-power.md) for power state, systemd units,
  processes and `broadcast`.
- [`ed machines workspace`](./machines-workspace.md) for the saved multi-pane
  layouts.
- [`ed system`](./system.md) for the same metrics report taken on this Mac.
- [Conventions and contracts](./conventions.md) for the exit code table and the
  `--json` guarantee in full.
- [The `ed` command line](./README.md) for the rest of the reference.
