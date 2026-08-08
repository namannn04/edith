# `ed extensions`

Extensions are the features Edith can turn on and off: panel tabs, menu bar
items, and the things that run in the background. Each one is a single boolean
in Edith's shared preferences, and `ed extensions` is the registry in front of
those booleans. They get their own verbs rather than living only under
`ed config` because turning one on can need a macOS permission Edith has not
been granted yet, and because the registry knows the readable name, the group
and the permission list that a bare key does not.

Everything here reads and writes
`UserDefaults(suiteName: "com.pulkit.edith.shared")`, so all four commands work
whether or not Edith is running. A write posts `settingsChanged`, so a running
app picks the change up live and a closed one picks it up the next time it
launches. Nothing in this group waits on the app, and nothing in it can exit 4.

## At a glance

| Command | What it does |
| --- | --- |
| `ed extensions` | Runs `ls`, which is the default subcommand |
| `ed extensions ls` | Every extension, its group, and whether it is on. `list` is an alias |
| `ed extensions enable <id>` | Turns one on, and names on stderr any required permission still missing |
| `ed extensions disable <id>` | Turns one off |
| `ed extensions info <id>` | Describes one: name, summary, key, group, state, permissions |

## The registry

`ExtensionRegistry.entries` in EdithKit is the single list every command here
walks, and its order is the order `ls` prints. Twelve entries, in this order:

| ID | Name | Group | What it does |
| --- | --- | --- | --- |
| `usage` | Agent Usage | Agent | Claude and Codex limits, usage stats, and alerts |
| `system` | System | System | Running apps, prevent sleep, and the keyboard-cleaning lock |
| `machines` | Machines | System | Your other computers over SSH: stats, files, Docker, and a terminal |
| `systemStats` | CPU & Memory in menu bar | System | Live CPU and memory readout as a menu bar item |
| `micMute` | Mic Mute | System | Mute every microphone system-wide with ⌘⇧M or the menu bar icon |
| `music` | Music | Media | Plays your local music folder, with media keys |
| `calendar` | Calendar | Media | Shows your schedule in the panel and the app |
| `notchShelf` | Notch Shelf | Media | File shelf, now playing, camera, and alerts around the notch |
| `clipboard` | Clipboard | Utilities | Clipboard history with instant paste |
| `focusDim` | Focus Dim | Utilities | Dims everything behind your active app |
| `presenter` | Presenter | Utilities | Blurs sensitive numbers while sharing your screen |
| `colorPicker` | Color Picker | Utilities | System loupe on a hotkey, sampled color to your clipboard |

The same twelve, with what each one is made of. `Key` is the preference the app
reads, and the key `ed config` writes for the same feature. `Featured` marks the
five the welcome tour shows before you ask it for all of them.

| ID | Key | Featured | Required permissions | Optional permissions | Required tools |
| --- | --- | --- | --- | --- | --- |
| `usage` | `tabUsageEnabled` | yes | none | `notifications` | `claude`, `codex` |
| `system` | `tabSystemEnabled` | yes | none | `accessibility`, `inputMonitoring` | none |
| `machines` | `tabMachinesEnabled` | yes | none | `notifications` | none |
| `systemStats` | `menuBarSystemStats` | no | none | none | none |
| `micMute` | `micMuteEnabled` | no | none | none | none |
| `music` | `tabMusicEnabled` | no | none | none | `yt-dlp` |
| `calendar` | `tabCalendarEnabled` | no | `calendar` | none | none |
| `notchShelf` | `notchShelfEnabled` | yes | none | `bluetooth`, `camera`, `automation` | none |
| `clipboard` | `clipboardEnabled` | yes | none | `accessibility` | none |
| `focusDim` | `focusDimEnabled` | no | `screenRecording` | none | none |
| `presenter` | `presenterEnabled` | no | `screenRecording` | none | none |
| `colorPicker` | `colorPickerEnabled` | no | `screenRecording` | none | none |

An id is matched exactly and case-insensitively against the `ID` column first,
then against the `Key` column, so `ed extensions info clipboard`,
`ed extensions info CLIPBOARD` and `ed extensions info clipboardEnabled` are the
same command. There is no prefix matching here: unlike a machine name, `clip`
fails with the full list of ids rather than guessing.

## Commands

### `ed extensions ls`

Prints every registry entry and whether it is on.

```
ed extensions ls [--json]
```

| Option | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the table |

The human form is a four column table, padded with two spaces, in registry
order:

```
$ ed extensions ls
ID           STATE  GROUP      NAME
usage        on     Agent      Agent Usage
system       on     System     System
machines     on     System     Machines
systemStats  off    System     CPU & Memory in menu bar
micMute      off    System     Mic Mute
music        off    Media      Music
calendar     off    Media      Calendar
notchShelf   off    Media      Notch Shelf
clipboard    on     Utilities  Clipboard
focusDim     off    Utilities  Focus Dim
presenter    off    Utilities  Presenter
colorPicker  on     Utilities  Color Picker
```

`--json` is a top-level array of one object per registry entry, in the same
order, and every row carries the same eleven keys whether or not they have
anything in them. A test asserts exactly that set of keys on every row. The
first two rows:

```json
[
  {
    "enabled": true,
    "featured": true,
    "group": "Agent",
    "id": "usage",
    "key": "tabUsageEnabled",
    "missingRequiredPermissions": [],
    "optionalPermissions": [
      "notifications"
    ],
    "requiredPermissions": [],
    "requiredTools": [
      "claude",
      "codex"
    ],
    "summary": "Claude and Codex limits, usage stats, and alerts.",
    "title": "Agent Usage"
  },
  {
    "enabled": true,
    "featured": true,
    "group": "System",
    "id": "system",
    "key": "tabSystemEnabled",
    "missingRequiredPermissions": [],
    "optionalPermissions": [
      "accessibility",
      "inputMonitoring"
    ],
    "requiredPermissions": [],
    "requiredTools": [],
    "summary": "Running apps, prevent sleep, and the keyboard-cleaning lock.",
    "title": "System"
  }
]
```

`group` is the readable group name, capitalised: `Agent`, `System`, `Media` or
`Utilities`. `key` is the preference `ed config` uses for the same feature.
`missingRequiredPermissions` is `requiredPermissions` filtered down to the ones
Edith's mirrored grant state does not say yes to, so it is the field to gate on
rather than parsing prose.

```
ed extensions ls
ed extensions list
ed extensions ls --json
ed extensions ls --json | jq -r '.[] | select(.enabled) | .id'
```

`ls` reads preferences and nothing else. It never fails and always exits 0, and
it is the default subcommand, so bare `ed extensions` prints the same table.

### `ed extensions enable`

Turns one extension on.

```
ed extensions enable <id> [--json]
```

| Argument | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `id` | one of the twelve ids, or a defaults key | required | The extension to turn on |

| Option | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit the extension's record on stdout instead of the one-line confirmation |

The write is unconditional: the key is set to `true`, the store is synchronised,
and `settingsChanged` is posted, whether or not the extension was already on.
Then, in the human form, any required permission Edith has not recorded as
granted is named on stderr, one line each, with the command that asks for it:

```
$ ed extensions enable focusDim
focusDim enabled
note: Focus Dim needs Screen Recording; run `ed permissions request screenRecording`
```

The first line is stdout, the `note:` line is stderr, and the exit code is 0
either way. This is the one place `ed` deliberately differs from the switch on
each row of the Extensions page: the pane refuses the toggle when a required
permission is missing and opens the permission sheet instead, leaving the switch
off, while `ed` turns the extension on and tells you what it still needs. The
extension is on and inert until the grant lands.

`--json` prints the same record `info` prints, already reflecting the new state,
and prints no note at all: the missing permissions are in
`missingRequiredPermissions`.

```json
{
  "enabled": true,
  "featured": false,
  "group": "Utilities",
  "id": "focusDim",
  "key": "focusDimEnabled",
  "missingRequiredPermissions": [
    "screenRecording"
  ],
  "optionalPermissions": [],
  "requiredPermissions": [
    "screenRecording"
  ],
  "requiredTools": [],
  "summary": "Dims everything behind your active app.",
  "title": "Focus Dim"
}
```

```
ed extensions enable clipboard
ed extensions enable machines
ed extensions enable notchShelfEnabled
ed extensions enable focusDim --json
```

An unknown id is refused before anything is written, and exits 3 with every
known id as the hint:

```
$ ed extensions enable clipbored
error: no extension named clipbored
hint: known ids: usage, system, machines, systemStats, micMute, music, calendar, notchShelf, clipboard, focusDim, presenter, colorPicker
```

Enabling never asks for a permission and never installs a tool. `music` wants
`yt-dlp` and `usage` wants `claude` and `codex`, and `ed` reports them in
`requiredTools` rather than fetching them; `ed tools ls` and
`ed tools install <id>` are the verbs for that.

### `ed extensions disable`

Turns one extension off.

```
ed extensions disable <id> [--json]
```

| Argument | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `id` | one of the twelve ids, or a defaults key | required | The extension to turn off |

| Option | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit the extension's record on stdout instead of the one-line confirmation |

The same write in reverse: the key is set to `false`, the store is synchronised,
`settingsChanged` is posted. Permissions are not consulted at all, so there is
never a note, and `--json` emits the same record with `enabled` now `false`.

```
$ ed extensions disable notchShelf
notchShelf disabled
```

```
ed extensions disable presenter
ed extensions disable colorPicker --json
```

Disabling only flips the switch. It does not revoke a macOS grant, does not
delete anything the extension collected, and does not stop the app: your
clipboard history, shelf and music library survive `disable` and come back when
you enable it again. Unknown ids exit 3, as everywhere else in this group.

### `ed extensions info`

Describes one extension without changing anything.

```
ed extensions info <id> [--json]
```

| Argument | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `id` | one of the twelve ids, or a defaults key | required | The extension to describe |

| Option | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the indented block |

The human form is the title, the summary, then a fixed set of labelled rows. The
`needs` row appears only when the extension has required permissions and the
`asks for` row only when it has optional ones, so a plain extension prints four
rows:

```
$ ed extensions info clipboard
Clipboard
  Clipboard history with instant paste.
  id       clipboard
  key      clipboardEnabled
  group    Utilities
  state    on
  asks for Accessibility
```

```
$ ed extensions info calendar
Calendar
  Shows your schedule in the panel and the app.
  id       calendar
  key      tabCalendarEnabled
  group    Media
  state    off
  needs    Calendar
```

`needs` and `asks for` print the readable permission names (`Input Monitoring`,
`Screen Recording`), while `--json` prints the ids `ed permissions request`
accepts (`inputMonitoring`, `screenRecording`).

```json
{
  "enabled": false,
  "featured": false,
  "group": "Media",
  "id": "music",
  "key": "tabMusicEnabled",
  "missingRequiredPermissions": [],
  "optionalPermissions": [],
  "requiredPermissions": [],
  "requiredTools": [
    "yt-dlp"
  ],
  "summary": "Plays your local music folder, with media keys.",
  "title": "Music"
}
```

```
ed extensions info notchShelf
ed extensions info music --json
ed extensions info tabMachinesEnabled
```

`info` is a pure read: no key is written and no notification is posted.

## Exit codes

| Code | When |
| --- | --- |
| 0 | the extension was listed, described, enabled or disabled, including when `enable` had to warn about a missing permission |
| 2 | the command line was wrong: an unknown flag, or `enable`, `disable` or `info` with no id |
| 3 | no extension matches the id you named, by id or by defaults key |

Nothing in this group produces 1 or 4. There is no app to be unavailable and no
failure mode between "the id exists" and "the boolean is written".

## Notes and gotchas

- The state `ls` and `info` report is `object(forKey:) as? Bool ?? false`, so a
  key that has never been written reads as off. `ed config get` answers the same
  question from the catalogue's fallback instead, which is `true` for
  `tabUsageEnabled` and `tabSystemEnabled`, so on a Mac where Edith has never
  run those two disagree. Upgrading from an older Edith writes a concrete value
  for all twelve keys on the next launch and they agree again; a fresh install
  only writes the keys you turn on, so an untouched `tabUsageEnabled` keeps
  disagreeing until something writes it.
- Every extension is also an ordinary `ed config` boolean, and both paths write
  the same key in the same store and post the same `settingsChanged`.
  `ed config set clipboardEnabled true` and `ed extensions enable clipboard`
  leave identical state; only the second one knows to mention Accessibility.
  Related settings sit in that extension's own config group, so
  `ed config ls --group clipboard` and `--group notch`, `--group focusdim` or
  `--group colorpicker` give you the rest of the knobs.
- The permission check reads what the app last mirrored into preferences, not
  live TCC state, because a command line process cannot read another
  application's grants. If a note names a permission you know you have already
  granted, run `ed permissions refresh` and try again.
- `bluetooth` and `automation` are granted by macOS on first use and have no
  mirrored key, so they are always reported as not granted. That is why they
  appear only as optional permissions, on `notchShelf`, and never in
  `missingRequiredPermissions`.
- `requiredTools` is reported verbatim from the registry. The app's provisioning
  sheet filters that list by whether the tool is currently wanted, which drops
  `codex` while `codexLimitsEnabled` is off; `ed` does not filter, so `usage`
  always lists both `claude` and `codex`.
- Ordering is stable and worth relying on: the array `--json` emits follows the
  registry's own order, and only the keys inside each object are sorted, which
  is why the output diffs cleanly between runs.
- Enabling from `ed` does not stamp the `extensionPermissionsSeen.<id>` marker
  the Extensions pane writes when you flip a switch there. The pane still reads
  it, but `ExtensionPermissionFlow.decision` ignores the value, so the two paths
  still end up equivalent.
- The `ls` renderer flattens tabs and newlines to spaces and drops control
  characters, so a row is always one line, and the last column is never padded.

## Where to go next

- [`ed permissions`](./permissions.md) for granting what an extension needs
- [`ed config`](./config.md) for the settings an extension exposes once it is on
- [`ed tools`](./tools.md) for the command line tools `requiredTools` names
- [All `ed` commands](./README.md)
