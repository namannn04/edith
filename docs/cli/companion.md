# `ed companion`

`ed companion` talks to Edith's local memory backend. The companion stores
Markdown notes as append-only episodes in Postgres, keeps the original note in
its vault, and deduplicates sources by their SHA-256 content hash.

Run the backend with docker compose from `apps/companion`. The CLI reaches it
directly on this Mac or through an `ed machines` port forward. Pass
`--endpoint` for one invocation, set `EDITH_COMPANION_URL` for a shell, or use
the default `http://127.0.0.1:4820`.

This page is the command reference. For the machinery behind it, the vault,
chunking, embeddings, retrieval, claims, beliefs and the nightly loop, read
[How the companion works](./companion-concepts.md).

## At a glance

| Command | What it does |
| --- | --- |
| `ed companion` | Runs `ed companion status`, the default subcommand. |
| `ed companion status` | Counts stored records and episodes waiting to be indexed. |
| `ed companion doctor` | Checks Postgres, migrations, pgvector, Redis and the vault. |
| `ed companion search <query>` | Searches indexed memory with hybrid retrieval. |
| `ed companion index` | Embeds episodes that are waiting to be indexed. |
| `ed companion ingest <path>` | Sends one Markdown file or a recursive folder scan to the backend. |
| `ed companion episodes` | Lists recent episodes, newest first. |
| `ed companion episode <id>` | Reads one episode in full, body included. |
| `ed companion chat <message>` | Talks with the companion, streamed as it thinks. |
| `ed companion conversations` | Lists chats, or replays one by id. |
| `ed companion forget <id>` | Deletes a conversation and its messages. |
| `ed companion nightly` | Runs the nightly learning pipeline right now. |
| `ed companion reason` | Shows or changes the reasoning provider, model and API key. |

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
  "chunks": 126,
  "claims": 18,
  "episodes": 42,
  "latestIngestedAt": "2026-08-09T08:14:22.301Z",
  "observations": 64,
  "pendingEpisodes": 2,
  "sources": 39
}
```

`sources` counts unique note bodies, `episodes` counts appended memory events,
and `claims` and `observations` count derived records. `chunks` counts embedded
search chunks, and `pendingEpisodes` counts episodes that have no chunks yet.
`latestIngestedAt` is the most recent ingest time as an ISO 8601 string, or
`null` when no episode exists.

Examples:

```
$ ed companion status
RESOURCE          COUNT
sources           39
episodes          42
claims            18
observations      64
chunks            126
pending episodes  2
latest  2026-08-09T08:14:22.301Z

$ ed companion status --endpoint http://127.0.0.1:4821 --json
{
  "chunks": 126,
  "claims": 18,
  "episodes": 42,
  "latestIngestedAt": "2026-08-09T08:14:22.301Z",
  "observations": 64,
  "pendingEpisodes": 2,
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

### `ed companion search`

Searches embedded memory chunks with hybrid vector and full-text retrieval.

Usage:

```
ed companion search <query> [--limit <n>] [--json] [--endpoint <url>]
```

Arguments:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<query>` | text | required | Supplies the memory search text. |

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--limit` | integer from `1` to `50` | `8` | Asks for this many ranked hits. |
| `--json` | flag | off | Emits one JSON array on stdout. |
| `--endpoint` | URL | environment or local default | Uses this Companion API base URL. |

`--json` shape:

```json
[
  {
    "chunkId": "ad5085e1-6c90-471f-a58d-16e028423d10",
    "episodeId": "5d4c0ebf-1086-46fb-ab93-dd325ed197f3",
    "kind": "md",
    "occurredAt": "2026-08-09T06:30:00Z",
    "ord": 0,
    "score": 0.032787,
    "snippet": "The launch plan calls for a staged rollout after the warden review.",
    "title": "Planning notes"
  }
]
```

Each hit identifies its chunk and parent episode with `chunkId` and
`episodeId`. `ord` is the chunk position in the episode. `title`, `occurredAt`
and `kind` describe the source episode, `snippet` contains matching text, and
`score` is the fused retrieval score.

Examples:

```
$ ed companion search "launch plan" --limit 3
#  SCORE     TITLE           OCCURRED
1  0.032787  Planning notes  2026-08-09T06:30:00Z
  1  The launch plan calls for a staged rollout after the warden review.

$ ed companion search "nothing like this" --json
[]
```

Behaviour: this is a read-only `GET /v1/search`. The query is URL encoded and
`--limit` must be from 1 through 50. No hits print `no matches` in human output
or `[]` with `--json`. If the embedding service returns HTTP 502, the command
names the Ollama embedding service, leaves stdout empty, and exits 4.

### `ed companion index`

Embeds pending episodes and stores their searchable chunks.

Usage:

```
ed companion index [--json] [--endpoint <url>]
```

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emits one JSON document on stdout. |
| `--endpoint` | URL | environment or local default | Uses this Companion API base URL. |

`--json` shape:

```json
{
  "chunksCreated": 9,
  "episodesIndexed": 3
}
```

`episodesIndexed` counts episodes completed by this request, and
`chunksCreated` counts the searchable chunks created for them.

Examples:

```
$ ed companion index
indexed 3 episodes into 9 chunks

$ ed companion index --json
{
  "chunksCreated": 9,
  "episodesIndexed": 3
}
```

Behaviour: this mutating command sends `POST /v1/index` with an empty body.
Only episodes without chunks are indexed. If the embedding service returns
HTTP 502, the command names the Ollama embedding service, leaves stdout empty,
and exits 4.

### `ed companion ingest`

Scans Markdown, audio recordings and PDFs and posts them to the companion.

Usage:

```
ed companion ingest <path> [--json] [--endpoint <url>]
```

Arguments:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<path>` | `.md`, audio or `.pdf` file, or a directory | required | Reads one file or recursively finds Markdown, audio (`.wav`, `.m4a`, `.mp3`, `.ogg`, `.flac`, `.aiff`) and PDFs below a folder. |

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
Markdown larger than 2MB and audio larger than 48MB are skipped with a note on
stderr. No matching file is a usage error. Markdown is posted in batches of at
most 200; audio uploads one file at a time and waits while the companion
transcribes it with whisper.cpp, so a long recording takes a while. The
transcript becomes the episode body with kind `voice`, the detected language,
the duration, and per-segment timings kept in the episode metadata. PDFs upload
one at a time and land as kind `pdf` with their extracted text as the body;
scanned PDFs without a text layer are rejected with a clear error.

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

### `ed companion sync`

Pulls a connector's recent activity into the observations table.

Usage:

```
ed companion sync <connector> [--json] [--endpoint <url>]
```

Arguments:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<connector>` | `github` | required | Which connector to sync; only `github` exists so far. |

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emits one JSON document on stdout. |
| `--endpoint` | URL | environment or local default | Uses this Companion API base URL. |

`--json` shape:

```json
{
  "eventsFetched": 87,
  "observationsInserted": 42
}
```

`eventsFetched` counts the GitHub events read this run; `observationsInserted` counts the observations that were new. Re-running immediately inserts nothing because every observation carries a dedupe key.

Examples:

```
$ ed companion sync github
fetched 87 events, 42 new observations
```

Behaviour: the companion reads up to three pages of the authenticated user's GitHub events with the token in its `GITHUB_TOKEN` environment variable. Push events become one `commit` observation per commit; pull request, issue and review events each become one observation. Without a configured token the companion answers 412 and the command fails with exit 4.

### `ed companion observations`

Lists the behavioural record the connectors have gathered.

Usage:

```
ed companion observations [--json] [--endpoint <url>] [--limit <n>] [--kind <kind>]
```

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emits one JSON document on stdout. |
| `--endpoint` | URL | environment or local default | Uses this Companion API base URL. |
| `--limit` | 1 to 200 | 20 | How many observations to list. |
| `--kind` | `commit`, `pull_request`, `issue`, `review` | all | Only this observation kind. |

`--json` shape:

```json
[
  {
    "id": "0d5c53a4-52f0-4be3-a121-c7f3ac53f7de",
    "kind": "commit",
    "observedAt": "2026-08-09T09:12:44Z",
    "source": "github",
    "summary": "pulkitxm/edith 72d2aeb Route audio files through ed companion ingest"
  }
]
```

Each item is one observed action: `source` names the connector, `kind` the action type, `summary` a one-line rendering, and `observedAt` when it happened. Newest first.

Examples:

```
$ ed companion observations --kind commit --limit 3
#  KIND    SUMMARY                                       OBSERVED
1  commit  pulkitxm/edith 72d2aeb Route audio files ...  2026-08-09T09:12:44Z
```

Behaviour: read-only; an empty record prints a quiet line. Observations are what corroboration will check your claims against, so they never come from anything you wrote for the companion.

### `ed companion reflect`

Asks the companion's reasoning provider to distill durable beliefs from recent episodes.

Usage:

```
ed companion reflect [--json] [--endpoint <url>]
```

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emits one JSON document on stdout. |
| `--endpoint` | URL | environment or local default | Uses this Companion API base URL. |

`--json` shape:

```json
{
  "beliefsFormed": 2,
  "episodesConsidered": 7,
  "model": "anthropic, model claude-sonnet-5"
}
```

`episodesConsidered` counts the episodes read this run, `beliefsFormed` the new beliefs that survived validation, and `model` names the provider that did the thinking.

Examples:

```
$ ed companion reflect
considered 7 episodes, formed 2 beliefs (anthropic, model claude-sonnet-5)
```

Behaviour: the companion reads its most recent episodes and asks the configured reasoner for two to five higher-order beliefs, each citing the episode ids it rests on. Candidates that cite unknown episodes, cite nothing, or restate an existing active belief are dropped. The provider is Anthropic when `ANTHROPIC_API_KEY` is set on the companion, or any OpenAI-compatible endpoint via `REASON_PROVIDER=openai` and `REASON_URL`; with neither configured the command fails with exit 4.

### `ed companion beliefs`

Lists the beliefs the reflection pass has formed, newest first.

Usage:

```
ed companion beliefs [--json] [--endpoint <url>] [--limit <n>]
```

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emits one JSON document on stdout. |
| `--endpoint` | URL | environment or local default | Uses this Companion API base URL. |
| `--limit` | 1 to 200 | 20 | How many to list. |

`--json` shape:

```json
[
  {
    "confidence": 0.7,
    "evidenceEpisodeIds": ["ade45706-c7e0-480c-9125-11503509bef2"],
    "firstFormed": "2026-08-09T16:20:11Z",
    "id": "3f7f7a68-0f4b-4f0f-9dd6-6cf2b1f7f0aa",
    "kind": "pattern",
    "statement": "Ships work in small, frequently pushed increments.",
    "status": "active"
  }
]
```

Each belief carries its `statement`, a `kind` of `pattern`, `preference` or `state`, the extractor's `confidence`, when it was `firstFormed`, the `evidenceEpisodeIds` it cites, and its `status`. Beliefs are never deleted, only superseded or retired.

Examples:

```
$ ed companion beliefs --limit 1
1. [pattern, 70%] Ships work in small, frequently pushed increments.
   evidence: 3 episodes, since 2026-08-09T16:20:11Z
```

Behaviour: read-only. An empty list suggests running `ed companion reflect` first.

### `ed companion ask`

Answers a question from your own memory, citing the episodes the answer rests on.

Usage:

```
ed companion ask <question> [--json] [--endpoint <url>]
```

Arguments:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `<question>` | text | required | The question to answer. |

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emits one JSON document on stdout. |
| `--endpoint` | URL | environment or local default | Uses this Companion API base URL. |

`--json` shape:

```json
{
  "answer": "The auth refactor shipped in March, and it felt slower than it should have.",
  "chunksConsidered": 8,
  "citations": [
    {
      "episodeId": "ade45706-c7e0-480c-9125-11503509bef2",
      "occurredAt": "2026-03-14T00:00:00Z",
      "quote": "Shipped the auth refactor this week. Felt slower than it should have been.",
      "support": "verbatim",
      "title": "Warden retro"
    }
  ],
  "model": "anthropic, model claude-sonnet-5"
}
```

`answer` is the grounded reply, `citations` the episodes it rests on, `chunksConsidered` how many memory chunks were retrieved, and `model` the reasoner that answered. `support` types each citation: `verbatim` is checked structurally, the quote must actually appear in the cited text or the label demotes to `paraphrase`; `inference` marks the reasoner reading between the lines and renders that way.

Examples:

```
$ ed companion ask "how did the auth refactor go"
The auth refactor shipped in March, and it felt slower than it should have.
[1] Warden retro (2026-03-14T00:00:00Z)  [verbatim]
    "Shipped the auth refactor this week. Felt slower than it should have been."
```

Behaviour: the companion retrieves the eight nearest chunks by embedding, hands them to the reasoner tagged by episode id, and drops any citation that names an episode the reasoner was not shown, so an answer can only cite what it actually read. When the memory holds nothing relevant the answer says so. Needs a reasoning provider like `ed companion reflect`; exit 4 without one.

### `ed companion extract`

Pulls the claims you made out of episodes that have none yet.

Usage:

```
ed companion extract [--json] [--endpoint <url>]
```

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emits one JSON document on stdout. |
| `--endpoint` | URL | environment or local default | Uses this Companion API base URL. |

`--json` shape:

```json
{
  "claimsExtracted": 4,
  "episodesConsidered": 3
}
```

Examples:

```
$ ed companion extract
considered 3 episodes, extracted 4 claims
```

Behaviour: the reasoner reads up to ten episodes without claims and records each assertion with a type (`fact`, `intention`, `commitment`, `progress`, `self_assessment`, `prediction`, `preference`, `feeling`) and whether independent records could test it. Needs a reasoning provider; exit 4 without one.

### `ed companion claims`

Lists the extracted claims, newest first, with the latest verdict where one exists.

Usage:

```
ed companion claims [--json] [--endpoint <url>] [--limit <n>]
```

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emits one JSON document on stdout. |
| `--endpoint` | URL | environment or local default | Uses this Companion API base URL. |
| `--limit` | 1 to 200 | 20 | How many to list. |

`--json` shape:

```json
[
  {
    "assertedAt": "2026-03-14T00:00:00Z",
    "claimType": "progress",
    "id": "77b7a0e2-4a37-4b3f-8b0f-0a9d1c2c8e21",
    "statement": "Shipped the auth refactor this week.",
    "testable": true,
    "verdict": "corroborated",
    "verdictNote": "Commits to the auth paths land in the same week."
  }
]
```

`verdict` and `verdictNote` are null until a corroboration pass has judged the claim.

Examples:

```
$ ed companion claims --limit 1
1. [progress] -> corroborated Shipped the auth refactor this week.
   Commits to the auth paths land in the same week.
```

Behaviour: read-only.

### `ed companion corroborate`

Judges unchecked testable claims against the observations recorded around when they were made.

Usage:

```
ed companion corroborate [--json] [--endpoint <url>]
```

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emits one JSON document on stdout. |
| `--endpoint` | URL | environment or local default | Uses this Companion API base URL. |

`--json` shape:

```json
{
  "claimsChecked": 2,
  "contradicted": 0,
  "corroborated": 1,
  "unclear": 1
}
```

Examples:

```
$ ed companion corroborate
checked 2 claims: 1 corroborated, 0 contradicted, 1 unclear
```

Behaviour: up to ten unchecked `progress`, `commitment` and `fact` claims are compared against the observations within four days of their assertion. The verdict is `corroborated`, `contradicted` or `unclear` with a one-line note; missing records always read as `unclear`, never as contradiction. Needs a reasoning provider; exit 4 without one.

### `ed companion runs`

Lists the background learning runs the scheduler has recorded.

Usage:

```
ed companion runs [--json] [--endpoint <url>] [--limit <n>]
```

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--json` | flag | off | Emits one JSON document on stdout. |
| `--endpoint` | URL | environment or local default | Uses this Companion API base URL. |
| `--limit` | 1 to 200 | 10 | How many to list. |

`--json` shape:

```json
[
  {
    "finishedAt": "2026-08-10T02:03:11Z",
    "id": "b0a3e2c1-9a70-40dd-b1b4-2e0a1f5c7d90",
    "ok": true,
    "startedAt": "2026-08-10T02:00:00Z",
    "steps": [
      { "name": "sync_github", "ok": true },
      { "name": "index", "ok": true },
      { "name": "extract_claims", "ok": true },
      { "name": "corroborate", "ok": true },
      { "name": "reflect", "ok": true }
    ]
  }
]
```

Examples:

```
$ ed companion runs --limit 1
1. 2026-08-10T02:00:00Z  ok  sync_github, index, extract_claims, corroborate, reflect
```

Behaviour: read-only. The companion runs the pipeline once a night at `COMPANION_REFLECT_AT` (02:00 by default) in the backend's local time, or continuously every `COMPANION_SCHEDULE_EVERY_SECONDS` when that testing override is set. Steps that lack their prerequisite, like a missing GitHub token or reasoning provider, record themselves as skipped rather than failing the run. `POST /v1/nightly/run` triggers one manually.

### `ed companion chat`

Talks with the companion. Retrieval grounds the reply in your own episodes, the
reply streams to stdout as the model produces it, and validated citations print
after it. Every exchange persists, so a conversation can be continued later
from any machine.

Usage:

```
ed companion chat <message> [--conversation <id>] [--json] [--endpoint <url>]
```

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--conversation` | conversation id | new conversation | Continues that conversation with its history in context. |
| `--json` | flag | off | Suppresses streaming and emits one JSON document at the end. |
| `--endpoint` | URL | environment or local default | Uses this Companion API base URL. |

`--json` shape:

```json
{
  "answer": "You shipped the auth refactor and kept avoiding the billing migration.",
  "chunksConsidered": 8,
  "citations": [
    {
      "episodeId": "6a7c1f0e-6f0f-4bb0-9d3a-2f6f6f0e1a2b",
      "occurredAt": "2026-08-05T09:00:00Z",
      "quote": "shipped the session-scoped tokens today",
      "support": "verbatim",
      "title": "auth-refactor.md"
    }
  ],
  "conversationId": "e3b6d2a4-27c8-4f7c-9b7e-3e2b1a0c9d8f",
  "latencyMs": 1874,
  "model": "anthropic, model claude-sonnet-5"
}
```

The conversation id prints on stderr after a plain-text chat; pass it back with
`--conversation` to keep talking in the same thread.

Behaviour: requires a configured reasoning provider (`ed companion reason`);
without one the backend answers 412 and the command exits `4`.

### `ed companion conversations`

Lists conversations newest-first, or replays one in full when an id is given.

Usage:

```
ed companion conversations [<id>] [--limit <n>] [--json] [--endpoint <url>]
```

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--limit` | positive integer | `20` | How many conversations to list. |
| `--json` | flag | off | Emits one JSON document on stdout. |
| `--endpoint` | URL | environment or local default | Uses this Companion API base URL. |

Without an id the JSON is an array of
`{id, title, createdAt, lastActiveAt, messageCount, lastMessage}`; with an id it
is one `{id, title, createdAt, messages}` object whose messages carry `role`,
`content`, `citations`, `model` and `createdAt`.

### `ed companion forget`

Deletes a conversation and every message in it.

Usage:

```
ed companion forget <id> [--json] [--endpoint <url>]
```

`--json` shape: `{"deleted": "<conversation id>"}`. Unknown ids exit `4` with
the backend's `no such conversation` detail.

### `ed companion episode`

Reads one episode in full: the metadata the list view shows, plus the whole
body text.

Usage:

```
ed companion episode <id> [--body] [--open] [--json] [--endpoint <url>]
```

Options:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--body` | flag | off | Prints only the body text, for piping. |
| `--open` | flag | off | Downloads the original file from the vault and opens it with the default app. |
| `--json` | flag | off | Emits one JSON document on stdout. |
| `--endpoint` | URL | environment or local default | Uses this Companion API base URL. |

`--json` shape: `{id, occurredAt, ingestedAt, kind, title, body, bodyEn, langs,
durationS, mediaRef, sha256, bytes, chunks}`. `durationS` and `mediaRef` are
`null` for anything but voice episodes. The raw stored file is served by the
backend at `GET /v1/episodes/<id>/media`.

### `ed companion nightly`

Runs the whole nightly pipeline immediately: GitHub sync, indexing, claim
extraction, corroboration and reflection. The command returns when the pipeline
finishes, which can take minutes on a slow reasoner.

Usage:

```
ed companion nightly [--json] [--endpoint <url>]
```

`--json` shape: `{"runId": "<uuid>"}`. Inspect the recorded steps with
`ed companion runs`.

### `ed companion reason`

Shows or changes how the companion reasons. Settings persist on the backend and
hot-swap into the running service, so no restart or `.env` edit is needed; the
environment remains the fallback for anything never set here.

Usage:

```
ed companion reason [show] [--json] [--endpoint <url>]
ed companion reason set [--provider <p>] [--model <m>] [--url <u>] [--api-key <k>]
ed companion reason test [--json] [--endpoint <url>]
```

Options for `ed companion reason set`:

| Name | Type / values | Default | What it does |
| --- | --- | --- | --- |
| `--provider` | `anthropic` or `openai` | unchanged | Which API shape to speak; `openai` covers any OpenAI-compatible server such as Ollama. |
| `--model` | model name | unchanged | Model to request; empty resets to the provider default. |
| `--url` | URL | unchanged | Base URL for the OpenAI-compatible provider. |
| `--api-key` | secret | unchanged | Stored in the backend's settings table, never on this Mac; empty clears it. |

`ed companion reason show` (also the bare default) prints the active provider,
model, URL, whether a key is set with its last-four hint, and whether the
reasoner is configured at all. `--json` shape: `{provider, url, model,
hasApiKey, apiKeyHint, configured, description}`. The key itself is never
returned.

`ed companion reason test` sends one tiny completion through the active
provider and reports the round-trip: `{ok, model, latencyMs}` under `--json`,
exit `4` with the provider's error when the call fails.

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

Search and indexing need the Ollama service to be reachable and the configured
embedding model to be pulled before the first request.

## Where to go next

Use [`ed machines`](./machines.md) to create and open a port forward. Read
[conventions and contracts](./conventions.md) for JSON, stdout, stderr and exit
code guarantees shared by every command.

- [All `ed` commands](./README.md)
