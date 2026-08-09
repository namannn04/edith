# `ed machines files`

`ed machines files` is a file manager for a machine you have already told Edith
about. It lists directories, moves files in both directions, and runs the same
copy, move, rename, trash, search and duplicate operations the app's Files pane
runs. Reach for it when you want to look at or rearrange something on another
box without opening a shell there, and when you want the result in JSON.

Everything here except `undo` and `open` is plain shell sent over the SSH
connection Edith already holds, so nothing is installed on the machine and Edith
does not have to be running. Those two are the exceptions, because the history
one reverses and the window the other raises both live in the running app rather
than on disk.

## At a glance

| Command | What it does |
| --- | --- |
| `ed machines files ls` | List a remote directory. The default subcommand. Aliased `list`. |
| `ed machines files get` | Download one file from the machine. |
| `ed machines files put` | Upload one file to the machine. |
| `ed machines files cp` | Copy paths into a directory there. |
| `ed machines files mv` | Move paths into a directory there. |
| `ed machines files rename` | Rename one path in place. |
| `ed machines files mkdir` | Make a directory, parents included. |
| `ed machines files rm` | Move paths to the machine's trash, or delete them outright. |
| `ed machines files search` | Find files by name under a directory. |
| `ed machines files info` | Measure a path with `du`, directories included. |
| `ed machines files duplicate` | Copy a file beside itself, the way the window does. |
| `ed machines files undo` | Undo the last move or rename an open Files pane made. |
| `ed machines files open` | Open Edith's Files window on a directory, by default the one this terminal is in. Starts Edith when it is closed. |

## How these reach the machine

Every verb but `undo` resolves the machine, opens or reuses the shared
ControlMaster socket, and sends one command line. A machine resolves by display
name, SSH alias, id, or any unambiguous prefix, case-insensitively; an unknown
or ambiguous name exits 3 before anything is sent. A machine that cannot be
reached exits 4 with what `ssh` said:

```
$ ed machines files ls tuf
error: could not reach Asus TUF 7: Connection refused
hint: check the machine is awake and reachable, then retry
```

Two spellings put the machine in different places, and both work:

```
ed machines files ls tuf /var/log
ed machines tuf files ls /var/log
```

`ed tuf files ls` is not one of them. A machine name in the first position is
shorthand for `ed machines exec`, so that line runs `files ls` as a command on
the machine and the machine says it does not exist.

Paths are quoted individually before they are sent, so spaces and shell
metacharacters survive intact. The other side of that is that the machine never
expands a glob for you: `ed machines files cp tuf '/var/log/*.log' /tmp` looks
for a file literally named `*.log`. Quote the whole line through
`ed tuf 'cp /var/log/*.log /tmp'` when you want the remote shell to expand it.
The exception is `search`, whose text is handed to `find -iname`, which does its
own matching.

A relative path is resolved by the machine against the SSH login directory,
normally the home directory. The working directory `ed tuf cd` remembers belongs
to `ed machines exec`, and `open` is the one verb here that reads it, so a
Files window opens where the shell in that terminal left off.

## Commands

### `ed machines files ls`

Lists one remote directory. This is the default subcommand, so
`ed machines files tuf /var/log` works, and it is aliased `list`.

```
ed machines files ls <machine> [path] [--all] [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `machine` | machine name, SSH alias, id or unambiguous prefix | required | Which machine to read. |
| `path` | remote directory | `.`, which means the login home directory | Directory to list. |
| `--all`, `-a` | flag | off | Include dotfiles. |
| `--json` | flag | off | Emit JSON on stdout. |

```json
{
  "entries": [
    {
      "kind": "directory",
      "linkTarget": null,
      "mode": "755",
      "modified": "2026-08-04T18:22:07Z",
      "name": "uploads",
      "path": "/home/pulkit/uploads",
      "sizeBytes": 4096
    },
    {
      "kind": "file",
      "linkTarget": null,
      "mode": "644",
      "modified": "2026-08-06T09:14:52Z",
      "name": "deploy.sh",
      "path": "/home/pulkit/deploy.sh",
      "sizeBytes": 1842
    },
    {
      "kind": "symlink",
      "linkTarget": "/srv/app/current",
      "mode": "777",
      "modified": "2026-07-19T11:03:44Z",
      "name": "current",
      "path": "/home/pulkit/current",
      "sizeBytes": 16
    }
  ],
  "path": "/home/pulkit"
}
```

```
ed machines files ls tuf
ed machines files ls tuf /var/log --all
ed machines files ls tuf /etc --json
ed machines tuf files ls /srv
```

The default `path` is the literal string `.`, and `ed` turns that into the home
directory by asking the machine for `$HOME` first, falling back to `/` if it
answers nothing. Typing `.` yourself means the same thing, so there is no way to
say "the directory I was last in" here.

The listing itself is one `find -mindepth 1 -maxdepth 1 -printf` with a 45
second timeout, falling back to `ls -lAn --time-style=+%s` on a machine whose
`find` has no `-printf`. Dotfiles are always fetched and dropped locally when
`--all` is off, so the flag costs no extra round trip. Entries come back
directories first, then by name case-insensitively, which is the order the app's
pane uses.

`kind` is `directory`, `file`, `symlink` or `other`. `mode` is whatever the
machine printed: `755` from the `find` path, `drwxr-xr-x` from the fallback.
`modified` is ISO 8601, or `null` when the fallback ran and the timestamps were
not epochs. `linkTarget` is `null` for everything that is not a symlink.
`sizeBytes` for a directory is the directory entry's own size, usually 4096,
even though the human table leaves that column blank:

```
$ ed machines files ls tuf
T  MODE  SIZE    NAME
d  755           uploads
-  644   1.8 KB  deploy.sh
l  777   16 B    current
```

An empty directory prints the header row and exits 0. A path that does not
exist, or one the account cannot read, exits 1:

```
$ ed machines files ls tuf /root
error: could not read /root on Asus TUF 7
```

The hint is meant to carry the machine's own complaint, but both the `find` and
the fallback are run with their stderr discarded, so it arrives empty and the
reason is not reported. Ask the machine directly with `ed tuf ls -la /root` when
you need to know which of the two it was.

### `ed machines files get`

Downloads one file from the machine to this Mac.

```
ed machines files get <machine> <remote> [local] [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `machine` | machine name, SSH alias, id or unambiguous prefix | required | Which machine to read from. |
| `remote` | remote file path | required | The file to download. |
| `local` | local path, `~` expanded | the remote file's name, in the working directory | Where to write it. |
| `--json` | flag | off | Emit JSON on stdout. |

```json
{
  "local": "/Users/pulkit/os-release",
  "remote": "/etc/os-release",
  "sizeBytes": 382
}
```

```
ed machines files get tuf /etc/os-release
ed machines files get tuf /var/log/syslog ~/Desktop/syslog.txt
ed machines files get tuf /etc/hosts --json
```

The transfer is `cat <remote>` on the far side, streamed into the local file 128
KB at a time over the shared connection. There is no timeout: a large file takes
as long as it takes. The local path is created or truncated without asking, so
downloading twice overwrites the first copy.

Before the first byte moves, `ed` asks the machine how big the file is with
`stat`, capped at 30 seconds, and then keeps one line on stderr up to date as
the bytes land: the file name, what has arrived, the total, and a percentage.
That line is repainted on a timer roughly ten times a second rather than once
per chunk, and it is transient, cleared when the transfer ends or fails:

```
$ ed machines files get tuf /srv/backup.tar.gz
  ⠹ backup.tar.gz  24.0 MB of 87.3 MB  27% 14s
```

It is written only when stderr is a terminal, and never with `--json`, so a
piped or redirected run is as quiet as it ever was. When the `stat` cannot
answer, the meter falls back to the bytes received alone, with no total and no
percentage.

`sizeBytes` is measured from the local file after the transfer rather than from
the size the machine reported for the meter, so it is what actually landed, and
it is 0 if the file cannot be stat'ed. The human line is the path and that size:

```
$ ed machines files get tuf /etc/os-release
/Users/pulkit/os-release  382 B
```

A remote path that does not exist, or one `cat` refuses such as a directory,
exits 1, and the half-written local file is removed rather than left looking
complete:

```
$ ed machines files get tuf /etc/shadow
error: download failed: cat: /etc/shadow: Permission denied
```

### `ed machines files put`

Uploads one file from this Mac to the machine.

```
ed machines files put <machine> <local> <remote> [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `machine` | machine name, SSH alias, id or unambiguous prefix | required | Which machine to write to. |
| `local` | local file path, `~` expanded | required | The file to upload. |
| `remote` | remote file path, or a directory | required | Where to put it. |
| `--json` | flag | off | Emit JSON on stdout. |

```json
{
  "local": "/Users/pulkit/clip.mov",
  "remote": "/home/pulkit/uploads/clip.mov",
  "sizeBytes": 38109184
}
```

```
ed machines files put tuf ./deploy.sh /tmp/deploy.sh
ed machines files put tuf ./clip.mov /home/pulkit/uploads/
ed machines files put tuf ~/notes.md /srv/notes.md --json
```

The local file is checked before the machine is dialled, so a typo there exits 3
with `no file at /Users/pulkit/deploy.sh` and costs nothing.

The destination takes a directory as well as a file path. A path ending in `/`
keeps the local filename; so does a path that turns out to be a directory, which
`ed` establishes with a `test -d` probe capped at 20 seconds; anything else is
used verbatim. An empty destination becomes `/` plus the filename.

Once the destination is settled the same meter `get` prints appears on stderr,
counting the bytes sent against the local file's size, which `ed` reads here
rather than asking the machine for:

```
$ ed machines files put tuf ./clip.mov /home/pulkit/uploads/
  ⠸ clip.mov  9.7 MB of 38.1 MB  25% 6s
```

It follows the same rules as it does on `get`: terminal only, suppressed by
`--json`, and cleared when the transfer ends or fails.

The upload is `cat > <remote>`, streamed 128 KB at a time, and then it is
checked rather than assumed. The bytes sent must match the local file's size,
and the file's size on the machine, read back with `stat`, must match the bytes
sent. Any mismatch, a write the machine stopped accepting, or a non-zero exit
runs `rm -f` on the destination and exits 1:

```
$ ed machines files put tuf ./clip.mov /tmp/no-such-dir/clip.mov
error: upload failed: bash: line 1: /tmp/no-such-dir/clip.mov: No such file or directory
```

That cleanup is unconditional, which is the sharp edge of this command: an
upload that fails while overwriting an existing remote file removes the old file
too. `sizeBytes` in the JSON is the local file's size.

This is a single-file transfer, because a directory has nothing to pipe into
`cat`. Send a tree with `ed tuf 'tar -xzf - -C /srv'` and a local `tar` on the
other end of the pipe, or copy it within the machine with `cp`.

### `ed machines files cp`

Copies one or more paths into a directory on the machine. This is the window's
copy and paste.

```
ed machines files cp <machine> <path>... <directory> [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `machine` | machine name, SSH alias, id or unambiguous prefix | required | Which machine. |
| `path...` | one or more remote paths, then the destination directory last | at least two values required | What to copy, and where to. |
| `--json` | flag | off | Emit JSON on stdout. |

```json
{
  "copied": [
    "/home/pulkit/notes.md",
    "/home/pulkit/deploy.sh"
  ],
  "done": true,
  "into": "/home/pulkit/backup",
  "machine": "Asus TUF 7"
}
```

```
ed machines files cp tuf /home/pulkit/notes.md /home/pulkit/backup
ed machines files cp tuf /srv/a.conf /srv/b.conf /srv/keep
ed machines files cp tuf /var/log/syslog /tmp --json
```

The last value is always the destination, like the shell tool this mirrors, and
the rest are sources. Fewer than two values exits 1 with `give at least one
source and a destination directory`.

What runs is `cp -a`, so a directory is copied whole and modes, ownership where
the account is allowed to set it, and timestamps are preserved. The destination
is not checked for being a directory: with exactly one source and a destination
that does not exist, this copies the source to that name, which is `cp`
behaviour rather than a special case.

The command is capped at 300 seconds. Without `--json` the output is a single
line saying what was done, `copied 2 into /home/pulkit/backup`. A non-zero exit
on the machine exits 1 with that same description and whatever the machine
printed:

```
$ ed machines files cp tuf /srv/a.conf /srv/locked
error: copied 1 into /srv/locked failed on Asus TUF 7: cp: cannot create regular file '/srv/locked/a.conf': Permission denied
```

`done` is `true` in every JSON document this prints, because a failure never
gets that far; it is the field to assert on rather than to branch on.

### `ed machines files mv`

Moves one or more paths into a directory on the machine. This is the window's
cut and paste.

```
ed machines files mv <machine> <path>... <directory> [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `machine` | machine name, SSH alias, id or unambiguous prefix | required | Which machine. |
| `path...` | one or more remote paths, then the destination directory last | at least two values required | What to move, and where to. |
| `--json` | flag | off | Emit JSON on stdout. |

```json
{
  "done": true,
  "into": "/home/pulkit/archive",
  "machine": "Asus TUF 7",
  "moved": [
    "/home/pulkit/old.log"
  ]
}
```

```
ed machines files mv tuf /home/pulkit/old.log /home/pulkit/archive
ed machines files mv tuf /srv/a.conf /srv/b.conf /srv/old
ed machines files mv tuf /tmp/build /srv/releases --json
```

Identical in shape to `cp` and identical in its refusals: fewer than two values
exits 1, a non-zero exit on the machine exits 1 with the machine's message, and
the cap is 300 seconds. What runs is plain `mv`, which means a file of the same
name in the destination is overwritten without a word. Check first with
`ed machines files ls` when that matters.

A move made here is not on any window's undo stack. Reverse it with another
`mv`, not with `ed machines files undo`.

### `ed machines files rename`

Renames one path, leaving it in the directory it is already in.

```
ed machines files rename <machine> <path> <name> [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `machine` | machine name, SSH alias, id or unambiguous prefix | required | Which machine. |
| `path` | remote path | required | What to rename. |
| `name` | a bare name, no slashes | required | What to call it. |
| `--json` | flag | off | Emit JSON on stdout. |

```json
{
  "done": true,
  "machine": "Asus TUF 7",
  "path": "/home/pulkit/notes.md",
  "to": "/home/pulkit/journal.md"
}
```

```
ed machines files rename tuf /home/pulkit/notes.md journal.md
ed machines files rename tuf /srv/app.conf app.conf.bak
ed machines files rename tuf /tmp/report.txt summary.txt --json
```

The new name is joined to the original path's directory, so the file stays
where it is. A name containing a slash is refused before anything is sent, and
exits 1 rather than 2:

```
$ ed machines files rename tuf /home/pulkit/notes.md sub/journal.md
error: a new name cannot contain a slash
hint: use `ed machines files mv` to move it somewhere else
```

The rename is guarded on the machine: it tests for the target first and gives up
with status 17 if something is already there, so an existing name is refused
rather than overwritten. That guard prints nothing, which is why the refusal
arrives without detail:

```
$ ed machines files rename tuf /home/pulkit/notes.md deploy.sh
error: renamed to /home/pulkit/deploy.sh failed on Asus TUF 7
```

The `to` field carries the full new path, not the bare name you typed, and so
does the human line, which reads `renamed to /home/pulkit/journal.md`.

### `ed machines files mkdir`

Makes a directory on the machine.

```
ed machines files mkdir <machine> <path> [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `machine` | machine name, SSH alias, id or unambiguous prefix | required | Which machine. |
| `path` | remote directory path | required | The directory to make. |
| `--json` | flag | off | Emit JSON on stdout. |

```json
{
  "done": true,
  "machine": "Asus TUF 7",
  "path": "/home/pulkit/backup/2026-08"
}
```

```
ed machines files mkdir tuf /home/pulkit/backup
ed machines files mkdir tuf /srv/releases/2026-08/staging
ed machines files mkdir tuf /tmp/work --json
```

What runs is `mkdir -p`, so missing parents are created in one go and a
directory that already exists is not an error: it prints `made <path>` and exits
0. A path the account cannot write exits 1 with the machine's message.

### `ed machines files rm`

Moves paths to the machine's trash, or with `--delete` removes them for good.

```
ed machines files rm <machine> <path>... [--delete] [--yes] [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `machine` | machine name, SSH alias, id or unambiguous prefix | required | Which machine. |
| `path...` | one or more remote paths | at least one required | What to remove. |
| `--delete` | flag | off | Delete outright rather than moving to the trash. |
| `--yes` | flag | off | Actually do it. Required with `--delete`, and ignored without it. |
| `--json` | flag | off | Emit JSON on stdout. |

```json
{
  "deleted": false,
  "done": true,
  "machine": "Asus TUF 7",
  "paths": [
    "/home/pulkit/old.log"
  ]
}
```

The dry run that `--delete` without `--yes` produces is a different, shorter
document, with neither `machine` nor `done`:

```json
{
  "deleted": false,
  "paths": [
    "/home/pulkit/old.log"
  ]
}
```

```
ed machines files rm tuf /home/pulkit/old.log
ed machines files rm tuf /tmp/a /tmp/b
ed machines files rm tuf /tmp/scratch --delete --yes
ed machines files rm tuf /tmp/scratch --delete --json
```

Trashing is the default and needs no confirmation, because it is reversible.
`--delete` is not, so it does nothing without `--yes`, reports what it would
have done, and still exits 0:

```
$ ed machines files rm tuf /tmp/scratch --delete
would delete 1 path(s) for good
nothing was deleted; pass --yes to go ahead
```

The trash is the freedesktop location in the login account's home,
`~/.local/share/Trash/files`, with a matching `.trashinfo` record in
`~/.local/share/Trash/info` holding the original path and the deletion time, so
the machine's own file manager can put the file back. Both directories are
created if they are missing. A name already sitting in the trash gets the
current epoch seconds appended rather than clobbering what is there. `--delete`
skips all of that and runs `rm -rf`.

Naming no path at all exits 1 with `name at least one path`, because the paths
argument accepts an empty list at the parser level. The cap is 300 seconds, and
a failure on the machine exits 1 with its message.

`deleted` in the JSON reports which of the two removals ran, not whether it
worked. `done` is what says it worked, and a dry run has no `done` at all.

### `ed machines files search`

Finds files by name under a directory. This is the window's search field.

```
ed machines files search <machine> <path> <query> [--limit <n>] [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `machine` | machine name, SSH alias, id or unambiguous prefix | required | Which machine. |
| `path` | remote directory | required | Where to search, recursively. |
| `query` | text, matched anywhere in the file name | required | What to look for. |
| `--limit` | integer greater than zero | `300` | Stop after this many matches. |
| `--json` | flag | off | Emit JSON on stdout. |

```json
[
  "/var/log/nginx/access.log",
  "/var/log/nginx/error.log",
  "/var/log/syslog"
]
```

```
ed machines files search tuf /var/log nginx
ed machines files search tuf /srv .env --limit 20
ed machines files search tuf /home/pulkit report --json
```

What runs is `find <path> -iname '*<query>*' -not -path '*/.git/*' | head`,
capped at 120 seconds. Matching is case-insensitive and against the name only,
never the contents, and `.git` directories are skipped so a search under a
source tree is not drowned in objects. Because the text goes to `-iname` as a
glob, a `*` or `?` inside it is honoured rather than escaped.

`find`'s own errors are discarded, which makes this quiet in a useful way and
misleading in one way: directories the account cannot read are skipped instead
of failing the command, and a directory that does not exist simply matches
nothing:

```
$ ed machines files search tuf /var/log nothing-like-this
nothing under /var/log matches nothing-like-this
```

That note is on stderr and the exit code is 0. With `--json` the same case is an
empty array. Note that the document here is a top-level array of absolute paths,
not an object; it is the only command in this group shaped that way.

`--limit` is validated locally: zero or less exits 2 with
`--limit must be greater than zero`. Hitting the cap is silent, so a result of
exactly `--limit` lines means there may be more.

### `ed machines files info`

Measures how big something is, following a directory all the way down.

```
ed machines files info <machine> <path> [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `machine` | machine name, SSH alias, id or unambiguous prefix | required | Which machine. |
| `path` | remote path | required | What to measure. |
| `--json` | flag | off | Emit JSON on stdout. |

```json
{
  "machine": "Asus TUF 7",
  "path": "/var/log",
  "sizeBytes": 419430400
}
```

```
ed machines files info tuf /var/log
ed machines files info tuf /home/pulkit/uploads --json
ed machines tuf files info /srv
```

What runs is `du -sk <path>`, capped at 120 seconds, and the kilobytes are
multiplied by 1024. This is disk usage rather than the sum of file sizes, so it
counts whole blocks and answers for directories, which is the reason to use it
instead of reading `sizeBytes` out of `ed machines files ls`.

The human line is formatted by macOS rather than by Edith's own byte formatter,
so it reads the way Finder's Get Info reads:

```
$ ed machines files info tuf /var/log
419.4 MB  /var/log
```

`du`'s errors are discarded, so a path that does not exist is reported as
nothing at all rather than as a failure: the size is 0, the line reads
`Zero KB  /nope`, and the exit code is 0. Confirm the path with
`ed machines files ls` when a zero would be surprising.

### `ed machines files duplicate`

Copies a file beside itself, naming the copy the way the window names it.

```
ed machines files duplicate <machine> <path> [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `machine` | machine name, SSH alias, id or unambiguous prefix | required | Which machine. |
| `path` | remote path | required | What to duplicate. |
| `--json` | flag | off | Emit JSON on stdout. |

```json
{
  "machine": "Asus TUF 7",
  "path": "/home/pulkit/report.txt",
  "to": "/home/pulkit/report copy.txt"
}
```

```
ed machines files duplicate tuf /home/pulkit/report.txt
ed machines files duplicate tuf /srv/app/config
ed machines files duplicate tuf /home/pulkit/report.txt --json
```

The name is worked out on the machine: the extension is kept, ` copy` is added
to the stem, and if that is taken the number climbs, so `report.txt` gives
`report copy.txt`, then `report copy 2.txt`, then `report copy 3.txt`.
Duplicating twice never overwrites the first copy. The copy itself is `cp -R`,
so a directory duplicates whole, and the cap is 300 seconds.

One case differs from the app. A name that is nothing but an extension, such as
`.bashrc`, has an empty stem on the machine's arithmetic, so the CLI produces
` copy.bashrc` with a leading space where the window produces `.bashrc copy`.

A failure exits 1 and hands back what the machine printed:

```
$ ed machines files duplicate tuf /etc/hosts
error: could not duplicate /etc/hosts on Asus TUF 7
hint: cp: cannot create regular file '/etc/hosts copy': Permission denied
```

### `ed machines files undo`

Undoes the last move or rename made in an open Files pane for that machine.

```
ed machines files undo <machine> [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `machine` | machine name, SSH alias, id or unambiguous prefix | required | Whose Files pane to ask. |
| `--json` | flag | off | Emit JSON on stdout. |

```json
{
  "machine": "Asus TUF 7",
  "undone": true,
  "what": "Undo Rename"
}
```

```
ed machines files undo tuf
ed machines files undo tuf --json
```

This is the only verb in the group that does not touch SSH. The machine name is
resolved against Edith's own machine list, and everything after that happens
over the app's notification bus: `ed` posts a request carrying the machine's id,
then waits up to 20 seconds for the answer, printing `waiting for Edith to
answer...` on stderr once a second has passed.

**What is undoable.** Exactly two operations, and only when a Files pane
performed them and they succeeded: a rename committed in the pane, and a move
within the machine, which is a drag onto a folder or a cut and paste. The step
is labelled `Rename` or `Move` accordingly.

**What is not.** Copies, duplicates, new folders, trashes, deletes, uploads,
downloads and transfers between machines are never recorded. Neither is anything
`ed` itself did: `ed machines files mv` and `ed machines files rename` do not
join the history, so reverse those with another `mv` or `rename`, which is the
same command the pane would have run.

**How far back.** Each pane keeps its last 20 steps and drops the oldest beyond
that. One invocation pops one step, the most recent, so walk backwards by
running the command again.

**For how long.** As long as the pane is there. The stack lives in memory and is
never written to disk, so closing the pane, pointing it at another screen,
closing the workspace tab or quitting Edith all discard it. Nothing expires on a
timer, and nothing survives a relaunch.

**Which window.** Only a Files pane inside Edith's main window registers itself
as undoable. A standalone Finder window, the kind the Files button on a machine
opens, keeps a private stack that its own Command-Z drives and that `ed` cannot
reach. When several panes are open for one machine, `ed` gets whichever of them
has something on its stack, not necessarily the frontmost.

The reversal replays the step's moves backwards using the same guarded rename
`ed machines files rename` uses, so an undo whose original name has been taken
in the meantime stops rather than overwriting, and it stops at the first move
that fails.

Three things make this exit 4. Edith's main window not being open at all, which
is checked as soon as the name has resolved, so a name that matches nothing
still exits 3 ahead of it:

```
$ ed machines files undo tuf
error: the undo history lives in an open Finder window, and Edith is not running
hint: open Edith and its Files window for Asus TUF 7, then retry
```

A running app with nothing to give back:

```
$ ed machines files undo tuf
error: no Finder window for Asus TUF 7 has anything to undo
hint: open one with the Files tab, or reverse it with `ed machines files mv`
```

And an app that never answers within the 20 seconds, which is reported as
`Edith did not answer for undoing a file change in time`, or as
`Edith is not running, so it cannot answer for undoing a file change` when the
menu bar helper has gone away in the meantime.

On success the human line is `undid <label> on <machine>`. The label is the
pane's own menu title, which already starts with the word Undo, so the line
reads a little oddly and the JSON does too:

```
$ ed machines files undo tuf
undid Undo Rename on Asus TUF 7
```

The only values `what` takes are `Undo Rename`, `Undo Move` and, if the pane has
no title to give, `the last change`.

### `ed machines files open`

Opens Edith's Files window on a directory of the machine.

```
ed machines files open <machine> [path] [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `machine` | machine name, SSH alias, id or unambiguous prefix | required | Which machine to browse. |
| `path` | remote directory | the directory `ed <machine> cd` remembers for this terminal, else the machine's home | Where to open. |
| `--json` | flag | off | Emit JSON on stdout. |

```json
{
  "machine": "Asus TUF 7",
  "opened": true,
  "path": "/var/log"
}
```

```
ed machines files open tuf
ed machines files open tuf /var/log
ed tuf cd /srv/app && ed machines files open tuf
```

The window belongs to the app, so like `undo` this verb never touches SSH
itself: `ed` resolves the machine against Edith's list, posts a request carrying
the machine's id and the path, and waits for the app to say it opened one. The
app connects the machine if it is not connected yet, so this works from cold.

Edith being closed is not a refusal here. `ed` starts it, waits for it to come
up, and asks again, up to eight rounds of three seconds, so a cold start that
takes a moment still lands:

```
$ ed machines files open tuf /etc
  ⠹ starting Edith
opened /etc on Asus TUF 7
```

That is the one thing `open` does that `undo` does not, and the reason is that
a window can be opened from nothing while an undo history cannot.

The default path is what makes it worth typing. `ed tuf cd /srv/app` remembers a
directory per terminal, and `open` with no path reads that same record, so the
window lands where the shell is rather than at the home directory. Give a path
to override it, and give a path in a terminal that has never `cd`'d anywhere for
that machine, or the window opens at home.

Opening twice for the same machine and path brings the existing window forward
instead of stacking another one, which is the same rule the Files button in the
machine's tab bar follows.

What still exits 4 is an Edith that cannot be started, either because the app is
not in `/Applications` or beside this binary, or because it did not come up
within 20 seconds:

```
$ ed machines files open tuf
error: Edith is not installed where ed can find it
hint: it looks in /Applications and alongside this binary
```

So does an app that comes up but never answers, reported the way `undo` reports
it. Both happen after the machine name has resolved, so an unknown machine still
exits 3 first.

## Exit codes

| Code | What produced it |
| --- | --- |
| 0 | The command did what it says. Also the `--delete` dry run of `rm`, a `search` with no matches, `info` on a path that does not exist, `mkdir` on a directory that is already there, and `ls` of an empty directory. |
| 1 | The machine ran the command and it failed: a `cp`, `mv`, `mkdir` or `rm` the account is not allowed to make, a `rename` onto a name already taken, a `duplicate` that could not be written, a `get` or `put` that failed its checks, an `ls` that could read nothing. Also the local refusals: fewer than two paths for `cp` or `mv`, no path for `rm`, a slash in a `rename` name. |
| 2 | `--limit` of zero or less on `search`. Also any parse failure: an unknown flag, a missing positional, a `--limit` that is not a number. |
| 3 | No machine matches the name, more than one does, or no machines are configured at all. Also `put` when there is no local file at the path given. |
| 4 | The machine could not be reached, or the SSH transport failed part way through a command. Also all three ways `undo` gives up: Edith's main window closed, no pane with anything to undo, or no reply in 20 seconds. `open` uses it when Edith cannot be found or will not start, and when the app never answers. |

## Notes and gotchas

Nothing in this group needs Edith running except `undo` and `open`, and both
want the main window rather than the menu bar helper. `undo` refuses when it is
closed, because the history it reverses died with it. `open` starts it instead. The rest go straight down the
ControlMaster socket the app and `ed` share, so they work with Edith closed and
they reuse an open connection when it is there.

Nothing here tells a running Edith what changed. A Files pane showing the
directory you just rearranged from the command line keeps showing the old
listing until it is refreshed with Command-R. The traffic only goes the other
way, through `undo`.

The timeouts are fixed and worth knowing when a machine is slow: 15 seconds for
the `$HOME` probe, 20 for the `test -d` probe `put` makes, 30 for the `stat`
calls around a transfer, the one `get` makes to size the remote file and the one
`put` makes to check what landed, 45 for a directory listing, 120 for `search`
and `info`, 300 for `cp`, `mv`, `rename`, `mkdir`, `rm` and `duplicate`, and 20
for the `undo` reply. The transfer itself has no timeout at all, because a slow
file is not a broken one.

A failed command and a broken connection are different exit codes on purpose. A
command the machine ran and rejected exits 1 with the machine's own message
appended; a connection that could not be opened or that dropped mid-command
exits 4. Gate a script on 4 for "try again later" and on 1 for "this will not
work".

`--json` never changes what happens on the machine, only what is printed. Every
verb here prints exactly one document per invocation, with object keys sorted,
diagnostics on stderr only, and no streaming mode. `search` is the one whose
document is an array rather than an object, and `rm`'s dry run is the one whose
document has a different shape from its success. The transfer meter on `get` and
`put` is the one thing `--json` switches off rather than reshapes, because it is
stderr furniture rather than anything printed on stdout.

`--yes` exists on `rm` only, and only `--delete` consults it. Passing `--yes`
without `--delete` changes nothing: trashing never asks, because the machine's
trash can give the file back.

The remote trash is the freedesktop directory under the login home, whatever the
machine's desktop environment would normally use. On a machine with no desktop
at all the files still land in `~/.local/share/Trash/files`, which is a fine
place to find them but not somewhere anything will empty for you.

Shell completion knows this group only as far as the names it already holds:
after `ed machines files` it offers the verbs, and in the machine slot it offers
the configured machines. Remote paths are not completed at all, so Tab where a
path goes offers nothing of its own and never dials the machine. The completion
that does ask a machine, for command names and paths, belongs to the
`ed <machine> ...` shorthand, and even there only when a ControlMaster socket
for that machine is already open.

## Where to go next

- [`ed machines`](./machines.md) is where machines are added, named and
  connected, and where the name every command here takes comes from.
- [Running commands on a machine](./machines-remote.md) covers
  `ed machines exec` and the `ed <machine> ...` shorthand, which is the escape
  hatch for anything this group does not do.
- [`ed machines workspace`](./machines-workspace.md) explains the panes, one of
  which is the Files pane whose history `undo` reverses.
- [Conventions and contracts](./conventions.md) has the full exit code and JSON
  contract these pages assume.
- [All command groups](./README.md)
