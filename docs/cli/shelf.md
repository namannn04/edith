# `ed shelf`

`ed shelf` reads and writes the notch shelf, the tray of files you park by
dragging them to the notch and pick up again later. Reach for it when a script
should leave a file where the notch will hand it to you, or when you want the
path of something you already dropped there without opening the shelf at all.

The shelf is a plain folder with an index beside it: the files sit flat in
`~/Library/Application Support/Edith/Shelf`, and `.index.json` in that same
folder records each one's id, name and when it landed. Nothing here talks to
the app, so every verb works whether or not Edith is running, and the paths it
prints are real paths any other tool can open.

Items are numbered from 1, newest first by the time they were added. That
number is what `path` and `rm` take. It is `ed`'s own ordering: the notch lays
its tiles out on a canvas you can drag them around on, so the number here names
a row in this listing rather than a position on screen.

## At a glance

| Command | What it does |
| --- | --- |
| `ed shelf` | Runs `ed shelf ls`, which is the default subcommand. |
| `ed shelf ls` | Lists what is parked, newest first, with size and when it landed. |
| `ed shelf path <n>` | Prints the full path of one item, which is what to pipe into another tool. |
| `ed shelf add <file>` | Copies a file onto the shelf and leaves the original where it is. |
| `ed shelf rm <n>` | Takes one item off the shelf and deletes the shelf's copy. |
| `ed shelf clear` | Empties the shelf. |

`ed shelf list` is the same command as `ed shelf ls`, and `ed shelf` with
nothing after it runs `ls`, including its flags: `ed shelf --json` is
`ed shelf ls --json`.

## Commands

### `ed shelf ls`

Lists everything on the shelf, newest first.

Usage:

```
ed shelf ls [--json]
```

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emits one JSON document on stdout. |

There are no positional arguments, and there is no limit, search or filter:
`ls` always prints the whole shelf.

`--json` shape, an array with one object per item, in the same order the table
prints:

```json
[
  {
    "addedAt": "2026-08-03T15:54:20Z",
    "exists": true,
    "id": "DFB41F1C-26A1-4E03-86F7-83AACFFABC28",
    "index": 1,
    "name": "screenshot.png",
    "path": "/Users/pulkit/Library/Application Support/Edith/Shelf/screenshot.png",
    "sizeBytes": 225070
  },
  {
    "addedAt": "2026-08-01T09:12:44Z",
    "exists": true,
    "id": "6C2B0A55-9F41-4B7C-9D0E-2A1F7E3C8B10",
    "index": 2,
    "name": "notes 2.pdf",
    "path": "/Users/pulkit/Library/Application Support/Edith/Shelf/notes 2.pdf",
    "sizeBytes": 48211
  }
]
```

`index` is the number `path` and `rm` take. `id` is the item's UUID from the
index file, stable for the life of the item and accepted nowhere as an
argument. `name` is the filename on the shelf, which is not always the name of
the file you added. `path` is `name` joined onto the shelf folder, so it is
always flat and always absolute. `sizeBytes` and `exists` are measured on disk
at the moment you run the command, not stored: a file removed behind the
index's back reports `"sizeBytes": 0` and `"exists": false` rather than
disappearing from the list. `addedAt` is ISO 8601 in UTC, to the second.

Examples:

```
ed shelf ls
ed shelf --json
ed shelf ls --json
```

The table is four columns: the item number, the name on the shelf, its size,
and when it was added.

```
$ ed shelf ls
#  NAME            SIZE     ADDED
1  screenshot.png  225 KB   2026-08-03T15:54:20Z
2  notes 2.pdf     48.2 KB  2026-08-01T09:12:44Z
```

Behaviour: `ls` reads the index and stats each file, writes nothing, and needs
neither the main app nor the menu bar helper. An empty shelf is not an error:
without `--json` it writes `the shelf is empty` to stderr, leaves stdout empty
and exits 0, and with `--json` it prints `[]` and exits 0. An unreadable or
absent index decodes to an empty shelf, so a corrupted index looks exactly like
a shelf you have never used.

### `ed shelf path`

Prints the full path of one shelf item.

Usage:

```
ed shelf path <n> [--json]
```

Arguments:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<n>` | integer, 1 or more | required | The item number from `ed shelf ls`, counting from 1. |

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emits one JSON document on stdout. |

`--json` shape, the same object `ls` emits for that item:

```json
{
  "addedAt": "2026-08-03T15:54:20Z",
  "exists": true,
  "id": "DFB41F1C-26A1-4E03-86F7-83AACFFABC28",
  "index": 1,
  "name": "screenshot.png",
  "path": "/Users/pulkit/Library/Application Support/Edith/Shelf/screenshot.png",
  "sizeBytes": 225070
}
```

Examples:

```
ed shelf path 1
ed shelf path 1 --json
open "$(ed shelf path 1)"
cp "$(ed shelf path 2)" ~/Desktop/
```

Without `--json` the output is the bare path on one line and nothing else,
which is what makes it worth substituting into another command:

```
$ ed shelf path 1
/Users/pulkit/Library/Application Support/Edith/Shelf/screenshot.png
```

Behaviour: `path` prints where the copy lives, not where the original came
from; the shelf does not record the source. It reports the path whether or not
the file is still there, so check `exists` in the JSON if that matters. A
number below 1 or above the count exits 3 and says how many items the shelf
holds, and asking on an empty shelf exits 4:

```
$ ed shelf path 9
error: there is no shelf item 9
hint: the shelf holds 2 items, numbered from 1

$ ed shelf path 1
error: the shelf is empty
hint: drag something onto the notch, or run `ed shelf add <file>`
```

### `ed shelf add`

Copies a file onto the shelf.

Usage:

```
ed shelf add <file> [--json]
```

Arguments:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<file>` | path to an existing file or directory | required | What to park. `~` is expanded, and a relative path resolves against your current directory. |

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emits one JSON document on stdout. |

`--json` shape, the new item, always at index 1 because it is the newest:

```json
{
  "addedAt": "2026-08-08T11:02:57Z",
  "exists": true,
  "id": "0B7A44E2-51C8-4F0A-8D33-9C6B2E5A1477",
  "index": 1,
  "name": "report 2.pdf",
  "path": "/Users/pulkit/Library/Application Support/Edith/Shelf/report 2.pdf",
  "sizeBytes": 184320
}
```

Examples:

```
ed shelf add ./report.pdf
ed shelf add ~/Downloads/build.zip
ed shelf add ~/Projects/notes
ed shelf add ./report.pdf --json
```

```
$ ed shelf add ./report.pdf
shelved report.pdf

$ ed shelf add ./report.pdf
shelved report 2.pdf
```

Behaviour: `add` copies rather than moves, so the file you named is still where
it was afterwards, exactly as dragging it onto the notch does: the shelf holds
its own copy and the original is left alone. The name on the shelf is the
last path component, made unique against what is already in the shelf folder by
inserting a counter before the extension: `report.pdf`, then `report 2.pdf`,
then `report 3.pdf`, and an extension-less `Makefile` becomes `Makefile 2`. The
check is against the folder, not the index, so a file left behind by a previous
shelf still forces the rename. Nothing is ever overwritten.

A path with nothing at it exits 3 with `no file at <path>` and no hint. A copy
the filesystem refuses, whether the source is unreadable, the shelf folder is
not writable, or the disk is full, exits 1 with the system's own description as
the hint:

```
$ ed shelf add /nowhere/at/all.txt
error: no file at /nowhere/at/all.txt

$ ed shelf add ./locked.txt
error: could not put locked.txt on the shelf
hint: “locked.txt” couldn’t be copied because you don’t have permission to access “Shelf”.
```

A directory is accepted and copied whole, recursively, because the copy is a
plain `copyItem`. The `sizeBytes` reported for one is what the filesystem
records for the directory entry itself, not the total of what is inside it.

### `ed shelf rm`

Takes one item off the shelf.

Usage:

```
ed shelf rm <n> [--json]
```

Arguments:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<n>` | integer, 1 or more | required | The item number from `ed shelf ls`, counting from 1. |

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emits one JSON document on stdout. |

There is no `--yes` guard here: `rm` takes effect the moment you run it.

`--json` shape:

```json
{
  "remaining": 1,
  "removed": 2
}
```

`removed` echoes back the number you passed, not an id or a name, and
`remaining` is how many items are left.

Examples:

```
ed shelf rm 1
ed shelf rm 2 --json
```

```
$ ed shelf rm 2
removed notes 2.pdf, 1 left
```

Behaviour: `rm` deletes the shelf's copy outright. It does not go to the Trash,
unlike `ed music rm` and `ed cleaner clean`, and it is not recoverable, so the
copy is gone even though whatever you originally added is untouched. A copy
that is already missing is not an error: the index entry is dropped and the
command still exits 0.

Numbers shift after every removal, because they are positions in a
newest-first list rather than ids. Removing several items means re-reading
`ed shelf ls` between calls, or removing from the highest number downwards.

An index below 1 or above the count exits 3, and `rm` on an empty shelf exits 4
with the same message `path` gives.

### `ed shelf clear`

Empties the shelf.

Usage:

```
ed shelf clear [--json]
```

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emits one JSON document on stdout. |

There are no positional arguments, no `--yes` guard and no way to keep part of
the shelf: `clear` empties it the moment you run it.

`--json` shape:

```json
{
  "removed": 2
}
```

`removed` is how many items were on the shelf before it was emptied.

Examples:

```
ed shelf clear
ed shelf clear --json
```

```
$ ed shelf clear
cleared 2 items
```

Behaviour: `clear` deletes every file the index knows about, then writes an
empty index. Files that are in the shelf folder but not in the index are left
where they are, so a folder that has been edited by hand can still hold
something after a clear. Clearing an already empty shelf is reported as
`cleared 0 items` and exits 0 rather than failing. The `.index.json` file
itself stays, holding `[]`.

## Exit codes

| Code | When this group produces it |
| --- | --- |
| 0 | The listing, path, add, removal or clear succeeded. Also an empty shelf under `ls`, an already empty shelf under `clear`, and `--help` on the group or any verb. |
| 1 | `add` could not copy the file: an unreadable source, a destination the filesystem refused, or no space. The hint is the system's own description. |
| 2 | The command line was wrong in ArgumentParser's own terms: an unknown flag, a missing `<index>` or `<file>`, an `<index>` that is not an integer, or an extra positional argument. |
| 3 | `add` was given a path with nothing at it, or `path` or `rm` was given a number below 1 or above the number of items. |
| 4 | `path` or `rm` was run on an empty shelf. |

Exit 4 here does not mean the app is missing. Nothing in this group talks to
Edith, and the one thing that reports itself unavailable is an empty shelf,
which is a state you fix with `ed shelf add` rather than by starting the app.
`ls` treats the same empty shelf as success, so use `ls` when you are probing
rather than acting.

## Notes and gotchas

- The shelf folder is flat. Every item is a direct child of
  `~/Library/Application Support/Edith/Shelf`, and the index is `.index.json`
  in that same folder, hidden by its leading dot. Because names are made
  unique against the folder, adding a file called `.index.json` lands as
  `.index 2.json` rather than clobbering the index.
- A running Edith holds the index in memory. It reads `.index.json` once, when
  the notch shelf starts, and writes the whole in-memory list back on every
  change it makes. Nothing tells it that `ed` wrote the file, so a shelf
  changed from the CLI while the app is open does not appear in the notch, and
  the next drag or drag-out from the notch saves the app's older list over
  yours. Files added by `ed` survive as orphans in the folder; items removed by
  `ed` come back in the index with `"exists": false`, because their copies are
  really gone. Quitting and reopening Edith, or running the CLI while it is
  closed, avoids the whole question.
- `ls` sorts newest first every time, but the index file is written in whatever
  order the writer used. `add` appends, the way the app does. `rm` writes back
  what it read, which is the sorted list, so removing one item quietly reverses
  the stored order of the rest. That changes nothing about what `ed` prints,
  and it does move the tiles in the notch for items you have never dragged,
  because an untouched tile is positioned by its index in the file.
- Each item can carry a `position` recorded by dragging its tile around the
  notch canvas. `ed` never reads it, writes it or shows it, and it survives
  `ed shelf rm` for the items that are left, because `rm` saves back the items
  it decoded rather than rebuilding them.
- `add` always reports `"index": 1`. The number is written into the document
  rather than recomputed, and it is right because the item's `addedAt` is the
  moment you ran the command, unless something on the shelf carries a
  timestamp from the future.
- There is no `ed shelf get`, no `ed shelf copy` and no way to pull an item
  back out. `path` plus `cp` is the whole story, and the shelf's copy stays
  until you remove it.
- Nothing here is gated on the extension. `ed shelf` works with
  `notchShelfEnabled` off, so you can park and read files even when the notch
  is not showing anything. Turn the surface on with
  `ed extensions enable notchShelf`.
- Nothing here expires anything either. Items expire only when a running Edith
  sweeps them, using `notchShelfKeepDuration`, whose values are `forever`,
  `oneHour`, `oneDay`, `oneWeek` and `oneMonth`, defaulting to `forever` when
  the setting is unset or unrecognised. The sweep happens when the shelf starts
  and each time it expands, so a Mac whose Edith is closed keeps everything
  regardless of the setting.
- The rest of the notch's behaviour is settings rather than commands:
  `notchShelfOpenOnDrag`, `notchShelfOpenOnHover`, `notchShelfRequireOption`,
  `notchShelfRemoveAfterDragOut`, `notchShelfShowOnExternal`,
  `notchShelfHaptics` and `notchShelfShowMusic`. See `ed config ls notchShelf`.
- The table flattens control characters out of a name, so a filename
  containing a newline or a tab prints on one line. `--json` carries the name
  exactly as it is on disk, which is what to match on.
- `--help` works on the group and on all five verbs, prints on stdout and exits
  0. `--version` is inherited from the root and works on any of them too,
  printing the CLI version.
- Completion knows the group: `ed shelf <TAB>` offers the five verbs, and
  `ed shelf add <TAB>` completes file paths. The index slots of `path` and `rm`
  offer nothing, because completion does not read the shelf; run
  `ed shelf ls` for the numbers.

## Where to go next

- [`ed clipboard`](./clipboard.md), the other thing the notch panel holds, and
  the one whose entries are numbered the same way.
- [`ed extensions`](./extensions.md), to turn the notch shelf itself on or off.
- [`ed config`](./config.md), for the shelf's hover, drag and expiry settings.
- [Conventions and contracts](./conventions.md), for the exit code table and
  the `--json` guarantee in full.
- [All `ed` commands](./README.md).
