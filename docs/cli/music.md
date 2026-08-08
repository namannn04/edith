# `ed music`

`ed music` is two things behind one noun. It is transport control for whichever
music player is actually playing on this Mac, Spotify, Apple Music or Edith's
own library player, and it is the file manager for Edith's library folder:
listing, moving, renaming and trashing tracks. Reach for it to see what is
playing without switching apps, to drive playback from a script or a hotkey, and
to keep the library tidy from a shell.

The group answers to `ed music`, `ed nowplaying` and `ed np`. A bare `ed music`
runs `ed music status`, and flags meant for `status` may be given straight to
it, so `ed np --json` and `ed music --player spotify` both work.

## At a glance

| Command | What it does |
| --- | --- |
| `ed music status` | What is playing right now, on whichever player. The default subcommand. |
| `ed music play` | Resume playback on the active player. |
| `ed music pause` | Pause the active player. |
| `ed music stop` | Stop the active player and reset its position to zero. |
| `ed music toggle` | Toggle play and pause. Aliased `playpause`. |
| `ed music next` | Skip to the next track. |
| `ed music previous` | Go back to the previous track. Aliased `prev`. |
| `ed music volume` | Set the active player's volume, from 0 to 1. |
| `ed music players` | Every player Edith can see, and which one is active. |
| `ed music ls` | List the library, a folder at a time. Aliased `list`. |
| `ed music mkdir` | Make a folder in the library. Aliased `newfolder`. |
| `ed music mv` | Move a track into a folder. Aliased `move`. |
| `ed music rename` | Rename a track or a folder. |
| `ed music rm` | Move a track or folder to the Trash. |
| `ed music start` | Play one track out of the library, or a whole folder. |
| `ed music seek` | Jump to a point in the current track, from 0 to 1. |
| `ed music shuffle` | Turn shuffle on or off, or report it. |
| `ed music repeat` | Turn repeat on or off, or report it. Aliased `loop`. |
| `ed music rescan` | Read the music folder again after changing it outside Edith. |

## Players

There are exactly three players, and they are named `builtin`, `spotify` and
`apple`. `builtin` is Edith's own library player, which lives in the menu bar
app and shows up as `Edith` in human output.

Each is reached a different way, which is why some commands need Edith running
and others do not.

- `spotify` and `apple` are driven straight over AppleScript: `ed` pipes a
  script into `/usr/bin/osascript` and waits up to 6 seconds. Edith does not
  have to be running for this, and never sees the command.
- `builtin` is driven over the app's own notification bus. Reading its state
  posts `requestMusicState` and waits up to 2 seconds for a `musicState` reply;
  changing it posts `musicCommand`. It counts as reachable only when the menu
  bar app is running and the `tabMusicEnabled` extension is on.

Every AppleScript starts with a `System Events` check for the player's process,
so a player that is not already open is reported as not running rather than
launched. Nothing in this group ever opens Spotify or Apple Music for you.

**Choosing the active player.** With no `--player`, `ed` takes a snapshot of all
three and scores each one: not running scores 0, running scores 1, plus 2 if it
has a track loaded and plus 4 if it is actually playing. The highest score wins.
Ties are broken first toward the player you last drove from the command line,
which `ed` remembers in the `cliActivePlayer` shared default after every
successful transport command, and otherwise toward the earlier player in the
fixed order `builtin`, `spotify`, `apple`. When the best score is still 0,
nothing is running and the command exits 4:

```
$ ed music pause
error: no music player is running
hint: open Spotify or Apple Music, or turn on Edith's Music extension
```

**Forcing one.** `--player <name>` skips the scoring, probes only that player,
and fails if it is not running. The spellings are generous and
case-insensitive:

| Player | Accepted spellings |
| --- | --- |
| `builtin` | `builtin`, `built-in`, `edith`, `internal` |
| `spotify` | `spotify` |
| `apple` | `apple`, `applemusic`, `apple-music`, `music`, `itunes` |

Anything else exits 3 with `no player named <text>` and the three canonical
names as the hint. A named player that is closed exits 4 and says which:

```
$ ed music next --player spotify
error: Spotify is not running
hint: open Spotify, then retry
```

`--player` exists on eight commands only: `status`, `play`, `pause`, `stop`,
`toggle`, `next`, `previous` and `volume`. `players` always looks at all three.
`start`, `seek`, `shuffle` and `repeat` always mean Edith's own player, because
they drive the library queue rather than a generic transport.

## Commands

### `ed music status`

Prints one line about whatever is playing, on whichever player. This is the
default subcommand, so `ed music` and `ed np` are the same thing.

```
ed music status [--json] [--player <name>]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout. |
| `--player` | `builtin`, `spotify`, `apple` | whichever is active | Force one player instead of scoring all three. |

```json
{
  "active": {
    "artist": "Bonobo",
    "durationSeconds": 344,
    "elapsedSeconds": 87.412,
    "isPlaying": true,
    "name": "Spotify",
    "player": "spotify",
    "running": true,
    "title": "Kerala",
    "volume": 0.65
  },
  "player": "spotify",
  "players": [
    {
      "artist": null,
      "durationSeconds": 0,
      "elapsedSeconds": 0,
      "isPlaying": false,
      "name": "Edith",
      "player": "builtin",
      "running": false,
      "title": null,
      "volume": null
    },
    {
      "artist": "Bonobo",
      "durationSeconds": 344,
      "elapsedSeconds": 87.412,
      "isPlaying": true,
      "name": "Spotify",
      "player": "spotify",
      "running": true,
      "title": "Kerala",
      "volume": 0.65
    },
    {
      "artist": null,
      "durationSeconds": 0,
      "elapsedSeconds": 0,
      "isPlaying": false,
      "name": "Apple Music",
      "player": "apple",
      "running": false,
      "title": null,
      "volume": null
    }
  ]
}
```

`players` always holds all three entries in the order `builtin`, `spotify`,
`apple`, even when `--player` narrowed the probe: the ones that were not probed
appear as not running. `active` repeats the winning entry and is `null` when
nothing qualifies. `title` and `artist` are `null` rather than empty strings
when the player has no track, and `volume` is `null` when the player did not
report one.

```
ed music status
ed music status --json
ed music status --player apple
ed np
```

The human line is `<state>  <title>  <artist>  <elapsed>/<duration>
(<player>)`, with state `playing`, `paused` or `idle`, and collapses to
`idle  (Edith)` when there is no track:

```
$ ed music status
playing  Kerala  Bonobo  1:27/5:44  (Spotify)
```

The two output modes fail differently, on purpose. The human form resolves an
active player and exits 4 when there is none, or when the forced one is closed.
`--json` swallows that: it reports `"active": null` and exits 0, so a status
poll never has to be wrapped in an exit-code check.

### `ed music play`

Resumes playback on the active player. It resumes what is loaded rather than
choosing something to play; `ed music start` is the one that picks a track.

```
ed music play [--json] [--player <name>]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout. |
| `--player` | `builtin`, `spotify`, `apple` | whichever is active | Force one player. |

```json
{
  "action": "playing",
  "name": "Spotify",
  "player": "spotify"
}
```

```
ed music play
ed music play --player builtin
ed music play --json
```

`action` is the past tense the human line prints, so stdout reads
`playing  (Spotify)`. On Spotify and Apple Music this sends the AppleScript
`play`; on the built-in player it posts the `resume` command, which the app acts
on only when a track is loaded and paused.

### `ed music pause`

Pauses the active player.

```
ed music pause [--json] [--player <name>]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout. |
| `--player` | `builtin`, `spotify`, `apple` | whichever is active | Force one player. |

```json
{
  "action": "paused",
  "name": "Edith",
  "player": "builtin"
}
```

```
ed music pause
ed music pause --player spotify
```

### `ed music stop`

Stops the active player and resets its position to the start of the track.

```
ed music stop [--json] [--player <name>]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout. |
| `--player` | `builtin`, `spotify`, `apple` | whichever is active | Force one player. |

```json
{
  "action": "stopped",
  "name": "Apple Music",
  "player": "apple"
}
```

```
ed music stop
ed music stop --player apple
```

Apple Music has a real `stop` verb and gets it. Spotify and the built-in player
do not, so `stop` there is a pause followed by a seek back to zero: two verbs in
one AppleScript for Spotify, and two posted commands for the built-in player.

### `ed music toggle`

Toggles play and pause on the active player. Aliased `playpause`.

```
ed music toggle [--json] [--player <name>]
ed music playpause [--json] [--player <name>]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout. |
| `--player` | `builtin`, `spotify`, `apple` | whichever is active | Force one player. |

```json
{
  "action": "toggled",
  "name": "Spotify",
  "player": "spotify"
}
```

```
ed music toggle
ed music playpause --player spotify
```

This is the verb to bind to a hotkey: it needs no state of its own and it picks
the player that is playing, which is usually the one you meant.

### `ed music next`

Skips to the next track.

```
ed music next [--json] [--player <name>]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout. |
| `--player` | `builtin`, `spotify`, `apple` | whichever is active | Force one player. |

```json
{
  "action": "skipped",
  "name": "Spotify",
  "player": "spotify"
}
```

```
ed music next
ed music next --player builtin
```

On the built-in player the next track comes from the current queue, which
`ed music shuffle` reorders.

### `ed music previous`

Goes back to the previous track. Aliased `prev`.

```
ed music previous [--json] [--player <name>]
ed music prev [--json] [--player <name>]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout. |
| `--player` | `builtin`, `spotify`, `apple` | whichever is active | Force one player. |

```json
{
  "action": "went back",
  "name": "Apple Music",
  "player": "apple"
}
```

```
ed music previous
ed music prev
```

### `ed music volume`

Sets the active player's volume as a fraction from 0 to 1.

```
ed music volume <level> [--json] [--player <name>]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `level` | number from 0 to 1 | required | The volume to set, as a fraction. |
| `--json` | flag | off | Emit JSON on stdout. |
| `--player` | `builtin`, `spotify`, `apple` | whichever is active | Force one player. |

```json
{
  "action": "volume set",
  "name": "Spotify",
  "player": "spotify"
}
```

```
ed music volume 0.4
ed music volume 1 --player spotify
ed music volume 0.25 --json
```

The level is checked before anything is sent: outside 0 to 1 exits 2 with
`volume must be between 0 and 1`, and a value that is not a number exits 2 as a
parse failure. Spotify and Apple Music take a percentage, so the fraction is
multiplied by 100 and rounded on the way out and divided by 100 on the way back
in `status`. The JSON reports only what was done and to whom; read the level
back with `ed music status --json`.

### `ed music players`

Lists every player Edith can see, what state each is in, and which one the other
commands would target.

```
ed music players [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout. |

```json
{
  "active": {
    "artist": null,
    "durationSeconds": 212,
    "elapsedSeconds": 41,
    "isPlaying": true,
    "name": "Edith",
    "player": "builtin",
    "running": true,
    "title": "alpha-song.mp3",
    "volume": 0.7
  },
  "player": "builtin",
  "players": [
    {
      "artist": null,
      "durationSeconds": 212,
      "elapsedSeconds": 41,
      "isPlaying": true,
      "name": "Edith",
      "player": "builtin",
      "running": true,
      "title": "alpha-song.mp3",
      "volume": 0.7
    },
    {
      "artist": null,
      "durationSeconds": 0,
      "elapsedSeconds": 0,
      "isPlaying": false,
      "name": "Spotify",
      "player": "spotify",
      "running": false,
      "title": null,
      "volume": null
    },
    {
      "artist": null,
      "durationSeconds": 0,
      "elapsedSeconds": 0,
      "isPlaying": false,
      "name": "Apple Music",
      "player": "apple",
      "running": false,
      "title": null,
      "volume": null
    }
  ]
}
```

The document is the same shape `ed music status --json` emits. This command has
no `--player`, because listing one player is not a list, and it never fails for
want of a running player:

```
$ ed music players
PLAYER   STATE    PLAYBACK          TRACK
builtin  -        -
spotify  running  playing   active  Kerala
apple    -        -
```

The fourth column has no heading and holds `active` on exactly one row, or on no
row at all when nothing is running. The built-in player reports its track as a
file name rather than a title, because that is what the app broadcasts.

### `ed music ls`

Lists Edith's library one folder at a time. Aliased `list`.

```
ed music ls [folder] [--folders] [--recursive] [--search <text>] [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `folder` | path relative to the library root | `""`, the root | Folder to list. |
| `--folders` | flag | off | Only folders. Tracks are left out of the table, and the JSON `tracks` array comes back empty. |
| `--recursive` | flag | off | Every track underneath, not just the ones directly in this folder. |
| `--search` | text | none | Only tracks whose relative path or title contains this text, case-insensitively. |
| `--json` | flag | off | Emit JSON on stdout. |

```json
{
  "folder": "Focus",
  "folders": [
    {
      "name": "Deep",
      "path": "Focus/Deep",
      "tracks": 12
    }
  ],
  "tracks": [
    {
      "file": "delta-loop.mp3",
      "path": "Focus/delta-loop.mp3",
      "title": "Delta Loop"
    }
  ]
}
```

```
ed music ls
ed music ls Focus
ed music ls --recursive --search drive
ed music ls --folders --json
```

The library is a folder of files, so this reads the disk and does not need Edith
running. Only playable files are counted: `mp3`, `m4a`, `m4b`, `aac`, `wav`,
`aiff`, `flac`, `mp4` and `mov`. Hidden files are skipped, and a recursive walk
does not descend into packages. A title is derived from the file name rather
than from tags: the extension is dropped, dashes and underscores become spaces,
and the result is capitalised, so `alpha-song.mp3` lists as `Alpha Song`.

Subfolders are always listed, whatever `--search` or `--recursive` say, and each
one carries the number of playable tracks anywhere underneath it. `--search`
filters tracks only. Folders sort by name and tracks by file name, both the way
Finder sorts; `--recursive` sorts by relative path instead.

```
$ ed music ls
FOLDER  TRACKS
Chill   4
Focus   12

TITLE       PATH
Alpha Song  alpha-song.mp3
Beta Tune   beta-tune.mp3
```

An empty folder prints `nothing here` on stderr and nothing on stdout. A folder
that does not exist exits 3; with no music folder configured at all, this and
every other library command exit 4 and say where to set one.

### `ed music mkdir`

Makes a folder in the library. Aliased `newfolder`.

```
ed music mkdir <name> [--under <folder>] [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `name` | text | required | What to call it. |
| `--under` | path relative to the library root | `""`, the root | Folder to make it inside. |
| `--json` | flag | off | Emit JSON on stdout. |

```json
{
  "name": "Chill",
  "path": "Focus/Chill"
}
```

```
ed music mkdir Chill
ed music mkdir Deep --under Focus
ed music mkdir "Late Night" --json
```

The name is sanitised before use: it is trimmed, and `/` and `:` each become
`-`, so a name cannot escape the folder it was asked for. A name that is blank
after trimming exits 1 with `a name cannot be blank`, and a folder that already
exists exits 1 with `<path> is already there` rather than being reused. A
`--under` that does not exist exits 3. On success `ed` posts
`musicFolderChanged`, so an open Edith picks the new folder up without a
rescan.

### `ed music mv`

Moves a track into a folder. Aliased `move`.

```
ed music mv <track> <folder> [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `track` | path, or enough of the path or title to be unambiguous | required | The track to move. |
| `folder` | path relative to the library root | required | Where to move it. Pass `""` for the root. |
| `--json` | flag | off | Emit JSON on stdout. |

```json
{
  "from": "beta-tune.mp3",
  "to": "Chill/beta-tune.mp3"
}
```

```
ed music mv beta-tune.mp3 Chill
ed music mv "night drive" Focus/Deep
ed music mv Chill/beta-tune.mp3 ""
```

A track is resolved by trying its exact relative path first, then by a
case-insensitive substring match against every track's path and title. A query
that matches more than one exits 3 and lists up to five of them rather than
guessing:

```
$ ed music mv e Chill
error: e matches 2 tracks
hint: beta-tune.mp3, Focus/delta-loop.mp3
```

A query matching nothing exits 3 with `no track matching <query>`. A destination
folder that does not exist exits 3. A file already sitting at the destination,
including the case where the track is already in that folder, exits 1 with
`<path> is already there`; nothing is overwritten.

The file keeps its name across the move. Favourites are repointed at the new
path, and `ed` posts a `renamed` message to the running player so the currently
playing track survives being moved out from under it.

### `ed music rename`

Renames a track or a folder in place.

```
ed music rename <target> <name> [--folder] [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `target` | track path or query, or folder path with `--folder` | required | What to rename. |
| `name` | text | required | The new name, without the extension. |
| `--folder` | flag | off | Rename a folder rather than a track. |
| `--json` | flag | off | Emit JSON on stdout. |

```json
{
  "from": "alpha-song.mp3",
  "to": "Night Drive.mp3"
}
```

```
ed music rename alpha-song.mp3 "Night Drive"
ed music rename "beta tune" Interlude
ed music rename --folder Chill Calm
```

A track keeps its extension, so renaming `alpha-song.mp3` to `Night Drive` gives
`Night Drive.mp3`. A folder has no extension to keep and takes the name as
given. The name is sanitised the same way `mkdir` sanitises it, a blank name
exits 1, and renaming onto a name that already exists exits 1 rather than
overwriting.

Without `--folder` the target goes through the same track resolution `mv` uses,
so an ambiguous query exits 3 with the matches. With `--folder` the target has
to be a real folder path and anything else exits 3. Favourites follow the new
name, folders included, and the running player is told so playback does not
break mid-track.

### `ed music rm`

Moves a track or a folder to the Trash. Nothing is deleted outright, so a
mistake is recoverable from Finder.

```
ed music rm <target> [--folder] [--yes] [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `target` | track path or query, or folder path with `--folder` | required | What to trash. |
| `--folder` | flag | off | Remove a folder and everything in it. |
| `--yes` | flag | off | Actually do it. Without this nothing is moved. |
| `--json` | flag | off | Emit JSON on stdout. |

```json
{
  "path": "Chill/beta-tune.mp3",
  "tracks": 1,
  "trashed": true
}
```

```
ed music rm beta-tune.mp3
ed music rm beta-tune.mp3 --yes
ed music rm --folder Chill --yes
ed music rm --folder Chill --json
```

Without `--yes` this is a dry run that touches nothing, prints what it would do,
and still exits 0. The JSON is the same document with `"trashed": false`, which
is the field to gate on:

```
$ ed music rm --folder Chill
would move Chill to the Trash (4 track(s))
nothing was moved; pass --yes to go ahead
```

`tracks` is 1 for a track and the number of playable tracks anywhere under the
folder for `--folder`. Trashing the library root itself is refused and exits 1
with `the library root cannot be removed`. A Trash operation the filesystem
rejects, for instance on a volume with no Trash, exits 1 with what macOS said.

### `ed music start`

Plays one track out of Edith's own library, or everything in a folder. This is
the click on a row in the Music page, so unlike `play` it needs the app running.

```
ed music start <target> [--folder] [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `target` | track path or query, or folder path with `--folder` | required | What to play. |
| `--folder` | flag | off | Treat the argument as a folder and play everything under it. |
| `--json` | flag | off | Emit JSON on stdout. |

```json
{
  "file": "alpha-song.mp3",
  "path": "alpha-song.mp3",
  "title": "Alpha Song"
}
```

With `--folder` the document is different:

```json
{
  "folder": true,
  "playing": "Chill"
}
```

```
ed music start alpha-song.mp3
ed music start "night drive"
ed music start --folder Chill
```

The check for the menu bar app comes first, before the track is even looked up,
so with Edith closed every form of this exits 4 with `playing from the library
needs the Edith menu bar app to be running`. There is no matching check on the
Music extension: with the extension off the request is posted into the void and
the command still exits 0.

The request is fire and forget. `ed` posts it and reports success without
waiting for the player to confirm, so a zero exit means the message was sent,
not that sound came out. What it posts for a single track is the same `toggle`
the UI posts when you click a row, which means running `ed music start` on the
track that is already playing pauses it rather than restarting it.

`--folder` currently posts a payload the running player does not read: the CLI
sends the folder under the keys `kind` and `path`, while the app's handler looks
for `sourceKind` and `sourcePath`. The command reports the folder and exits 0,
and nothing starts playing. Playing a specific track works.

### `ed music seek`

Jumps to a point in the current track, as a fraction of its length.

```
ed music seek <position> [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `position` | number from 0 to 1 | required | Where to jump to, as a fraction of the track. |
| `--json` | flag | off | Emit JSON on stdout. |

```json
{
  "position": 0.5
}
```

```
ed music seek 0
ed music seek 0.5
ed music seek 0.9 --json
```

The human line truncates to a whole percentage: `seeked to 50%`, and `0.999`
prints as `99%`. A position outside 0 to 1 exits 2 with `position must be
between 0 and 1`, and that check runs before the app check, so a bad number
fails the same way whether or not Edith is running.

This is the seek bar in the Music footer and it only drives Edith's own player.
There is no `--player`, and no way to seek Spotify or Apple Music from here.
With the menu bar app closed it exits 4.

### `ed music shuffle`

Turns shuffle on or off for Edith's own player, or reports it.

```
ed music shuffle [state] [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `state` | `on`, `off`, `true`, `false`, `yes`, `no`, `1`, `0`, `enabled`, `disabled` | none, which reports | What to set shuffle to. Leave it out to read the current value. |
| `--json` | flag | off | Emit JSON on stdout. |

```json
{
  "shuffle": true
}
```

```
ed music shuffle
ed music shuffle on
ed music shuffle off --json
```

Reading prints `on` or `off`. Setting prints `shuffle on` or `shuffle off` and
writes the `musicShuffling` preference, which is the same key
`ed config set musicShuffling true` writes and the same footer toggle the UI
shows. The write lands whether or not Edith is running; the notification that
tells a live player to reorder its queue only matters when one is listening, so
this never exits 4.

The words are matched case-insensitively. A word that is not one of them exits
1, not 2, with `<state> is not on or off` and the hint `pass on, off, true or
false`.

### `ed music repeat`

Turns repeat on or off for Edith's own player, or reports it. Aliased `loop`.

```
ed music repeat [state] [--json]
ed music loop [state] [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `state` | `on`, `off`, `true`, `false`, `yes`, `no`, `1`, `0`, `enabled`, `disabled` | none, which reports | What to set repeat to. Leave it out to read the current value. |
| `--json` | flag | off | Emit JSON on stdout. |

```json
{
  "repeat": false
}
```

```
ed music repeat
ed music loop on
ed music repeat off --json
```

Identical to `shuffle` in every way except the preference it writes,
`musicLooping`, the command it posts to a live player, `loop`, and the JSON key,
which is `repeat` rather than the internal name. Note the mismatch that follows
from that: the verb and the JSON key are `repeat`, the setting is
`musicLooping`, and the alias is `loop`.

### `ed music rescan`

Reads the music folder again, which is what to run after adding or removing
files behind Edith's back.

```
ed music rescan [--json]
```

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout. |

```json
{
  "tracks": 128,
  "wasTracks": 126
}
```

```
ed music rescan
ed music rescan --json
```

`wasTracks` is the count taken before the cached library root and per-folder
track counts were dropped, `tracks` the count after, so the two normally agree
and differ only when the stored folder itself moved. The human line prints just
the new count: `128 track(s) in the library`.

This walks the disk itself and needs nothing running, then posts
`requestMusicRescan` and `musicFolderChanged` so a live Edith rescans too. With
no music folder configured it exits 4.

## Exit codes

| Code | What produced it |
| --- | --- |
| 0 | The command did what it says. Also the dry run of `ed music rm` without `--yes`, and `ed music status --json` when no player is running. |
| 1 | A library operation the filesystem refused: a blank name, a destination that already exists, a Trash that failed, or trashing the library root. Also `shuffle` or `repeat` given a word that is neither on nor off. |
| 2 | `volume` or `seek` outside 0 to 1, a level or position that is not a number, an unknown flag, a missing argument. |
| 3 | An unknown `--player` spelling, a track query that matches nothing, a track query that matches more than one track, a folder that does not exist. |
| 4 | No player is running, or the forced player is not; no music folder is set; `start` or `seek` with the menu bar app closed; Edith's own player unreachable because the app is closed, the Music extension is off, or it did not answer in time; osascript refused, timed out, or macOS has not granted this command line Automation access. |

## Notes and gotchas

`ed music status` with no `--player` probes all three players in the order
`builtin`, `spotify`, `apple`, one after another. The built-in probe is skipped
instantly when the app is closed or the extension is off, and the AppleScript
probes return quickly when the player is not open, so the worst case is a slow
answer rather than a hang: 2 seconds for the built-in reply and 6 for each
script. `--player` cuts it to a single probe.

Automation failures are swallowed on the way in. Reading a player's state drops
any osascript error and treats the player as not running, and every transport
command probes before it sends, so with Automation denied `ed music status`
exits 4 with `no music player is running` and `ed music pause --player spotify`
exits 4 with `Spotify is not running` rather than naming the real cause. The
osascript error is reported verbatim only when the send itself fails after a
probe that worked: then `ed` exits 4 with
`macOS has not granted this command line Automation access` and points at
System Settings. That grant belongs to your terminal, not to Edith, and is
separate from anything `ed permissions` reports.

The last player you successfully drove is remembered in the `cliActivePlayer`
shared default and used only to break a tie between two players with the same
score. `status` and `players` read it; they never write it.

Every library command needs `musicFolderPath` to be set and exits 4 with
`no music folder is set` when it is not, even though none of them need the app.
Set it with `ed config set musicFolderPath ~/Music` or from the Music page. One
subtlety follows from where the app resolves that path: a folder on `/Volumes`
that the app has not confirmed is dropped in favour of `<repoPath>/local/music`
when `repoPath` is set and `~/Library/Application Support/Edith/music`
otherwise, so the checks pass but `ed music ls` lists the fallback folder rather
than the external drive.

Track queries are matched against the relative path and the derived title, never
against file tags, and the first exact relative-path hit wins before any
substring matching happens. That makes `ed music mv Chill/beta-tune.mp3 Focus`
unambiguous even when `beta` matches several files.

Favourites follow a rename or a move, including a folder rename, because the
stored relative paths are repointed as part of the move. They do not follow a
trash: `ed music rm` leaves the old path sitting in `musicFavourites`.

`ed music rename --folder "" <name>` renames the library folder itself, because
the empty path resolves to the library root and only `rm` guards against it.
That leaves `musicFolderPath` pointing at a folder that no longer exists.

`shuffle` and `repeat` write to the standard defaults domain, matching the
`.standard` scope those two settings declare in the config catalog, so
`ed config get musicShuffling` and `ed music shuffle` always agree.

Library mutations announce themselves on the app's notification bus:
`mkdir`, `mv`, `rename`, `rm` and `rescan` all post `musicFolderChanged`, and
`mv` and `rename` additionally post a `renamed` command so a running player
follows the file. None of them wait for an acknowledgement.

Every command in this group emits exactly one JSON document per invocation, with
object keys sorted, and prints diagnostics on stderr only. There is no streaming
mode here, so `--json` output is always pretty-printed.

## Where to go next

- [`ed config`](./config.md) sets `musicFolderPath`, `musicVolume`,
  `musicShuffling`, `musicLooping` and the rest of the `music` group.
- [`ed extensions`](./extensions.md) turns the `music` extension on, which is
  what makes the built-in player reachable at all.
- [`ed permissions`](./permissions.md) covers the grants that belong to the
  Edith bundle, which are not the Automation grant this group needs.
- [`ed download`](./download.md) is how tracks get into the library in the first
  place.
- [All command groups](./README.md)
