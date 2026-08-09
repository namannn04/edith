# `ed companion`

`ed companion` talks to Edith's local memory backend. The companion stores
Markdown notes as append-only episodes in Postgres, keeps the original note in
its vault, and deduplicates sources by their SHA-256 content hash.

Run the backend with docker compose from `apps/companion`. The CLI reaches it
directly on this Mac or through an `ed machines` port forward. Pass
`--endpoint` for one invocation, set `EDITH_COMPANION_URL` for a shell, or use
the default `http://127.0.0.1:4820`.

## At a glance

| Command | What it does |
| --- | --- |
| `ed companion` | Runs `ed companion status`, the default subcommand. |
| `ed companion status` | Counts stored sources, episodes, claims and observations. |
| `ed companion doctor` | Checks Postgres, migrations, pgvector, Redis and the vault. |
| `ed companion ingest <path>` | Sends one Markdown file or a recursive folder scan to the backend. |
| `ed companion episodes` | Lists recent episodes, newest first. |

## Commands

### `ed companion status`

Reports how much the companion currently stores and when an episode was most
recently ingested.

Usage:

```
ed companion status [--json] [--endpoint <url>]
```

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emits one JSON document on stdout. |
| `--endpoint` | URL | environment or local default | Uses this Companion API base URL. |

`--json` shape:

```json
{
  "claims": 18,
  "episodes": 42,
  "latestIngestedAt": "2026-08-09T08:14:22.301Z",
  "observations": 64,
  "sources": 39
}
```

`sources` counts unique note bodies, `episodes` counts appended memory events,
and `claims` and `observations` count derived records. `latestIngestedAt` is the
most recent ingest time as an ISO 8601 string, or `null` when no episode exists.

Examples:

```
$ ed companion status
RESOURCE      COUNT
sources       39
episodes      42
claims        18
observations  64
latest  2026-08-09T08:14:22.301Z

$ ed companion status --endpoint http://127.0.0.1:4821 --json
{
  "claims": 18,
  "episodes": 42,
  "latestIngestedAt": "2026-08-09T08:14:22.301Z",
  "observations": 64,
  "sources": 39
}
```

Behaviour: this is a read-only `GET /v1/status`. A bare `ed companion` runs the
same command. If no API answers at the resolved endpoint, stdout stays empty,
the diagnostic names that endpoint on stderr, and the command exits 4.

### `ed companion doctor`

Asks the backend to check each service it depends on.

Usage:

```
ed companion doctor [--json] [--endpoint <url>]
```

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emits one JSON document on stdout. |
| `--endpoint` | URL | environment or local default | Uses this Companion API base URL. |

`--json` shape:

```json
{
  "checks": [
    { "detail": "connected", "name": "postgres", "ok": true },
    { "detail": "3 of 3 migrations applied", "name": "migrations", "ok": true },
    { "detail": "installed", "name": "pgvector", "ok": true },
    { "detail": "connected", "name": "redis", "ok": true },
    { "detail": "writable", "name": "vault", "ok": true }
  ],
  "ok": true
}
```

`ok` is true only when every check passed. Each item in `checks` has the
dependency `name`, its own Boolean `ok`, and a human-readable `detail` from the
backend.

Examples:

```
$ ed companion doctor
postgres  ok  connected
migrations  ok  3 of 3 migrations applied
pgvector  ok  installed
redis  ok  connected
vault  ok  writable

$ ed companion doctor --json
{
  "checks": [
    { "detail": "connected", "name": "postgres", "ok": true }
  ],
  "ok": true
}
```

Behaviour: `doctor` decodes the health report even when the API returns HTTP
503. A reachable but unhealthy backend still exits 0 because health lives in
the payload, where scripts can inspect `ok`. Failure to reach the API exits 4.

### `ed companion ingest`

Scans Markdown and posts it to the companion in batches.

Usage:

```
ed companion ingest <path> [--json] [--endpoint <url>]
```

Arguments:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<path>` | `.md` file or directory | required | Reads one note or recursively finds Markdown below a folder. |

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emits one JSON document on stdout. |
| `--endpoint` | URL | environment or local default | Uses this Companion API base URL. |

`--json` shape:

```json
{
  "duplicates": 1,
  "ingested": 1,
  "results": [
    {
      "episodeId": "5d4c0ebf-1086-46fb-ab93-dd325ed197f3",
      "name": "daily/2026-08-09.md",
      "occurredAt": "2026-08-09T06:30:00.000Z",
      "status": "ingested"
    },
    {
      "episodeId": "b938dfb5-cc52-477c-8be2-3997c59931aa",
      "name": "projects/edith.md",
      "occurredAt": "2026-08-08T18:10:00.000Z",
      "status": "duplicate"
    }
  ],
  "skipped": 1
}
```

`ingested`, `duplicates` and `skipped` are counts for the whole scan. Every
posted file has one item in `results`: `name` is the filename or its path
relative to the scanned folder, `status` is `ingested` or `duplicate`,
`episodeId` identifies the stored episode, and `occurredAt` is its ISO 8601
event time. Oversized files are counted in `skipped` but have no result item.

Examples:

```
$ ed companion ingest ./notes
ingested  daily/2026-08-09.md
duplicate  projects/edith.md
1 ingested, 1 duplicates, 0 skipped

$ ed companion ingest ./notes --json
{
  "duplicates": 0,
  "ingested": 0,
  "results": [],
  "skipped": 0
}
```

Behaviour: a directory walk is recursive, skips hidden files, and sorts names
before upload. The file modification time is sent as a fallback event time.
Files larger than 2MB are skipped with a note on stderr. No matching file is a
usage error. Accepted files are posted in batches of at most 200.

### `ed companion episodes`

Lists the most recent episodes ordered by occurrence time.

Usage:

```
ed companion episodes [--limit <n>] [--json] [--endpoint <url>]
```

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--limit` | positive integer | `20` | Asks for this many recent episodes. The API caps it at 200. |
| `--json` | flag | off | Emits one JSON document on stdout. |
| `--endpoint` | URL | environment or local default | Uses this Companion API base URL. |

`--json` shape:

```json
[
  {
    "id": "5d4c0ebf-1086-46fb-ab93-dd325ed197f3",
    "kind": "md",
    "occurredAt": "2026-08-09T06:30:00.000Z",
    "sha256": "a46b0c249b09d97a9a2eeb66e995fe56d6513fbb80a4f711f846d6b92e98a1e3",
    "title": "Planning notes"
  }
]
```

Each item has its episode `id`, ISO 8601 `occurredAt`, source `kind`, display
`title`, and the source content hash in `sha256`.

Examples:

```
$ ed companion episodes --limit 3
#  TITLE           KIND  OCCURRED
1  Planning notes  md    2026-08-09T06:30:00.000Z
2  Edith launch    md    2026-08-08T18:10:00.000Z

$ ed companion episodes --limit 50 --json
[
  {
    "id": "5d4c0ebf-1086-46fb-ab93-dd325ed197f3",
    "kind": "md",
    "occurredAt": "2026-08-09T06:30:00.000Z",
    "sha256": "a46b0c249b09d97a9a2eeb66e995fe56d6513fbb80a4f711f846d6b92e98a1e3",
    "title": "Planning notes"
  }
]
```

Behaviour: this is a read-only `GET /v1/episodes`. `--limit` must be greater
than zero. The backend returns at most 200 items, and an empty backend returns
an empty JSON array or a table header with no rows.

## Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Success, including a reachable doctor report whose `ok` is false. |
| `1` | General failure. |
| `2` | Bad usage, including a missing Markdown path or a non-positive limit. |
| `4` | The companion backend is unreachable or returned an unusable response. |

## Notes and gotchas

`--endpoint` wins over `EDITH_COMPANION_URL`, which wins over
`http://127.0.0.1:4820`. A saved machine forward can put a remote companion on
that local address: run `ed machines forwards on tuf 2`, then
`ed companion status`.

Each Markdown file must be no larger than 2MB. Larger notes are skipped before
any request, and uploads are split into batches of 200 files. The backend
deduplicates by SHA-256 of the note text, so ingesting the same content again is
safe and returns `duplicate` with the original episode id.

## Where to go next

Use [`ed machines`](./machines.md) to create and open a port forward. Read
[conventions and contracts](./conventions.md) for JSON, stdout, stderr and exit
code guarantees shared by every command.
