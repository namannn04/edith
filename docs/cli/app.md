# `ed app`

`ed app` holds the one-shot verbs the Edith app performs. These are things the
app does once when asked, rather than switches `ed config set` can flip: lock
the keyboard for cleaning, send the test notification, open or quit the window,
ask Sparkle to look for an update, and relaunch after granting a permission.

Edith is two processes with two bundle ids: the menu bar helper,
`com.pulkit.edith.statusbar`, and the main window, `com.pulkit.edith`. Each verb
is a distributed notification addressed to whichever of the two owns the work,
so each needs that process to be running and exits 4 naming the part that is
missing. `clean-keys`, `test-notification` and `open` are answered by the menu
bar helper. `quit` and `check-updates` are answered by the main window, because
the window and Sparkle both live there. `updates` and `clear-updates` touch a
file, and `relaunch` terminates both bundle ids itself and launches the app
bundle again, so all three work with Edith closed.

Reach for this group when you want the app to do something now. Reach for
`ed config` when you want to change what it does from now on.

## At a glance

| Command | What it does |
| --- | --- |
| `ed app actions` | List the five one-shot actions, what each needs, and whether it can run right now. Aliased `ed app ls`, and what a bare `ed app` runs. |
| `ed app clean-keys` | Ask the menu bar app to lock the keyboard so it can be wiped without typing. |
| `ed app test-notification` | Ask the menu bar app to send the same test notification the settings pane sends. |
| `ed app open` | Ask the menu bar app to open Edith's main window. |
| `ed app quit` | Quit the main window, leaving the menu bar running. |
| `ed app check-updates` | Ask Sparkle to check for an update now, and report what it found. |
| `ed app updates` | Print the update checks Edith has already made, newest first. |
| `ed app relaunch` | Quit Edith and start it again, which is what a new permission needs. |
| `ed app clear-updates` | Delete the record of past update checks. |

## Commands

### `ed app actions`

Lists the five one-shot actions with the process each one needs and whether that
process is running.

```
ed app actions [--json]
```

`ls` is an alias, and `actions` is the group's default subcommand, so
`ed app actions`, `ed app ls` and a bare `ed app` all print the same table.

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout. |

`--json` shape, a top-level array with one object per action:

```json
[
  {
    "action": "clean-keys",
    "available": true,
    "needs": "menuBar",
    "summary": "Lock the keyboard so it can be wiped."
  },
  {
    "action": "test-notification",
    "available": true,
    "needs": "menuBar",
    "summary": "Send a test notification."
  },
  {
    "action": "open",
    "available": true,
    "needs": "menuBar",
    "summary": "Open the Edith panel."
  },
  {
    "action": "quit",
    "available": false,
    "needs": "mainApp",
    "summary": "Quit the Edith main window."
  },
  {
    "action": "check-updates",
    "available": false,
    "needs": "mainApp",
    "summary": "Ask Sparkle to check for an update now."
  }
]
```

`needs` is `menuBar` or `mainApp`, never anything else. `available` is the live
answer for that one process, so the two `mainApp` rows can be false while the
three `menuBar` rows are true.

Examples:

```
ed app actions
ed app ls --json
ed app
```

This command reads the process table and nothing else: it changes nothing, needs
neither process, and reports a closed app as `available: false` rather than
failing, so it always exits 0. It is the cheap way to find out whether the next
verb will work.

```
$ ed app actions
ACTION             NEEDS     STATE  WHAT
clean-keys         menu bar  ready  Lock the keyboard so it can be wiped.
test-notification  menu bar  ready  Send a test notification.
open               menu bar  ready  Open the Edith panel.
quit               main app  ready  Quit the Edith main window.
check-updates      main app  ready  Ask Sparkle to check for an update now.
```

The human table writes `needs` as `menu bar` or `main app`, and `STATE` as
`ready` or `app not running`.

### `ed app clean-keys`

Locks the keyboard so you can wipe it without typing into whatever is in front.

```
ed app clean-keys [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout. |

`--json` shape:

```json
{
  "action": "clean-keys",
  "requested": true
}
```

Examples:

```
ed app clean-keys
ed app clean-keys --json
```

Without `--json` it prints `clean-keys requested`. This is the menu bar's
keyboard-cleaning lock, so it needs the helper and exits 4 with `clean-keys
needs the Edith menu bar app to be running` when the helper is closed. The
request is fire and forget: `ed` posts the notification and returns, so exit 0
means the request was sent, not that the lock came up.

What the helper does with it is the same path the System page's button takes. It
re-reads its permissions, ignores the request outright when a clean is already
under way, and if Input Monitoring or Accessibility is missing it raises that
request instead of locking; otherwise it dismisses the panel, arms the countdown
and shows the overlays. If the System extension is off the helper has no system
store at all and the notification lands nowhere, and `ed` still exits 0, so
check `ed extensions ls` for `system` when nothing happens.

### `ed app test-notification`

Sends the same test notification the settings pane sends.

```
ed app test-notification [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout. |

`--json` shape:

```json
{
  "action": "test-notification",
  "requested": true
}
```

Examples:

```
ed app test-notification
ed app test-notification --json
```

Without `--json` it prints `test-notification requested`. It needs the menu bar
helper and exits 4 otherwise. The notification is sent by the Agent Usage
notifier, so it needs the `usage` extension on as well as the helper running;
with that extension off, nothing is sent and `ed` still exits 0. The helper
discards the notifier's own answer, so a notification blocked in System Settings
is silent here too: `ed permissions request notifications` is the fix.

### `ed app open`

Opens Edith's main window.

```
ed app open [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout. |

`--json` shape:

```json
{
  "action": "open",
  "requested": true
}
```

Examples:

```
ed app open
ed app open --json
```

Without `--json` it prints `open requested`. The guard is on the menu bar
helper, not the window: the helper is what receives the request and launches or
activates the main app, so `ed app open` exits 4 when the helper is closed even
though what it opens is the window. It is the counterpart to `ed app quit`. When
neither process is running, `ed app relaunch` is what starts Edith from cold.

### `ed app quit`

Quits the Edith main window and leaves the menu bar running.

```
ed app quit [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout. |

`--json` shape:

```json
{
  "action": "quit",
  "requested": true
}
```

Examples:

```
ed app quit
ed app quit --json
```

Without `--json` it prints `quit requested`. This is the one menu-bar-facing
verb that is guarded on the main window rather than the helper, because there is
nothing to quit otherwise: with the window closed it exits 4 with `quit needs
the Edith main window to be open`, hint `open Edith from the menu bar, then
retry`.

It quits less than the menu bar's own Quit item does. The menu item posts the
same request and then terminates the helper as well; `ed app quit` posts only
the request, so the menu bar app survives and `ed app open` brings the window
back.

### `ed app check-updates`

Asks the running app to run a Sparkle check now, waits for the answer, and
reports it.

```
ed app check-updates [--json] [--no-wait]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout. |
| `--no-wait` | flag | off | Return as soon as the request is sent, collapsing the wait from 60 seconds to 0.1. |

`--json` shape once the app has answered:

```json
{
  "detail": null,
  "finished": true,
  "outcome": "updateFound",
  "requested": true,
  "version": "0.0.28"
}
```

`outcome` is `upToDate`, `updateFound` or `failed`, and falls back to `unknown`
if the app answers without one. `version` carries the version Sparkle found and
is `null` on the other outcomes; `detail` carries the failure text and is `null`
unless the check failed.

With `--no-wait`, the usual answer is that nothing came back in time, which is
reported rather than treated as an error:

```json
{
  "finished": false,
  "requested": true
}
```

Examples:

```
ed app check-updates
ed app check-updates --json
ed app check-updates --no-wait
```

Without `--json` it prints the outcome alone, `upToDate`, or the outcome and the
version, `updateFound 0.0.28`, and with `--no-wait` and no answer it prints
`update check requested`.

Sparkle lives in the main window, so this exits 4 with `check-updates needs the
Edith main window to be open` when only the menu bar is running. The wait is 60
seconds; after the first second `ed` prints `waiting for Edith to answer...` on
stderr, which keeps stdout to the one JSON document.

Silence at the end of those 60 seconds is exit 4, not a false success. `ed`
diagnoses which kind of silence it was: `Edith is not running, so it cannot
answer for the update check` when the helper is gone, and otherwise `Edith did
not answer for the update check in time`, with the hint that the running app may
predate this command. Two ordinary situations produce that second message: a
build whose Sparkle updater never started does not listen for the request at
all, and a check that is already in flight is dropped rather than queued.

`--no-wait` never fails that way. It still waits 0.1 seconds and still reports a
reply that lands inside it, but a silent app is reported as
`"finished": false` and exit 0, which makes it the right form for a script that
only wants the check kicked off.

Whatever the outcome, the app records the check in its own log, so
`ed app updates` shows it afterwards even when `ed` gave up waiting.

### `ed app updates`

Prints the update checks Edith has already made, newest first.

```
ed app updates [--limit <n>] [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--limit <n>` | integer greater than zero | `20` | Show at most this many checks. |
| `--json` | flag | off | Emit JSON on stdout. |

`--json` shape, a top-level array with one object per check:

```json
[
  {
    "date": "2026-08-08T14:18:40Z",
    "detail": null,
    "kind": "manual",
    "outcome": "upToDate",
    "version": null
  },
  {
    "date": "2026-08-06T21:37:42Z",
    "detail": null,
    "kind": "automatic",
    "outcome": "updateFound",
    "version": "0.0.28"
  }
]
```

`kind` is `automatic` for a background check, which is both the scheduled ones
and every `ed app check-updates`, because the app answers that request with
Sparkle's background check. `manual` is the app's own Check for Updates button
and nothing `ed` can produce. `outcome` is `upToDate`, `updateFound` or
`failed`. `version` is filled in only on `updateFound`, `detail` only on
`failed`, and both are present as `null` otherwise so the shape does not change
between runs.

Examples:

```
ed app updates
ed app updates --limit 5
ed app updates --json
```

```
$ ed app updates --limit 5
WHEN                  KIND       OUTCOME      WHAT
2026-08-08T14:18:40Z  manual     upToDate     Up to date
2026-08-08T08:39:36Z  manual     upToDate     Up to date
2026-08-08T04:51:46Z  automatic  upToDate     Up to date
2026-08-07T13:42:03Z  automatic  upToDate     Up to date
2026-08-06T21:37:42Z  automatic  updateFound  Found 0.0.28
```

The `WHAT` column is a sentence built from the record: `Up to date`,
`Found <version>`, or the failure detail. A found update with no version reads
`Update found`, and a failure with no detail reads `Check failed`.

This is a file, `~/Library/Application Support/Edith/update-checks.json`, so it
needs nothing running. The app keeps the newest 200 checks and drops the rest,
and `ed` sorts by date descending before applying `--limit`. With no checks
recorded, it writes `no update checks recorded yet` to stderr, leaves stdout
empty and exits 0; with `--json` it prints `[]` instead.

`--limit 0` and `--limit=-1` exit 2 with `--limit must be greater than zero`.
Written as `--limit -1`, ArgumentParser reads the `-1` as another option and
exits 2 for a missing value instead, which is the same code by a different
route.

### `ed app relaunch`

Quits both Edith processes and starts the app again, which is what a new
permission grant needs before it takes effect.

```
ed app relaunch [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout. |

`--json` shape:

```json
{
  "path": "/Applications/Edith.app",
  "relaunched": true
}
```

Examples:

```
ed app relaunch
ed app relaunch --json
```

Without `--json` it prints `relaunched Edith`, and only once the quit and the
launch have both happened. While it works it paints two transient spinner lines
on stderr, `waiting for Edith to quit` and then `starting Edith`; they are
skipped with `--json` and whenever stderr is not a terminal, so stdout stays one
document. This is the Permissions pane's relaunch button as a command, with a
longer reach: the button restarts the menu bar helper it lives in, while `ed`
takes both processes down. macOS hands a process its TCC answers when it starts,
so a grant you have just given is invisible until the app runs again.

It needs no running process, but it does need to find the app, which it checks
before it quits anything. When neither the bundle this binary sits inside nor
`/Applications/Edith.app` exists, it exits 4 with `Edith is not installed where
ed can find it`, hint `it looks in /Applications and alongside this binary`.

The order is: post the quit request, then terminate every process carrying
either bundle id, wait up to 8 seconds for them to go, force quit whatever is
still there and give that 3 seconds more, and only then launch the bundle and
wait for it to come up. With Edith already closed the quit step finishes at
once. The launch asks for a fresh instance and does not activate it, so Edith
comes back without taking focus.

Either half can fail the command, and neither failure is silent. If anything is
still alive after the force quit it exits 1 with `Edith did not quit, so it was
not relaunched`, hinting that you quit it from the menu bar and run the command
again, and nothing is launched. A launch that throws exits 1 with `could not
start Edith:` and the reason, hinting at opening the bundle from Finder.

Both processes come back: the helper is terminated along with the main window,
and the main app starts it again as it launches, so a grant that belongs to the
helper bundle rather than the main one is picked up by a relaunch too.

### `ed app clear-updates`

Deletes the record of past update checks.

```
ed app clear-updates [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout. |

`--json` shape, where `removed` is how many checks were in the log before it
went:

```json
{
  "removed": 42
}
```

Examples:

```
ed app clear-updates
ed app clear-updates --json
```

Without `--json` it prints `cleared 42 check(s)`. This is the clear button in
the update schedule sheet. It counts the file, deletes it, and exits 0 whether
or not there was anything to delete, reporting `cleared 0 check(s)` in the empty
case.

It is the only destructive verb in this group and it takes no `--yes`, because
there is nothing behind the log: the file is removed outright rather than moved
to the Trash, and the checks it held are gone. Nothing else is touched, and
neither process needs to be running.

## Exit codes

| Code | What produces it here |
| --- | --- |
| 0 | The command did what it says, including a request that was sent but never confirmed, `check-updates --no-wait` with no answer, `updates` with an empty log, and `actions` when nothing is running. |
| 1 | `relaunch` could not finish the work: Edith was still running after the force quit, or the launch itself threw. |
| 2 | The command line was wrong: an unknown flag, an unknown subcommand, or `--limit` at zero or below on `ed app updates`. |
| 4 | The process the verb needs is not running: the menu bar helper for `clean-keys`, `test-notification` and `open`, the main window for `quit` and `check-updates`. Also `check-updates` when the app never answers within 60 seconds, and `relaunch` when no `Edith.app` can be found. |

3 does not come out of this group, and 1 comes only from `relaunch`. The action
names are fixed rather than typed, so there is no name for you to get wrong:
`ed app frobnicate` is parsed as a stray argument to the default `actions`
subcommand and exits 2 rather than 3.

## Notes and gotchas

The transport is `DistributedNotificationCenter`, wrapped as `IPC`, with names
like `com.pulkit.edith.requestKeyboardClean`. Neither binary shells out to the
other and there is no socket, so a verb reaches Edith only when Edith is
listening for that exact name. `relaunch` is the exception: it posts a quit but
does not depend on anyone hearing it, terminating and starting the processes
itself.

"Running" means a process with that bundle id is registered with the window
server, which is what `NSRunningApplication` reports. An app in the middle of
launching reads as not running. `ed app relaunch` waits for the main app to
register before it returns, but the helper is started by the main app after
that, so `ed app relaunch && ed app clean-keys` still races the helper's launch.

Four of the five actions are fire and forget: `ed` posts and returns without
waiting for confirmation, so exit 0 means the notification was sent. Only
`check-updates` waits for a reply, and only it can fail on silence.
`ed app actions` is the way to check first rather than reading exit codes after.
`relaunch` is not one of the five and is neither fire and forget nor a reply: it
watches the processes go and come back, so its exit code says what actually
happened.

Extensions gate two of the actions inside the app rather than in `ed`.
`clean-keys` needs the `system` extension and `test-notification` needs `usage`;
with the extension off, the helper is running, the guard passes, `ed` exits 0
and nothing happens. `ed extensions ls` is where that shows up.

`--json` output follows the CLI-wide contract: one document per invocation,
object keys sorted, absent values present as `null` rather than dropped.
`actions` and `updates` emit a top-level array, the rest an object. The one
document that drops keys rather than nulling them is the unanswered
`check-updates --no-wait`, which has no outcome to report and so carries
`requested` and `finished` alone. The `waiting for Edith to answer...` line from
`check-updates` goes to stderr, so piping stdout into `jq` stays clean.

The reply to `check-updates` also carries the check's `kind`, which `ed` does
not print; `ed app updates` shows the kind of every recorded check, and a check
you started with `ed` appears there as `automatic`, because the app runs the
request as a Sparkle background check rather than a user-initiated one.

The silence diagnosis for `check-updates` asks whether the menu bar helper is
running, while the guard before it asked about the main window. In the unusual
state where the window is open and the helper is not, the failure reads `Edith
is not running` rather than naming the helper.

`ed app clear-updates` writes nothing back to a running app. The window's own
history list is held in memory and is not told the file went, so it keeps
showing the old rows until the next check is recorded, at which point it
rewrites itself from the now-empty file and shows that one check.

`ed app quit` leaves the menu bar helper alive. `ed app relaunch` is the one verb
here that takes the helper down, and it does that by terminating the process
itself rather than asking Edith to; `RunningApps` still protects both Edith
bundle ids from every quit path it drives, `ed apps quit --all` included.

## Where to go next

- [`ed permissions`](./permissions.md) for the grants that make `ed app
  relaunch` worth running.
- [`ed extensions`](./extensions.md) for the `system` and `usage` switches that
  decide whether `clean-keys` and `test-notification` do anything.
- [`ed apps`](./apps.md) for quitting other applications, which is a different
  group with a similar name.
- [All command groups](./README.md).
