# `ed apps`

`ed apps` is the System page's Running apps card on stdout: what is running on
this Mac right now, and a way to quit any of it, one app at a time or
everything at once. Reach for it when you want the list without opening a
window, or when a script needs a quiet desktop before something noisy runs.

The two verbs sit on opposite sides of a line. Listing reads the process table
directly and needs nothing. Quitting cannot be done by `ed` at all: sending a
quit event is Automation, and that grant belongs to the Edith bundle rather
than to a command line process, so `ed` asks the menu bar app to send it and
exits 4 when Edith is closed.

## At a glance

| Command | What it does |
| --- | --- |
| `ed apps ls` | Lists every app with a Dock presence, with its pid and bundle id. Runs when you type `ed apps` with no subcommand, and answers to `ed apps list`. |
| `ed apps quit` | Asks Edith to quit one app by name, bundle id or prefix, or everything except Finder and Edith with `--all`. |

## Commands

### `ed apps ls`

Prints the applications running on this Mac. It is the default subcommand, so
`ed apps` on its own runs it, and `list` is an accepted alias.

```
ed apps ls [--json]
```

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout instead of the table. Long form only, there is no `-j`. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |
| `--version` | flag | off | Print the CLI version on stdout and exit 0. Inherited from the root command, so it works here too. |

There is nothing else. `ls` has no search, no limit and no sort option: it
prints every app it can see, in one order, every time.

The table is three columns, and the rows are sorted by name with a
case-insensitive, locale-aware comparison:

```
$ ed apps ls
NAME        PID    BUNDLE
Dia         40466  company.thebrowser.dia
Edith       57385  com.pulkit.edith
Finder      612    com.apple.finder
Notion      60983  notion.id
Spotify     18719  com.spotify.client
WhatsApp    9226   net.whatsapp.WhatsApp
Wispr Flow  77028  com.electron.wispr-flow
Zed         49161  dev.zed.Zed
```

The list is `NSWorkspace`'s running applications filtered to the ones whose
activation policy is regular, which means the ones macOS gives a Dock icon and
a menu bar to. Background daemons, launch agents and menu bar only apps are not
in it, and neither is Edith's own menu bar helper, so the `Edith` row above is
the main window process and never the helper that actually does the quitting.
An app whose windows are all closed but which is still in the Dock is listed,
despite the command's own one-line summary calling these the apps with a window
open.

#### `--json` shape

A top-level array, in the same order as the table, of one object per app. This
is a real document trimmed to three of the eight entries:

```json
[
  {
    "active": true,
    "bundleID": "company.thebrowser.dia",
    "name": "Dia",
    "pid": 40466
  },
  {
    "active": false,
    "bundleID": "com.apple.finder",
    "name": "Finder",
    "pid": 612
  },
  {
    "active": false,
    "bundleID": "dev.zed.Zed",
    "name": "Zed",
    "pid": 49161
  }
]
```

What the fields mean:

- `name` is the app's localized name, the same string the Dock and the Finder
  show. An app that reports no name gets `""` rather than `null`, so the key is
  always a string.
- `bundleID` is the bundle identifier, and it is `null` rather than missing when
  the process has none. It is the only nullable field here.
- `pid` is the process id as an integer, which is what the helper is handed when
  you quit a single app.
- `active` is true for the frontmost app and false for every other, so exactly
  one entry is true while any app is focused and none is while focus sits with
  something the list does not cover.
- The `BUNDLE` column of the table is `bundleID`, printed as an empty cell where
  the JSON says `null`. The table has no column for `active`.

Object keys are sorted, so `active`, `bundleID`, `name` and `pid` always come in
that order. The array itself keeps the name order, not a sorted-key order.

#### Examples

```
ed apps ls
ed apps ls --json
ed apps ls --json | jq -r '.[] | select(.active) | .name'
ed apps ls --json | jq -r '.[] | "\(.pid) \(.name)"'
```

#### Behaviour notes

Nothing is mutated and nothing is written. Neither the Edith app nor the menu
bar helper has to be running, no macOS permission is involved, and no
subprocess is launched, so this never exits 4 and never blocks.

Every cell is flattened before it is printed: newlines, carriage returns and
tabs become spaces, and other control characters are dropped, so a hostile app
name cannot break the table across lines. Column widths are counted in
characters, which means a name carrying an invisible mark such as a
left-to-right override still occupies a column of width the eye does not see,
and its row can look a character out of line.

`ed apps ls` and the app's Running apps card read the same process list but
present it differently. The card measures CPU and memory per process and sorts
by CPU descending by default; `ed` measures neither and always sorts by name.
For per-process CPU on this Mac use `ed system stats --processes <n>`, which
covers every process rather than only the ones with a Dock icon.

### `ed apps quit`

Asks Edith to quit an app. Names one app, or passes `--all` to quit everything
except Finder and Edith.

```
ed apps quit <app> [--force] [--json]
ed apps quit --all [--yes] [--force] [--json]
```

#### Arguments

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<app>` | string, optional | none | App name, bundle id, or an unambiguous prefix of a name. Required unless `--all` is given, and refused when it is. |

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--all` | flag | off | Quit everything except Finder, Edith and Edith's menu bar helper. Cannot be combined with an app name. |
| `--force` | flag | off | Use `forceTerminate` instead of `terminate`, which kills the app outright rather than letting it save first. Applies to both forms. |
| `--yes` | flag | off | Actually quit. Required with `--all`; without it the command counts the targets and touches nothing. Accepted and ignored for a single app. |
| `--json` | flag | off | Emit JSON on stdout instead of the human line. |
| `--help`, `-h` | flag | off | Print the help for this command on stdout and exit 0. |
| `--version` | flag | off | Print the CLI version on stdout and exit 0. |

The checks run in a fixed order, and the order is worth knowing because it
decides which failure you see first.

Naming nothing at all is a failure rather than a no-op, and so is naming both:

```
$ ed apps quit
error: say which app to quit
hint: pass a name, or --all

$ ed apps quit --all Safari
error: --all quits everything, so it takes no app name
```

Both of those exit 1, not 2. They are checked inside the command rather than by
the argument parser, which only sees a valid command line in each case: an
optional positional that is absent, and an optional positional that is present.

Next comes the app check, before anything is resolved or counted. With Edith
closed every form of this command exits 4 with the same message, including the
`--all` dry run that would not have quit anything:

```
error: quitting apps needs the Edith menu bar app to be running
hint: start Edith, then retry
```

Only then is the app name resolved, or the `--all` list counted.

Resolution tries three things in order and stops at the first that works: an
exact match on the localized name, an exact match on the bundle id, then a
unique prefix of a name. All three are case-insensitive, and only the last is a
prefix match, so a partial bundle id matches nothing. A prefix that matches
several apps fails with the list rather than guessing, and a name that matches
none says how to find the right one:

```
$ ed apps quit nosuchapp
error: no running app called nosuchapp
hint: run `ed apps ls` to see them
```

Both of those exit 3. Only apps `ed apps ls` shows are candidates, so a menu bar
only app cannot be named here at all.

`--all` counts its targets and, without `--yes`, reports the count and stops:

```
$ ed apps quit --all
would quit 6 app(s)
nothing was quit; pass --yes to go ahead
```

The count is the listed apps minus Finder, minus Edith, minus Edith's menu bar
helper, which is not in the list to begin with. The first line is stdout and
the second is stderr, so `ed apps quit --all | wc -l` sees one line. With
`--yes` the request goes out, and the wording changes to the past tense of
asking rather than of quitting:

```
$ ed apps quit --all --yes
asked Edith to quit 6 app(s)
```

A single app reads the same way:

```
$ ed apps quit Spotify
asked Edith to quit Spotify
```

#### `--json` shape

Three shapes, one per form. `--all` without `--yes` reports what it counted and
that it did nothing:

```json
{
  "apps": 6,
  "quit": false
}
```

`--all --yes` is the same object with `quit` flipped:

```json
{
  "apps": 6,
  "quit": true
}
```

Quitting one app emits that app's row, the same four keys `ed apps ls` uses,
describing the app as it was at the moment the request was sent:

```json
{
  "active": false,
  "bundleID": "com.spotify.client",
  "name": "Spotify",
  "pid": 18719
}
```

`apps` is the count of targets, not of apps that quit, and `quit` says whether
the request was sent rather than whether anything closed. Neither form waits for
an answer, so neither can tell you more than that. With `--json` the stderr note
about `--yes` is not printed: the document is the whole output.

#### Examples

```
ed apps quit Spotify
ed apps quit com.spotify.client --force
ed apps quit --all
ed apps quit --all --yes --json
```

#### Behaviour notes

This mutates nothing that `ed` owns. It writes no file and changes no setting.
What it does is post one `com.pulkit.edith.requestQuitApps` distributed
notification carrying either `all` and `force`, or `pid` and `force`, and then
return. The menu bar helper observes that name and calls `terminate()` or
`forceTerminate()` on the matching applications.

It is fire and forget. `ed` does not wait for a reply, does not learn whether
the app closed, and exits 0 as soon as the notification is posted. An app with
unsaved changes puts up a save dialog and stays open; `ed` has already exited 0
by then. If you need to know, list again and look:

```
ed apps quit Spotify
sleep 2
ed apps ls --json | jq -r '.[].name'
```

The helper refuses to quit `com.apple.finder`, `com.pulkit.edith` and
`com.pulkit.edith.statusbar` whatever it is asked, and it recomputes the `--all`
list itself at the moment it acts rather than trusting the count `ed` sent. That
guard is the last word, not the first: `ed apps quit Finder` resolves cleanly,
posts the request, prints `asked Edith to quit Finder` and exits 0, and then
nothing happens. The same is true of `ed apps quit Edith`. Success here means
the request was sent, and a protected app is the one case where a sent request
is guaranteed to be dropped.

`--force` maps to `forceTerminate`, which is the hard kill: no save prompt, no
chance to flush anything to disk. `--yes` is only consulted on the `--all` path,
so `ed apps quit Spotify --yes` is accepted and the flag does nothing.

## Exit codes

| Code | When |
| --- | --- |
| 0 | The list was printed, the count was reported, or the quit request was posted. `--help` and `--version` also exit 0. |
| 1 | `ed apps quit` was given neither an app name nor `--all`, or was given both. |
| 2 | The command line was wrong in the ordinary way: an unknown flag, a second positional argument, or a value the parser could not read. |
| 3 | The named app is not running, or the name is a prefix that matches more than one running app. |
| 4 | `ed apps quit` was run while the Edith menu bar app was not running. Every form is affected, including the `--all` dry run. |

`ed apps ls` only ever exits 0 or 2. Code 1 is otherwise the catch-all for an
unexpected error escaping either command, and nothing on the listing path throws
one.

## Notes and gotchas

- `ed apps` with no subcommand is `ed apps ls`, and `ed apps list` is the same
  command again. Completion offers `ls` and `quit`; the `list` alias works but
  is not among the candidates.
- `ed app` and `ed apps` are different groups. The singular one acts on Edith
  itself, open, quit, relaunch and update checks; the plural one acts on
  everything else running on the Mac. There is no prefix matching between
  subcommand names, so the two never collide, but the names are one letter
  apart and easy to mistype.
- Nothing completes an app name. `ed apps quit <TAB>` offers nothing at all,
  because the completion tree declares that argument free-form and the engine
  only proposes flags once the word you are on already starts with a `-`, so
  `ed apps quit -<TAB>` is the one that lists `--all`, `--force`, `--yes`,
  `--json` and `--help`. `ed apps ls` is the discovery step.
- The two argument errors on `quit` exit 1 rather than 2 even though they read
  like usage errors. Gate on 1 as well as 2 if you are distinguishing a bad
  command line from a real failure.
- Order of checks beats specificity of message. With Edith closed,
  `ed apps quit nosuchapp` exits 4 rather than 3, because the app check runs
  before the name is resolved. Start Edith before trusting a 3 or a 4 from this
  command to mean what it says.
- The `--all` preview is not free of the app requirement either. It counts
  nothing and posts nothing, but it still exits 4 when Edith is closed.
- The count `--all` prints is computed by `ed` and the quitting is done by the
  helper a moment later against its own fresh list. An app launched or closed in
  between changes what happens without changing what was printed.
- An empty app name matches every app rather than none, because the empty string
  is a prefix of everything: `ed apps quit ""` exits 3 and lists all of them. It
  is a harmless way to see the resolver's ambiguity message.
- Exact name beats exact bundle id beats unique prefix, and the prefix rule
  applies to names only. `ed apps quit com.spotify` matches nothing even though
  `ed apps quit com.spotify.client` works.
- Object keys are sorted in every document this group emits, so two runs diff
  cleanly. Array order is insertion order, which for `ls` is the name order the
  table shows.
- Both commands see only apps with a Dock presence. Menu bar agents, helpers and
  daemons are invisible to `ls` and unreachable by `quit`, which is also why
  `ed apps quit --all` never touches the menu bar helper it is talking to.
- The UI path and the CLI path funnel through the same `RunningApps` helper, so
  the System page's per-row quit button, its `Quit all apps` header button and
  these commands cannot disagree about what is protected or about what `--force`
  means. The difference is which process runs it: the UI quits from the main
  window's process, `ed` quits from the menu bar helper's.
- The UI asks before it acts, with a confirmation dialog naming the app or the
  count. `--yes` is the command line's version of that dialog, and it exists
  only for `--all`. A single named app quits without any confirmation.

## Where to go next

- [`ed app`](./app.md) for acting on Edith itself rather than on other apps,
  including quitting and relaunching it.
- [`ed system`](./system.md) for CPU and memory per process on this Mac,
  covering everything running and not only the apps with a Dock icon.
- [`ed machines power`](./machines-power.md) for the same idea on another
  machine, where `ed machines kill` signals a remote process.
- [Conventions and contracts](./conventions.md) for the exit code table, the
  `--json` guarantee and the full list of what needs the app running.
- [The `ed` command line](./README.md) for the rest of the reference.
