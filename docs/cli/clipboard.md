# `ed clipboard`

`ed clipboard` is the clipboard panel as a command: the history Edith captures,
what it weighs, and the same act of putting an entry back on the pasteboard that
clicking a row performs. Reach for it when you want the thing you copied ten
minutes ago without leaving the terminal, or when a script needs the last thing
that landed on the pasteboard.

The history is a file on disk, `index.jsonl` under
`~/Library/Application Support/Edith/clipboard`, with the bytes behind the
entries in `blobs/` beside it. Nothing here asks the running app for its
answer, so every verb works whether or not Edith is running. Mutations post the
`clipboardChanged` notification afterwards, which is what makes an open panel
redraw; when nothing is listening the post is a no-op and the write still
stands.

Entries are numbered from 1 in the same order the panel shows them: pinned
first, then most recently copied, honouring `clipboardPinTo`. That number is
what `get`, `copy`, `pin`, `unpin` and `rm` take, and it names the same entry
the UI would act on.

## At a glance

| Command | What it does |
| --- | --- |
| `ed clipboard ls` | List the history, pinned first, with each entry's number |
| `ed clipboard stats` | How many entries there are, what they weigh, and the split by family |
| `ed clipboard get <index>` | Print one entry as plain text on stdout |
| `ed clipboard copy <index>` | Put one entry back on the pasteboard and bump it to the top |
| `ed clipboard pin <index>` | Keep one entry at the top and out of the retention sweep |
| `ed clipboard unpin <index>` | Let one entry age out again |
| `ed clipboard rm <index>` | Forget one entry and delete its blob |
| `ed clipboard clear` | Forget the whole history |

A bare `ed clipboard` runs `ls`. `ls` also answers to `list`, and `stats` also
answers to `size`.

## Commands

### `ed clipboard ls`

Lists the history with the number every other verb takes.

```
ed clipboard ls [--pinned] [--search <text>] [--limit <n>] [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--pinned` | flag | off | Keep only pinned entries. |
| `--search <text>` | string | unset | Keep only entries whose preview or source app contains this text, case-insensitively. |
| `--limit <n>` | integer, 0 or more | `25` | Show at most this many entries. Pass 0 for all of them. |
| `--json` | flag | off | Emit JSON on stdout. |

The filters run in that order: `--search` first, then `--pinned`, then `--limit`
on what is left. `--search` is trimmed and lowercased before it is used, so a
value that is only whitespace filters nothing, and it matches the preview text
and the source application, which is the same match the panel's search field
makes.

Numbers are assigned before any filtering, against the whole history, so a
number you read out of `ed clipboard ls --pinned` still names the same entry to
`get` and `rm`. The list can therefore be numbered 1, 4, 9 with no gap being an
error.

`--json` is an array of entry objects, one per shown row, in display order:

```json
[
  {
    "copiedAt": "2026-08-06T23:02:21Z",
    "family": "text",
    "id": "5C2F0A1E-1B4D-4E0A-9A21-7C3B4D8E6F10",
    "index": 1,
    "isText": true,
    "kind": "txt",
    "pinned": true,
    "preview": "ssh pulkit@10.0.0.4",
    "sizeBytes": 19,
    "sourceApp": "Ghostty"
  },
  {
    "copiedAt": "2026-08-06T22:41:08Z",
    "family": "image",
    "id": "0D1A7B33-9F42-4C58-8E71-2B6A0C4F91DD",
    "index": 2,
    "isText": false,
    "kind": "png",
    "pinned": false,
    "preview": "PNG image",
    "sizeBytes": 1245184,
    "sourceApp": "Preview"
  }
]
```

`kind` is the entry's file extension, the thing the blob is stored as: `txt`,
`json`, `sql`, `png`, `rtf`, `html`, `url`, `files`, `weburl`, `data` and so on.
`family` is the coarse bucket the app groups by, one of `text`, `richText`,
`html`, `image`, `file`, `document`, `media` or `data`. Both keys are present on
every entry object the group emits. `preview` and `sourceApp` are `null` rather
than absent when the entry has neither.

Examples:

```
ed clipboard ls
ed clipboard ls --limit 0
ed clipboard ls --pinned --json
ed clipboard ls --search token --limit 5
```

```
$ ed clipboard ls --limit 4
#  KIND          SIZE       FROM     PREVIEW
1  txt   pinned  19 bytes   Ghostty  ssh pulkit@10.0.0.4
2  png           1.2 MB     Preview  PNG image
3  html          8 KB       Safari   Edith keeps a history of everything you copy
4  txt           142 bytes  Xcode    func render(headers: [String]) -> String
```

The third column has no header; it holds the word `pinned` and is otherwise
blank. Sizes are formatted the way Finder formats them, so read `sizeBytes` from
`--json` when you need the exact count. Previews are capped at 500 characters at
capture time, and the table flattens newlines and tabs to spaces so one entry is
always one row.

A truncated list says so on stderr and still exits 0:

```
$ ed clipboard ls
showing 25 of 1217; pass --limit 0 for all of them
```

That note is only printed on the human path. `--json` never prints it, so a
script that wants everything has to pass `--limit 0` itself.

An empty history is not an error here: `ls` prints the header row and nothing
else, `ls --json` prints `[]`, and both exit 0. The verbs that take a number are
the ones that refuse.

### `ed clipboard stats`

Reports how much the history is holding.

```
ed clipboard stats [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout. |

```json
{
  "byKind": [
    {
      "count": 517,
      "kind": "text",
      "sizeBytes": 345088
    },
    {
      "count": 40,
      "kind": "richText",
      "sizeBytes": 28672
    },
    {
      "count": 229,
      "kind": "html",
      "sizeBytes": 2516582
    },
    {
      "count": 35,
      "kind": "image",
      "sizeBytes": 43230003
    },
    {
      "count": 87,
      "kind": "file",
      "sizeBytes": 73728
    },
    {
      "count": 309,
      "kind": "data",
      "sizeBytes": 39936
    }
  ],
  "count": 1217,
  "diskBytes": 46714880,
  "largestBytes": 9227145,
  "newest": "2026-08-06T23:02:21Z",
  "oldest": "2026-07-27T09:43:29Z",
  "pinned": 3,
  "sizeBytes": 46234009
}
```

The `kind` inside `byKind` is the family, not the extension, which is the
opposite of what `kind` means in an entry object. Families with no entries are
left out entirely rather than reported as zero, and the array stays in the fixed
family order `text`, `richText`, `html`, `image`, `file`, `document`, `media`,
`data` rather than being sorted.

`sizeBytes` totals what the entries claim; `diskBytes` is what the blob
directory actually occupies. They differ when two entries share one blob,
because a blob is keyed by its hash and stored once, and when a blob is
orphaned. `oldest` is the earliest capture time, `newest` the most recent copy
time, so a `copy` of an old entry moves `newest` without moving `oldest`.

Examples:

```
ed clipboard stats
ed clipboard size
ed clipboard stats --json
```

```
$ ed clipboard stats
ITEMS  PINNED  SIZE     ON DISK  LARGEST  OLDEST
1217   3       46.2 MB  46.7 MB  9.2 MB   2026-07-27T09:43:29Z

KIND      COUNT  SIZE
text      517    345 KB
richText  40     29 KB
html      229    2.5 MB
image     35     43.2 MB
file      87     74 KB
data      309    40 KB
```

The table has no column for `newest`; take it from `--json`. With an empty
history the human path prints `the clipboard history is empty` on stderr, writes
nothing to stdout and exits 0, while `--json` still prints a full document with
`count` 0, `byKind` `[]` and both dates `null`.

### `ed clipboard get`

Prints one entry as plain text on stdout, with no trailing decoration.

```
ed clipboard get <index> [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<index>` | integer, from 1 | required | The entry number, counting from 1. |
| `--json` | flag | off | Emit JSON on stdout. |

`--json` is the same entry object `ls` emits with one extra key, `text`, holding
the same string the human path prints:

```json
{
  "copiedAt": "2026-08-06T22:38:12Z",
  "family": "text",
  "id": "9B4E77C0-3A15-4F2E-B0D9-51C8E2A7F3B4",
  "index": 3,
  "isText": true,
  "kind": "sql",
  "pinned": false,
  "preview": "select id, name from machines order by name",
  "sizeBytes": 43,
  "sourceApp": "TablePlus",
  "text": "select id, name from machines order by name"
}
```

Which entries can be printed is decided by the stored extension, not by the
family:

- `rtf`, `rtfd` and `html` are rendered down to their plain text, so you get the
  words rather than the markup.
- `txt`, `json`, `xml`, `csv`, `tsv`, `plist`, `yaml`, `sql`, `sh`, `py`, `rb`,
  `pl`, `php`, `js`, `swift`, `md`, `log`, `conf`, `ini` and `toml` are decoded
  as UTF-8, falling back to UTF-16.
- everything else, images, PDFs, archives, copied files, copied URLs and any
  extension outside that list, is refused with exit 1 and pointed at
  `ed clipboard copy` instead.

That last rule is worth knowing because `isText` in the JSON can be `true` for
an entry `get` will still refuse: a snippet copied as a source-code type Edith
has no extension mapping for is filed under the `text` family but is not on the
list above.

Examples:

```
ed clipboard get 1
ed clipboard get 3 --json
ed clipboard get 1 > note.txt
ed clipboard get 1 | pbcopy
```

```
$ ed clipboard get 2
error: entry png is not text
hint: use `ed clipboard copy` to put it back on the pasteboard instead
```

Nothing is written or reordered by `get`; it does not count as a copy, so the
entry keeps its place in the list.

### `ed clipboard copy`

Puts one entry back on the pasteboard, the same as clicking it in the panel.

```
ed clipboard copy <index> [--plain] [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<index>` | integer, from 1 | required | The entry number, counting from 1. |
| `--plain` | flag | off | Copy as plain text even when the entry is styled. |
| `--json` | flag | off | Emit JSON on stdout. |

`--json` is the entry object exactly as `ls` emits it, with no extra keys. It
reports the entry as it was before the copy, so `copiedAt` is the previous copy
time rather than this one.

The whole pasteboard is replaced: `clearContents` first, then the entry's own
type. Rich text and HTML are written twice, once in their own type and once as a
plain string, so an app that only understands text still gets something. A
copied file goes back as a file URL, and a list of files goes back as a list of
them, which is why pasting one into Finder works; a copied web link goes back as
both a URL and a string. `--plain` only bites on a text, rich text or HTML
entry; on an image or a file it is quietly ignored and the real type is written.

Two side effects come with it. The entry's `lastCopiedAt` is bumped, so it moves
to the top of the list and everything that was above it shifts down by one. And
the pasteboard is stamped with a private `com.pulkit.edith.clipboard.own` type,
which is how the app's watcher knows this came from Edith and does not file it
as a fresh entry.

Examples:

```
ed clipboard copy 1
ed clipboard copy 4 --plain
ed clipboard copy 2 --json
```

```
$ ed clipboard copy 4
copied entry 4
```

An entry whose blob has gone missing under the index exits 3 with `the stored
copy of that entry is gone`, and nothing reaches the pasteboard.

### `ed clipboard pin`

Keeps one entry at the top and out of the retention sweep.

```
ed clipboard pin <index> [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<index>` | integer, from 1 | required | The entry number, counting from 1. |
| `--json` | flag | off | Emit JSON on stdout. |

```json
{
  "changed": true,
  "id": "5C2F0A1E-1B4D-4E0A-9A21-7C3B4D8E6F10",
  "index": 1,
  "pinned": true
}
```

Pinning exempts an entry from the sweep that `clipboardMaxItems` and
`clipboardMaxAgeDays` drive, which is the only way to keep something the history
would otherwise drop. Pinned entries sort to the top of the list unless
`ed config set clipboardPinTo bottom` says otherwise.

Pinning something already pinned is not an error: `changed` is `false`, the file
is not rewritten, `entry 1 was already pinned` goes to stderr, and the exit code
is 0.

Examples:

```
ed clipboard pin 1
ed clipboard pin 3 --json
```

```
$ ed clipboard pin 3
pinned entry 3
```

### `ed clipboard unpin`

Lets one entry age out again.

```
ed clipboard unpin <index> [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<index>` | integer, from 1 | required | The entry number, counting from 1. |
| `--json` | flag | off | Emit JSON on stdout. |

Identical to `pin` in every respect but the value written, including the JSON
shape, where `pinned` is `false`. Unpinning something already unpinned reports
`entry 3 was already unpinned` on stderr and exits 0.

Unpinning does not delete anything, but it does hand the entry back to the
retention sweep, so an old entry can disappear on the app's next pass.

Examples:

```
ed clipboard unpin 3
ed clipboard unpin 1 --json
```

### `ed clipboard rm`

Forgets one entry and deletes the blob behind it.

```
ed clipboard rm <index> [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<index>` | integer, from 1 | required | The entry number, counting from 1. |
| `--json` | flag | off | Emit JSON on stdout. |

```json
{
  "remaining": 1216,
  "removed": 3
}
```

`removed` here is the index that was removed, not a count, which is the opposite
of what the same key means under `clear`. `remaining` is how many entries the
history holds afterwards.

Removal also prunes orphaned blobs, so the file under `blobs/` goes with the
entry unless another entry references the same content. This is not a Trash
move and there is no undo: the bytes are gone.

Examples:

```
ed clipboard rm 3
ed clipboard rm 1 --json
```

```
$ ed clipboard rm 3
removed entry 3, 1216 left
```

Numbers shift after a removal, so removing several entries by number means
re-reading `ls` between each one, or reading `id` out of `--json` first and
working from that.

### `ed clipboard clear`

Forgets the whole history.

```
ed clipboard clear [--keep-pinned] [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--keep-pinned` | flag | off | Keep pinned entries. |
| `--json` | flag | off | Emit JSON on stdout. |

```json
{
  "remaining": 3,
  "removed": 1214
}
```

`removed` is a count here, and `remaining` is what survived, which is 0 without
`--keep-pinned` and the number of pinned entries with it.

There is no confirmation flag on this one: unlike `ed machines rm` or
`ed cleaner clean`, `clear` acts immediately. Orphaned blobs are pruned with it,
so the disk space comes back at once. Clearing an already empty history writes
nothing and reports `cleared 0 entries`, exit 0.

Examples:

```
ed clipboard clear
ed clipboard clear --keep-pinned
ed clipboard clear --json
```

```
$ ed clipboard clear --keep-pinned
cleared 1214 entries
```

## Exit codes

| Code | When this group produces it |
| --- | --- |
| 0 | The command did what it says, including `--help`, an empty `ls`, and pinning something that was already pinned |
| 1 | `get` on an entry that is not text: `error: entry png is not text` |
| 2 | `--limit` below zero, or a command line ArgumentParser cannot parse, such as a non-numeric index or an unknown flag |
| 3 | No entry with that number, or the blob behind an entry is missing |
| 4 | The history is empty and you named a number |

The empty case is the one that surprises people. Every verb that takes a number
goes through the same lookup, and that lookup calls an empty history
unavailable rather than not-found, because the usual reason for it is that the
extension has never been on:

```
$ ed clipboard pin 1
error: the clipboard history is empty
hint: turn the Clipboard extension on with `ed extensions enable clipboard`
```

A number outside a non-empty history is a plain 3, and the hint tells you the
range:

```
$ ed clipboard get 9999
error: there is no clipboard entry 9999
hint: the history holds 1217 entries, numbered from 1
```

A negative limit is caught before anything is read:

```
$ ed clipboard ls --limit=-1
error: --limit cannot be negative
hint: pass 0 or more
```

## Notes and gotchas

- **Numbers are positions, ids are identities.** Any copy, pin, unpin, removal,
  or anything you copy anywhere else on the Mac while the extension is on
  reshuffles the list. A script that acts on more than one entry should read
  `id` from `--json` and re-derive the number, rather than caching a number from
  an earlier run.
- **`copy` reorders, `get` does not.** `copy` bumps `lastCopiedAt` the way
  clicking a row does, so entry 4 becomes entry 1 and everything above it slides
  down. `get` only reads.
- **`kind` means two different things.** In an entry object it is the file
  extension; inside `stats`'s `byKind` it is the family. `family` on an entry
  object is the value that lines up with a `byKind` row.
- **`removed` means two different things.** `rm` reports the index it removed,
  `clear` reports how many it removed. Both sit next to a `remaining` count.
- **Ordering follows the panel, not the file.** Pinned entries come first, each
  group sorted by most recent copy. `ed config set clipboardPinTo bottom` flips
  the two groups, and `ed clipboard ls` follows it, so the same number can name
  a different entry after that setting changes. The command's own help text says
  "newest first", which is only true when nothing is pinned.
- **Mutations take a file lock.** Copy, pin, unpin, remove and clear hold an
  exclusive lock on `~/Library/Application Support/Edith/clipboard/.lock` while
  they rewrite the index, so `ed` and a running Edith cannot interleave writes.
  Reads do not take the lock, so a very long `ls` can race a capture and simply
  show the older list.
- **Removal is permanent.** `rm` and `clear` delete blobs, and neither offers a
  `--yes` gate or a Trash step. There is no `ed clipboard` verb that restores
  anything.
- **The extension does not gate reading.** `ed clipboard ls` reports whatever is
  on disk even with the Clipboard extension off; the extension is what captures
  new entries. `ed extensions enable clipboard` turns capture on, and
  `ed config ls --group clipboard` lists the retention, hotkey, ignore-list and
  capture switches that shape what ends up here.
- **`preview` is a preview.** It is capped at 500 characters, so it is a search
  target and a display string, not the content. Use `get` for the content.
- **Everything works with the app closed.** Nothing in this group waits on
  Edith, and none of it can exit 4 for a missing app. The only 4 it produces is
  the empty history.

## Where to go next

- [`ed color`](./color.md), the other history the picker keeps, and the second
  command group defined in the same source file
- [`ed extensions`](./extensions.md), to turn clipboard capture on or off
- [`ed config`](./config.md), for the `clipboard` group of settings that decide
  what is captured and how long it is kept
- [All command groups](./README.md)
