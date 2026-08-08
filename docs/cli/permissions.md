# `ed permissions`

macOS hands privacy grants to an application bundle, not to a process, so the
nine permissions Edith uses belong to the Edith app and never to `ed`. A command
line process cannot read another bundle's TCC state, and it must not try. `ed`
therefore reports the mirror the app writes into the shared defaults suite every
time it re-reads the real state, and hands anything that needs a live system
prompt back to the app.

Reach for this group when an extension is on but doing nothing:
`ed permissions ls --attention` names the grant that is holding it up, in one
line, without you opening System Settings to find out.

## At a glance

| Command | What it does |
| --- | --- |
| `ed permissions ls` | Print every permission with its mirrored state, whether it blocks an enabled extension, and which enabled extensions use it |
| `ed permissions request <permission>` | Ask the running app to raise the macOS prompt for one permission, wait, then report whether the grant landed |
| `ed permissions refresh` | Ask the running app to re-read the real TCC state, then print the refreshed mirror |

`ls` is the default subcommand, so a bare `ed permissions` prints the table.
`list` is an accepted alias for `ls`.

## The permissions Edith uses

There are exactly nine and they are fixed in the binary. `ed permissions
request` is the only command in this group that takes one of their ids; it
matches case-insensitively, and an id that is not one of these exits 3 with the
full list as the hint.

| Id | Where it lives in System Settings | What Edith needs it for | Used by |
| --- | --- | --- | --- |
| `calendar` | Privacy & Security > Calendars | Read and show your schedule in Calendar | required by `calendar` |
| `notifications` | Notifications | Usage limit, pacing and reset alerts | optional for `usage`, `machines` |
| `accessibility` | Privacy & Security > Accessibility | Clean keys, and clipboard instant paste | optional for `system`, `clipboard` |
| `inputMonitoring` | Privacy & Security > Input Monitoring | Block key presses while Clean keys is locking the keyboard | optional for `system` |
| `fullDisk` | Privacy & Security > Full Disk Access | Reach local service credentials and usage data | nothing declares it |
| `screenRecording` | Privacy & Security > Screen Recording | Detect shared content, and sample colours from the screen | required by `focusDim`, `presenter`, `colorPicker` |
| `camera` | Privacy & Security > Camera | The Notch Shelf camera preview | optional for `notchShelf` |
| `bluetooth` | Edith opens no pane, granted on first use | Notch Shelf device connection alerts | optional for `notchShelf` |
| `automation` | Edith opens no pane, granted on first use | Notch Shelf controlling external playback | optional for `notchShelf` |

For the seven that can be requested, the `reason` string in `--json` is the same
sentence the Permissions pane shows under each row, so the CLI and the UI cannot
describe those grants differently. `bluetooth` and `automation` are the
exception: the pane prefers their first-use explanation, which is the same
sentence `request` prints as its hint when it refuses them.

How each one is observed, and what asking for it actually does:

| Id | Mirror setting | How the app observes the real state | What `request` makes the app do |
| --- | --- | --- | --- |
| `calendar` | `permCalendarGranted` | the event store's own authorisation status | ask `EKEventStore` for full access to events, and open the Calendars pane |
| `notifications` | `permNotificationsGranted` | `UNUserNotificationCenter`, counting authorised and provisional as granted | request alert and sound authorisation, and open the Notifications pane |
| `accessibility` | `permAccessibilityGranted` | `AXIsProcessTrusted()` | raise the trusted-process prompt, and open the Accessibility pane |
| `inputMonitoring` | `permInputMonitoringGranted` | `CGPreflightListenEventAccess()` | `CGRequestListenEventAccess()`, and open the Input Monitoring pane |
| `fullDisk` | `permFullDiskGranted` | try to open `~/Library/Application Support/com.apple.TCC/TCC.db` for reading | open the Full Disk Access pane, because macOS offers no prompt for it |
| `screenRecording` | `permScreenRecordingGranted` | `CGPreflightScreenCaptureAccess()` | `CGRequestScreenCaptureAccess()`, and open the Screen Recording pane |
| `camera` | `permCameraGranted` | `AVCaptureDevice` video authorisation | ask `AVCaptureDevice` when the state is undetermined, open the Camera pane otherwise |
| `bluetooth` | none | not observed | refused, exit 4 |
| `automation` | none | not observed | refused, exit 4 |

`calendar` is the odd one out in that table. Its mirror is written by the main
Edith window rather than by the menu bar helper, and the helper is what answers
`request` and `refresh`, so with only the menu bar running the calendar row
keeps whatever the window last stored. The prompt still comes up; the mirror
catches up the next time the window is open. The other six move under a refresh.

`bluetooth` and `automation` have no mirror setting because macOS grants them
the first time the code that needs them runs, and there is no ahead-of-time
prompt to raise. They therefore report `granted` as `false` for as long as they
exist, which is a statement about what Edith knows rather than about what macOS
has decided. `ls` says `on first use` for them instead of `no`; `refresh` says
`no`.

`fullDisk` is in the catalogue but no extension declares it, so it never blocks
anything and never appears under `--attention`. Request it by hand when a
feature tells you to.

The seven mirror settings are ordinary read-only keys in the `permissions`
group, so `ed config ls --group permissions` shows the same booleans and writing
one exits 1. That group also holds `permissionsFilter`, which is the filter the
Permissions pane opens with, and is writable.

## Commands

### `ed permissions ls`

Print the permission table as Edith last observed it. Reads the states out of
the shared defaults suite, and asks the app for nothing beyond whether its
process is up, which only `--json` needs, so it works whether or not Edith is
running.

```
ed permissions ls [--attention] [--json]
```

Aliases: `ed permissions list`. Default subcommand: `ed permissions` alone runs
it.

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--attention` | flag | off | Keep only permissions that block an enabled extension: not granted, and required (not merely optional) by at least one extension that is currently on |
| `--json` | flag | off | Emit JSON on stdout |

#### `--json` shape

An object with `appRunning` and `permissions`, and one object per permission in
the fixed order of the table above. Trimmed here to three of the nine rows:

```json
{
  "appRunning": true,
  "permissions": [
    {
      "blocksEnabledExtension": true,
      "granted": false,
      "grantsOnFirstUse": false,
      "id": "calendar",
      "name": "Calendar",
      "optionalFor": [],
      "reason": "Required to read and show your schedule in Calendar.",
      "requiredBy": [
        "calendar"
      ],
      "usedByEnabledExtension": true
    },
    {
      "blocksEnabledExtension": false,
      "granted": true,
      "grantsOnFirstUse": false,
      "id": "screenRecording",
      "name": "Screen Recording",
      "optionalFor": [],
      "reason": "Required to detect shared content or sample colors from the screen.",
      "requiredBy": [
        "focusDim",
        "presenter",
        "colorPicker"
      ],
      "usedByEnabledExtension": true
    },
    {
      "blocksEnabledExtension": false,
      "granted": false,
      "grantsOnFirstUse": true,
      "id": "bluetooth",
      "name": "Bluetooth",
      "optionalFor": [
        "notchShelf"
      ],
      "reason": "Asked when Notch Shelf first checks for device connections.",
      "requiredBy": [],
      "usedByEnabledExtension": true
    }
  ]
}
```

`appRunning` reports whether the menu bar helper is up, which is how you tell a
live mirror from one that has not been touched since the app was last closed.
`requiredBy` and `optionalFor` list every extension that declares the
permission, enabled or not; `usedByEnabledExtension` and
`blocksEnabledExtension` are the two questions that account for which extensions
are actually on. `grantsOnFirstUse` is true exactly for `bluetooth` and
`automation`. `--attention` filters the `permissions` array the same way it
filters the human table, so the two flags combine.

#### Examples

```
ed permissions ls
ed permissions ls --attention
ed permissions ls --json | jq -r '.permissions[] | select(.granted | not) | .id'
ed permissions ls --json | jq .appRunning
```

#### Behaviour

The `STATE` column is `granted` when the mirror says so, `on first use` when the
permission cannot be requested, and `no` otherwise. The unnamed third column
holds `blocking` on any row that stops an enabled extension working. `USED BY`
lists only the extensions that are currently enabled, comma separated, so a
permission whose users are all switched off shows an empty column while `--json`
still names them under `requiredBy` and `optionalFor`.

```
$ ed permissions ls
PERMISSION       STATE                   USED BY
calendar         no            blocking  calendar
notifications    granted                 usage,machines
accessibility    granted                 system,clipboard
inputMonitoring  granted                 system
fullDisk         no
screenRecording  granted                 focusDim,presenter,colorPicker
camera           granted                 notchShelf
bluetooth        on first use            notchShelf
automation       on first use            notchShelf

$ ed permissions ls --attention
PERMISSION  STATE            USED BY
calendar    no     blocking  calendar
```

Nothing is mutated and nothing is asked of the app, so this exits 0 on every
machine, including one where Edith has never run and every mirror key is absent
and therefore false.

### `ed permissions request`

Ask the running app to raise the macOS prompt for one permission, wait for it,
then report the mirror. This is the button on a row of the Permissions pane.

```
ed permissions request <permission> [--json]
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<permission>` | one of `calendar`, `notifications`, `accessibility`, `inputMonitoring`, `fullDisk`, `screenRecording`, `camera`, `bluetooth`, `automation` | required | The permission to ask for. Matched case-insensitively, so `INPUTMONITORING` resolves the same as `inputMonitoring` |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout |

#### `--json` shape

```json
{
  "granted": false,
  "permission": "calendar"
}
```

`permission` is the id you asked for, normalised to the catalogue's spelling.
`granted` is the mirror re-read after the wait, not a promise that the prompt
was answered.

#### Examples

```
ed permissions request calendar
ed permissions request screenRecording --json
ed permissions request notifications && ed app relaunch
```

#### Behaviour

The three checks run in this order, and the first one that fails is the one you
see:

1. the id is looked up, and an unknown one exits 3 listing all nine,
2. `bluetooth` and `automation` are refused, because they have no prompt to
   raise, and exit 4,
3. the menu bar app must be running, and exit 4 says so when it is not.

Because the refusal is checked before the app is, asking for `bluetooth` with
Edith closed still tells you the useful thing:

```
$ ed permissions request bluetooth
error: Bluetooth is granted on first use and cannot be requested
hint: macOS will ask for Bluetooth access when connection alerts first run.

$ ed permissions request wifi
error: no permission named wifi
hint: known: calendar, notifications, accessibility, inputMonitoring, fullDisk, screenRecording, camera, bluetooth, automation
```

Past those checks the command posts the permission's grant notification, sleeps
1500 ms, posts a refresh, sleeps another 1000 ms, and reads the mirror. So it
takes at least two and a half seconds, and it is a fixed wait rather than a
reply it can wait on. The app's side of that notification opens the matching
System Settings pane on your screen, which is a visible side effect of a command
you may have run over SSH.

A grant that has not landed inside those two and a half seconds is the normal
outcome for anything you have to toggle in System Settings by hand. The command
reports it and still exits 0, so gate on the `granted` field rather than on the
exit code:

```
$ ed permissions request calendar
calendar not granted yet
note: finish the prompt in System Settings, then run `ed permissions refresh`
```

Accessibility, Input Monitoring and Screen Recording only take effect for a
process that starts after the grant, so follow a successful request with
`ed app relaunch`.

### `ed permissions refresh`

Ask the running app to re-read the real TCC state, then print the refreshed
mirror. Run it when you suspect what `ls` showed you is stale.

```
ed permissions refresh [--json]
```

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout |

#### `--json` shape

A top-level array, not an object, carrying the same nine permission objects `ls`
puts under its `permissions` key. There is no `appRunning` field, because the
command cannot get this far with the app closed. Trimmed here to two rows:

```json
[
  {
    "blocksEnabledExtension": true,
    "granted": false,
    "grantsOnFirstUse": false,
    "id": "calendar",
    "name": "Calendar",
    "optionalFor": [],
    "reason": "Required to read and show your schedule in Calendar.",
    "requiredBy": [
      "calendar"
    ],
    "usedByEnabledExtension": true
  },
  {
    "blocksEnabledExtension": false,
    "granted": true,
    "grantsOnFirstUse": false,
    "id": "notifications",
    "name": "Notifications",
    "optionalFor": [
      "usage",
      "machines"
    ],
    "reason": "Asked when you enable usage limit, pacing, or reset alerts.",
    "requiredBy": [],
    "usedByEnabledExtension": true
  }
]
```

#### Examples

```
ed permissions refresh
ed permissions refresh --json | jq -r '.[] | select(.blocksEnabledExtension) | .id'
```

#### Behaviour

It requires the menu bar app, posts one refresh notification, sleeps 1200 ms,
and prints what the mirror says then. The sleep is fixed rather than a reply it
waits on, so a machine under load can print a mirror the app is still mid-way
through updating; running it twice costs nothing.

The human table is narrower than the one `ls` prints, two columns and no
`blocking` marker, and its `STATE` is only ever `granted` or `no`. That is why
`bluetooth` and `automation` read `no` here and `on first use` under `ls`:

```
$ ed permissions refresh
PERMISSION       STATE
calendar         no
notifications    granted
accessibility    granted
inputMonitoring  granted
fullDisk         no
screenRecording  granted
camera           granted
bluetooth        no
automation       no
```

With Edith closed:

```
$ ed permissions refresh
error: refreshing permissions needs the Edith menu bar app to be running
hint: start Edith, then retry
```

Refreshing makes the menu bar helper rewrite any of its six mirror settings the
real state has moved under, `calendar` excepted for the reason given above, so
it is the one command here that leaves stored state changed, and what it changes
is only Edith's record of what macOS had already decided.

## Exit codes

| Code | What produces it in this group |
| --- | --- |
| 0 | Any successful run, including a `request` whose grant did not land inside the wait |
| 2 | An unknown flag, or `ed permissions request` with no permission named |
| 3 | `ed permissions request <permission>` where the id is not one of the nine, with the full list as the hint |
| 4 | `ed permissions request bluetooth` or `automation`; `request` or `refresh` while the Edith menu bar app is closed |

`ed permissions ls` has no failure path and always exits 0.

## Notes and gotchas

- Nothing in this group reads the real TCC database. `ls` reads the mirror,
  `refresh` asks the app to update the mirror, `request` asks the app to raise a
  prompt. The grants belong to the Edith bundle, and a mirror is the only honest
  thing a separate process can report.
- On a Mac where Edith has never run, every mirror key is missing and therefore
  reads false, so `ls` reports nothing as granted. `appRunning: false` in the
  same document is what distinguishes that from a real answer.
- `--attention` looks at `requiredBy` only. A missing permission that is merely
  optional for an enabled extension degrades that extension rather than blocking
  it, so it never shows as `blocking` and never survives the filter.
- The permission ids are exactly the ids shell completion offers, and the same
  ids `ed extensions info <id> --json` prints under `requiredPermissions`,
  `optionalPermissions` and `missingRequiredPermissions`.
- Turning an extension on never waits for its permission. `ed extensions enable`
  enables it and names the missing grant on stderr, and this group is where you
  go next.
- Other commands point back here when macOS is what is stopping them. A calendar
  read with the grant missing exits 4 and hints at
  `ed permissions request calendar`, which is this same failure reached by a
  different route.
- `ed permissions request` opens System Settings on the Mac running Edith. That
  is the app's doing rather than the CLI's, and it happens whether you typed the
  command locally or over SSH.
- Both writing verbs talk to the app over its own distributed notification bus
  and neither shells out to it. `request` posts the permission's grant name;
  both post the shared refresh name afterwards.

## Where to go next

- [`ed extensions`](./extensions.md) for the extensions these permissions gate.
- [`ed config`](./config.md) for the read-only `perm*Granted` mirror keys and
  `permissionsFilter`.
- [`ed calendar`](./calendar.md) for the one read that fails outright without
  its grant.
- [`ed app`](./app.md) for `ed app relaunch`, which a new grant usually needs.
- [All `ed` commands](./README.md).
