# `ed machines workspace`

`ed machines workspace` reads and writes the saved multi-pane layouts the app's
Workspace view shows. Reach for it when you want an arrangement of machines and
screens ready before the window opens, when a script should retarget a pane at
whichever machine it just built, or when you want to know what the window is
about to show without opening it.

## The model

A **workspace** is a named layout: an id, a tree of panes, the id of the focused
pane, and optionally the id of a maximized one. Several workspaces can be saved
at once and exactly one of them is current, which is the one the view opens on
and the one every pane verb here acts on unless `--workspace` names another.

A **pane** is one rectangle in that tree. It holds one or more tabs and
remembers which of them is selected. A **tab** is a target: one machine and one
screen. `ed` builds panes with exactly one tab, and it only ever reads or writes
the selected one; a pane with several tabs came from the app's tab strip, and
`ed` reports all of them but adds and removes none.

Panes are held together by **splits**. A split has an axis, horizontal or
vertical, an ordered list of children, and a ratio for each child. `ed` never
sets a ratio by hand: `split` gives the new pane an equal share and rescales its
siblings, and `equalize` levels every split in the tree.

A **screen** is what a pane draws. There are six, and every one of them is
accepted anywhere a `--screen` goes:

| Screen | What the pane shows |
| --- | --- |
| `overview` | The machine's overview: CPU, memory, disks, uptime. |
| `processes` | The process list. |
| `docker` | The Docker console: containers, images, volumes. |
| `terminal` | A terminal on the machine. |
| `files` | The Finder pane for that machine. |
| `tools` | The Tools tab: port forwards, snippets, services and power. |

Panes are numbered from 1 in the order the tree flattens: depth first, children
in order, so left to right inside a horizontal split and top to bottom inside a
vertical one. The number is a position rather than an id: every split inserts a
pane into that order and pushes the rest along, every close takes one out, and
splitting to the left of or above pane 1 makes the new pane pane 1.

```
Compare, before                     Compare, after `split 1 tuf --side bottom`
1  Asus TUF 7   overview            1  Asus TUF 7   overview
2  mini         docker              2  Asus TUF 7   overview
                                    3  mini         docker
```

The whole set lives in one file,
`~/Library/Application Support/Edith/machines/workspaces.json`, holding the list
of layouts and the id of the current one. Nothing in this group talks to Edith
for its data, so every verb works whether or not the app is running. Each write
does post the app's `machinesChanged` notification afterwards, and a running
Edith does not use it to reload workspaces, which is the one thing worth reading
[Notes and gotchas](#notes-and-gotchas) for before you script against a machine
that has Edith open.

## At a glance

| Command | What it does |
| --- | --- |
| `ed machines workspace` | Runs `ed machines workspace ls`, which is the default subcommand. |
| `ed machines workspace ls` | Lists the saved workspaces, their pane and machine counts, and which is current. |
| `ed machines workspace use <workspace>` | Makes one workspace the current one. |
| `ed machines workspace new <machines>...` | Builds a workspace with one pane per machine, tiled side by side. |
| `ed machines workspace rename <workspace> <name>` | Renames a workspace, leaving which one is current alone. |
| `ed machines workspace rm <workspace>` | Forgets a workspace. |
| `ed machines workspace panes` | Lists the panes in a workspace, what each shows, and which is focused. |
| `ed machines workspace split <pane> <machine>` | Splits a pane and points the new one at a machine and a screen. |
| `ed machines workspace close <pane>` | Closes a pane. |
| `ed machines workspace point <pane> [<machine>]` | Retargets a pane's selected tab without splitting anything. |
| `ed machines workspace equalize` | Evens out every split in the workspace. |

`ed machines workspaces` is the same group under a second name, and the verbs
carry aliases too: `list` for `ls`, `remove` for `rm`, and `even` for
`equalize`. `ed machines workspace` with nothing after it runs `ls`, including
its flags, so `ed machines workspace --json` is
`ed machines workspace ls --json`.

Five verbs take `--workspace` to act on a layout other than the current one:
`panes`, `split`, `close`, `point` and `equalize`. The three that operate on a
whole workspace, `use`, `rename` and `rm`, take it as a positional argument
instead, and `new` takes none because it is making one.

## Commands

### `ed machines workspace ls`

Lists every saved workspace.

Usage:

```
ed machines workspace ls [--json]
```

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emits one JSON document on stdout. |

There are no positional arguments and no filters: `ls` always prints the whole
file, in the order the layouts are stored rather than sorted.

`--json` shape, an array with one object per workspace:

```json
[
  {
    "current": true,
    "id": "A494FD58-CB43-4068-8325-655E86794590",
    "machines": 2,
    "name": "Compare",
    "panes": 2
  },
  {
    "current": false,
    "id": "6C1D0E22-5A77-4B3E-9C48-2F0A7D5B4E31",
    "machines": 1,
    "name": "Asus TUF 7 x3",
    "panes": 3
  }
]
```

`id` is the layout's UUID, which `use`, `rename`, `rm` and `--workspace` all
accept in place of the name. `panes` counts the rectangles; `machines` counts
the distinct machines across every tab of every pane, so a workspace with three
panes on one machine reports `"panes": 3, "machines": 1`. `current` is true for
exactly one row while any workspace exists.

Examples:

```
ed machines workspace ls
ed machines workspace --json
ed machines workspace ls --json | jq -r '.[] | select(.current).name'
```

The table is the same four columns with the last one unlabelled, holding
`current` on one row and nothing on the others:

```
$ ed machines workspace ls
NAME     PANES  MACHINES
Compare  2      2         current
```

Behaviour: `ls` reads the file, writes nothing, posts nothing, and needs neither
the main app nor the menu bar helper. An empty or missing file is not an error:
without `--json` it writes `no workspaces are saved` to stderr, leaves stdout
empty and exits 0, and with `--json` it prints `[]` and exits 0. `ls` and `new`
are the only verbs in this group that do not need a saved workspace already, so
use `ls` when you are probing rather than acting. An unreadable or undecodable
file decodes to an empty store, which is indistinguishable from never having
saved one.

### `ed machines workspace use`

Makes one workspace the current one.

Usage:

```
ed machines workspace use <workspace> [--json]
```

Arguments:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<workspace>` | name, id, or unambiguous name prefix | required | Which workspace to switch to. Case-insensitive. |

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emits one JSON document on stdout. |

`--json` shape, the same object `ls` emits for one row, with `current` always
true because it just became so:

```json
{
  "current": true,
  "id": "A494FD58-CB43-4068-8325-655E86794590",
  "machines": 2,
  "name": "Compare",
  "panes": 2
}
```

Examples:

```
ed machines workspace use Compare
ed machines workspace use comp
ed machines workspace use A494FD58-CB43-4068-8325-655E86794590
ed machines workspace use Compare --json
```

```
$ ed machines workspace use Compare
now showing Compare
```

Behaviour: `use` writes the current pointer and nothing else; the layout itself
is untouched. Names resolve in a fixed order: an exact case-insensitive name
first, then the id, then a unique case-insensitive name prefix. A prefix that
matches more than one workspace exits 3 and lists the matches rather than
guessing, and a name that matches none exits 3 with every known name as the
hint:

```
$ ed machines workspace use nope
error: no workspace called nope
hint: known: Compare
```

Running `use` when no workspaces are saved exits 4, because there is nothing to
switch to rather than something you named wrongly.

### `ed machines workspace new`

Builds a workspace with one pane per machine.

Usage:

```
ed machines workspace new <machines>... [--screen <screen>] [--name <name>] [--json]
```

Arguments:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<machines>...` | one or more machine names, ssh aliases, ids or unambiguous prefixes | at least one required | Gives each named machine a pane, in the order you list them. |

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--screen` | `overview`, `processes`, `docker`, `terminal`, `files`, `tools` | `overview` | What every pane shows. One value for the whole workspace; retarget individual panes afterwards with `point`. |
| `--name` | text | the machine names joined with ` + ` | What to call the workspace. |
| `--json` | flag | off | Emits one JSON document on stdout. |

The `--screen` help text in `ed machines workspace new --help` lists five
screens and omits `tools`; the value is accepted all the same, and the error
you get from a bad one lists all six.

`--json` shape, the new workspace, always current:

```json
{
  "current": true,
  "id": "1F2C77B0-9A34-4C51-B0E7-6D9E42A31C08",
  "machines": 2,
  "name": "Asus TUF 7 + mini",
  "panes": 2
}
```

Examples:

```
ed machines workspace new tuf
ed machines workspace new tuf mini --screen terminal
ed machines workspace new tuf mini --name "Deploy" --screen docker
ed machines workspace new tuf tuf tuf --screen files --json
```

```
$ ed machines workspace new tuf mini --screen terminal
made Asus TUF 7 + mini with 2 pane(s)
```

Behaviour: `new` is the Workspace toolbar's Layout menu as a command. One
machine gives a single pane with no split at all; several give one horizontal
split with equal ratios, tiled left to right in the order you named them. Every
machine is resolved before anything is written, so an unknown or ambiguous name
exits 3 and no workspace is created.

The new workspace is appended to the file and becomes current, so `new` always
switches you. Names are not checked for uniqueness: making two workspaces called
`Deploy` leaves both in the file, and every later lookup by that name finds the
first one, which makes the second reachable only by its id. Pass `--name` if you
are scripting this.

Repeating a machine is allowed and gives it a pane each time, which is how you
get four panes on one machine, every one of them on the single `--screen` you
named until `point` sends them elsewhere. The `machines` count in the JSON
counts distinct machines, so that workspace reports four panes and one machine.

An empty machine list is caught by the parser and exits 2 with
`Missing expected argument '<machines> ...'`; the command's own guard behind it,
`name at least one machine`, exits 1 and is only reachable if the parser ever
lets an empty list through.

### `ed machines workspace rename`

Renames a workspace.

Usage:

```
ed machines workspace rename <workspace> <name> [--json]
```

Arguments:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<workspace>` | name, id, or unambiguous name prefix | required | Which workspace to rename. Case-insensitive. |
| `<name>` | text | required | The new name. Leading and trailing whitespace is trimmed. |

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emits one JSON document on stdout. |

`--json` shape, the renamed workspace:

```json
{
  "current": true,
  "id": "A494FD58-CB43-4068-8325-655E86794590",
  "machines": 2,
  "name": "Fleet",
  "panes": 2
}
```

Examples:

```
ed machines workspace rename Compare Fleet
ed machines workspace rename comp "Two machines"
ed machines workspace rename A494FD58-CB43-4068-8325-655E86794590 Fleet --json
```

```
$ ed machines workspace rename Compare Fleet
renamed Compare to Fleet
```

Behaviour: `rename` changes the name and nothing else. It captures which
workspace is current before it writes and puts it back afterwards, so renaming a
workspace you are not using does not switch you to it, unlike `new`.

A name that is empty or only whitespace is refused and exits 1 with
`a workspace needs a name`. The old name is not freed for anything: the file
allows duplicates, so renaming one workspace onto another's name is accepted and
leaves you with two rows that resolve to the first.

The `current` field in the JSON is read from the stored pointer rather than the
effective one. When no workspace has ever been made current, `ls` shows the
first row as current and `rename` reports `"current": false` for that same row.
Run `use` once if you want the two to agree.

### `ed machines workspace rm`

Forgets a workspace.

Usage:

```
ed machines workspace rm <workspace> [--json]
```

Arguments:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<workspace>` | name, id, or unambiguous name prefix | required | Which workspace to delete. Case-insensitive. |

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emits one JSON document on stdout. |

There is no `--yes` guard here, unlike `ed machines rm`: this takes effect the
moment you run it.

`--json` shape, its own shape rather than the one the other whole-workspace
verbs share:

```json
{
  "remaining": 1,
  "removed": "Compare"
}
```

`removed` is the name of what went, and `remaining` is how many workspaces are
left in the file.

Examples:

```
ed machines workspace rm Compare
ed machines workspace rm comp --json
```

```
$ ed machines workspace rm Compare
removed Compare
```

Behaviour: `rm` deletes the layout outright. Nothing is moved to a trash and
there is no undo, so a workspace you built pane by pane is worth recreating with
a `new` plus a few `split`s rather than fetching back.

Removing the current workspace moves the pointer to whatever is now first in the
file; removing any other leaves the pointer alone. Removing the last one leaves
an empty store, at which point every verb except `ls` and `new` exits 4 until
you make one again.

### `ed machines workspace panes`

Lists the panes in a workspace and what each one shows.

Usage:

```
ed machines workspace panes [--workspace <workspace>] [--json]
```

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--workspace` | name, id, or unambiguous name prefix | the current workspace | Which workspace to describe. |
| `--json` | flag | off | Emits one JSON document on stdout. |

There are no positional arguments.

`--json` shape, shared by `panes`, `split`, `close`, `point` and `equalize`, all
five of which print the workspace as it stands after they are done:

```json
{
  "panes": [
    {
      "focused": false,
      "index": 1,
      "tabs": [
        {
          "machine": "Asus TUF 7",
          "screen": "overview",
          "selected": true
        }
      ]
    },
    {
      "focused": true,
      "index": 2,
      "tabs": [
        {
          "machine": "mini",
          "screen": "docker",
          "selected": true
        },
        {
          "machine": "mini",
          "screen": "terminal",
          "selected": false
        }
      ]
    }
  ],
  "workspace": "Compare"
}
```

`index` is the number every pane verb takes. `focused` marks the one pane the
window would have focused, and `selected` marks the one tab in each pane that is
showing. `machine` is the machine's display name looked up from the machine
list, not its id; a pane pointed at a machine that is no longer in the list
reads `"machine": "removed machine"` rather than disappearing.

Examples:

```
ed machines workspace panes
ed machines workspace panes --workspace Compare
ed machines workspace panes --json
ed machines workspace panes --json | jq -r '.panes[] | select(.focused).index'
```

The table is four columns: the pane number, an unlabelled focus column, the
machine, and the screen. It prints one row per pane, showing the selected tab
only, so a pane with three tabs still gets one line:

```
$ ed machines workspace panes
#           MACHINE          SHOWING
1           removed machine  overview
2  focused  Asus TUF 7       overview
```

Behaviour: `panes` reads two files, the workspaces and the machine list, and
writes neither. It needs no app. `--workspace` resolves exactly the way the
positional argument of `use` does, and naming one that does not exist exits 3.
With no workspaces saved at all it exits 4, `--workspace` or not.

`removed machine` in that transcript is the local Mac. The app can put a pane on
This Mac, which is not an entry in the machine list, so `ed` has no name for it
and reports it as removed. That is the state of a default workspace built by the
app, and there is no way to point a pane back at This Mac from `ed`.

### `ed machines workspace split`

Splits a pane in two and points the new one at a machine and a screen.

Usage:

```
ed machines workspace split <pane> <machine> [--side <side>] [--screen <screen>]
                            [--workspace <workspace>] [--json]
```

Arguments:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<pane>` | integer, 1 to the pane count | required | Which pane to split, counting from 1 as `panes` numbers them. |
| `<machine>` | machine name, ssh alias, id or unambiguous prefix | required | What the new pane points at. |

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--side` | `left`, `right`, `top`, `bottom` | `right` | Which side of the existing pane the new one goes on. `left` and `right` split horizontally, `top` and `bottom` vertically. |
| `--screen` | `overview`, `processes`, `docker`, `terminal`, `files`, `tools` | `overview` | What the new pane shows. |
| `--workspace` | name, id, or unambiguous name prefix | the current workspace | Which workspace to split a pane in. |
| `--json` | flag | off | Emits one JSON document on stdout. |

`--json` shape: the workspace after the split, in the shape `panes` prints. The
new pane is the focused one.

Examples:

```
ed machines workspace split 1 mini
ed machines workspace split 1 mini --side bottom --screen terminal
ed machines workspace split 2 tuf --screen docker --workspace Fleet
ed machines workspace split 1 mini --json
```

```
$ ed machines workspace split 1 mini --side bottom --screen terminal
split pane 1 to the bottom; 3 panes now
```

Behaviour: this is the pane header's split menu, which offers Split Right and
Split Down and reuses the pane's own target; `ed` reaches all four sides and
makes you say what the new pane points at. The new pane carries exactly one
tab, on the machine and screen you named, and becomes the focused pane. Where
it lands depends on what is already there. If the pane you split already sits
in a split running along the same axis, the newcomer joins as a sibling: it
takes an equal share and every
existing sibling is scaled down to make room, so three panes in a row stay a row
rather than becoming a row containing a row. Otherwise the pane is replaced by a
fresh split of the two, half and half.

`--side left` and `--side top` insert before the pane you named, which means the
new pane takes that pane's number and everything after it shifts up by one. Read
`panes` again rather than assuming the number you split is still the same pane.

Nothing is written until every argument checks out, and they are checked in this
order: the pane number, the machine, the side, then the screen. A bad pane
number exits 3 and says how many the workspace has; an unknown machine exits 3
with the known machines in the hint; a bad side or screen exits 3 and lists the
accepted values:

```
$ ed machines workspace split 7 tuf
error: there is no pane 7 in Compare
hint: it has 2, numbered from 1

$ ed machines workspace split 1 tuf --side sideways
error: no side called sideways
hint: sides: left, right, top, bottom
```

There is no cap on the number of panes and no check that a screen suits the
machine. `--screen docker` on a machine without Docker is accepted here and
fails later, in the pane, where the app's own tab menu would simply not have
offered it.

### `ed machines workspace close`

Closes a pane.

Usage:

```
ed machines workspace close <pane> [--workspace <workspace>] [--json]
```

Arguments:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<pane>` | integer, 1 to the pane count | required | Which pane to close, counting from 1. |

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--workspace` | name, id, or unambiguous name prefix | the current workspace | Which workspace to close a pane in. |
| `--json` | flag | off | Emits one JSON document on stdout. |

There is no `--yes` guard: the pane goes the moment you run it, along with every
tab in it.

`--json` shape: the workspace after the close, in the shape `panes` prints.

Examples:

```
ed machines workspace close 3
ed machines workspace close 1 --workspace Fleet
ed machines workspace close 2 --json
```

```
$ ed machines workspace close 3
closed pane 3; 2 left
```

Behaviour: this is Close Pane in the same pane menu, which the app greys out on
a single-pane workspace. Closing a pane removes it from the tree and then tidies
the tree around it. A split left with one child collapses into that child, and
a split nested inside another on the same axis is flattened into it, with ratios
multiplied through so the panes that remain keep their relative sizes. The
practical effect is that pane numbers after a close are not simply the old ones
minus one; run `panes` again.

If the pane you closed was the focused one, focus moves to the first pane. If it
was the maximized one, nothing is maximized any more.

The last pane cannot be closed, because a workspace with no panes has nothing to
draw. That check runs before the pane number is even looked at, so on a
single-pane workspace every `close` reports the same thing and exits 1,
including `close 9`:

```
$ ed machines workspace close 1
error: Compare has one pane left, and a workspace needs one
hint: remove the whole thing with `ed machines workspace rm`
```

### `ed machines workspace point`

Points a pane at a different machine, a different screen, or both, without
splitting anything.

Usage:

```
ed machines workspace point <pane> [<machine>] [--screen <screen>]
                            [--workspace <workspace>] [--json]
```

Arguments:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<pane>` | integer, 1 to the pane count | required | Which pane to retarget, counting from 1. |
| `<machine>` | machine name, ssh alias, id or unambiguous prefix | optional | The machine to point at. Leave it out to change only the screen. |

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--screen` | `overview`, `processes`, `docker`, `terminal`, `files`, `tools` | unchanged | The screen to show. Leave it out to change only the machine. |
| `--workspace` | name, id, or unambiguous name prefix | the current workspace | Which workspace the pane is in. |
| `--json` | flag | off | Emits one JSON document on stdout. |

At least one of `<machine>` and `--screen` is required. Giving neither exits 1:

```
$ ed machines workspace point 1
error: say a machine, a --screen, or both
```

`--json` shape: the workspace after the change, in the shape `panes` prints.

Examples:

```
ed machines workspace point 1 mini
ed machines workspace point 1 --screen terminal
ed machines workspace point 2 tuf --screen files
ed machines workspace point 1 mini --workspace Fleet --json
```

```
$ ed machines workspace point 2 tuf --screen files
pane 2 now shows files on Asus TUF 7
```

Behaviour: `point` is the Workspace tab strip's machine picker as a command. It
rewrites the selected tab of that pane in place, leaving the tree, the ratios,
the focus and every other tab exactly as they were. On a pane with several tabs
it changes only the one that is showing; there is no way to address the others
from `ed`.

The unchanged half really is left alone: `point 1 mini` keeps whatever screen
the pane was on, and `point 1 --screen terminal` keeps whatever machine it was
pointed at. The confirmation line is assembled from the parts you gave, so with
only a machine it reads `pane 1 now shows  on mini`, with the gap where the
screen would have been.

The pane number is checked first, then the machine, then the screen, and nothing
is written until all three are good. A bad screen exits 3 and names the six:

```
$ ed machines workspace point 1 --screen bogus
error: no screen called bogus
hint: screens: overview, processes, docker, terminal, files, tools
```

### `ed machines workspace equalize`

Evens out every split in a workspace.

Usage:

```
ed machines workspace equalize [--workspace <workspace>] [--json]
```

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--workspace` | name, id, or unambiguous name prefix | the current workspace | Which workspace to level. |
| `--json` | flag | off | Emits one JSON document on stdout. |

There are no positional arguments, and there is no way to equalize one split
rather than all of them.

`--json` shape: the workspace, in the shape `panes` prints. The ratios it just
changed are not part of that document, so the JSON before and after are
identical.

Examples:

```
ed machines workspace equalize
ed machines workspace even
ed machines workspace equalize --workspace Fleet --json
```

```
$ ed machines workspace equalize
evened out 3 panes
```

Behaviour: `equalize` walks the tree and gives every child of every split an
equal share, which is the equal-square button in the Workspace toolbar. It is
the only verb here that touches ratios, and ratios are the only thing it
touches: no pane moves, nothing is retargeted, focus does not change.

A workspace whose root is a single pane has no split to level, so the command
does nothing to the layout and still reports `evened out 1 panes`. It writes the
file and posts the notification either way, so it is never a pure read even when
it changes nothing.

## Exit codes

| Code | When this group produces it |
| --- | --- |
| 0 | The listing or the change succeeded. Also `ls` on an empty store, `equalize` on a single-pane workspace, and `--help` on the group or any verb. |
| 1 | The file could not be written, with the system's own description in the message. Also `close` on the last pane, `rename` to a blank name, `point` with neither a machine nor a `--screen`, and `new` with a machine list the parser let through empty. |
| 2 | The command line was wrong in ArgumentParser's own terms: an unknown flag, a missing `<workspace>`, `<name>`, `<pane>` or `<machines>`, or a `<pane>` that is not an integer. |
| 3 | Something you named does not exist: a workspace name or prefix that matches none or several, a pane number below 1 or above the count, a `--screen` or `--side` outside the accepted values, or a machine name that matches none or several. |
| 4 | No workspaces are saved at all, and the verb needs one. Every verb except `ls` and `new` produces this on an empty store. |

Exit 4 here never means the app is missing. Nothing in this group waits on
Edith, and the only thing that reports itself unavailable is an empty store,
which you fix with `ed machines workspace new` rather than by opening the app.

## Notes and gotchas

- A running Edith holds the workspace file in memory and does not reload it.
  The Workspace view reads `workspaces.json` once, when it is first built, and
  writes its whole in-memory store back on every change it makes. The
  `machinesChanged` notification `ed` posts after each write is observed by the
  machine list, not by the workspace model, so a layout built from the CLI
  while the app is open does not appear, and the app's next pane change saves
  its older copy over yours. Do CLI workspace work while Edith is closed, or
  quit and reopen it to pick up what you wrote.
- The app's Layout menu replaces the whole file. Choosing Compare two machines,
  Docker everywhere, Terminal grid, Files side by side or Single pane does not
  add a workspace: it sets the saved list to exactly that one layout. Every
  workspace `ed` saved is gone at that point. `ed machines workspace new`
  builds the same kind of layout and appends it instead.
- This Mac cannot be reached from here. The app's machine list starts with a
  built-in local machine that is not in `machines.json`, so `MachineResolver`
  never finds it and `panes` prints `removed machine` for any pane pointing at
  it. A workspace the app built for you almost certainly contains one.
- `tools` is a valid `--screen` on `new`, `split` and `point`, even though the
  help text for `new --screen` lists only five values. The hint you get from a
  bad screen is generated from the enum and lists all six in their declared
  order: `overview, processes, docker, terminal, files, tools`.
- Screen availability is not checked against the machine. The app hides
  `docker` for a machine with no Docker daemon and offers only `overview`,
  `processes`, `files` and `terminal` for This Mac; `ed` accepts anything and
  lets the pane deal with it.
- Workspace names are not unique, and only `rename` checks one at all: it trims
  and refuses a blank, while `new --name` stores whatever you pass, whitespace
  included. Two workspaces can share a name; lookups take the first, so the
  second is addressable only by its id. `ls --json` is where you get ids.
- Workspace lookup is name, then id, then unique prefix, and it is
  case-insensitive throughout. There is no ssh-alias step here, unlike machine
  lookup, because a workspace has only the one name.
- Which workspace is current is stored as an id, and an absent or dangling one
  falls back to the first in the file. `ls` shows that fallback as current;
  `rename` reports `"current": false` for it, because it reads the stored
  pointer rather than the effective one. One `use` makes them agree.
- `new` switches you to the workspace it made. `use` switches you deliberately.
  Nothing else does: `rename` restores the pointer it found, and the five pane
  verbs preserve it, so editing another workspace through `--workspace` leaves
  you where you were. The one exception is a store that has never had a current
  workspace, where a pane edit makes the edited layout current.
- Pane numbers are positions in a flattened tree, not ids, and both `split` and
  `close` can renumber panes other than the one you named. Anything that
  touches more than one pane should re-read `panes` between steps, or work from
  the highest number down.
- `ed` writes one tab per pane and reads the selected tab only. Extra tabs come
  from the app, survive everything here, and show up in `panes --json`. There is
  no verb to add, close, select or reorder a tab, and none to set focus or to
  maximize a pane; `split` and `close` move focus as a side effect and that is
  the whole of it.
- Every mutating verb rewrites the entire file atomically from what it just
  read. Two `ed` processes editing different workspaces at the same moment
  leave only the later change, and a running app counts as a third writer.
- The file on disk is compact JSON with keys in whatever order the encoder
  produced. The pretty, alphabetically sorted documents `--json` prints are
  generated fresh and are not what is stored, so do not diff one against the
  other.
- The layout also carries a `maximized` pane id, which `ed` never sets and only
  ever clears, when the maximized pane is the one you close. Split ratios are
  the other stored value no `--json` document reports: `split` and `equalize`
  set them in bulk, dragging a divider in the window sets one by hand, and
  nothing here reads them back to you.
- Completion knows the verbs and the machine slots. `ed machines workspace
  <TAB>` offers the ten subcommands, and the machine argument of `split` and
  `point` and the machine list of `new` complete against your machines. The
  workspace slots of `use`, `rename` and `rm` complete nothing, and neither do
  pane numbers or the values of `--workspace`, `--screen` and `--side`. Writing
  an option before the positionals, as in `split --screen docker 1 <TAB>`, also
  costs you the machine completion, because the option's value is counted as a
  positional when the slot is worked out.
- `--help` works on the group and on all ten verbs, prints on stdout and exits
  0. `--version` is inherited from the root and works on any of them.

## Where to go next

- [`ed machines`](./machines.md), for the machine list every pane points into,
  and for adding the machines you want panes for.
- [`ed machines files`](./machines-files.md) and
  [`ed machines docker`](./machines-docker.md), the command line forms of two of
  the screens a pane can show.
- [Running commands on a machine](./machines-remote.md), which is the terminal
  screen's counterpart.
- [Conventions and contracts](./conventions.md), for the exit code table and the
  `--json` guarantee in full.
- [All `ed` commands](./README.md).
