# `ed usage`

`ed usage` reports what your coding agents cost and how close you are to a
provider's rate limit. Every number is read back out of the two files the app's
dashboard already writes, `usage.json` and `limits-history.jsonl`, so `ed` never
recomputes anything and the CLI and the UI cannot disagree. Reach for it when
you want a spend figure in a script, a per-project breakdown without opening the
window, or a gate on how much session budget is left.

Both files live in `Repo.dataDir`, which is
`~/Library/Application Support/Edith/data` unless the `repoPath` setting names a
confirmed development checkout, in which case it is `apps/dashboard/data` inside
that checkout. Every verb here reads those files and works whether or not Edith
is running. Two invocations are the exception, `ed usage limits --refresh` and
`ed usage refresh`, which ask the app to go and collect fresh data before
reporting and exit 4 when it is closed.

## At a glance

| Command | What it does |
| --- | --- |
| `ed usage` | Runs `ed usage summary`, the default subcommand |
| `ed usage limits` | Session and weekly rate limits per provider, newest observation per provider |
| `ed usage summary` | Cost and tokens over a window, in total and per source |
| `ed usage daily` | Cost and tokens per calendar day, oldest first |
| `ed usage models` | Cost and tokens per model, most expensive first |
| `ed usage projects` | Cost and tokens per project, most expensive first |
| `ed usage sources` | The agents that produced the history, with their ids |
| `ed usage refresh` | Asks the running app to re-collect usage data |

## Commands

### `ed usage limits`

Prints the most recent rate limit observation for each provider Edith tracks.

```
ed usage limits [--refresh] [--json]
```

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--refresh` | flag | off | Asks the app to poll the providers again and waits up to 20 seconds for it to say it did, before reading the file |
| `--json` | flag | off | Emit JSON on stdout |

#### `--json` shape

A top-level array, one object per provider that has ever been recorded, in the
fixed order `codex` then `claude`. `session` and `weekly` are each either an
object or `null`.

```json
[
  {
    "label": "Codex",
    "observedAt": "2026-08-08T16:39:59Z",
    "provider": "codex",
    "session": null,
    "weekly": {
      "percent": 0,
      "resetsAt": "2026-08-15T16:39:59Z",
      "resetsInSeconds": 604797.62
    }
  },
  {
    "label": "Claude",
    "observedAt": "2026-08-08T16:39:58Z",
    "provider": "claude",
    "session": {
      "percent": 30,
      "resetsAt": "2026-08-08T19:50:00Z",
      "resetsInSeconds": 11402.481
    },
    "weekly": {
      "percent": 61,
      "resetsAt": "2026-08-13T08:00:00Z",
      "resetsInSeconds": 400798.117
    }
  }
]
```

#### Examples

```
ed usage limits
ed usage limits --json
ed usage limits --refresh
ed usage limits --json | jq -r '.[] | select(.provider == "claude") | .session.percent'
```

#### Behaviour

Without `--refresh` the command mutates nothing and needs no app: it reads the
tail of `limits-history.jsonl` and reports the last line it finds for each
provider. Only the final 8 KB of that file is read, so a provider whose newest
row has scrolled out of that window is treated as never seen and is left out of
the output entirely.

`percent` is what the provider reported, stored rounded to one decimal place.
`resetsAt` is the reset time the provider gave, or `null` when it gave none, and
`resetsInSeconds` is computed at print time from your clock, so it goes negative
once the reset moment has passed. The human table shows the session reset as a
coarse duration instead, `3h 10m` or `2d 4h`, clamped at zero, and a `-` in any
column the provider has not reported.

`--refresh` is the refresh button on the rate limit cards. It needs the menu bar
app and exits 4 with `refreshing the rate limits needs the Edith menu bar app to
be running` when Edith is closed. The reply it waits for is only posted when a
poll actually succeeds, so a provider that is failing to answer costs you the
full 20 seconds and then the old numbers are printed anyway, exit 0. After one
second of waiting `ed` prints `waiting for Edith to answer...` once, on stderr.

Unlike `ed usage refresh`, this one posts its request before it starts
listening, so an app that answers within the same instant can beat the listener
and cost you the full 20 seconds for a poll that in fact worked. The numbers
printed afterwards are read from the file either way, so the wait is the only
thing you lose.

Even a successful refresh does not guarantee a newer `observedAt`: the app
appends a history row only when the values differ from the previous one, so
polling twice inside a quiet window leaves the timestamp where it was.

When no provider has ever been recorded the command exits 4 with `no limit
history yet`, hinted with `enable the Agent Usage extension and let Edith poll
once`. That check comes after the refresh, so `--refresh` on a fresh install
does the poll and then reports the emptiness if nothing landed.

```
$ ed usage limits
PROVIDER  SESSION  WEEKLY  SESSION RESETS  OBSERVED
Codex     -        0.0%    -               2026-08-08T16:39:59Z
Claude    30.0%    61.0%   3h 10m          2026-08-08T16:39:58Z
```

### `ed usage summary`

Totals cost and tokens over a window, then breaks the same totals down by
source. This is what a bare `ed usage` runs.

```
ed usage summary [--range <range>] [--source <source>]... [--json]
```

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--range` | `today`, `week`, `month`, `all` | `all` | Which days to include: today only, the last 7 days, the last 30 days, or everything on file |
| `--source` | string, repeatable | every source | Count only these source ids. Repeat the flag to include several |
| `--json` | flag | off | Emit JSON on stdout |

#### `--json` shape

```json
{
  "bySource": {
    "cli": {
      "cacheCreationTokens": 175571245,
      "cacheReadTokens": 5445483888,
      "cost": 5094.730294150003,
      "inputTokens": 348913,
      "outputTokens": 16022050,
      "tokens": 5637426096
    },
    "codex": {
      "cacheCreationTokens": 0,
      "cacheReadTokens": 39030016,
      "cost": 28.771853,
      "inputTokens": 919731,
      "outputTokens": 155273,
      "tokens": 40105020
    }
  },
  "days": 7,
  "generatedAt": "2026-08-08T16:44:18Z",
  "range": "week",
  "totals": {
    "cacheCreationTokens": 175571245,
    "cacheReadTokens": 5484513904,
    "cost": 5123.502147150003,
    "inputTokens": 1268644,
    "outputTokens": 16177323,
    "tokens": 5677531116
  }
}
```

`tokens` is the sum of the other four token fields, not a separate figure from
the collector. `days` counts the days in the window that exist in the file, not
the length of the window, so a `week` range over four days of history reports
`4`. `generatedAt` is the string `usage.json` carries verbatim, and is `null`
when the file has no such field; `ed` does not reformat it.

#### Examples

```
ed usage summary
ed usage summary --range week
ed usage summary --range month --source cli --source codex
ed usage summary --range today --json | jq .totals.cost
```

#### Behaviour

Reads only, mutates nothing, and needs no app. It exits 4 when `usage.json` is
missing, 1 when the file is there but will not decode, and 3 when `--range` is
not one of the four ranges.

`--source` is not validated against the file. An id nobody recognises is not an
error: it matches nothing, so `totals` comes back at zero and `bySource` comes
back as `{}`, while `days` still counts the days in the window, exit 0. Run
`ed usage sources` first to get ids that exist.

The human output puts three lines above the table, a dollar sign only on the
cost line, and orders the table by source id:

```
$ ed usage summary --range week
cost    $5123.50
tokens  5677531116
days    7

SOURCE  COST     TOKENS
cli     5094.73  5637426096
codex   28.77    40105020
```

### `ed usage daily`

One row per day in the window, cost and tokens.

```
ed usage daily [--range <range>] [--source <source>]... [--json]
```

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--range` | `today`, `week`, `month`, `all` | `all` | Which days to include |
| `--source` | string, repeatable | every source | Count only these source ids. Repeat the flag to include several |
| `--json` | flag | off | Emit JSON on stdout |

#### `--json` shape

A top-level array sorted by `date` ascending. `totals` is the same six-field
object `ed usage summary` uses.

```json
[
  {
    "date": "2026-08-07",
    "totals": {
      "cacheCreationTokens": 26904348,
      "cacheReadTokens": 670275994,
      "cost": 647.5789594999999,
      "inputTokens": 180723,
      "outputTokens": 3836938,
      "tokens": 701198003
    }
  },
  {
    "date": "2026-08-08",
    "totals": {
      "cacheCreationTokens": 15319939,
      "cacheReadTokens": 765744244,
      "cost": 587.5631597500012,
      "inputTokens": 97362,
      "outputTokens": 3066068,
      "tokens": 784227613
    }
  }
]
```

#### Examples

```
ed usage daily --range week
ed usage daily --range month --source codex
ed usage daily --json | jq -r '.[] | [.date, .totals.cost] | @tsv'
```

#### Behaviour

Reads only, mutates nothing, and needs no app. Same exit codes as
`ed usage summary`: 4 with no `usage.json`, 1 on a file that will not decode, 3
on a bad `--range`.

Days are not filtered out by `--source`. A day that exists in the window but has
no rows for the sources you asked for still gets a row, with every total at
zero, so the date sequence stays continuous over the days the collector saw. It
is still not a calendar: days the collector never recorded are absent, not
zero-filled.

```
$ ed usage daily --range week
DATE        COST     TOKENS
2026-08-02  620.79   877878788
2026-08-03  761.36   729558198
2026-08-04  547.72   705959878
2026-08-05  1035.51  535978079
2026-08-06  922.99   1342730557
2026-08-07  647.58   701198003
2026-08-08  587.56   784227613
```

### `ed usage models`

Cost and tokens per model, so you can see which model is actually spending the
money.

```
ed usage models [--range <range>] [--source <source>]... [--json]
```

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--range` | `today`, `week`, `month`, `all` | `all` | Which days to include |
| `--source` | string, repeatable | every source | Count only these source ids. Repeat the flag to include several |
| `--json` | flag | off | Emit JSON on stdout |

#### `--json` shape

A top-level array sorted by `totals.cost` descending.

```json
[
  {
    "model": "claude-opus-5",
    "totals": {
      "cacheCreationTokens": 153031472,
      "cacheReadTokens": 4093821515,
      "cost": 3747.5389512500024,
      "inputTokens": 335270,
      "outputTokens": 13006480,
      "tokens": 4260194737
    }
  },
  {
    "model": "gpt-5.6-sol",
    "totals": {
      "cacheCreationTokens": 0,
      "cacheReadTokens": 39030016,
      "cost": 28.771853,
      "inputTokens": 919731,
      "outputTokens": 155273,
      "tokens": 40105020
    }
  }
]
```

#### Examples

```
ed usage models
ed usage models --range week
ed usage models --range month --source cli
ed usage models --json | jq -r '.[0].model'
```

#### Behaviour

Reads only, mutates nothing, and needs no app. Same exit codes as
`ed usage summary`.

A row whose model name is missing from the file is grouped under the literal
name `unknown` rather than dropped, so the model totals always add up to the
summary totals for the same window and sources.

```
$ ed usage models --range week
MODEL                      COST     TOKENS
claude-opus-5              3747.54  4260194737
claude-fable-5             1202.34  777247635
claude-sonnet-5            144.57   598911741
gpt-5.6-sol                28.77    40105020
claude-haiku-4-5-20251001  0.28     1071983
```

### `ed usage projects`

Cost and tokens per project, from the per-project rollup the collector attaches
to each day.

```
ed usage projects [--range <range>] [--limit <n>] [--json]
```

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--range` | `today`, `week`, `month`, `all` | `all` | Which days to include |
| `--limit` | integer greater than zero | `25` | Show at most this many projects, taken from the top of the cost order |
| `--json` | flag | off | Emit JSON on stdout |

This is the one window command that does not take `--source`. It declares its
own `--range`, so `--source` here is an unknown option and exits 2.

#### `--json` shape

A top-level array sorted by `cost` descending, truncated to `--limit`. The
per-project rows carry only cost and tokens, not the six-field totals object the
other commands use.

```json
[
  {
    "cost": 1837.7667801071357,
    "project": "noveum-app-nextjs",
    "tokens": 1887083203
  },
  {
    "cost": 1340.774043018298,
    "project": "edith",
    "tokens": 1664124164
  },
  {
    "cost": 988.1540715389959,
    "project": "fable",
    "tokens": 919092634
  }
]
```

#### Examples

```
ed usage projects
ed usage projects --range week --limit 5
ed usage projects --range today --json | jq -r '.[] | .project'
```

#### Behaviour

Reads only, mutates nothing, and needs no app. It exits 4 with no `usage.json`,
1 on a file that will not decode, 3 on a bad `--range`, and 2 on `--limit 0` or
a negative limit, which is checked as "must be greater than zero" rather than
read as "all of them".

A project's name is the collector's `projectName`, falling back to its path and
then to the literal `unknown`. Names come from the git root of the working
directory a chat ran in, which is why a chat run inside a worktree is attributed
to the repository rather than to the worktree folder, and why a machine's remote
projects arrive suffixed with the machine name.

These numbers come from a different part of the file than every other verb here:
`ed usage summary`, `daily` and `models` read `bySource`, while `projects` reads
the `projects` array. They are derived from the same transcripts but rolled up
separately, so the project totals will not tie out to the summary totals to the
cent, and no `--source` filter applies to them.

```
$ ed usage projects --range week --limit 5
PROJECT            COST     TOKENS
noveum-app-nextjs  1837.77  1887083203
edith              1340.77  1664124164
fable              988.15   919092634
macos              303.80   383653333
x-convo-exporter   228.97   191821868
```

### `ed usage sources`

Lists the agents that produced the history, which is where the ids `--source`
expects come from.

```
ed usage sources [--json]
```

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emit JSON on stdout |

#### `--json` shape

A top-level array in the file's own order, not sorted. `label` and `tool` are
`null` when the file carries no metadata for that id.

```json
[
  {
    "default": true,
    "id": "cli",
    "label": "Claude Code",
    "tool": "Claude Code"
  },
  {
    "default": true,
    "id": "codex",
    "label": "Codex",
    "tool": "Codex"
  },
  {
    "default": true,
    "id": "commandcode",
    "label": "Command Code",
    "tool": "Command Code"
  },
  {
    "default": true,
    "id": "asus-tuf-7:cli",
    "label": "Claude Code · Asus TUF 7",
    "tool": "Claude Code"
  },
  {
    "default": true,
    "id": "opencode",
    "label": "OpenCode",
    "tool": "OpenCode"
  },
  {
    "default": true,
    "id": "cowork",
    "label": "Cowork",
    "tool": "Claude Code"
  }
]
```

`default` says whether the id is in the file's `defaultSources`, which is the
set the dashboard pre-selects. It is not a filter `ed` applies anywhere: every
read command counts every source unless you pass `--source`.

#### Examples

```
ed usage sources
ed usage sources --json
ed usage sources --json | jq -r '.[].id'
```

#### Behaviour

Reads only, mutates nothing, and needs no app. It exits 4 with no `usage.json`
and 1 on a file that will not decode. It takes no window options, so there is no
exit 3 here.

The human table falls back to the id in the `LABEL` column when the file has no
label, and prints an empty `TOOL` cell when it has no tool. When the file lists
no sources at all the command prints the header line by itself and exits 0.
`ed` reads only `label` and `tool` out of the file's per-source metadata, so
extra fields the collector writes for remote sources, such as the machine name
and id behind an `asus-tuf-7:cli`, do not appear in `--json`.

```
$ ed usage sources
ID              LABEL                     TOOL
cli             Claude Code               Claude Code
codex           Codex                     Codex
commandcode     Command Code              Command Code
asus-tuf-7:cli  Claude Code · Asus TUF 7  Claude Code
opencode        OpenCode                  OpenCode
cowork          Cowork                    Claude Code
```

### `ed usage refresh`

Asks the running app to re-collect usage data and rewrite `usage.json`.

```
ed usage refresh [--no-wait] [--json]
```

#### Options

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--no-wait` | flag | off | Return as soon as the request is sent, instead of waiting up to 180 seconds for the app to finish |
| `--json` | flag | off | Emit JSON on stdout |

#### `--json` shape

```json
{
  "completed": true,
  "requested": true
}
```

`requested` is always `true`: reaching the JSON at all means the request went
out. `completed` says whether the app answered inside the timeout.

#### Examples

```
ed usage refresh
ed usage refresh --no-wait
ed usage refresh --json | jq .completed
ed usage refresh && ed usage summary --range today
```

#### Behaviour

This is the only verb in the group that changes anything, and the change is made
by the app, not by `ed`. It needs the menu bar app and exits 4 with `refreshing
usage needs the Edith menu bar app to be running`, hinted `start Edith, then
retry`, when Edith is closed. The collection itself is the app running its
bundled `refresh-usage` script, the same work the dashboard's refresh does, and
it takes noticeably longer on a first run, because the collector installs
`ccusage` before it can read anything.

By default `ed` waits up to 180 seconds for the app to say it finished and then
prints `usage refreshed`; `--no-wait` collapses that wait to 0.1 seconds, which
in practice always times out, so it prints `refresh requested` and returns. Once
a second has passed `ed` prints `waiting for Edith to answer...` once, on
stderr.

A timeout is not an error. The command exits 0 either way, with `completed`
recording which happened, so exit code alone is not a signal that fresh data
landed. Neither is `completed: true`: the app posts its finished notification
from the collector's termination handler whatever status the script exited with,
so a collection that failed still reports as completed and leaves the previous
`usage.json` in place. If you need to know the data moved, compare
`generatedAt` from `ed usage summary --json` before and after.

## Exit codes

| Code | When this group produces it |
| --- | --- |
| 0 | The command printed its report. Also a refresh that timed out, and a read that legitimately found nothing to show |
| 1 | `usage.json` exists but will not decode: `could not read <path>: <reason>` |
| 2 | `--limit 0` or a negative limit on `ed usage projects`, plus the usual parse failures, an unknown flag, a missing value, or `--source` passed to `ed usage projects` |
| 3 | `--range` is not `today`, `week`, `month` or `all`. The hint lists the four |
| 4 | No `usage.json` at all; no rate limit history at all; or Edith is not running for `ed usage refresh` and `ed usage limits --refresh` |

## Notes and gotchas

- `ed usage` with no subcommand runs `ed usage summary`, so a bare `ed usage`
  prints the all-time totals rather than a help screen. `ed usage --help` is
  still the help screen, and exits 0.
- The two files are independent. `ed usage limits` reads only
  `limits-history.jsonl` and works with no `usage.json` at all; every other verb
  reads only `usage.json` and works with no limit history. Neither absence
  affects the other.
- `--range week` means the last 7 days and `--range month` the last 30, both
  counted back from midnight today and both including today. The comparison is
  made on the `YYYY-MM-DD` string, so it is your local calendar day, and there
  is no upper bound: a day stamped in the future is always included.
- Cost and token figures are doubles all the way through, and the serialiser
  prints an integral double as an integer. `"percent": 30` is 30.0 and
  `"cost": 0` is a genuine zero, not a missing field.
- Token counts in the human tables are truncated to a whole number, not rounded,
  and costs are formatted to two decimal places. Only `--json` gives you the
  unrounded values.
- Object keys in `--json` are sorted, arrays keep the order the command chose:
  fixed provider order for `limits`, date ascending for `daily`, cost descending
  for `models` and `projects`, and the file's own order for `sources`.
- Nothing here reaches the network. `--refresh` and `refresh` post a
  notification and wait; the polling and collecting happen inside the app, which
  is also why the numbers `ed` prints can only ever be as fresh as the last
  thing the app wrote.
- A refresh that the app never answers leaves both commands exiting 0 with the
  file's existing contents, so a script that must have current data should check
  `generatedAt` or `observedAt` rather than trusting the exit code.
- `ed config set tabUsageEnabled false` turns off the Agent Usage extension, and
  with it the collection and the limit polling; `claudeLimitsEnabled` and
  `codexLimitsEnabled` do the same for a single provider's polling. The read
  verbs keep working against whatever was collected before that, so
  `ed usage limits` goes on printing a silenced provider's last row until it
  scrolls out of the 8 KB tail.

## Where to go next

- [`ed config`](./config.md) for `tabUsageEnabled`, `claudeLimitsEnabled`,
  `codexLimitsEnabled` and `repoPath`, which decide what gets collected and
  where it lands
- [`ed extensions`](./extensions.md) for turning the Agent Usage extension on
  and off by id
- [`ed permissions`](./permissions.md) for the grants the app needs before it
  can collect anything
- [`ed system`](./system.md) for this Mac's metrics, the other read-only
  reporting group
- [All `ed` commands](./README.md)
