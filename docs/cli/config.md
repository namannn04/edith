# `ed config`

Every preference the Edith UI writes is a key in the same defaults the app
reads, and `ed config` is that surface from the command line: 201 settings in 23
groups, each with a type, a default, a scope and a one-line summary. Reach for
it when you want to know what a switch in Settings is actually called, flip one
without opening the window, or move a whole setup to another Mac.

Nothing here needs Edith to be running. A write goes straight into the defaults
and then posts the same `settingsChanged` notification the app posts to itself,
so a running Edith picks the change up immediately and a closed one sees it the
next time it launches.

## At a glance

| Command | What it does |
| --- | --- |
| `ed config ls` | List settings with their group, type and current value |
| `ed config get` | Print one setting's value and nothing else |
| `ed config set` | Validate a value and write it |
| `ed config unset` | Drop the stored value so the default applies again |
| `ed config describe` | Explain one setting: type, scope, allowed values, default, current value |
| `ed config export` | Print the settings you have changed as one JSON document |
| `ed config import` | Apply a JSON document of settings |

`ls` is the default subcommand, so a bare `ed config` lists everything, and
`ed config list` is an accepted spelling of `ls`.

## Commands

### `ed config ls`

Lists settings with their group, type and current value, in catalogue order.

```
ed config ls [<prefix>] [--group <group>] [--changed] [--json]
```

| Argument | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `prefix` | string | none, every setting | Only settings whose key starts with this text. Matched case-sensitively, so `notch` matches and `Notch` does not |

| Option | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--group` | one of `appearance`, `panel`, `usage`, `limits`, `menubar`, `alerts`, `budget`, `dashboard`, `machines`, `finder`, `system`, `cleaner`, `music`, `calendar`, `clipboard`, `notch`, `focusdim`, `presenter`, `colorpicker`, `micmute`, `backup`, `permissions`, `terminal` | none | Only settings in this group |
| `--changed` | flag | `false` | Only settings that differ from their default |
| `--json` | flag | `false` | Emit JSON on stdout |

The three filters compose: prefix first, then group, then changed.

`--json` emits an array of the same object `get` and `describe` emit, one per
setting, in catalogue order. Keys inside each object are sorted.

```json
[
  {
    "allowed": [
      "system",
      "light",
      "dark"
    ],
    "default": "system",
    "group": "appearance",
    "isSet": false,
    "key": "appearance",
    "readOnly": false,
    "scope": "shared",
    "summary": "Window and panel appearance.",
    "type": "string",
    "value": "system"
  },
  {
    "allowed": [],
    "default": "default",
    "group": "appearance",
    "isSet": false,
    "key": "theme",
    "readOnly": false,
    "scope": "shared",
    "summary": "Accent palette name.",
    "type": "string",
    "value": "default"
  }
]
```

```
ed config ls
ed config ls --group limits
ed config ls clipboardHotKey
ed config ls --changed --json
```

Reading changes nothing and needs nothing. A group that is not one of the 23
exits 3 and lists them all. A prefix that matches no key exits 3, unless the
prefix is the name of a sibling subcommand, which exits 2 instead of pretending
you meant a setting:

```
$ ed config ls get
error: get is a subcommand, not a setting prefix

$ ed config ls exp
error: no setting starts with exp
hint: did you mean `ed config export`?
```

### `ed config get`

Prints one setting's current value and nothing else, which is what to pipe into
something.

```
ed config get <key> [--json]
```

| Argument | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `key` | a catalogue key | required | The setting to read |

| Option | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | `false` | Emit JSON on stdout |

A string setting prints raw, with no quotes. A setting with no value prints an
empty line. Anything else prints as compact JSON on one line, so a number prints
`60`, a bool prints `true` and a list prints `["/"]`.

`--json` prints the full description rather than the bare value:

```json
{
  "allowed": [],
  "default": 60,
  "group": "limits",
  "isSet": false,
  "key": "warnPercent",
  "readOnly": false,
  "scope": "shared",
  "summary": "Percentage at which a limit turns amber.",
  "type": "int",
  "value": 60
}
```

```
ed config get musicFolderPath
ed config get clipboardMaxItems
ed config get limitsProvider --json
```

An unknown key exits 3. When any catalogue key contains what you typed, the hint
lists up to five of them, case-insensitively:

```
$ ed config get limits
error: no setting named limits
hint: did you mean: claudeLimitsEnabled, codexLimitsEnabled, limitsProvider, limitsInMenuBar, backupLimits
```

### `ed config set`

Validates a value against the setting's type and allowed list, writes it, and
tells the running app.

```
ed config set <key> <value> [--json]
```

| Argument | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `key` | a catalogue key | required | The setting to write |
| `value` | text, parsed by the setting's type | required | The new value |

| Option | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | `false` | Emit JSON on stdout |

How the text is parsed depends on the type:

| Type | Accepted text | Refused |
| --- | --- | --- |
| `bool` | `true`, `false`, `yes`, `no`, `on`, `off`, `1`, `0`, `enabled`, `disabled`, in any case | anything else, `is not a boolean, use true or false` |
| `int` | a whole number, surrounding spaces trimmed | `abc is not a whole number` |
| `number` | a decimal number, surrounding spaces trimmed | `abc is not a number` |
| `string` | the text verbatim, and when the setting has an allowed list, one of those values exactly | a value outside the list, with the list as the hint |
| `csv` | the text verbatim, stored as one string | the same allowed-list check, though no `csv` setting declares one |
| `stringList` | comma separated, each item trimmed, empty text gives an empty list | nothing |
| `map` | nothing | always, `map settings cannot be set from the command line` |

The human output is the key and the value the store now holds. `--json` adds
what was there before, which is the fallback when the setting had never been
written:

```json
{
  "key": "creditHidden",
  "previous": false,
  "value": true
}
```

```
ed config set preventSleep true
ed config set warnPercent 70
ed config set limitsProvider codex
ed config set cleanerSelectedDrives /,/Volumes/Data
```

Validation happens before the write, so a rejected value leaves the stored value
alone and exits 1. The 22 read-only keys are refused the same way, also exit 1,
before anything is touched:

```
$ ed config set appearance bogus
error: bogus is not a valid value
hint: allowed: system, light, dark

$ ed config set micMuted true
error: micMuted is read only
```

A successful write posts `settingsChanged` whether or not Edith is running, so
`ed config set presenterMode true` blurs the numbers in the open window the same
way the menu bar toggle does.

### `ed config unset`

Removes the stored value so the setting falls back to its catalogue default.

```
ed config unset <key> [--json]
```

| Argument | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `key` | a catalogue key | required | The setting to clear |

| Option | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | `false` | Emit JSON on stdout |

The value reported back is the effective one after the removal, so it is the
catalogue default, or `null` for a setting that declares none:

```json
{
  "key": "menuBarSubColorHex",
  "value": null
}
```

```
ed config unset appearance
ed config unset menuBarSubColorHex --json
```

Clearing a setting that was never written is a no-op that still succeeds, still
prints the default and still announces the change. Read-only keys exit 1, the
same as with `set`. Unknown keys exit 3.

### `ed config describe`

Explains one setting. This is what to read before writing something you are
unsure of.

```
ed config describe <key> [--json]
```

| Argument | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `key` | a catalogue key | required | The setting to explain |

| Option | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | `false` | Emit JSON on stdout |

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

The `allowed` line appears only when the setting has an allowed list, and a
final `read only` line appears only for the 22 keys the app owns. `--json` emits
the same object `ls` and `get` emit, which always carries every field:

```json
{
  "allowed": [
    "claude",
    "codex"
  ],
  "default": "claude",
  "group": "limits",
  "isSet": true,
  "key": "limitsProvider",
  "readOnly": false,
  "scope": "shared",
  "summary": "Provider shown first in the limits UI.",
  "type": "string",
  "value": "claude"
}
```

```
ed config describe clipboardPopupAt
ed config describe budgetMode --json
```

`isSet` is the same test `--changed` and `export` use: there is a stored value
and it differs from any registered default. Unknown keys exit 3 with the same
near-match hint `get` gives.

### `ed config export`

Prints the settings you have changed as one JSON document, ready for
`ed config import` on another Mac.

```
ed config export [--defaults] > edith.json
```

| Option | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--defaults` | flag | `false` | Include settings still at their default |

This is the one command in the group with no `--json`, because all of its output
is JSON already; passing the flag exits 2. The document is an object of key to
current value, keys sorted, which is exactly the shape `ed schema` describes.

```json
{
  "budgetCapPercent": 90,
  "clipboardEnabled": true,
  "clipboardMaxItems": 500,
  "limitsProvider": "claude",
  "presenterEnabled": true,
  "preventSleep": true,
  "tabMachinesEnabled": true,
  "tabUsageEnabled": true
}
```

```
ed config export > edith.json
ed config export --defaults > everything.json
ed config export | jq 'keys | length'
```

Read-only keys and the two `map` settings are never exported, with or without
`--defaults`, because neither can be imported: that leaves 177 exportable keys
of the 201. Without `--defaults` you get only the ones carrying a value of their
own, which is a much shorter list and is the one worth moving between Macs.

### `ed config import`

Applies a JSON document of settings, reporting what it did rather than failing
on the parts it cannot use.

```
ed config import <file|-> [--dry-run] [--json]
```

| Argument | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `file` | a path, `~` expanded, or `-` for stdin | required | The document to apply |

| Option | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--dry-run` | flag | `false` | Report what would change without writing |
| `--json` | flag | `false` | Emit JSON on stdout |

Keys are processed in sorted order and each one lands in exactly one of three
buckets. `applied` is a value that parsed and differs from what is stored;
`unchanged` is a value that parsed and matches; `skipped` is everything else,
which is an unknown key, a read-only key, a `map` setting, a value of the wrong
JSON type, or a string outside the setting's allowed list.

What each type wants in the document:

| Type | Wants | Note |
| --- | --- | --- |
| `bool` | a JSON boolean | a JSON `1` or `0` is accepted too |
| `int` | a JSON number | a decimal is truncated, so `60.7` becomes `60` |
| `number` | a JSON number | |
| `string`, `csv` | a JSON string | checked against the allowed list; a `csv` value is one comma separated string, not an array |
| `stringList` | a JSON array of strings | a bare string is skipped |
| `map` | nothing | always skipped |

```json
{
  "applied": [
    "appearance"
  ],
  "dryRun": true,
  "skipped": [
    "cleanerCategoryDefaults",
    "limitsProvider",
    "micMuted",
    "notARealKey",
    "showDockIcon"
  ],
  "unchanged": [
    "warnPercent"
  ]
}
```

```
ed config import edith.json
ed config import edith.json --dry-run
ed config export | ed config import - --dry-run
cat edith.json | ed config import -
```

The count goes to stdout and the commentary goes to stderr, so a pipeline sees
only the number:

```
$ ed config import edith.json --dry-run
would apply 1 setting
1 already matched
skipped: cleanerCategoryDefaults, limitsProvider, micMuted, notARealKey, showDockIcon
```

A document where nothing is usable still exits 0: skipping is a report, not a
failure. `settingsChanged` is posted once at the end, and only when this was not
a dry run and at least one setting actually changed. A path that cannot be read
exits 3, and a document that is not a JSON object exits 1.

Since a setting whose value already matches counts as unchanged rather than
applied, re-importing a document you just exported reports that there is nothing
to do:

```
$ ed config export > edith.json
$ ed config import edith.json --dry-run
would apply 0 settings
83 already matched
```

## The setting catalogue

Every key `ed config` knows, in the order `ed config ls` prints them. The
catalogue is compiled into the CLI, so this is the whole surface: a key that is
not here cannot be set, and `import` skips it.

- **Type** is how a value is parsed and stored. `csv` is one comma separated
  string, `stringList` is a real array, and `map` is a nested object that only
  the app can write.
- **Default** is the value the setting reports when nothing has been stored.
  `none` means it reads as blank in the table and `null` in `--json` until
  something writes it.
- **Scope** is which defaults domain holds the value. `shared` is the
  `com.pulkit.edith.shared` suite that the app, its menu bar helper and `ed` all
  read, so a write there reaches Edith. `standard` is whichever process's own
  domain is reading, which for `ed` is `ed`, not the app: those 15 keys are the
  ones to read through their own command instead.
- **read only** marks the 22 keys the app owns and maintains. `ed` reports them
  and refuses to write them, exit 1.

### `appearance`

| Key | Type | Default | Scope | What it controls |
| --- | --- | --- | --- | --- |
| `appearance` | string: `system`, `light`, `dark` | `system` | shared | Window and panel appearance. |
| `theme` | string | `default` | shared | Accent palette name. |
| `lastPaletteTheme` | string | none | shared | Palette the theme picker restores when a custom accent is cleared. |
| `showDockIcon` | bool | `false` | shared | Show Edith in the Dock as well as the menu bar. |
| `creditHidden` | bool | `false` | shared | Hide the credit line at the bottom of the panel. |
| `homeClockZones` | csv | none | shared | Comma separated time zone identifiers shown on the Home clocks. |

### `panel`

| Key | Type | Default | Scope | What it controls |
| --- | --- | --- | --- | --- |
| `extensionsExpand` | string | none | shared | Extension card the Extensions page scrolls to and opens next. |
| `settingsSection` | string | none | shared | Settings section a deep link opens on. |
| `mainWindowZoom` | number | `1` | shared | Main window zoom factor. |
| `onboardingCompleted` | bool | `false` | shared | Whether the welcome tour has been finished or skipped. |
| `EdithMainWindowFullScreen` | bool | `false` | standard | Whether the main window opens in full screen. |
| `hotKeyCode` | int | `14` | shared | Virtual key code of the global panel shortcut. |
| `hotKeyMods` | int | `2304` | shared | Carbon modifier mask of the global panel shortcut. |
| `hotKeyLabel` | string | none | shared | Printable label for the global panel shortcut. |
| `tab` | string | `usage` | standard | Panel tab shown on open. |
| `tabOrder` | csv | none | shared | Comma separated panel tab order. |
| `mainWindowSection` | string | none | shared | Section the main window opens on. |
| `settingsTab` | string | none | shared | Settings tab shown on open. |
| `mainSidebarOpen` | bool | `true` | shared | Whether the main window sidebar starts open. |
| `mainSidebarWidth` | number | none | shared | Main window sidebar width in points. |
| `repoPath` | string | none | shared | Development repository root used for usage data and music. |

### `usage`

| Key | Type | Default | Scope | What it controls |
| --- | --- | --- | --- | --- |
| `tabUsageEnabled` | bool | `true` | shared | Agent Usage extension: Claude and Codex limits, stats and alerts. |

### `limits`

| Key | Type | Default | Scope | What it controls |
| --- | --- | --- | --- | --- |
| `claudeLimitsEnabled` | bool | `true` | shared | Track Claude rate limits. |
| `codexLimitsEnabled` | bool | `true` | shared | Track Codex rate limits. |
| `limitsProvider` | string: `claude`, `codex` | `claude` | shared | Provider shown first in the limits UI. |
| `warnPercent` | int | `60` | shared | Percentage at which a limit turns amber. |
| `critPercent` | int | `85` | shared | Percentage at which a limit turns red. |
| `pacingMargin` | number | `10` | shared | Percentage points ahead of pace before pacing alerts fire. |

### `menubar`

| Key | Type | Default | Scope | What it controls |
| --- | --- | --- | --- | --- |
| `limitsInMenuBar` | bool | `true` | shared | Show session and weekly percentages in the menu bar. |
| `menuBarColorMode` | string: `auto`, `white`, `custom` | `auto` | shared | How the menu bar readout is tinted. |
| `smartColor` | bool | none | shared | Tint the menu bar readout by a time-aware risk model. |
| `menuBarSubColorHex` | string | none | shared | Hex colour of the menu bar subtitle text. |
| `menuBarLowColorHex` | string | none | shared | Hex colour used below the warning threshold. |
| `menuBarMidColorHex` | string | none | shared | Hex colour used between the warning and critical thresholds. |
| `menuBarHighColorHex` | string | none | shared | Hex colour used above the critical threshold. |
| `menuBarStatsColorHex` | string | none | shared | Hex colour of the CPU and memory menu bar readout. |
| `menuBarSystemStats` | bool | `false` | shared | CPU and memory readout as a menu bar item. |

### `alerts`

| Key | Type | Default | Scope | What it controls |
| --- | --- | --- | --- | --- |
| `notifSessionLevel` | int | `0` | standard, read only | Session threshold the last alert fired at. |
| `notifWeeklyLevel` | int | `0` | standard, read only | Weekly threshold the last alert fired at. |
| `notifSessionPacing` | string | none | standard, read only | Session pacing zone the last alert fired for. |
| `notifWeeklyPacing` | string | none | standard, read only | Weekly pacing zone the last alert fired for. |
| `notifyMaster` | bool | `false` | shared | Master switch for every usage notification. |
| `notifyTrackSession` | bool | none | shared | Alert when the session limit crosses a threshold. |
| `notifyTrackWeekly` | bool | none | shared | Alert when the weekly limit crosses a threshold. |
| `notifyRecovery` | bool | none | shared | Alert when usage falls back into the green. |
| `notifyPacingWarning` | bool | none | shared | Alert when spend runs ahead of pace. |
| `notifyPacingHot` | bool | none | shared | Alert when spend is burning far ahead of pace. |
| `notifyReminderSession` | bool | none | shared | Remind before the session window resets. |
| `notifyReminderSessionOffsetMin` | int | `15` | shared | Minutes before the session reset to remind. |
| `notifyReminderWeekly` | bool | none | shared | Remind before the weekly window resets. |
| `notifyReminderWeeklyOffsetMin` | int | `60` | shared | Minutes before the weekly reset to remind. |
| `notifyTokenExpired` | bool | none | shared | Alert when a provider token expires. |

### `budget`

| Key | Type | Default | Scope | What it controls |
| --- | --- | --- | --- | --- |
| `budgetEnabled` | bool | `false` | shared | Track a spend budget. |
| `budgetMode` | string: `cap`, `pace` | `cap` | shared | Budget comparison mode. |
| `budgetKind` | string: `session`, `weekly` | `session` | shared | Window the budget applies to. |
| `budgetCapPercent` | number | `50` | shared | Budget cap as a percentage of the limit. |
| `budgetDeadline` | number | `0` | shared | Unix timestamp the budget is paced towards. |

### `dashboard`

| Key | Type | Default | Scope | What it controls |
| --- | --- | --- | --- | --- |
| `dashPaths` | string | none | shared | Folder scope for the dashboard charts. |
| `dashRange` | string | `all` | shared | Dashboard date range. |
| `dashSources` | csv | none | shared | Comma separated usage sources included in the dashboard. |
| `dashKnownSources` | csv | none | shared | Sources seen so far, used to auto-select newly discovered ones. |
| `dashSourceSelectionVersion` | int | none | shared | Schema version of the stored source selection. |
| `dashModels` | string | none | shared | Model filter for the dashboard charts. |
| `dashBillingDay` | int | `26` | shared | Day of month the billing cycle starts on. |
| `dashSort` | string | `cost` | shared | Model table sort column. |
| `dashSortAsc` | bool | `false` | shared | Sort the model table ascending. |
| `dashHeatMetric` | string: `tokens`, `cost` | `tokens` | shared | Metric the activity heatmap colours by. |
| `projSort` | string | `cost` | shared | Project drilldown sort column. |
| `projSortAsc` | bool | `false` | shared | Sort the project drilldown ascending. |

### `machines`

| Key | Type | Default | Scope | What it controls |
| --- | --- | --- | --- | --- |
| `machinesTab` | string: `overview`, `processes`, `docker`, `terminal`, `tools` | `overview` | shared | Machine detail tab shown on open. |
| `machinesSelection` | string | none | shared | Identifier of the machine the detail view opens on. |
| `machinesMode` | string: `fleet`, `workspace`, `machine` | `fleet` | shared | Machines page view shown on open. |
| `dockerLogWrap` | bool | `true` | shared | Wrap long lines in the Docker log viewer. |
| `dockerLogTimestamps` | bool | `false` | shared | Show timestamps in the Docker log viewer. |
| `dockerLogFontSize` | number | `11` | shared | Text size in the Docker log viewer. |
| `tabMachinesEnabled` | bool | `false` | shared | Machines extension: other computers over SSH. |
| `machinesAutoConnect` | bool | none | shared | Connect to machines automatically when the app starts. |
| `machinesNotifyDown` | bool | none | shared | Notify when a machine stops responding. |
| `machinesNotifyDiskFull` | bool | none | shared | Notify when a machine's disk crosses the threshold. |
| `machinesDiskThreshold` | number | `90` | shared | Disk usage percentage that triggers the disk alert. |

### `finder`

| Key | Type | Default | Scope | What it controls |
| --- | --- | --- | --- | --- |
| `finderViewMode` | string: `icon`, `list` | `list` | shared | Remote file browser layout. |
| `finderSortKey` | string: `name`, `size`, `modified`, `kind` | `name` | shared | Remote file browser sort column. |
| `finderSortAscending` | bool | `true` | shared | Sort the remote file browser ascending. |
| `finderShowHidden` | bool | `false` | shared | Show dotfiles in the remote file browser. |
| `finderIconSize` | number | none | shared | Icon size in the remote file browser. |

### `system`

| Key | Type | Default | Scope | What it controls |
| --- | --- | --- | --- | --- |
| `SUEnableAutomaticChecks` | bool | `true` | standard | Check for updates on a schedule. |
| `SUScheduledCheckInterval` | number | `86400` | standard | Seconds between scheduled update checks. |
| `SUAutomaticallyUpdate` | bool | `true` | standard | Download and install updates automatically. |
| `tabSystemEnabled` | bool | `true` | shared | System extension: running apps, prevent sleep and the cleaning lock. |
| `preventSleep` | bool | `false` | shared | Keep the Mac awake (Keep Awake). |
| `systemAppsSort` | string | `memory` | shared | Running apps sort column. |
| `systemAppsSortAsc` | bool | `false` | shared | Sort running apps ascending. |

### `cleaner`

| Key | Type | Default | Scope | What it controls |
| --- | --- | --- | --- | --- |
| `cleanerSelectedDrives` | stringList | none | shared | Volumes the disk cleaner scans. |
| `cleanerCustomFolders` | stringList | none | shared | Extra folders added to the disk cleaner. |
| `cleanerCategoryDefaults` | map | none | shared | Per-category cleaner defaults. |
| `cleanerSelectionOverrides` | map | none | shared | Per-path cleaner selection overrides. |

### `music`

| Key | Type | Default | Scope | What it controls |
| --- | --- | --- | --- | --- |
| `musicFolderStale` | bool | `false` | shared, read only | Whether the stored music folder has gone missing. |
| `musicCrossfadeEnabled` | bool | `true` | shared | Fade between tracks when one ends. |
| `musicCrossfadeSeconds` | number | `2` | shared | Seconds the crossfade between tracks lasts. |
| `musicLastTrack` | string | none | standard, read only | Relative path of the track playback resumes from. |
| `musicLastPosition` | number | `0` | standard, read only | Seconds into the track playback resumes from. |
| `musicWasPlaying` | bool | `false` | standard, read only | Whether playback was running when the app last quit. |
| `tabMusicEnabled` | bool | `false` | shared | Music extension: local library playback with media keys. |
| `musicVolume` | number | `0.7` | standard | Player volume from 0 to 1. |
| `musicLooping` | bool | `false` | standard | Repeat the current track. |
| `musicGridView` | bool | `false` | shared | Show the library as a grid. |
| `musicFolderPath` | string | none | shared | Folder the music library plays from. |
| `musicShuffling` | bool | `false` | standard | Play the folder in a random order. |
| `musicFavourites` | stringList | none | shared | Relative paths of favourited tracks. |
| `musicDownloadKind` | string: `audio`, `video` | `audio` | shared | Default format for downloads. |
| `musicBackup` | bool | none | shared | Include the music folder in the iCloud backup. |

### `calendar`

| Key | Type | Default | Scope | What it controls |
| --- | --- | --- | --- | --- |
| `tabCalendarEnabled` | bool | `false` | shared | Calendar extension: your schedule in the panel and the app. |

### `clipboard`

| Key | Type | Default | Scope | What it controls |
| --- | --- | --- | --- | --- |
| `clipboardEnabled` | bool | `false` | shared | Clipboard extension: history with instant paste. |
| `clipboardHotKeyCode` | int | none | shared | Virtual key code of the clipboard panel shortcut. |
| `clipboardHotKeyMods` | int | none | shared | Carbon modifier mask of the clipboard panel shortcut. |
| `clipboardHotKeyLabel` | string | none | shared | Printable label for the clipboard panel shortcut. |
| `clipboardMaxItems` | int | none | shared | Maximum entries kept in the clipboard history. |
| `clipboardMaxItemBytes` | int | none | shared | Largest single clipboard entry kept, in bytes. |
| `clipboardMaxAgeDays` | int | none | shared | Days a clipboard entry is kept before it is pruned. |
| `clipboardIgnoredApps` | csv | none | shared | Comma separated bundle identifiers never captured. |
| `clipboardAutoPaste` | bool | none | shared | Paste straight into the frontmost app on pick. |
| `clipboardPastePlainText` | bool | none | shared | Strip formatting when pasting. |
| `clipboardCheckInterval` | number | `1` | shared | Seconds between pasteboard polls. |
| `clipboardPopupAt` | string: `cursor`, `statusItem`, `window`, `center`, `lastPosition` | `cursor` | shared | Where the clipboard panel opens. |
| `clipboardPinTo` | string: `top`, `bottom` | `top` | shared | Which edge the clipboard panel grows from. |
| `clipboardShowFooter` | bool | none | shared | Show the hint footer in the clipboard panel. |
| `clipboardSaveFiles` | bool | none | shared | Capture copied files. |
| `clipboardSaveImages` | bool | none | shared | Capture copied images. |
| `clipboardSaveText` | bool | none | shared | Capture copied text. |
| `clipboardBackup` | bool | none | shared | Include clipboard history in the iCloud backup. |
| `clipboardWindowPositionX` | number | none | shared | Last clipboard panel x position. |
| `clipboardWindowPositionY` | number | none | shared | Last clipboard panel y position. |

### `notch`

| Key | Type | Default | Scope | What it controls |
| --- | --- | --- | --- | --- |
| `notchShelfEnabled` | bool | `false` | shared | Notch Shelf extension: file shelf, now playing, camera and alerts. |
| `notchShelfOpenOnDrag` | bool | none | shared | Open the shelf when a drag reaches the notch. |
| `notchShelfOpenOnHover` | bool | none | shared | Open the shelf on hover. |
| `notchShelfRequireOption` | bool | none | shared | Require Option held to open the shelf. |
| `notchShelfKeepDuration` | string | none | shared | How long shelf items are kept. |
| `notchShelfRemoveAfterDragOut` | bool | none | shared | Remove an item from the shelf after it is dragged out. |
| `notchShelfShowOnExternal` | bool | none | shared | Show the shelf on external displays. |
| `notchShelfHaptics` | bool | none | shared | Haptic feedback on the shelf. |
| `notchShelfShowMusic` | bool | none | shared | Show now playing controls in the shelf. |
| `notchAlertsEnabled` | bool | none | shared | Show alerts around the notch. |
| `notchAlertAudio` | bool | none | shared | Alert on audio device changes. |
| `notchAlertPower` | bool | none | shared | Alert on power source changes. |
| `notchAlertBattery` | bool | none | shared | Alert on battery level changes. |
| `notchAlertBluetooth` | bool | none | shared | Alert on Bluetooth connections. |
| `notchAudioMixerEnabled` | bool | none | shared | Per-app audio mixer in the notch shelf. |

### `focusdim`

| Key | Type | Default | Scope | What it controls |
| --- | --- | --- | --- | --- |
| `focusDimActive` | bool | `false` | shared | Focus dim on right now. |
| `focusDimEnabled` | bool | `false` | shared | Focus Dim extension: dim everything behind the active app. |
| `focusDimIntensity` | number | `0.5` | shared | Dim strength from 0 to 1. |
| `focusDimAnimationDuration` | number | none | shared | Seconds the dim takes to fade. |
| `focusDimOtherDisplaysMode` | string: `perScreenFront`, `dimUnfocused` | `perScreenFront` | shared | How other displays are treated. |
| `focusDimHotKeyCode` | int | none | shared | Virtual key code of the focus dim shortcut. |
| `focusDimHotKeyMods` | int | none | shared | Carbon modifier mask of the focus dim shortcut. |
| `focusDimHotKeyLabel` | string | none | shared | Printable label for the focus dim shortcut. |

### `presenter`

| Key | Type | Default | Scope | What it controls |
| --- | --- | --- | --- | --- |
| `presenterAutoActive` | bool | `false` | shared, read only | A share is being detected right now. |
| `presenterAutoPaused` | bool | `false` | shared, read only | Auto presenter mode is paused until the current share ends. |
| `presenterAutoReason` | string | none | shared, read only | Why auto presenter mode turned on. |
| `presenterEnabled` | bool | `false` | shared | Presenter extension: blur sensitive numbers while sharing. |
| `presenterMode` | bool | `false` | shared | Presenter mode on right now. |
| `presenterAutoEnabled` | bool | none | shared | Turn presenter mode on automatically when a share is detected. |
| `presenterDetectRecording` | bool | none | shared | Treat screen recording as a share. |
| `presenterDetectScreenSharing` | bool | none | shared | Treat screen sharing as a share. |
| `presenterDetectMirroring` | bool | none | shared | Treat display mirroring as a share. |
| `presenterHideMenuBarNumbers` | bool | none | shared | Hide menu bar percentages while presenting. |
| `presenterBlurMoney` | bool | none | shared | Blur spend figures. |
| `presenterBlurUsage` | bool | none | shared | Blur usage percentages. |
| `presenterBlurMusic` | bool | none | shared | Blur track names. |
| `presenterBlurCalendar` | bool | none | shared | Blur calendar entries. |
| `presenterHotKeyCode` | int | none | shared | Virtual key code of the presenter shortcut. |
| `presenterHotKeyMods` | int | none | shared | Carbon modifier mask of the presenter shortcut. |
| `presenterHotKeyLabel` | string | none | shared | Printable label for the presenter shortcut. |

### `colorpicker`

| Key | Type | Default | Scope | What it controls |
| --- | --- | --- | --- | --- |
| `colorPickerEnabled` | bool | `false` | shared | Color Picker extension: system loupe on a hotkey. |
| `colorPickerCopyFormat` | string: `hex`, `rgb`, `hsl`, `swiftUI`, `nsColor` | `hex` | shared | Format the sampled colour is copied in. |
| `colorPickerProfile` | string: `sRGB`, `displayP3` | `sRGB` | shared | Colour space the loupe samples in. |
| `colorPickerHistorySize` | int | none | shared | Number of swatches kept in the history. |
| `colorPickerHotKeyCode` | int | none | shared | Virtual key code of the colour picker shortcut. |
| `colorPickerHotKeyMods` | int | none | shared | Carbon modifier mask of the colour picker shortcut. |
| `colorPickerHotKeyLabel` | string | none | shared | Printable label for the colour picker shortcut. |

### `micmute`

| Key | Type | Default | Scope | What it controls |
| --- | --- | --- | --- | --- |
| `micMuted` | bool | `false` | shared, read only | Microphone muted right now. |
| `micMuteEnabled` | bool | `false` | shared | Mic Mute extension: system-wide microphone kill switch. |
| `micMuteInMenuBar` | bool | none | shared | Show the mic mute indicator in the menu bar. |
| `micHotKeyCode` | int | none | shared | Virtual key code of the mic mute shortcut. |
| `micHotKeyMods` | int | none | shared | Carbon modifier mask of the mic mute shortcut. |
| `micHotKeyLabel` | string | none | shared | Printable label for the mic mute shortcut. |

### `backup`

| Key | Type | Default | Scope | What it controls |
| --- | --- | --- | --- | --- |
| `icloudBackup` | bool | `true` | shared | Master switch for the iCloud backup. |
| `backupSettings` | bool | none | shared | Back up settings to iCloud. |
| `backupUsage` | bool | none | shared | Back up usage history to iCloud. |
| `backupLimits` | bool | none | shared | Back up limit history to iCloud. |
| `lastBackupAt` | number | none | shared, read only | Unix timestamp of the last settings backup. |
| `lastMusicBackupAt` | number | none | shared, read only | Unix timestamp of the last music backup. |
| `lastClipboardBackupAt` | number | none | shared, read only | Unix timestamp of the last clipboard backup. |

### `permissions`

| Key | Type | Default | Scope | What it controls |
| --- | --- | --- | --- | --- |
| `permCalendarGranted` | bool | `false` | shared, read only | Calendar permission, as last observed by Edith. |
| `permNotificationsGranted` | bool | `false` | shared, read only | Notifications permission, as last observed by Edith. |
| `permAccessibilityGranted` | bool | `false` | shared, read only | Accessibility permission, as last observed by Edith. |
| `permInputMonitoringGranted` | bool | `false` | shared, read only | Input Monitoring permission, as last observed by Edith. |
| `permFullDiskGranted` | bool | `false` | shared, read only | Full Disk Access permission, as last observed by Edith. |
| `permScreenRecordingGranted` | bool | `false` | shared, read only | Screen Recording permission, as last observed by Edith. |
| `permCameraGranted` | bool | `false` | shared, read only | Camera permission, as last observed by Edith. |
| `permissionsFilter` | string | none | shared | Filter the Permissions page opens with. |

### `terminal`

| Key | Type | Default | Scope | What it controls |
| --- | --- | --- | --- | --- |
| `completionsAutoRefresh` | bool | `true` | shared | Keep the shell completion scripts current when the app starts. |

## Exit codes

| Code | What produced it |
| --- | --- |
| 0 | The command did what it says. An `unset` of something that was never set, and an `import` where every key was skipped, both count as success |
| 1 | The write was refused: a read-only key, a value that does not parse as the setting's type, a value outside the allowed list, a `map` setting, or an import document that is not a JSON object |
| 2 | The command line was wrong: an unknown flag such as `ed config export --json`, a missing argument, or `ed config ls get` where a setting prefix was expected |
| 3 | The name does not exist: an unknown key, an unknown `--group`, a prefix matching no key, or an import file that cannot be read |

Nothing in this group exits 4, because nothing in it needs Edith to be running.

## Notes and gotchas

**A shared suite, and a per-process one.** A `shared` setting lives in the
`com.pulkit.edith.shared` defaults suite, which the app, its menu bar helper and
`ed` all open, so writing one from the command line is the same act as clicking
the switch. A `standard` setting lives in whatever `UserDefaults.standard` means
for the process doing the reading, which for `ed` is `ed`'s own domain rather
than the app's. Those 15 keys are `EdithMainWindowFullScreen`, `tab`,
`notifSessionLevel`, `notifWeeklyLevel`, `notifSessionPacing`,
`notifWeeklyPacing`, `SUEnableAutomaticChecks`, `SUScheduledCheckInterval`,
`SUAutomaticallyUpdate`, `musicLastTrack`, `musicLastPosition`,
`musicWasPlaying`, `musicVolume`, `musicLooping` and `musicShuffling`. Setting
one of them changes what `ed` sees, not what the app does, so drive the live
ones through the command that owns them: `ed music volume 0.4` reaches the
player, `ed config set musicVolume 0.4` does not.

**Read only means the app writes it.** The 22 read-only keys are state the app
maintains and `ed` reports: the `perm*Granted` mirror of macOS permission state,
the `last*BackupAt` timestamps, the four `notifSession*` and `notifWeekly*`
records of which alert already fired, `musicFolderStale`, the `musicLast*` and
`musicWasPlaying` resume state, the `presenterAuto*` share detection, and
`micMuted`. They show up in `ls`, `get` and `describe`, are refused by `set` and
`unset` with exit 1, and are left out of `export` and skipped by `import`.

**A missing default is not the same as `false`.** Where the catalogue declares
no default, the setting reads blank in the table and `null` in `--json` until
something writes it, which is why most of the `notch*` and `notify*` switches
look empty on a fresh install. `ed config ls --changed` is the honest view of
what has actually been decided.

**`--changed` compares against registered defaults too.** A setting counts as
changed when it has a stored value that differs from any default registered at
launch. Four keys are registered that way, `icloudBackup`,
`completionsAutoRefresh`, `musicCrossfadeEnabled` and `musicCrossfadeSeconds`,
so storing the registered value on one of them leaves it out of `--changed` and
out of `export`, which is what you want: it is not a change.

**Two settings cannot be written from here at all.** `cleanerCategoryDefaults`
and `cleanerSelectionOverrides` are nested objects, so `set` refuses them,
`export` omits them and `import` skips them. They are readable: `ls`, `get` and
`describe` print the stored object as compact JSON. `ed schema` still lists them
as writable objects, so a document that validates against the schema can still
contain a key `import` will skip.

**`ed schema` is the machine-readable half of this page.** It prints a JSON
Schema for the `import` document: the 179 writable keys as properties,
`additionalProperties: false`, the `enum` for each of the 16 keys with an
allowed list, the default where the catalogue declares one, and `x-group`,
`x-scope` and `x-format` annotations. A `csv` setting is typed as a string with
`"x-format": "comma-separated"`; a `stringList` is an array of strings.

**Extensions are settings, with better manners.** `tabUsageEnabled`,
`tabSystemEnabled`, `tabMachinesEnabled`, `menuBarSystemStats`,
`micMuteEnabled`, `tabMusicEnabled`, `tabCalendarEnabled`, `notchShelfEnabled`,
`clipboardEnabled`, `focusDimEnabled`, `presenterEnabled` and
`colorPickerEnabled` are the same switches `ed extensions enable` and
`ed extensions disable` flip. Prefer those verbs: they know which macOS
permission the extension needs and say which one is missing, where
`ed config set` just writes the bool.

**Values are matched exactly, keys are matched exactly.** An allowed value is
compared case-sensitively, so `ed config set appearance Dark` exits 1 while
`dark` works. Booleans are the one exception, where the word is lowercased
first. The `ls` prefix is case-sensitive as well; only the near-match hint on an
unknown key searches case-insensitively.

**Lists are split on commas and trimmed.** `ed config set musicFavourites
"a.mp3, b.mp3"` stores two entries with no leading space, an empty value stores
an empty list, and empty items are dropped, so a trailing comma is harmless.

**Output is stable enough to diff.** `ls` prints in catalogue order, which is
the order of this page. Every JSON object has its keys sorted, and `export`
sorts the whole document, so two exports of the same machine differ only where
the settings do.

**Completion knows the catalogue.** `ed config get <TAB>` and
`ed config set <TAB>` offer every key, `ed config set limitsProvider <TAB>`
offers `claude codex`, a bool setting offers `true false`, and
`ed config ls <TAB>` offers the group names.

## Where to go next

- [`ed extensions`](./extensions.md) for the feature switches and the
  permissions they need
- [`ed permissions`](./permissions.md) for the real state behind the
  `perm*Granted` mirror
- [`ed music`](./music.md), [`ed clipboard`](./clipboard.md) and
  [`ed machines`](./machines.md) for the commands that own the live state these
  keys only describe
- [Getting started](./getting-started.md) for `ed schema`, `ed guide` and shell
  completion
- [Conventions and contracts](./conventions.md) for the `--json` and exit code
  rules every group shares
- [All command groups](./README.md)
