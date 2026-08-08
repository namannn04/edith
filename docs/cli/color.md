# `ed color`

`ed color` reads the swatch history Edith's colour picker keeps: every colour
you have sampled with the loupe, newest first, in whichever of the five
representations you ask for. Reach for it when you want the colour you just
picked to land in a script or a stylesheet rather than on the pasteboard.

The history is one key in Edith's shared defaults suite
(`com.pulkit.edith.shared`), so both verbs work whether or not the app is
running. `colour` is an accepted spelling of the group, and `ed color` with
nothing after it is `ed color ls`.

Sampling a colour is not here. The loupe is `NSColorSampler`, which belongs to
the app, so picking stays on the eyedropper in the menu bar panel and on the
hotkey (`⌃⌥⌘C` unless you have rebound it). `ed` reads what the loupe recorded,
and can forget it.

## At a glance

| Command | What it does |
| --- | --- |
| `ed color` | Runs `ed color ls`, which is the default subcommand. |
| `ed color ls` | Lists picked colours, newest first, as a table or as one chosen format per line. |
| `ed color clear` | Forgets every picked colour. |

`ed colour` is the same group under its British spelling, and `ed color list`
is the same command as `ed color ls`.

## Commands

### `ed color ls`

Lists the colours in the picker's history, newest first.

Usage:

```
ed color ls [--format <f>] [--limit <n>] [--json]
```

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--format <f>` | one of `hex`, `rgb`, `hsl`, `swiftUI`, `nsColor` | unset, which prints the table | Prints that one representation per colour, one per line, and nothing else. |
| `--limit <n>` | integer, 0 or more | `25` | Shows at most this many colours. `0` shows all of them. |
| `--json` | flag | off | Emits one JSON document on stdout. |

There are no positional arguments.

`--format` is matched against the raw format names exactly, so `swiftUI` is
accepted and `SwiftUI`, `swiftui` and `hexadecimal` are not; an unknown name
exits 3 and lists the five it accepts. `--limit` is checked before the format
name and before the store is read, so a negative value exits 2 with
`--limit cannot be negative` on stderr and nothing on stdout. `--limit 0` is not
unbounded in practice: the app caps what it stores at `colorPickerHistorySize`,
which is clamped to 1 through 100.

`--json` shape, an array with one object per colour:

```json
[
  {
    "hex": "#4C6EF5",
    "hsl": "hsl(228, 89%, 63%)",
    "pickedAt": "2026-08-07T18:41:09Z",
    "profile": "sRGB",
    "rgb": "rgb(76, 110, 245)"
  },
  {
    "hex": "#1B1B1E",
    "hsl": "hsl(240, 5%, 11%)",
    "pickedAt": "2026-08-06T21:04:33Z",
    "profile": "displayP3",
    "rgb": "rgb(27, 27, 30)"
  }
]
```

`profile` is the raw value, `sRGB` or `displayP3`, not the display name the
table prints. `pickedAt` is ISO 8601 in UTC. The JSON carries `hex`, `rgb` and
`hsl` only: `swiftUI` and `nsColor` are reachable through `--format`, and the
swatch's id and its raw components are not exposed at all. An empty history is
an empty array rather than an error.

Examples:

```
ed color ls
ed color ls --format hex --limit 1
ed color ls --limit 0 --format swiftUI
ed color ls --json
```

The table is four columns: hex, `rgb()`, the colour space under its display
name, and when it was picked.

```
$ ed color ls
HEX      RGB                PROFILE     PICKED
#4C6EF5  rgb(76, 110, 245)  sRGB        2026-08-07T18:41:09Z
#F9C442  rgb(249, 196, 66)  sRGB        2026-08-07T18:39:52Z
#1B1B1E  rgb(27, 27, 30)    Display P3  2026-08-06T21:04:33Z
```

`--format` replaces the table with bare values, which is what makes the command
worth piping. The newest colour is the first line, so `--limit 1` is the colour
you just picked:

```
$ ed color ls --format hex --limit 1
#4C6EF5

$ ed color ls --format swiftUI --limit 2
Color(red: 0.2980, green: 0.4310, blue: 0.9610)
Color(red: 0.9760, green: 0.7690, blue: 0.2590)
```

A name that is not one of the five formats exits 3 with the list, rather than
being guessed at:

```
$ ed color ls --format SwiftUI
error: no colour format named SwiftUI
hint: formats: hex, rgb, hsl, swiftUI, nsColor
```

Behaviour: `ls` only reads and writes nothing back, needs neither the main app
nor the menu bar helper, and never fails because Edith is closed. With an empty history
and no `--format` it writes `no colours picked yet` to stderr, leaves stdout
empty and exits 0. With `--format` and an empty history it prints nothing at
all, not even that note, so a caller can treat empty output as "no colours"
without parsing prose. Unlike `ed clipboard ls`, a list cut short by `--limit`
says nothing about it, so a default run stops at 25 silently.

### `ed color clear`

Forgets the whole picked-colour history.

Usage:

```
ed color clear [--json]
```

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emits one JSON document on stdout. |

There are no positional arguments, and there is no `--yes` guard: `clear` takes
effect the moment you run it.

`--json` shape:

```json
{
  "removed": 3
}
```

`removed` is how many swatches were in the history before it was emptied.

Examples:

```
ed color clear
ed color clear --json
```

```
$ ed color clear
cleared 3 colours
```

Behaviour: this removes the `colorPickerHistory` key from the shared defaults
suite, then posts the same `settingsChanged` notification `ed config set` sends.
Nothing re-reads the swatch history on that notification, so a running Edith can
still show the colours you cleared: the Recent Colors grid reloads the next time
the settings pane appears, and the eyedropper's menu only once the picker is
restarted or another colour is sampled. The post is fire and forget, so the
command needs nothing running and exits 0 either way. Clearing an already empty
history is reported as `cleared 0 colours` rather than as an error. There is no
per-swatch removal; the history is cleared whole or not at all.

The settings pane has no button for this. Its Recent Colors grid copies a
swatch in the configured copy format when you click it and offers all five
formats on right-click, but it cannot forget one, so `ed color clear` is the
only way to empty the history from any surface.

## Exit codes

| Code | When this group produces it |
| --- | --- |
| 0 | The listing printed, or the history was cleared. Also an empty history, and `ed color ls --help`. |
| 2 | `--limit` was negative (`--limit cannot be negative`), or the command line was wrong in ArgumentParser's own terms: an unknown flag, `--format` or `--limit` with no value, or a `--limit` value that is not an integer. |
| 3 | `--format` named something that is not `hex`, `rgb`, `hsl`, `swiftUI` or `nsColor`. |

Nothing in this group exits 1 or 4: there is no remote call, no app request and
no write that can be refused.

## Notes and gotchas

- The history lives at the `colorPickerHistory` key of the
  `com.pulkit.edith.shared` defaults suite, as a JSON-encoded array of
  swatches. It is not a setting, so `ed config ls colorPicker` lists the
  picker's seven preferences and never the history itself, `ed config unset`
  has nothing to unset here, and neither `ed config export` nor Edith's own
  settings backup carries the swatches to another Mac.
- Order is newest first because the app inserts each new swatch at the front
  and truncates to `colorPickerHistorySize`. `ed` re-reads the store on every
  invocation and does no sorting of its own, so the first row is always the
  most recent pick.
- Lowering `colorPickerHistorySize` does not trim what is already stored. The
  cap is applied when the next colour is picked, so until then
  `ed color ls --limit 0` can return more swatches than the setting allows.
- Unreadable or absent stored data decodes to an empty history rather than to
  an error, so a corrupted key looks exactly like a picker you have never used.
- Every swatch is opaque. The formatters clamp each component to 0 through 1,
  and `nsColor` always ends `alpha: 1.0`, because the loupe never records
  transparency.
- The formatters do not convert between colour spaces. A `displayP3` swatch and
  an `sRGB` swatch with the same components print identical hex, rgb and hsl
  strings; the `profile` field is what tells you which space those numbers are
  in. Set the space you sample in with
  `ed config set colorPickerProfile sRGB|displayP3`.
- Exact shapes, so you can match on them: `hex` is `#RRGGBB` with uppercase
  digits, `rgb` is `rgb(76, 110, 245)` with components rounded to 0 through
  255, `hsl` is `hsl(228, 89%, 63%)` with integer degrees and percentages,
  `swiftUI` is `Color(red: 0.2980, green: 0.4310, blue: 0.9610)` and `nsColor`
  is `NSColor(red: 0.2980, green: 0.4310, blue: 0.9610, alpha: 1.0)`, both with
  four decimal places.
- `--format` is validated even when `--json` is passed, but it changes nothing
  about the output: with `--json` you always get `hex`, `rgb` and `hsl`. So
  `ed color ls --json --format nonsense` exits 3 while
  `ed color ls --json --format hsl` is the same document as
  `ed color ls --json`.
- What the picker copies to the pasteboard when you sample is a separate
  choice, `ed config set colorPickerCopyFormat hex|rgb|hsl|swiftUI|nsColor`.
  `--format` here does not change it, and changing it does not change what
  `ed color ls` prints.
- The picker only runs when its extension is on
  (`ed extensions enable colorPicker`, which is the `colorPickerEnabled`
  setting and wants the Screen Recording permission), but the history outlives
  the switch: turning the extension off stops new colours being recorded and
  leaves the ones already there readable.
- The eyedropper's context menu in the menu bar panel lists the last eight
  picks in hex, so `ed color ls --format hex --limit 8` prints exactly what that
  menu shows.
- `--help` works on the group and on both verbs, prints on stdout and exits 0.
- Completion knows this group: `ed color ls --format <TAB>` offers `hex`,
  `rgb`, `hsl`, `swiftUI` and `nsColor`. A bare `ed color ls <TAB>` offers them
  as well, because the completion tree hangs the format list off the command
  rather than off the flag; `ls` still takes no positional argument, and
  passing one is an ArgumentParser error and exits 2.

## Where to go next

- [`ed clipboard`](./clipboard.md), the other history Edith keeps for you, and
  the one with per-entry verbs.
- [`ed extensions`](./extensions.md), to turn the picker itself on or off.
- [`ed config`](./config.md), for the seven `colorPicker` settings behind it.
- [All `ed` commands](./README.md).
