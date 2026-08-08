# `ed download`

`ed download` is the queue Edith feeds to yt-dlp: YouTube links waiting to
become files in your music folder. Reach for it when you want to queue
something from a script or a terminal rather than from the Download sheet, or
when you want to know what the queue is holding without opening a window.

The queue is a single file, `downloads.json` under
`~/Library/Application Support/Edith/data`, so listing it, adding to it,
retrying, removing and clearing are plain file writes that work whether or not
Edith is running. Running the downloads is not something `ed` does: that belongs
to the app, so anything you add while Edith is closed waits in the queue and
starts when you next open it, and `ed` says so on stderr rather than failing.
The one binary `ed` runs itself is the yt-dlp that `ed download tool` reports on.

`ed downloads` and `ed dl` are the same group under different names, and
`ed download` with nothing after it is `ed download ls`.

## At a glance

| Command | What it does |
| --- | --- |
| `ed download` | Runs `ed download ls`, which is the default subcommand. |
| `ed download ls` | Lists the queue, newest first, as a numbered table. |
| `ed download add` | Queues one or more YouTube URLs as audio or video. |
| `ed download retry` | Puts a failed or interrupted entry back in the queue. |
| `ed download rm` | Takes one entry out of the queue. |
| `ed download clear` | Forgets what has finished, or the whole queue with `--everything`. |
| `ed download tool` | Reports the yt-dlp being used, or runs its self-update. |
| `ed download cancel` | Stops what is downloading and empties everything that has not finished. |

`ed download list` is the same command as `ed download ls`.

## Commands

### `ed download ls`

Lists what is in the queue, newest first.

Usage:

```
ed download ls [--active] [--limit <n>] [--json]
```

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--active` | flag | off | Keeps only entries that have not finished: `queued`, `resolving` and `downloading`. |
| `--limit <n>` | integer, 0 or more | `25` | Shows at most this many. `0` shows all of them. |
| `--json` | flag | off | Emits one JSON document on stdout. |

There are no positional arguments.

Entries are numbered from 1 in the order they are printed, which is by the time
they were queued, newest first. That number is what `ed download rm` and
`ed download retry` take, and it is recomputed on every invocation: removing
entry 1 renumbers everything below it, so read the list again between two
edits rather than counting down from an old listing.

That number counts through the whole queue, so take it from a bare `ls` or from
`ls --limit <n>`, which shows a prefix of the same list. Never take it from
`ls --active`: that numbers only what it prints, so its entry 1 is the first
unfinished download, while `rm 1` and `retry 1` mean the first entry in the
queue whatever state it is in.

`--active` filters on "not finished", and an interrupted download counts as
finished, so a paused or cancelled entry does not appear even though its file
was never written. Use a bare `ls` to see those.

`--limit` is checked before the file is read, so a negative value exits 2 and
nothing is printed.

`--json` shape, an array with one object per entry:

```json
[
  {
    "detail": "Night Drive.m4a",
    "index": 1,
    "kind": "audio",
    "queuedAt": "2026-08-07T19:12:44Z",
    "state": "done",
    "title": "Night Drive",
    "url": "https://youtu.be/dQw4w9WgXcQ"
  },
  {
    "detail": "63.4%",
    "index": 2,
    "kind": "video",
    "queuedAt": "2026-08-07T19:11:02Z",
    "state": "downloading",
    "title": "https://www.youtube.com/watch?v=aqz-KE-bpKQ",
    "url": "https://www.youtube.com/watch?v=aqz-KE-bpKQ"
  },
  {
    "detail": "ERROR: [youtube] Video unavailable",
    "index": 3,
    "kind": "audio",
    "queuedAt": "2026-08-07T18:55:10Z",
    "state": "failed",
    "title": "https://youtu.be/aaaaaaaaaaa",
    "url": "https://youtu.be/aaaaaaaaaaa"
  }
]
```

`state` is one of `queued`, `resolving`, `downloading`, `done`, `failed` and
`interrupted`. `detail` depends on the state: the progress yt-dlp last reported
for `downloading` (`63.4%`, or `63.4% (2/5)` while working through a playlist),
the produced filenames for `done`, the whole error text for `failed`, the
reason for `interrupted`, and an empty string for `queued` and `resolving`.
`title` is the produced file's name without its extension once the download is
`done`, and the URL itself until then. `kind` is `audio` or `video`, and an
entry written by an older Edith that recorded no kind reads back as `audio`.
`queuedAt` is ISO 8601 in UTC. The output filename template the entry was
queued with is not exposed.

Examples:

```
ed download ls
ed download ls --active
ed download ls --limit 0 --json
```

```
$ ed download ls
#  STATE        KIND   WHAT
1  done         audio  Night Drive
2  downloading  video  https://www.youtube.com/watch?v=aqz-KE-bpKQ
3  queued       audio  https://youtu.be/dQw4w9WgXcQ
```

Behaviour: `ls` reads one file and writes nothing, needs neither the main
window nor the menu bar app, and never fails because Edith is closed. An empty
queue writes `the download queue is empty` to stderr, or `nothing is
downloading` with `--active`, leaves stdout empty and exits 0. A list cut short
by `--limit` says so on stderr: `showing 25 of 41; pass --limit 0 for all of
them`. Neither note is printed under `--json`, where an empty queue is an empty
array and a truncated list is silent, so a caller never has to parse prose.
The table has four columns and `detail` is not one of them: `WHAT` is the
title, so the error text of a `failed` entry is reachable only through `--json`.
In the cells it does print, newlines, carriage returns and tabs become spaces
and every other control character is dropped, so nothing in a title can break
the columns.

### `ed download add`

Queues one or more YouTube URLs.

Usage:

```
ed download add <url>... [--kind audio|video] [--prefix <text>] [--json]
```

Arguments:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<url>...` | one or more strings | required | The links to download. At least one is required. |

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--kind <k>` | `audio` or `video` | `audio` | What to fetch. `audio` extracts to m4a, `video` merges best video and audio into mp4. |
| `--prefix <text>` | string | `""` | Prepended to the saved filename, so `--prefix roadtrip_` saves `roadtrip_Title.m4a`. |
| `--json` | flag | off | Emits one JSON document on stdout. |

Arguments are joined with newlines and handed to the same parser the sheet's
paste box uses, which splits on commas, newlines and carriage returns, trims
each piece, and keeps only what parses as a URL whose host contains
`youtube.com` or `youtu.be`. So a comma-separated list inside one quoted
argument works, several arguments work, and anything else in the line is
dropped without comment: a Vimeo link, a bare video id, or a sentence with a
link in it all contribute nothing. If nothing survives, the command exits 1
rather than queueing an empty batch:

```
$ ed download add "check this out"
error: none of that looked like a URL
hint: pass a link, for example https://youtu.be/dQw4w9WgXcQ
```

`--kind` is matched exactly against the two raw values; anything else exits 3
and lists them. The whole batch shares one kind and one prefix, so queue two
`add` commands when you want one of each.

`--json` shape, an array with one object per URL that was queued, in the order
they were parsed:

```json
[
  {
    "detail": "",
    "index": 1,
    "kind": "audio",
    "queuedAt": "2026-08-07T19:20:31Z",
    "state": "queued",
    "title": "https://youtu.be/dQw4w9WgXcQ",
    "url": "https://youtu.be/dQw4w9WgXcQ"
  }
]
```

The `index` here counts within what was just added, not the position in the
queue. Read `ed download ls --json` if you need queue positions.

Examples:

```
ed download add https://youtu.be/dQw4w9WgXcQ
ed download add https://youtu.be/dQw4w9WgXcQ --kind video --prefix roadtrip_
ed download add "https://youtu.be/a,https://youtu.be/b" --json
```

```
$ ed download add https://youtu.be/dQw4w9WgXcQ
queued https://youtu.be/dQw4w9WgXcQ
Edith is not running, so this starts when you next open it
```

Behaviour: `add` writes the new records to the front of `downloads.json` and
posts `downloadQueueChanged`, which a running Edith takes as a cue to re-read
the file and start on the next queued item. Duplicates are not detected: adding
a URL that is already queued or already downloaded queues it again. The saved
file goes to your music folder, which is `musicFolderPath` when you have set
one, `<repoPath>/local/music` when only `repoPath` is set, and
`~/Library/Application Support/Edith/music` otherwise. The note about
Edith not running goes to stderr, only when the menu bar app is absent, and
only on the human path; `--json` never prints it, and either way the exit code
is 0 because the queue write succeeded.

### `ed download retry`

Puts a failed or interrupted entry back into the queue.

Usage:

```
ed download retry <n> [--json]
ed download retry --all [--json]
```

Arguments:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<n>` | integer, counting from 1 | none | The download to retry, numbered as `ed download ls` numbers it. Optional, but required unless `--all` is passed. |

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--all` | flag | off | Retries everything that failed or was interrupted. |
| `--json` | flag | off | Emits one JSON document on stdout. |

Only `failed` and `interrupted` entries can be retried; retrying sets them back
to `queued` and leaves everything else alone. Naming an entry in any other
state exits 1 and says which state it is in, rather than silently doing
nothing. Passing neither a number nor `--all` also exits 1. `--all` on a queue
with nothing to retry is not an error: it reports 0 and exits 0.

`--json` shape:

```json
{
  "retried": 2
}
```

Examples:

```
ed download retry 3
ed download retry --all
ed download retry --all --json
```

```
$ ed download retry 1
error: download 1 is done, so there is nothing to retry
```

Behaviour: `retry` rewrites `downloads.json` when something changed, and posts
`downloadQueueChanged` either way, so a running Edith picks the work up at once
rather than waiting for its next look at the file. Retrying
by number matches on the entry's URL rather than on its position, so if the
same link failed twice, `ed download retry 3` re-queues both copies and
`retried` says 2. The "Edith is not running" note applies here too, on the
human path only.

### `ed download rm`

Takes one entry out of the queue.

Usage:

```
ed download rm <n> [--json]
```

Arguments:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<n>` | integer, counting from 1 | required | The download to remove, numbered as `ed download ls` numbers it. |

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emits one JSON document on stdout. |

There is no `--yes` guard: `rm` takes effect the moment you run it. It removes
the record, never the downloaded file, so removing a `done` entry forgets the
history and leaves the track in your music folder. Removing a `downloading`
entry does not stop the download; use `ed download cancel` for that.

`--json` shape:

```json
{
  "remaining": 11,
  "removed": 1
}
```

`removed` counts the records that matched, and `remaining` is what the file
holds afterwards.

Examples:

```
ed download rm 1
ed download rm 4 --json
```

```
$ ed download rm 2
removed Night Drive
```

Behaviour: the entry is matched by its URL and its queued timestamp together,
so an identical link queued at a different moment survives. Two URLs queued in
the same `add` share a timestamp, so a link passed twice in one command is
removed by one `rm` and `removed` reports 2. An index outside the list exits 3
with the size of the queue as the hint; running it against an empty queue exits
4. The file is rewritten and `downloadQueueChanged` is posted either way.

### `ed download clear`

Forgets what has finished.

Usage:

```
ed download clear [--everything] [--json]
```

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--everything` | flag | off | Clears what is still queued or running as well. |
| `--json` | flag | off | Emits one JSON document on stdout. |

There are no positional arguments and no `--yes` guard. Without
`--everything` it drops the `done`, `failed` and `interrupted` records and
leaves `queued`, `resolving` and `downloading` alone, which is the safe sweep
after a batch has run. With `--everything` the file is emptied whatever state
things are in. Neither form deletes a downloaded file; only the list is
cleared.

`--json` shape:

```json
{
  "remaining": 2,
  "removed": 9
}
```

Examples:

```
ed download clear
ed download clear --everything
ed download clear --json
```

```
$ ed download clear
cleared 9
```

Behaviour: clearing an already empty queue reports `cleared 0` and exits 0
rather than failing. `downloadQueueChanged` is posted afterwards, so a running
Edith empties its Download sheet to match. Note that `--everything` forgets an
in-flight download without stopping it, exactly as `rm` does.

### `ed download tool`

Reports the yt-dlp that does the work, or runs its self-update.

Usage:

```
ed download tool [--update] [--json]
```

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--update` | flag | off | Runs `yt-dlp -U` on the copy that was found, rather than only reporting its version. |
| `--json` | flag | off | Emits one JSON document on stdout. |

There are no positional arguments. yt-dlp is the one external program this
group depends on, and it is the only tool `ed download` manages. It is looked
up by scanning a fixed list of directories in order and taking the first
executable called `yt-dlp`:

```
~/Library/Application Support/Edith/bin    what Edith installs for you
~/.local/bin
~/.nvm/current/bin and each ~/.nvm/versions/node/*/bin, reverse alphabetical
/opt/homebrew/bin
/usr/local/bin
/usr/bin, /bin, /usr/sbin, /sbin
whatever your own PATH already contained, in its own order
```

Edith's own `bin` comes first, so a copy the app installed wins over a Homebrew
one. Directories under `/Volumes` that are not inside your home directory are
dropped from the search, so an unplugged external disk never decides the
answer. This is the same lookup the app uses, so `ed` and the Download sheet
always agree on which binary runs.

Installing is not here. `ed tools install yt-dlp` fetches `yt-dlp_macos` from
the official yt-dlp release itself, marks it executable and saves it into
`~/Library/Application Support/Edith/bin`, the same fetch the Music
extension's setup panel runs. It needs no app: it streams each step as it runs,
checks the binary answers `--version` afterwards, and fails with the manual
instruction when it did not land. `brew install yt-dlp` works just as well, and
`ed tools ls` reports which one PATH is offering.

`--json` shape without `--update`:

```json
{
  "installed": true,
  "path": "/Users/pulkit/Library/Application Support/Edith/bin/yt-dlp",
  "version": "2026.07.04"
}
```

`--json` shape with `--update`:

```json
{
  "after": "2026.08.02",
  "before": "2026.07.04",
  "changed": true,
  "path": "/Users/pulkit/Library/Application Support/Edith/bin/yt-dlp"
}
```

`path` and `version` are `null` when nothing was found, and `changed` compares
the version string before the update with the one after, so an update that had
nothing to do reports `false`.

Examples:

```
ed download tool
ed download tool --json
ed download tool --update
```

```
$ ed download tool
2026.07.04  /Users/pulkit/Library/Application Support/Edith/bin/yt-dlp

$ ed download tool --update
Updating to stable@2026.08.02 ... Updated yt-dlp to stable@2026.08.02
```

Behaviour: the two output modes disagree about what a missing yt-dlp means, on
purpose. The human path exits 4 with `yt-dlp is not installed` and a hint
naming both ways to get it, because a person typing this wants to be told. The
`--json` path reports `"installed": false` with two nulls and exits 0, because
an agent asking whether the tool is there should get an answer rather than an
error. `--update` draws no such distinction: with no yt-dlp to update it exits
4 in both modes, `--json` included. An update that runs and finds nothing newer
is not that case; it exits 0 and reports `"changed": false`.

Neither form needs Edith running: `ed` runs the binary itself. The version
string is whatever `yt-dlp --version` writes, on stdout or stderr, trimmed,
with no check on its exit status, so a copy that is present but broken reports
its complaint where a version would be. `--update` prints yt-dlp's own output
verbatim, and falls back to `yt-dlp is <version>` when the update was silent.
There is no `--yes` guard on `--update`, and a self-update run against a
Homebrew copy will say what Homebrew's yt-dlp says about being managed
elsewhere.

### `ed download cancel`

Stops what is downloading and empties the rest of the queue.

Usage:

```
ed download cancel [--json]
```

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emits one JSON document on stdout. |

There are no positional arguments and no `--yes` guard. Everything not
finished, meaning `queued`, `resolving` and `downloading`, is removed from the
queue. Finished entries stay: this is the mirror image of `clear`, which drops
the finished ones and keeps the rest.

`--json` shape:

```json
{
  "appRunning": true,
  "cancelled": 3,
  "stoppedRunning": true
}
```

`cancelled` counts the records taken out of the queue. `appRunning` says whether
the main Edith app was there to be asked, and `stoppedRunning` says whether it
was asked, so `false` means the queue was emptied without a transfer being
stopped. With nothing to cancel, `stoppedRunning` is always `false` while
`appRunning` still reports what it found.

Examples:

```
ed download cancel
ed download cancel --json
```

```
$ ed download cancel
cancelled 3
```

With Edith closed:

```
$ ed download cancel
cancelled 3
Edith was not running, so the queue was emptied without stopping yt-dlp
```

Behaviour: with nothing in flight the command writes `nothing is downloading`
to stderr, changes no file, and exits 0; under `--json` that note is not
printed and stdout carries `"cancelled": 0` instead. Otherwise, when the main
Edith app is running, it posts `requestDownloadCancel`, which the app's
downloader observes: it terminates the yt-dlp it has running and stops taking
new work. `ed` then removes the unfinished records and posts
`downloadQueueChanged`, so the app re-reads the emptied file and finds nothing
left to start. With the main app closed there is no downloader to ask and
nothing of Edith's is running, so `ed` empties the queue and says so on stderr:
`Edith was not running, so the queue was emptied without stopping yt-dlp`. That
note is on the human path only, and the exit code is 0 either way. The Download
sheet's Cancel All button runs the same cancel in the app but keeps the entries
as `interrupted`, which is why the sheet can retry them and
`ed download cancel`, which removes the records, leaves nothing to retry.

## Exit codes

| Code | When this group produces it |
| --- | --- |
| 0 | The listing printed, or the queue was changed. Also an empty queue for `ls`, `clear` and `cancel`, `retry --all` with nothing to retry, `tool --json` with yt-dlp missing, and `--help` on the group or any verb. |
| 1 | `add` found no YouTube URL in its arguments, `retry` was given neither a number nor `--all`, `retry <n>` named an entry that is not `failed` or `interrupted`, or the queue file could not be written. |
| 2 | `ls --limit` was negative (`--limit cannot be negative`), or the command line was wrong in ArgumentParser's own terms: an unknown flag, `add` with no URL, `rm` with no number, or a number that is not an integer. |
| 3 | `add --kind` named something other than `audio` or `video`, or `rm <n>` and `retry <n>` named a position outside the queue (`there is no download 9`, with the queue size as the hint). |
| 4 | `rm` or `retry <n>` was run against an empty queue (`the download queue is empty`), or `tool` could not find yt-dlp: an error on the human path, and under `--json` too when `--update` was passed. |

Nothing here exits 4 for the usual reason. No verb in this group asks Edith to
answer a question, so none of them fails because the app is closed.

## Notes and gotchas

- The queue lives at `downloads.json` in Edith's data directory,
  `~/Library/Application Support/Edith/data` normally, or
  `<repoPath>/apps/dashboard/data` when the `repoPath` setting points at a
  checkout. Both `ed` and the app read and write that one file, and every
  mutation here rewrites it whole and atomically.
- Order is by queued time, newest first, applied on every read. `ed` does no
  sorting of its own beyond that, so the numbering is stable between two reads
  only if nothing was added or removed in between. URLs queued by one `add`
  share a single timestamp, so their order relative to each other is not
  defined.
- Every mutating verb posts `com.pulkit.edith.downloadQueueChanged`, which is
  a fire-and-forget distributed notification. A running Edith reloads the queue
  from disk when it hears it and starts on the next queued item if it is idle,
  so `ed download add` on an open Edith begins downloading within moments. If
  nothing is listening, the file is still correct and the work happens the next
  time the app looks.
- yt-dlp runs inside the main Edith window, not the menu bar helper, and the
  "Edith is not running" note checks for the helper. The two normally start
  together, but the note is a hint rather than a guarantee: the queue drains
  when the app's downloader is alive, which in practice is once the Music page
  or Download sheet has been opened in that session. `cancel` is the one verb
  that looks for the main app instead, because the main app is what holds the
  yt-dlp there is to stop.
- `ed download add --kind` always defaults to `audio`. It does not read
  `musicDownloadKind`, the setting the sheet's Audio/Video picker writes, so
  choosing Video in the UI does not change what `ed` queues. Pass `--kind
  video`, or read the setting yourself with `ed config get musicDownloadKind`.
- `--prefix` is prepended raw to the title with no separator, so pass the
  underscore or dash you want: `--prefix roadtrip_` gives `roadtrip_Title.m4a`,
  `--prefix roadtrip` gives `roadtripTitle.m4a`. It is recorded in the entry's
  output template at queue time, so changing your music folder afterwards does
  not move where that entry will land.
- Audio is extracted to `m4a` and video is merged to `mp4`, with the thumbnail
  embedded either way. Intermediate `webm`, `mkv`, `opus`, `ogg`, `part`,
  `ytdl` and `temp` files next to the finished one are removed when a download
  completes.
- Only YouTube links are accepted, because that is what the parser filters to.
  Any other host is discarded silently, which means `ed download add
  https://vimeo.com/1234` and `ed download add hello` both fail the same way,
  with `none of that looked like a URL`.
- `detail` for a failed entry is the entire yt-dlp log for that attempt, not a
  one-line summary. It can be several kilobytes and contain newlines. The table
  has no column for it, so `--json` is the only way to read it.
- Removing an entry never deletes a downloaded file, and clearing the queue
  never touches your music folder. Use `ed music rm` for the files themselves.
- Nothing in this group has a `--yes` guard. `rm`, `clear`, `clear
  --everything` and `cancel` all act immediately, unlike `ed music rm` or
  `ed cleaner clean`.
- `--help` works on the group and on every verb, prints on stdout and exits 0.
- Completion knows the verbs and the flags: `ed dl <TAB>` offers all seven,
  and `ed download ls --<TAB>` offers `--active`, `--limit` and `--json`. It
  stops there. The number `rm` and `retry` take completes to nothing, and so
  does `--kind`, so `audio` and `video` have to be typed out.

## Where to go next

- [`ed music`](./music.md), the library these downloads land in, and the verbs
  for renaming, moving and playing what arrives.
- [`ed tools`](./tools.md), which is where yt-dlp gets installed in the first
  place.
- [`ed config`](./config.md) for `musicFolderPath` and `musicDownloadKind`.
- [All `ed` commands](./README.md).
