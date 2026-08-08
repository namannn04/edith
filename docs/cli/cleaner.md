# `ed cleaner`

`ed cleaner` is the disk cleaner: it measures the developer caches and build
output sitting in your home directory, and moves what it finds to the Trash.
Reach for it when a laptop is out of space and you would rather delete a
rebuildable cache than a file you care about.

Everything here runs inside the `ed` process. Scanning walks your own home
directory with your own file permissions, cleaning calls `trashItem` directly,
and nothing is asked of the app, so every verb works whether or not Edith is
running and none of them can exit 4.

The two things to know before you type anything: `ed cleaner clean` has no
notion of a selection, so it moves everything the same scan found rather than
the subset the Cleaner card would have ticked, and moving to the Trash does not
free the space until you empty the Trash.

## At a glance

| Command | What it does |
| --- | --- |
| `ed cleaner` | Runs `ed cleaner scan`, which is the default subcommand. |
| `ed cleaner scan` | Measures what could be reclaimed, per category, and prints a total. Reads only. |
| `ed cleaner categories` | Lists the eleven fixed caches the cleaner knows, and what each one holds. `--json` adds the paths. |
| `ed cleaner clean` | Re-scans, then moves every item found to the Trash. Does nothing without `--yes`. |
| `ed cleaner drives` | Lists the mounted volumes, their capacity and whether they are external. |

`ed cleaner ls` is the same command as `ed cleaner categories`.

## What each category removes

A category is an id you pass to `--category`. There are nineteen of them in two
families, and the difference matters: the eleven fixed caches are found by
looking at known paths under your home directory, and the eight project
categories only exist when you sweep a folder with `--root`.

The fixed caches, in the order `ed cleaner categories` prints them. "On by
default" is the Cleaner card's initial checkbox, and `ed cleaner clean` ignores
it.

| Id | What is removed | On by default | What it costs you |
| --- | --- | --- | --- |
| `derivedData` | Everything under `~/Library/Developer/Xcode/DerivedData`: build intermediates, module caches, index stores and build logs, for every project Xcode has ever opened | yes | The next build of each project is a full one, and Xcode reindexes |
| `swiftpm` | `~/Library/Caches/org.swift.swiftpm`, the shared Swift Package Manager cache of package checkouts and manifests | yes | Packages are fetched from the network again on the next resolve |
| `npm` | `~/.npm/_cacache`, npm's content-addressed tarball and index cache | yes | Tarballs are re-downloaded on the next install |
| `yarn` | `~/Library/Caches/Yarn` | yes | Re-downloaded on the next install |
| `bun` | `~/.bun/install/cache` | yes | Re-downloaded on the next install |
| `pip` | `~/Library/Caches/pip`, the wheel and HTTP cache | yes | Wheels are re-downloaded on the next install |
| `homebrew` | `~/Library/Caches/Homebrew`, the downloaded bottles and source tarballs. Installed formulae live elsewhere and are untouched | yes | The next `brew install` or upgrade downloads again |
| `playwright` | `~/Library/Caches/ms-playwright`, the browser binaries Playwright drives | no | The next test run downloads several hundred megabytes of browsers before it can start |
| `puppeteer` | `~/.cache/puppeteer`, the Chromium builds Puppeteer downloads | no | The next run downloads Chromium again |
| `claudeCode` | `~/.claude/debug` and `~/.claude/shell-snapshots` | yes | Nothing you would miss. Transcripts, projects and settings elsewhere under `~/.claude` are not touched |
| `claudeMcp` | `~/Library/Caches/claude-cli-nodejs`, MCP server logs, which grow without bound | yes | Nothing, past logs are gone |

The project categories match a directory by its **name**, anywhere under a
folder you pass to `--root`. There is no check that a project surrounds it, so
a directory you happen to have called `target` or `Pods` is swept along with
the real ones.

| Id | Directory names matched | What is removed | What it costs you |
| --- | --- | --- | --- |
| `nodeModules` | `node_modules` | The whole dependency tree, including anything patched in place | An install restores it, network permitting |
| `pycache` | `__pycache__` | Compiled bytecode caches | Nothing, Python regenerates them |
| `pyvenv` | `.venv` and `venv` | The entire virtual environment: the interpreter symlinks, every installed package, and any scripts you dropped in `bin` | Recreated from your requirements, if you have a lockfile |
| `rustTarget` | `target` | Cargo and Maven build output, which is usually the largest thing in a Rust checkout | A full rebuild |
| `gradle` | `.gradle` | Per-project Gradle caches and daemon state | A slower next build |
| `pods` | `Pods` | The CocoaPods checkout directory. Your `Podfile` and `Podfile.lock` are not touched | `pod install` restores it |
| `nextBuild` | `.next` | The Next.js build directory | A rebuild |
| `turbo` | `.turbo` | The Turborepo local task cache | Cache misses on the next run |

Both families are destructive in the same way and to the same degree: the item
is moved to the Trash whole, and the Trash keeps occupying the disk until you
empty it. Nothing here is deleted in place, so a mistake is recoverable from
Finder until then.

## Commands

### `ed cleaner scan`

Measures what could be reclaimed, and changes nothing. This is the default
subcommand, so `ed cleaner` with nothing after it is `ed cleaner scan`.

Usage:

```
ed cleaner scan [--category <c>] [--root <dir>]... [--json]
```

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--category <c>` | one of the nineteen ids listed above, matched exactly | unset, which means every category | Restricts the report to that one category. |
| `--root <dir>` | a path to an existing directory, repeatable | none | Also sweeps this folder for project junk. Repeat the flag for more than one folder. |
| `--json` | flag | off | Emits one JSON document on stdout. |

There are no positional arguments. Completion offers the eleven fixed category
ids in the first positional slot anyway, because the completion tree hangs them
off the command rather than off `--category`; typing one is an ArgumentParser
error and exits 2.

`--root` expands a leading `~` itself, so a quoted `--root '~/code'` works even
when the shell did not expand it, and a relative path is resolved against the
current directory. The path has to exist and has to be a directory; anything
else exits 3 with `there is no folder at <path>`.

`--json` shape:

```json
{
  "categories": [
    {
      "category": "npm",
      "detail": "Tarball cache, re-downloaded on install.",
      "items": [
        {
          "name": "content-v2",
          "path": "/Users/pulkit/.npm/_cacache/content-v2",
          "sizeBytes": 2258612224
        },
        {
          "name": "index-v5",
          "path": "/Users/pulkit/.npm/_cacache/index-v5",
          "sizeBytes": 14942208
        }
      ],
      "name": "npm cache",
      "sizeBytes": 2273554432
    }
  ],
  "totalBytes": 2273554432
}
```

`category` is the id, `name` and `detail` are the human strings the Cleaner
card shows on the row, and `sizeBytes` on a category is the sum of its items.
`totalBytes` is the sum across categories. An item's `name` is not the same
kind of thing in both families: for a fixed cache it is the last path
component, and for project junk it is the full path with your home directory
abbreviated to `~`. `path` is always absolute and is what would be trashed.

Examples:

```
ed cleaner scan
ed cleaner scan --category derivedData
ed cleaner scan --root ~/code --root ~/work
ed cleaner scan --root ~/code --category nodeModules --json
```

A full scan of the fixed caches plus one swept folder:

```
$ ed cleaner scan --root ~/code
ID           SIZE     ITEMS  NAME
derivedData  41.0 KB  2      Xcode DerivedData
swiftpm      82.5 MB  3      Swift Package cache
npm          2.3 GB   2      npm cache
bun          5.5 GB   2232   Bun cache
pip          41.0 KB  2      pip cache
homebrew     1.1 GB   3      Homebrew cache
playwright   1.7 GB   7      Playwright browsers
claudeMcp    15.9 MB  40     Claude Code MCP logs
rustTarget   1.2 MB   1      Cargo / Maven target
nodeModules  922 KB   1      node_modules
pyvenv       512 KB   1      Python virtualenvs
nextBuild    307 KB   1      Next.js .next
pycache      41.0 KB  1      Python __pycache__

total 10.6 GB
```

The fixed caches come first, in catalogue order, and only the ones that exist
on this Mac appear: `yarn`, `puppeteer` and `claudeCode` are absent above
because those paths are not there. The project categories follow, sorted
largest first.

Naming a project category without a folder to sweep says so rather than
pretending the id is unknown, and exits 1:

```
$ ed cleaner scan --category nodeModules
error: nodeModules only turns up when a folder is swept for project junk
hint: pass --root, for example `ed cleaner scan --root ~/code --category nodeModules`
```

An id that is not one of the nineteen exits 3 and lists all of them:

```
$ ed cleaner scan --category bogus
error: no cleaner category named bogus
hint: categories: derivedData, swiftpm, npm, yarn, bun, pip, homebrew, playwright, puppeteer, claudeCode, claudeMcp, nodeModules, pycache, pyvenv, rustTarget, gradle, pods, nextBuild, turbo
```

Behaviour: `scan` reads the filesystem and changes nothing on it. It needs
neither the main app nor the menu bar helper, and it does not read or write the
Cleaner card's saved selection. A scan that finds nothing writes
`nothing to reclaim` to stderr, leaves stdout empty and exits 0; with `--json`
it prints the usual document on stdout with an empty `categories` array and a
`totalBytes` of 0 instead. Sizes are on-disk allocated size, summed over regular
files only, so directories and symlinks contribute nothing and the number can
differ from what `ls -l` implies.

While it walks it says what it is walking. A single spinner line on stderr
starts as `scanning` and then names each fixed cache as the scan reaches it, by
display name rather than id, so `Xcode DerivedData`, then `Swift Package cache`,
then `npm cache`; the swept folders follow as
`Scanning <folder> for project junk…`, one per `--root`. The line is rewritten
in place, carries the seconds elapsed since the scan began, and is erased before
the table lands, so it leaves nothing in the transcript. It never touches
stdout: the table and the `--json` document are the same either way.

### `ed cleaner categories`

Lists the fixed caches the cleaner knows how to reclaim, one row per id, with
the one-line description of what that cache holds. The home-relative paths each
id covers are in the `--json` output only; the table does not have a column for
them. `ed cleaner ls` is an alias.

Usage:

```
ed cleaner categories [--json]
```

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emits one JSON document on stdout. |

There are no positional arguments and no filters: this prints the whole
catalogue every time.

`--json` shape, an array with one object per category, in catalogue order:

```json
[
  {
    "category": "derivedData",
    "detail": "Build intermediates, rebuilt on next build.",
    "name": "Xcode DerivedData",
    "onByDefault": true,
    "paths": [
      "Library/Developer/Xcode/DerivedData"
    ]
  },
  {
    "category": "playwright",
    "detail": "Re-downloaded on next test run.",
    "name": "Playwright browsers",
    "onByDefault": false,
    "paths": [
      "Library/Caches/ms-playwright"
    ]
  },
  {
    "category": "claudeCode",
    "detail": "Debug logs and shell snapshots. Transcripts are left untouched.",
    "name": "Claude Code logs",
    "onByDefault": true,
    "paths": [
      ".claude/debug",
      ".claude/shell-snapshots"
    ]
  }
]
```

`paths` are relative to your home directory, never absolute, and a category can
name more than one, as `claudeCode` does. They are printed whether or not they
exist here, which is the difference between this command and `scan`.
`onByDefault` is the Cleaner card's initial checkbox for that row and has no
effect on the CLI.

Examples:

```
ed cleaner categories
ed cleaner ls
ed cleaner categories --json
```

```
$ ed cleaner categories
ID           NAME                           WHAT
derivedData  Xcode DerivedData     default  Build intermediates, rebuilt on next build.
swiftpm      Swift Package cache   default  Cached package checkouts, re-fetched on demand.
npm          npm cache             default  Tarball cache, re-downloaded on install.
yarn         Yarn cache            default  Re-downloaded on install.
bun          Bun cache             default  Re-downloaded on install.
pip          pip cache             default  Wheel cache, re-downloaded on install.
homebrew     Homebrew cache        default  Downloaded bottles.
playwright   Playwright browsers            Re-downloaded on next test run.
puppeteer    Puppeteer cache                Re-downloaded on next run.
claudeCode   Claude Code logs      default  Debug logs and shell snapshots. Transcripts are left untouched.
claudeMcp    Claude Code MCP logs  default  MCP server logs that can grow very large.
```

The third column has no header; a row carries `default` there when that
category is ticked in the card to begin with, and is blank otherwise.

Behaviour: this is a constant table compiled into the binary. It touches no
files, cannot fail, and needs nothing running. It never lists the eight project
categories, even though `--category` accepts them and the not-found hint from
`scan` and `clean` names them, so this is not the complete list of ids.

### `ed cleaner clean`

Moves what a scan finds to the Trash. This is the destructive verb.

Usage:

```
ed cleaner clean [--category <c>] [--root <dir>]... [--yes] [--json]
```

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--category <c>` | one of the nineteen ids, matched exactly | unset, which means every category | Restricts the clean to that one category. |
| `--root <dir>` | a path to an existing directory, repeatable | none | Also sweeps this folder for project junk, and trashes what it finds there. |
| `--yes` | flag | off | Actually moves the files. Without it nothing is touched. |
| `--json` | flag | off | Emits one JSON document on stdout. |

There are no positional arguments. `--category` and `--root` mean exactly what
they mean on `scan`, and produce the same errors.

`--json` shape, without `--yes`:

```json
{
  "applied": false,
  "items": 2,
  "reclaimedBytes": 0,
  "wouldReclaimBytes": 2273554432
}
```

and with it:

```json
{
  "applied": true,
  "items": 2,
  "reclaimedBytes": 2273554432,
  "wouldReclaimBytes": 2273554432
}
```

The shape is the same either way, which is what makes it safe to gate on:
`applied` says whether anything moved, `items` is how many paths the scan
matched, `wouldReclaimBytes` is their total size, and `reclaimedBytes` counts
only the ones `trashItem` actually accepted. `reclaimedBytes` smaller than
`wouldReclaimBytes` means some paths could not be trashed. There is no
per-category or per-path breakdown in the result, so read `scan --json` first
if you want to know what is about to go.

Examples:

```
ed cleaner clean
ed cleaner clean --category npm --yes
ed cleaner clean --root ~/code --category nodeModules --yes
ed cleaner clean --json
```

A bare run is a dry run. The count lands on stdout and the nudge on stderr:

```
$ ed cleaner clean --category npm
would move 2 items, 2.3 GB, to the Trash
pass --yes to do it
```

```
$ ed cleaner clean --category npm --yes
moved 2.3 GB to the Trash
```

Behaviour: `clean` runs its own scan first and never reuses the result of an
earlier `ed cleaner scan`, so a `scan` then `clean` pair walks the disk twice
and can legitimately disagree if something changed in between. It then trashes
**every** item that scan produced. There is no selection: the Cleaner card's
ticked rows, its per-item overrides and the `onByDefault` flag are all ignored,
so a bare `ed cleaner clean --yes` takes the Playwright browsers and the
Puppeteer Chromium builds that the card leaves unticked. Narrow it with
`--category` when that is not what you want.

`clean` shows the same spinner line as `scan` on stderr, and under the same
rules, while it does its own walk. With `--yes` a second phase follows it,
`moving <n> items to the Trash`, for as long as `trashItem` is working through
the list; a dry run stops after the scan phase. Both lines erase themselves, so
the counts on stdout are all that survives the run.

A path that cannot be trashed is skipped silently: it is left in place, its
bytes are not counted in `reclaimedBytes`, and the command still exits 0. A run
that trashes nothing at all prints `moved 0 B to the Trash` and also exits 0,
so the exit code tells you the command ran, not that space was freed. Compare
`reclaimedBytes` against `wouldReclaimBytes` for that.

Nothing is deleted in place. Items go to the Trash, which means the disk is not
actually any emptier until you empty it, and it also means an accidental
`ed cleaner clean --yes` is recoverable from Finder.

### `ed cleaner drives`

Lists the mounted volumes, largest internal first.

Usage:

```
ed cleaner drives [--json]
```

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emits one JSON document on stdout. |

There are no positional arguments.

`--json` shape, an array with one object per volume:

```json
[
  {
    "external": false,
    "id": "/",
    "name": "Macintosh HD",
    "totalBytes": 494384795648
  }
]
```

`id` is the mount point, which is also what you would pass to `--root` to sweep
that volume. `name` is the volume name macOS reports, falling back to the last
path component. `totalBytes` is capacity, not free space; `ed system disks` is
where free space lives. `external` is true when the volume is removable or is
not an internal one, so a Thunderbolt SSD and a USB stick both read as
external.

Examples:

```
ed cleaner drives
ed cleaner drives --json
ed cleaner scan --root /Volumes/Backup
```

```
$ ed cleaner drives
NAME          MOUNT  SIZE    KIND
Macintosh HD  /      494 GB  internal
```

Behaviour: this enumerates mounted volumes and hides the hidden ones. It writes
nothing and needs nothing running. Ordering is internal volumes before external
ones, and within each group largest capacity first. Nothing else in the CLI
consumes this list: the app's drive picker stores a chosen set in
`cleanerSelectedDrives`, but `ed cleaner scan` and `ed cleaner clean` never read
that setting, so `drives` is here to tell you which mount point to hand to
`--root`.

## Exit codes

| Code | When this group produces it |
| --- | --- |
| 0 | The scan, listing or clean finished. Also an empty scan, a dry run without `--yes`, a clean that trashed nothing, and `--help` or `--version` on any of these commands. |
| 1 | `--category` named one of the eight project categories and no `--root` was given, so the category cannot turn up at all. |
| 2 | The command line was wrong in ArgumentParser's own terms: an unknown flag, `--category` or `--root` with no value, or a positional argument, none of these commands take one. |
| 3 | `--category` named an id that is not one of the nineteen, or `--root` named a path that does not exist or is not a directory. |

Nothing in this group exits 4. There is no app request, no SSH and no
permission to be missing, so there is nothing that can be unavailable.

## Notes and gotchas

- Moving to the Trash is not freeing space. `moved 5.5 GB to the Trash` means
  5.5 GB is still on the disk under `~/.Trash`, so empty the Trash afterwards
  if the point of the exercise was capacity.
- `ed cleaner clean` trashes everything the scan found. The Cleaner card's
  checkboxes live in `cleanerSelectionOverrides` and `cleanerCategoryDefaults`,
  and `ed` reads neither, so the CLI is always the equivalent of ticking Select
  all. `ed config ls --group cleaner` shows those four keys, and setting them
  changes the card rather than the CLI.
- The card's drive picker is the same story. It sweeps whatever
  `cleanerSelectedDrives` and `cleanerCustomFolders` hold, defaulting to your
  home folder; `ed` sweeps nothing at all unless you pass `--root`. Two
  surfaces, one catalogue, different scopes.
- Passing `--root` also changes how a bad `--category` is treated. Without a
  root, an unknown id exits 3 and a project id exits 1. With a root, both
  errors are swallowed: the fixed-cache lookup is skipped and the swept results
  are filtered by that id, so `ed cleaner scan --root ~/code --category bogus`
  prints `nothing to reclaim` and exits 0. Check the spelling with
  `ed cleaner categories` and the list in the exit-3 hint before you rely on a
  filtered clean.
- `--category` is matched exactly and case-sensitively against the id, so
  `--category NPM` and `--category node_modules` both exit 3. The id, not the
  display name, is what the flag takes.
- Repeating the same folder repeats its results. `--root ~/code --root ~/code`
  reports every match twice and doubles the total, because the sweep walks each
  root independently and does not deduplicate paths. Cleaning that is harmless,
  the second attempt on an already trashed path simply fails and is skipped,
  but the byte count you were shown was wrong.
- The project sweep has hard limits, and there is no warning when they bite. It
  stops after 600 matched directories in total, across all roots, and it never
  looks more than ten levels below a root. A very large or very deep tree can
  therefore report less than is really there.
- The sweep never follows symlinks, never descends into a directory whose name
  begins with a dot, and never descends into anything named `System`,
  `Library`, `Applications`, `usr`, `bin`, `sbin`, `opt`, `private`, `cores`,
  `dev`, `Volumes`, `Network` or `Photos Library.photoslibrary`. Dot-named
  targets are still matched: `.venv`, `.next`, `.gradle` and `.turbo` are found
  because the name is checked against the target list before the dot rule is
  applied. What the dot rule prevents is descending into unrelated dot
  directories.
- A matched directory is never descended into, so nested junk is counted once.
  A `node_modules` inside a `node_modules` is part of the outer one's size and
  is not reported separately.
- For the fixed caches, `ed` trashes the **children** of the cache directory,
  not the directory itself, so `~/.npm/_cacache` survives as an empty folder.
  The exception is a cache directory whose visible listing is empty: then the
  directory itself becomes the single item and is trashed whole. Hidden entries
  are not listed as items, but they are counted in a parent's size and they go
  with the parent when the parent is what gets trashed.
- Zero-sized items are dropped, and a category with no items left is dropped
  entirely. That is why `ed cleaner categories` lists eleven rows and a scan
  usually prints fewer.
- Sizes in the tables use powers of 1000, so `2.3 GB` is 2,273,554,432 bytes.
  `sizeBytes`, `totalBytes`, `wouldReclaimBytes` and `reclaimedBytes` in the
  JSON are exact byte counts, and every one of them is allocated size on disk
  rather than logical file length.
- A scan is not cheap and is not cached. Every invocation walks the caches
  again, and `clean` walks them a second time before it touches anything, so
  the two-step `scan` then `clean --yes` costs two full walks. The spinner line
  is where you see which cache the seconds are going into; on a machine with a
  large Bun or npm cache it will sit on that one row for most of the run.
- The spinner line is for a person watching and nothing else. It goes to
  stderr, and it is skipped entirely when stderr is not a terminal, when
  `--json` is passed, or when `NO_COLOR` is set or `TERM` is `dumb`. A run whose
  stderr is a pipe or a file therefore produces the table and not a single
  progress byte; redirecting stdout alone does not turn it off, because it is
  stderr that is checked.
- Completion knows less than the commands do. `ed cleaner clean --<TAB>` never
  offers `--root`, and `ed cleaner clean --category <TAB>` offers nothing at
  all. The eleven fixed ids hang off `scan`'s first positional slot, and because
  the engine drops flag words before it counts positionals they surface for
  `ed cleaner scan --category <TAB>` too, which is the one place they are worth
  having. The eight project ids are never offered anywhere. All of that is the
  completion tree being a hand-maintained mirror. The flags themselves work
  exactly as documented above.
- `--help` works on the group and on all four verbs, prints on stdout and exits
  0. `ed cleaner` on its own does not print help: it runs a full scan, because
  `scan` is the default subcommand.

## Where to go next

- [`ed system`](./system.md), whose `disks` verb reports free space on each
  volume, which is the number `cleaner drives` deliberately does not give you.
- [`ed config`](./config.md), for the four `cleaner` group settings that drive
  the Cleaner card's selection and drive picker.
- [Conventions and contracts](./conventions.md), for the exit code and `--json`
  rules this page leans on.
- [All `ed` commands](./README.md).
