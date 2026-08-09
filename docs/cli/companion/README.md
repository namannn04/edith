# `ed companion`

`ed companion` talks to Edith's local memory backend. The companion stores
Markdown notes as append-only episodes in Postgres, keeps the original note in
its vault, and deduplicates sources by their SHA-256 content hash.

Run the backend with docker compose from `apps/companion`. The CLI reaches it
directly on this Mac or through an `ed machines` port forward. Pass
`--endpoint` for one invocation, set `EDITH_COMPANION_URL` for a shell, or use
the default `http://127.0.0.1:4820`.

For the machinery behind these commands, vault, chunking, embeddings,
retrieval, claims and beliefs, read [how the companion works](./concepts.md).

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

## Commands

- [`ed companion status`](./status.md)
- [`ed companion doctor`](./doctor.md)
- [`ed companion search`](./search.md)
- [`ed companion index`](./index.md)
- [`ed companion ingest`](./ingest.md)
- [`ed companion episodes`](./episodes.md)
- [`ed companion sync`](./sync.md)
- [`ed companion observations`](./observations.md)
- [`ed companion reflect`](./reflect.md)
- [`ed companion beliefs`](./beliefs.md)
- [`ed companion ask`](./ask.md)
- [`ed companion extract`](./extract.md)
- [`ed companion claims`](./claims.md)
- [`ed companion corroborate`](./corroborate.md)
- [`ed companion runs`](./runs.md)
- [`ed companion chat`](./chat.md)
- [`ed companion conversations`](./conversations.md)
- [`ed companion forget`](./forget.md)
- [`ed companion episode`](./episode.md)
- [`ed companion nightly`](./nightly.md)
- [`ed companion reason`](./reason.md)

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

Use [`ed machines`](../machines/README.md) to create and open a port forward. Read
[conventions and contracts](../conventions.md) for JSON, stdout, stderr and exit
code guarantees shared by every command.

- [All `ed` commands](../README.md)
