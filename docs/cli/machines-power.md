# `ed machines power`

`ed machines power` is the run state of another machine: whether it is up, and
the three things you can tell it to do about that, which are restart, shut down
and wake. This page also covers the neighbouring verbs that act on what is
running there rather than on the machine itself: `ed machines services` for
systemd units, `ed machines kill` for a single process, and
`ed machines broadcast` for one line on every machine at once.

Everything here is the Tools tab of a machine window as a command, plus the
terminal's broadcast bar. Nothing here needs the Edith app to be running:
`status` reads the machine file on disk, `wake` opens a UDP socket, and the rest
go out over `/usr/bin/ssh` on the ControlMaster socket Edith and `ed` share.

Most of this page is disruptive. Read the next table before you type anything.

| Command | Disruptive? |
| --- | --- |
| `ed machines power status` | No. Reads the machine file and pokes the local control socket. Never contacts the machine. |
| `ed machines power reboot` | Yes, and it takes the machine down. Refuses to act without `--yes`. |
| `ed machines power shutdown` | Yes, and the machine will not come back without `wake` or a physical power button. Refuses to act without `--yes`. |
| `ed machines power wake` | Mildly. It puts one broadcast packet on the local network and nothing else. |
| `ed machines services ls` | No. Reads `systemctl list-units`. |
| `ed machines services start` | Yes, it changes a unit's state. No confirmation flag. |
| `ed machines services stop` | Yes, it changes a unit's state. No confirmation flag. |
| `ed machines services restart` | Yes, it changes a unit's state. No confirmation flag. |
| `ed machines kill` | Yes, it signals a live process. No confirmation flag. |
| `ed machines broadcast` | As disruptive as the line you give it, multiplied by every machine you own. No confirmation flag. |

Only `reboot` and `shutdown` have a `--yes` gate. `services stop`, `kill` and
`broadcast` act the moment you press return.

## At a glance

| Command | What it does |
| --- | --- |
| `ed machines power status` | Reports whether a shared connection is open, the stored MAC address, and which power verbs are possible right now. Runs when you type `ed machines power <machine>` with no verb. |
| `ed machines power reboot` | Restarts the machine through systemd. Does nothing without `--yes`. Aliased as `restart`. |
| `ed machines power shutdown` | Powers the machine off through systemd. Does nothing without `--yes`. Aliased as `poweroff`. |
| `ed machines power wake` | Sends a wake-on-LAN magic packet to the machine's stored MAC address. The one verb that works while the machine is off. |
| `ed machines services ls` | Lists systemd service units, with `--failed` to narrow to broken ones. Runs when you type `ed machines services <machine>` with no verb. |
| `ed machines services start` | Starts one unit. |
| `ed machines services stop` | Stops one unit. |
| `ed machines services restart` | Restarts one unit. |
| `ed machines kill` | Sends a signal to one process id, `TERM` unless you name another. |
| `ed machines broadcast` | Runs one command on every configured machine, labels each machine's output, and exits 1 if any of them failed. |

## Two ways to name the machine

Every command on this page except `broadcast` takes the machine as a positional
argument, and the machine can come first instead. The first line of each pair
below puts the verb first and the machine last, the second puts the machine
first.

```
ed machines power reboot tuf --yes
ed machines tuf power reboot --yes
ed machines services restart tuf nginx.service
ed machines tuf services restart nginx.service
```

Both forms parse to the same thing. What does not work is the bare shorthand:
`ed tuf power reboot` is `ed machines exec tuf -- power reboot`, so it looks for
a program called `power` on the far side and fails there. The shorthand always
means "run this on the machine", so reach for `ed machines tuf ...` when you
want Edith's own verb.

A machine resolves by display name, SSH config alias, id, or any unambiguous
case-insensitive prefix. An unknown or ambiguous name exits 3 with the
candidates in the hint, and never guesses.

## Commands

### `ed machines power status`

Says whether the machine has a live shared connection, what MAC address is
stored for it, and which of wake and reboot are possible right now. It is the
default subcommand of `power`, so `ed machines power tuf` runs it.

```
ed machines power status <machine> [--json]
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | machine name, ssh alias or id | required | Which machine to report on. Resolved by name, alias, id or unambiguous prefix. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the table. Long form only, there is no `-j`. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

One row, five columns:

```
$ ed machines power status tuf
MACHINE     CONNECTED  MAC                WAKE  REBOOT
Asus TUF 7  yes        04:42:1a:8d:2f:6c  yes   yes
```

`MAC` prints `-` when Edith has never learned one.

#### `--json` shape

```json
{
  "canReboot": true,
  "canShutDown": true,
  "canWake": true,
  "connected": true,
  "macAddress": "04:42:1a:8d:2f:6c",
  "machine": "Asus TUF 7"
}
```

`machine` is the display name, not the id. `macAddress` is `null` rather than
missing when none is stored, and `canWake` is exactly `macAddress != null`.
`canReboot` and `canShutDown` are both copies of `connected`.

#### Examples

```
ed machines power status tuf
ed machines power tuf
ed machines tuf power
ed machines power status tuf --json | jq -r '.canWake'
```

#### Behaviour notes

This is the one command on the page that never touches the network. `connected`
is a local test: it looks for the ControlMaster socket file for that machine and
runs `ssh -S <socket> -O check` against it. A machine that is up and reachable
but has no open shared connection reports `connected: false`, which is `no` in
the table.

Read that as a promise about cost, not about capability. `canReboot: false`
means there is no open channel to reuse, not that a reboot would be refused:
`ed machines power reboot` opens its own connection when there is none. What it
does tell you is that the next command will pay for a fresh SSH handshake.

Nothing is mutated. The only failure is an unknown machine, which exits 3.

### `ed machines power reboot`

Restarts the machine through systemd. Does nothing without `--yes`.

```
ed machines power reboot <machine> [--yes] [--json]
```

The command is also spelled `ed machines power restart`.

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | machine name, ssh alias or id | required | Which machine to restart. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--yes` | flag | off | Actually restart it. Without this nothing is done. |
| `--json` | flag | off | Emit JSON on stdout instead of the human lines. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

Without `--yes` it tells you what it would do, changes nothing, and exits 0. The
line naming the machine goes to stdout and the reminder goes to stderr:

```
$ ed machines power reboot tuf
would restart Asus TUF 7
nothing was done; pass --yes to go ahead
```

With `--yes` it connects, runs the reboot, and reports:

```
$ ed machines power reboot tuf --yes
Asus TUF 7 is restarting
```

#### `--json` shape

Two shapes, told apart by `applied`. Without `--yes` the document also carries
the exact shell line that would have run, so you can read it before you run it:

```json
{
  "action": "reboot",
  "applied": false,
  "command": "sudo -n systemctl reboot 2>&1 || systemctl reboot 2>&1",
  "machine": "Asus TUF 7"
}
```

With `--yes`, on success, `command` is not included:

```json
{
  "action": "reboot",
  "applied": true,
  "machine": "Asus TUF 7"
}
```

`action` is the literal string `reboot` in both, even when you typed the
`restart` alias.

#### Examples

```
ed machines power reboot tuf
ed machines power reboot tuf --yes
ed machines tuf power reboot --yes
ed machines power restart tuf --yes --json
```

#### Behaviour notes

The remote line is `sudo -n systemctl reboot 2>&1 || systemctl reboot 2>&1`, so
`ed` tries passwordless sudo first and falls back to plain `systemctl` for a
machine whose polkit rules already allow it. Stderr is folded into stdout on the
far side, which is why a refusal comes back as readable prose rather than as an
empty failure.

A machine that answers *a password is required* or *Interactive authentication
required* is reported as having refused, and exits 1, rather than being called
done. The hint appears only when the output matches one of the phrases that mean
privilege: `password is required`, `interactive authentication required`,
`access denied`, `not authorized` or `permission denied`.

```
$ ed machines power reboot tuf --yes
error: Asus TUF 7 did not reboot: sudo: a password is required
Call to Reboot failed: Interactive authentication required.
hint: give this account passwordless sudo for systemctl on Asus TUF 7
```

The error text after the colon is the machine's own combined output, trimmed.
When the machine said nothing at all that half falls back to a second sentence
of Edith's own, so the whole line reads
`error: Asus TUF 7 did not reboot: Asus TUF 7 refused to reboot`.

The command waits at most 20 seconds for the remote line to return. Reaching the
machine happens first and has its own 25 second budget; a machine that cannot be
reached exits 4 with `could not reach <machine>` before anything is attempted.

`systemctl reboot` returns as soon as systemd accepts the request, which is why
the usual successful run exits cleanly before the host disappears. If ssh
instead exits non-zero because the connection died under it, that is reported as
a refusal and exits 1; see the gotcha at the end of this page.

### `ed machines power shutdown`

Powers the machine off through systemd. Does nothing without `--yes`.

```
ed machines power shutdown <machine> [--yes] [--json]
```

The command is also spelled `ed machines power poweroff`.

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | machine name, ssh alias or id | required | Which machine to shut down. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--yes` | flag | off | Actually shut it down. Without this nothing is done. |
| `--json` | flag | off | Emit JSON on stdout instead of the human lines. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

```
$ ed machines power shutdown tuf
would shut Asus TUF 7 down
nothing was done; pass --yes to go ahead

$ ed machines power shutdown tuf --yes
Asus TUF 7 is shutting down
```

#### `--json` shape

The same two shapes as `reboot`, with `action` set to `shutdown` and the remote
line built from `poweroff`:

```json
{
  "action": "shutdown",
  "applied": false,
  "command": "sudo -n systemctl poweroff 2>&1 || systemctl poweroff 2>&1",
  "machine": "Asus TUF 7"
}
```

```json
{
  "action": "shutdown",
  "applied": true,
  "machine": "Asus TUF 7"
}
```

#### Examples

```
ed machines power shutdown tuf
ed machines power shutdown tuf --yes
ed machines tuf power poweroff --yes
ed machines power shutdown tuf --json
```

#### Behaviour notes

Identical to `reboot` in every respect but the verb: same 20 second timeout,
same sudo-then-plain fallback, same refusal detection, same exit codes.

Think about the way back before you run it. A machine that is off answers
nothing, so the only verb left is `ed machines power wake`, and that needs a
stored MAC address and a machine whose firmware has wake-on-LAN enabled. Check
with `ed machines power status <machine>` first: if `WAKE` says `no`, a shutdown
is a trip to the physical power button.

### `ed machines power wake`

Sends a wake-on-LAN magic packet to the machine's stored MAC address.

```
ed machines power wake <machine> [--json]
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | machine name, ssh alias or id | required | Which machine to wake. Resolved from the machine file, so it works while the machine is off. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the human line. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

```
$ ed machines power wake tuf
sent a wake packet to 04:42:1a:8d:2f:6c
```

#### `--json` shape

```json
{
  "action": "wake",
  "applied": true,
  "macAddress": "04:42:1a:8d:2f:6c",
  "machine": "Asus TUF 7"
}
```

`applied: true` means the packet left this Mac. It is not a claim that the
machine woke.

#### Examples

```
ed machines power wake tuf
ed machines tuf power wake
ed machines power wake tuf --json
ed machines edit tuf --mac 04:42:1a:8d:2f:6c
```

#### Behaviour notes

There is no SSH here at all. `ed` builds the magic packet by hand, six `0xFF`
bytes followed by the six address bytes repeated sixteen times, opens a UDP
socket with `SO_BROADCAST`, and sends it to `255.255.255.255` on port 9. That is
a limited broadcast, so it reaches the local link and no further: waking a
machine on another subnet needs a router that forwards directed broadcasts, and
this command cannot arrange that for you.

Edith learns the address the first time it sees the machine up, by reading
`/sys/class/net/*/address` and keeping the first entry that is not all zeroes.
Until that has happened there is nothing to send to, and the command exits 4:

```
$ ed machines power wake box
error: no MAC address is stored for Home Box
hint: open the machine in Edith while it is up so it can learn one, or set it with `ed machines edit Home Box --mac <address>`
```

The hint quotes the display name verbatim, so a name with spaces needs quoting
when you retype the suggestion.

A stored value that is not six colon-separated hex pairs exits 1 with
`<value> is not a MAC address`, and a socket that cannot be opened or written
exits 1 with `Could not open a socket.` or `The wake packet could not be sent.`.
Nothing here depends on the machine being reachable, which is the whole point of
the verb.

### `ed machines services ls`

Lists the systemd service units on a machine. It is the default subcommand of
`services`, so `ed machines services tuf` runs it. Also spelled
`ed machines services list`.

```
ed machines services ls <machine> [--failed] [--json]
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | machine name, ssh alias or id | required | Which machine to list units on. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--failed` | flag | off | Only failed units, meaning those whose `active` or `sub` field is `failed`. Filtered on this Mac after the full list arrives. |
| `--json` | flag | off | Emit JSON on stdout instead of the table. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

```
$ ed machines services tuf
UNIT                       ACTIVE  SUB      WHAT
cron.service               active  running  Regular background program processing daemon
docker.service             active  running  Docker Application Container Engine
nginx.service              active  running  A high performance web server
ollama.service             failed  failed   Ollama Service
ssh.service                active  running  OpenBSD Secure Shell server
systemd-timesyncd.service  active  running  Network Time Synchronization
```

#### `--json` shape

A top-level array, one object per unit, in the order `systemctl` returned them:

```json
[
  {
    "active": "active",
    "description": "A high performance web server",
    "failed": false,
    "load": "loaded",
    "running": true,
    "sub": "running",
    "unit": "nginx.service"
  },
  {
    "active": "failed",
    "description": "Ollama Service",
    "failed": true,
    "load": "loaded",
    "running": false,
    "sub": "failed",
    "unit": "ollama.service"
  }
]
```

`load`, `active` and `sub` are systemd's own three columns, passed through
untouched. `running` is `sub == "running"` and `failed` is
`active == "failed" || sub == "failed"`, both precomputed so a script does not
have to know systemd's vocabulary. The JSON key is `description`; the table
column is headed `WHAT`.

#### Examples

```
ed machines services tuf
ed machines services ls tuf --failed
ed machines tuf services ls
ed machines services ls tuf --json | jq -r '.[] | select(.failed) | .unit'
```

#### Behaviour notes

The remote line is this, with a 30 second timeout:

```
systemctl list-units --type=service --all --no-pager --no-legend --plain 2>/dev/null | head -200
```

Three consequences worth knowing.

The list is capped at 200 units and there is no flag to raise it. A machine with
more services than that loses the tail silently.

Only `.service` units are listed. Timers, sockets, mounts and targets are not,
because the parser drops any line whose first field does not end in `.service`.

A machine with no systemd at all reports nothing rather than failing. The
`2>/dev/null` swallows the "command not found" and `head` exits 0, so you get a
note on stderr and exit 0:

```
$ ed machines services ls box
no systemd units reported
```

`--failed` narrows the list here, on this Mac, after all 200 lines have crossed
the wire. It is not `systemctl --failed`, so it costs the same as the full list.

### `ed machines services start`

Starts one unit.

```
ed machines services start <machine> <unit> [--json]
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | machine name, ssh alias or id | required | Which machine the unit lives on. |
| `<unit>` | unit name | required | The unit, for example `nginx.service`. Quoted for the remote shell only when it holds something outside letters, digits and `._-+/=:@%,`, so a name with awkward characters survives. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the human line. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

```
$ ed machines services start tuf nginx.service
started nginx.service on Asus TUF 7
```

#### `--json` shape

```json
{
  "action": "start",
  "applied": true,
  "machine": "Asus TUF 7",
  "unit": "nginx.service"
}
```

This document is only ever emitted on success. A failure writes nothing to
stdout and reports on stderr instead.

#### Examples

```
ed machines services start tuf nginx.service
ed machines tuf services start docker.service
ed machines services start tuf nginx.service --json
```

#### Behaviour notes

There is no `--yes` on the unit verbs. They act immediately.

The remote line for `nginx.service` is
`systemctl start nginx.service 2>&1 || sudo -n systemctl start nginx.service 2>&1`,
with a 60 second timeout. The unit is only wrapped in single quotes when it holds
a character outside letters, digits and `._-+/=:@%,`, so an ordinary name goes
across bare. Note the order: plain `systemctl` first, `sudo -n` as the fallback,
which is the opposite way round from `reboot` and `shutdown`.

Systemd's own unit name shorthand applies, because `ed` passes the name straight
through: `nginx` and `nginx.service` are the same unit to `systemctl start`. The
`.service` suffix is what `ed machines services ls` prints, so it is the safe
thing to copy.

A failure exits 1 with the machine's output appended, and adds the sudo hint
only when the output looks like a privilege problem:

```
$ ed machines services start tuf nginx.service
error: could not start nginx.service on Asus TUF 7: Failed to start nginx.service: Unit nginx.service not found.
```

An unreachable machine exits 4 before the unit is touched. An unknown machine
name exits 3. A unit that does not exist is a remote failure, so it exits 1, not
3: `ed` never checks the unit list before acting.

### `ed machines services stop`

Stops one unit.

```
ed machines services stop <machine> <unit> [--json]
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | machine name, ssh alias or id | required | Which machine the unit lives on. |
| `<unit>` | unit name | required | The unit, for example `nginx.service`. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the human line. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

#### `--json` shape

The same four keys, with `action` set to `stop`:

```json
{
  "action": "stop",
  "applied": true,
  "machine": "Asus TUF 7",
  "unit": "nginx.service"
}
```

#### Examples

```
ed machines services stop tuf nginx.service
ed machines tuf services stop ollama.service
ed machines services stop tuf nginx.service --json
```

#### Behaviour notes

The most disruptive command on this page that has no confirmation flag. Stopping
`ssh.service` on a machine you reach over SSH is the obvious way to lock
yourself out, and `ed` will not stop you.

The human success line is built by appending `ed` to the verb, so `stop` prints
`stoped nginx.service on Asus TUF 7`, with one `p`. Match on the JSON if you are
scripting against this, not on the prose.

Everything else matches `start`: same command shape with the verb swapped, same
60 second timeout, same failure handling and exit codes.

### `ed machines services restart`

Restarts one unit.

```
ed machines services restart <machine> <unit> [--json]
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | machine name, ssh alias or id | required | Which machine the unit lives on. |
| `<unit>` | unit name | required | The unit, for example `nginx.service`. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the human line. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

```
$ ed machines services restart tuf nginx.service
restarted nginx.service on Asus TUF 7
```

#### `--json` shape

```json
{
  "action": "restart",
  "applied": true,
  "machine": "Asus TUF 7",
  "unit": "nginx.service"
}
```

#### Examples

```
ed machines services restart tuf nginx.service
ed machines tuf services restart docker.service
ed machines services restart tuf nginx.service --json
```

#### Behaviour notes

`systemctl restart` on a stopped unit starts it, so this is the verb to reach
for when you do not care what state the unit was in. The 60 second timeout is
the one to watch: a unit with a slow `ExecStop` can outlast it, and the command
then reports a failure for something that finishes fine a moment later.

Only `start`, `stop` and `restart` exist. There is no `enable`, `disable`,
`reload`, `status` or `journal` verb; for those, use the raw form,
`ed tuf systemctl reload nginx` or `ed tuf journalctl -u nginx -n 100`.

### `ed machines kill`

Sends a signal to one process on a machine.

```
ed machines kill <machine> <pid> [--signal <name>] [--json]
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machine>` | machine name, ssh alias or id | required | Which machine the process is on. |
| `<pid>` | integer greater than 0 | required | The process id. A value that is not an integer exits 2; zero or negative exits 1. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--signal` | `TERM`, `KILL`, `HUP`, `INT`, `QUIT`, `USR1`, `USR2` | `TERM` | Which signal to send. Case-insensitive, and a leading `SIG` is stripped, so `kill`, `KILL`, `sigkill` and `SIGKILL` are all the same. Anything else exits 3. |
| `--json` | flag | off | Emit JSON on stdout instead of the human line. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

```
$ ed machines kill tuf 4213
sent SIGTERM to 4213 on Asus TUF 7
```

#### `--json` shape

```json
{
  "alreadyExited": false,
  "machine": "Asus TUF 7",
  "pid": 4213,
  "sent": true,
  "signal": "KILL"
}
```

`signal` is the normalised name without the `SIG` prefix, whatever you typed.
`sent: true` means the remote `kill` exited 0; it is not a claim that the
process is gone, which for `TERM` is up to the process. `alreadyExited: true`
means the pid was not there to signal, and then `sent` is `false`.

#### Examples

```
ed machines kill tuf 4213
ed machines kill tuf 4213 --signal KILL
ed machines tuf kill 4213 --signal HUP
ed machines metrics tuf --processes 20 --json | jq -r '.sample.processes[] | "\(.pid) \(.name)"'
```

#### Behaviour notes

`ed machines metrics <machine> --processes 20` is how you find the pid; the
collector sends at most thirty processes, the busiest by CPU plus the largest by
memory, in no particular order, and `--processes` trims that list rather than
asking for more. There is no name matching here on purpose: this verb takes a
number, so it cannot kill the wrong thing because two processes shared a name.

The signal name is checked on this Mac before anything is sent, so a typo costs
nothing and never reaches the remote shell:

```
$ ed machines kill tuf 4213 --signal BOOM
error: there is no signal called BOOM
hint: signals: TERM, KILL, HUP, INT, QUIT, USR1, USR2
```

The remote line checks the pid is still there with `kill -0` and `/proc` before
it sends anything, then runs `kill -<SIGNAL> <pid> 2>&1`, through the login shell
with a 30 second timeout, so it runs as the SSH user and is subject to that
user's permissions. There is no sudo fallback here, unlike the unit verbs:
signalling another user's process comes back as `Operation not permitted` and
exits 1.

```
$ ed machines kill tuf 1
error: could not signal 1 on Asus TUF 7: bash: line 1: kill: (1) - Operation not permitted
```

A pid that is already gone is not a failure, because the process list a pid comes
from is a two second old snapshot and short lived processes routinely leave
between the sample and the signal. It exits 0 and says so, rather than passing
the shell's `No such process` on:

```
$ ed machines kill tuf 205886
205886 had already exited on Asus TUF 7
```

Zero and negative ids are rejected
locally with `a process id is greater than zero` and exit 1, though a negative
one needs `--` to get past the parser at all: a bare `ed machines kill tuf -1`
reads `-1` as an unknown option and exits 2, while `ed machines kill tuf -- -1`
reaches the check and exits 1.

### `ed machines broadcast`

Runs one command on every configured machine, one after another, and labels each
machine's output.

```
ed machines broadcast [--only <a,b>] [--json] [--] <command...>
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<command...>` | everything remaining | required | The command to run everywhere. Captured verbatim to the end of the line, joined with single spaces. A leading `--` is dropped. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--only` | comma-separated machine names | unset, meaning every configured machine | Restrict to these machines. Each entry is trimmed of surrounding spaces and resolved like any machine name, so aliases and prefixes work. |
| `--json` | flag | off | Emit JSON on stdout instead of the labelled blocks. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |

Flags belong before the command, because everything from the first non-flag word
onwards is the command. Use `--` to make that boundary explicit:

```
$ ed machines broadcast -- uptime
== Asus TUF 7 ==
 22:14:03 up 6 days,  3:41,  2 users,  load average: 0.42, 0.51, 0.48
== Home Box ==
 22:14:05 up 19:02,  1 user,  load average: 0.08, 0.03, 0.01
```

A machine whose command failed still shows its output, and the exit note goes to
stderr:

```
$ ed machines broadcast --only tuf,box -- docker ps -q
== Asus TUF 7 ==
b556d7fef23e
f8968a8b81e5
== Home Box ==
bash: line 1: docker: command not found
Home Box exited 127
```

#### `--json` shape

A top-level array, one object per machine, in the order they were tried:

```json
[
  {
    "machine": "Asus TUF 7",
    "output": "b556d7fef23e\nf8968a8b81e5",
    "status": 0
  },
  {
    "machine": "Home Box",
    "output": "bash: line 1: docker: command not found",
    "status": 127
  },
  {
    "machine": "Pi 4",
    "output": "The operation couldn’t be completed. (EdithCLI.CLIFailure error 1.)",
    "status": -1
  }
]
```

`status` is the remote exit code, or `-1` when the machine could not be reached
or the connection broke mid-command. `output` is stdout and stderr concatenated
and trimmed, and for a `-1` row it is Foundation's generic description of the
error rather than the reachability message you would get from
`ed machines connect`, so treat a `-1` as "could not run", not as text worth
parsing.

The whole array is emitted at the end, in one document. In the human form the
blocks stream as each machine finishes.

#### Examples

```
ed machines broadcast -- uptime
ed machines broadcast --only tuf,box -- df -h /
ed machines broadcast --json -- 'systemctl is-system-running' | jq -r '.[] | "\(.machine) \(.output)"'
ed machines broadcast -- 'apt list --upgradable 2>/dev/null | wc -l'
```

#### Behaviour notes

This is the terminal's broadcast bar as a command, aimed at every configured
machine rather than at the open panes. Machines are contacted one at a time, not
in parallel, each with its own 120 second timeout, so a run across five machines
can take ten minutes in the worst case. Each one opens or reuses the shared
ControlMaster socket, so a sleeping host is dialled rather than skipped.

A machine that cannot be reached is reported and the rest still run. That is the
point of the verb: one unreachable host does not cost you the other answers.

The exit code is 1 if any machine returned a non-zero status, including the `-1`
rows. It is the one command in this group that writes real output to stdout and
still exits non-zero, so gate on the exit code first and read the array second.

Arguments are joined with a single space and sent as one line to the remote
shell, which means shell metacharacters are the machine's to interpret, not
yours. Quote the whole line when you want a pipe, a redirect or a glob to run
over there, as in the last example above.

Failure to give a command at all exits 2 from the parser. A command that is only
whitespace, or a bare `--`, exits 1 with `give a command to run`. With no
machines configured it exits 3:

```
$ ed machines broadcast -- uptime
error: no machines are configured
hint: add one with `ed machines add`
```

`--only` resolves every name before any command runs, so one bad name exits 3
and nothing is executed anywhere. Names may repeat, and the machine then runs
the command twice.

## Exit codes

| Code | When |
| --- | --- |
| 0 | The command did what it says. Also the dry run of `reboot` and `shutdown` without `--yes`, `services ls` on a machine with no systemd, and `--help` on any of these. |
| 1 | The machine refused a reboot or shutdown; a unit verb failed or came back with a privilege message; `kill` was rejected by the far side or given a pid of zero or less; the wake packet could not be built or sent; `broadcast` had at least one machine return non-zero; `broadcast` was given an empty command. |
| 2 | The command line was wrong: an unknown flag, a missing machine, unit or command, or a pid that is not an integer. |
| 3 | The machine name is unknown or an ambiguous prefix; `--signal` named something that is not one of the seven; `broadcast` found no machines configured, or `--only` named a machine that does not exist. |
| 4 | The machine could not be reached, which covers every verb that opens a connection; or `wake` was asked for a machine with no stored MAC address. |

`broadcast` never exits 4 for an unreachable machine, because reaching some and
not others is the case it exists to handle. That failure becomes a `-1` row and
folds into the overall exit 1.

None of these codes ever comes from Edith not running. Nothing on this page
talks to the app.

## Notes and gotchas

- Nothing here needs the Edith app or the menu bar helper. `status` reads the
  machine file under `~/Library/Application Support/Edith` and the control
  socket; `wake` opens a UDP socket; everything else is `/usr/bin/ssh`. No macOS
  permission is involved either, so exit 4 on this page always means the machine
  is unreachable or unknown to wake-on-LAN, never that Edith is closed.
- The privilege fallback runs in different orders in the two families. `reboot`
  and `shutdown` try `sudo -n systemctl ...` first and fall back to plain
  `systemctl`. The unit verbs try plain `systemctl ...` first and fall back to
  `sudo -n`. Both fold stderr into stdout with `2>&1`, so both attempts' output
  arrives in one string.
- That has a sharp edge on the unit verbs. Because the first attempt's output is
  still in the buffer, a `start` that only succeeded through the sudo fallback
  can carry the first attempt's *Interactive authentication required* text, and
  the presence of that phrase alone is enough for `ed` to call it a failure. The
  unit changes state on the machine and `ed` exits 1 saying it could not. If you
  see that, check with `ed machines services ls <machine>` before retrying.
- The phrases that count as a privilege problem are `password is required`,
  `interactive authentication required`, `access denied`, `not authorized` and
  `permission denied`, matched case-insensitively anywhere in the output. A unit
  whose own log line happens to contain one of them is judged the same way.
- `power status` answers about the control socket, not about the machine.
  `connected: false` on a machine that is up simply means no shared connection
  is open yet, and the next command will open one.
- A reboot that takes the connection down with it is meant to be treated as
  success, and the code has a branch for exactly that, keyed on ssh reporting
  status 255 or a closed connection. That branch only fires for an error thrown
  by the SSH layer, and the layer returns the exit status instead of throwing
  it, so in practice an ssh that exits 255 because the host vanished is reported
  as a refusal and exits 1. The normal case is unaffected, because
  `systemctl reboot` returns 0 before the host goes down.
- `--yes` exists on `reboot` and `shutdown` only. `services stop`, `kill` and
  `broadcast` are all capable of taking a machine off the network and none of
  them asks first.
- Object keys in every `--json` document on this page are sorted
  lexicographically, and each invocation prints exactly one document, so output
  diffs cleanly and `jq` never sees a stream. `--json` is declared per command
  and is long-form only; there is no `-j`.
- A failing command prints nothing on stdout, with one exception:
  `ed machines broadcast` prints its blocks or its array and then exits 1 when a
  machine failed.
- `ed machines power` with no verb and no machine exits 2, because the default
  subcommand still wants a machine. `ed machines power <machine>` is
  `ed machines power status <machine>`, and `ed machines services <machine>` is
  `ed machines services ls <machine>`.
- Aliases: `power reboot` is also `power restart`, `power shutdown` is also
  `power poweroff`, and `services ls` is also `services list`. The `action`
  field in JSON always carries the canonical name, `reboot` or `shutdown`.
- Shell completion knows this whole subtree, including machine names in the
  machine slot. It does not complete unit names or pids, because those would
  need a round trip to the machine.

## Where to go next

- [`ed machines`](./machines.md) for the machine directory itself, including
  `ed machines edit <machine> --mac <address>` to teach `wake` an address, and
  `ed machines metrics` for the process list `kill` needs.
- [Running commands on a machine](./machines-remote.md) for the raw form, which
  is where `systemctl enable`, `journalctl` and anything else not covered here
  belongs.
- [`ed machines docker`](./machines-docker.md) for the container equivalents of
  start, stop, restart and rm.
- [`ed machines files`](./machines-files.md) for moving things onto and off a
  machine.
- [Conventions and contracts](./conventions.md) for the full exit code table and
  the `--json` guarantee.
- [The `ed` command line](./README.md) for the rest of the reference.
