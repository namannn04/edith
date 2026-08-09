# How the companion works

[`ed companion`](./companion.md) documents the commands. This page documents
the machinery behind them: what happens when a note is dropped, how memory is
stored and searched, and what the nightly loop concludes from it. Everything
here is read straight from the code in `apps/companion`.

Two pipelines carry the whole system:

- Every file you drop: file (md, pdf, voice) → SHA-256 dedupe → vault
  (original bytes) → episode (append-only) → chunks (at most 1600 chars) →
  embeddings (512-dim) → searchable.
- Every night at 02:00: sync GitHub → index pending episodes → extract claims
  → corroborate claims against observations → reflect into beliefs.

## The machine

The companion is one small Rust server plus four helper containers. The Mac
app and `ed` are thin clients over the same HTTP surface.

**One HTTP server.** A single-purpose axum binary on port 4820 with no CLI
modes. Boot order: connect Postgres, run migrations, build the reasoner from
DB settings merged over env, spawn the nightly scheduler, serve about thirty
routes under `/v1`. The app and `ed` both go through one shared Swift
`CompanionClient`; endpoint resolution is `--endpoint`, then
`EDITH_COMPANION_URL`, then the `companionEndpoint` default, then
`http://127.0.0.1:4820`. Remote access is a tunnel:
`ed machines forwards on tuf 2`.

**Five containers, four volumes.** `postgres` (pgvector, Postgres 18) holds
every table, `ollama` serves embeddings, `whisper` (the whisper.cpp server)
transcribes voice, `redis` exists but is only ever pinged by the doctor, and
`api` is the Rust server. Data lives in named volumes (`companion-pg`,
`companion-vault`, `companion-ollama`, `companion-whisper`); the only thing
stored on the Mac is the endpoint URL in the shared defaults suite. There is
no SQLite anywhere.

**The reasoner.** A thin LLM layer with two providers: the Anthropic messages
API (default model `claude-sonnet-5`, 2048 output tokens) or any
OpenAI-compatible URL such as local Ollama (default `qwen3:1.7b`). It lives
behind a read-write lock, which is why `PUT /v1/settings/reason` can rebuild
and hot-swap it with no restart. Everything cognitive (chat, ask, claims,
corroboration, reflection) goes through it; embeddings and transcription do
not.

**The data ladder.** Five rungs, each adding interpretation:

| Rung | What it is |
| --- | --- |
| `sources` | Unique file bodies, keyed by content hash |
| `episodes` | Append-only memory events, one per source |
| `chunks` | The embedded, searchable pieces of each episode |
| `claims`, `observations` | Derived records: what you said, and what the world recorded |
| `beliefs` | What the reasoner concludes about you |

Chat answers come from chunks; the Mind tab shows the top two rungs.

## Remembering: the write path

Memory is append-only. A file becomes an immutable episode; nothing is ever
edited in place, and identity is the content hash.

**The vault.** A content-addressed blob store on disk:
`/vault/objects/<first-two-hex>/<sha256>/<name>`, holding the original bytes
of everything ingested. Writes are idempotent (same hash, same path, write
skipped), and `GET /v1/episodes/{id}/media` serves those bytes back
byte-for-byte, which is what powers the waveform player and PDF preview in
the Library.

**Dedupe by hash.** Identity is SHA-256: of the text for Markdown, of the raw
bytes for PDF and audio. A known hash short-circuits to `duplicate` before
anything is written. There is no update path at all; editing a note and
re-dropping it creates a brand-new source and episode while the old one stays
forever. Append-only is a feature: memory of what you wrote then, not what
you later wished you wrote.

**Three media, one shape.** Markdown is stored whole, front matter included.
PDF goes through text extraction; scanned image-only PDFs are rejected with a
clear error. Voice is transcribed by whisper.cpp at temperature 0; the
transcript becomes the episode body, per-segment timings land in `meta`,
language and duration are kept, and prosody signals are computed right after
commit. All three end as the same `episodes` row with a `kind`.

**Front matter and time.** A hand-rolled `key: value` scanner, not full YAML.
The title comes from `title:`, else the first `#` heading, else the file
stem. The episode's `occurred_at` prefers a front-matter date (`date`,
`created` or `occurred_at`, first key found wins), then file mtime, then now.
Dates accept `YYYY-MM-DD` or RFC 3339. This is why an old journal entry lands
at its written date, not its import date.

**Chunking.** Paragraphs (blank-line separated) are greedily packed into
chunks of at most 1600 characters, joined by blank lines, with zero overlap;
a single oversized paragraph is hard-split at exactly 1600. Chunks are
disjoint, so concatenating them reproduces the text. A rough token count
(chars divided by 4) is stored but nothing uses it yet.

**Embeddings.** Ollama runs `qwen3-embedding:0.6b`; its 1024-dim vectors are
truncated to the first 512 dimensions (the Matryoshka property makes leading
dimensions carry most of the meaning) and L2-normalized. Storage is
pgvector's `halfvec(512)`, 16-bit floats, under an HNSW cosine index, so
similarity search is an approximate graph walk, not a scan. Beliefs get their
own embedded column the same way, which is what powers their life-cycle.

**Indexing without a watcher.** There is no file watcher and no dirty
tracking. "Needs indexing" is defined as an episode with zero chunks, which
is sound only because episodes are immutable. Indexing runs three ways: in
the background right after an ingest, on `POST /v1/index`, and as a nightly
step. Each pass takes up to 500 episodes and embeds in batches of 16; an
Ollama failure surfaces as HTTP 502, distinct from a database failure.

**Signals.** Prosody extracted from voice segments, no LLM involved:
`pause_s` for every gap of one second or more, `wpm` per segment (only when
it runs two seconds or more with at least three words), and one
`speech_ratio` spanning the whole take. They are the "how you sounded"
channel next to "what you said", rendered as the delivery bars under voice
episodes.

## Recalling: the read path

Retrieval is deliberately simple: embed the question, take the eight nearest
chunks, show them to the reasoner, then police what it cites.

**Retrieval.** Pure vector search: the question is embedded and chunks are
ordered by cosine distance with k fixed at 8. No keyword search, no
reranking, no recency weighting; claims, beliefs and observations are not
retrieved into chat at all. A `tsvector` column and GIN index already sit on
every chunk waiting for a hybrid ranker, but today nothing reads them.

**Prompt assembly.** Each retrieved chunk is rendered as
`episode <uuid> (<date>) <title>` plus its text, joined into one excerpts
block. There is no token budgeter; the cap is structural, 8 chunks of at most
1600 chars each, roughly 13k chars. Chat prepends a short system persona (a
thoughtful confidant who knows one person through their own notes) and the
last 12 messages of the conversation.

**Ask versus chat.** `/v1/ask` is one-shot and strict: the whole reply must
be JSON, `{answer, citations}`. `/v1/chat` is conversational and streams SSE
events (`meta`, then `delta`s, then `citations`, then `done`): the model
writes plain prose, then a `@@CITATIONS@@` sentinel line carrying the
citation array, which the server strips out of the visible stream. Ask writes
nothing back; chat persists both sides into `messages`.

**The stream filter.** A chunk-boundary-safe state machine sits between the
model and your screen. It strips `<think>` blocks (local models think out
loud), diverts everything after `@@CITATIONS@@` into a capture buffer, and
holds back any trailing bytes that might be the start of either marker, so a
token split across two deltas can never leak half a sentinel into the UI.

**Citations you can trust.** Two guarantees, both enforced server-side.
Grounding: a citation naming an episode that was not among the eight
retrieved is dropped, so an answer can only cite what the reasoner actually
read. Support grading: the quoted text is searched for structurally
(whitespace-squeezed, case-folded) in the cited chunk; found means
`verbatim` even if the model claimed less, not found demotes a `verbatim`
claim to `paraphrase`, and `inference` (reading between the lines) passes
through untouched.

**Conversations and telemetry.** Chat history lives in `conversations` and
`messages`; titles are auto-cut from the first message at 60 characters on a
word boundary. Separately, every search, ask and chat logs a `turns` row plus
one `retrievals` row per chunk (rank, scores, and whether it ended up cited):
raw material for judging retrieval quality later. One catch: the companion
never re-ingests its own replies, so it does not learn from what it says,
only from what you give it.

## Thinking: the nightly loop

While you sleep the reasoner turns raw episodes into claims, checks them
against external records, and distills beliefs. Each layer is more
interpretive and more careful.

**Claims.** A claim is one assertion you committed to, in your own words,
typed as one of eight: `fact`, `intention`, `commitment`, `progress`,
`self_assessment`, `prediction`, `preference` or `feeling`, plus a `testable`
flag when independent records could confirm it. Extraction reads the 10
newest unclaimed episodes (first 1500 chars each) and asks for zero to six
claims per episode; `asserted_at` is the episode's time, not tonight's.
Claims are never deduped or superseded; the only guard is one pass per
episode.

**Observations.** External records with a hard provenance rule: they never
come from anything you wrote for the companion. Today that means GitHub: the
sync pulls up to 300 recent events and keeps four kinds (`commit`,
`pull_request`, `issue`, `review`), each idempotent via a dedupe key like
`github:commit:<sha>`. They exist so corroboration has something you cannot
accidentally, or conveniently, author yourself.

**Corroboration.** Testable claims of type `progress`, `commitment` or
`fact` get judged against up to 40 observations within 96 hours either side
of the assertion. Verdicts are `corroborated`, `contradicted` or `unclear`,
with one deliberate asymmetry: absence of records always reads as `unclear`,
never as contradiction. "You said you shipped it and there are no commits" is
a question, not an accusation.

**Beliefs and reflection.** Reflection reads the 20 newest episodes (1200
chars each) and asks for two to five higher-order beliefs, each
`{statement, kind, confidence, evidence}` with kind one of `pattern`,
`preference` or `state`; evidence must point at episodes that were actually
shown or the belief is dropped. Then embedding similarity against active
beliefs decides the life-cycle: 0.90 or above strengthens the existing belief
(stability up by one, evidence unioned), 0.80 to 0.90 supersedes it (the old
one stays, marked and linked to its replacement), below 0.80 forms a new one.
Beliefs are never deleted, so the Mind tab can show what the companion used
to think.

**The nightly run.** A scheduler spawned at boot fires at
`COMPANION_REFLECT_AT`, default 02:00 server-local time (an interval override
exists for testing). Steps run in dependency order: `sync_github`, `index`,
`extract_claims`, `corroborate`, `reflect`. A step missing its prerequisite
(no GitHub token, no reasoner key) records itself as skipped rather than
failing the run, and the whole run plus per-step results lands in
`nightly_runs`, which is exactly what `ed companion runs` and the Mind tab
render. `POST /v1/nightly/run` does the same thing on demand, synchronously.

**The doctor.** Eight health checks behind `GET /v1/health`: Postgres,
migrations (all applied), pgvector, Redis, vault writable (it literally
writes and deletes a probe file), embeddings (Ollama version ping), stt
(whisper reachable), and reasoning (describes the provider, never fails). Any
failure turns the response 503, but clients still parse the body, which is
how the header dot and the Settings health card stay honest.

## Settings

Two layers, database over environment. Exactly four keys exist in the
`settings` table: `reason.provider`, `reason.url`, `reason.model` and
`reason.api_key`. Stored values win over env field by field, a write rebuilds
and hot-swaps the running reasoner client, and the API key is never returned,
only a hint made of its last four characters. On the Mac side nothing
sensitive is stored: only the endpoint URL in shared defaults.

## The numbers that matter

Every threshold in the system, in one place. Change one of these and the
character of the memory changes.

| Knob | Value | Meaning |
| --- | --- | --- |
| Chunk size | 1600 chars, 0 overlap | The unit of retrieval; paragraphs packed greedily, disjoint |
| Embedding | `qwen3-embedding:0.6b`, 512 dims | Matryoshka truncation from 1024, then L2-normalized, halfvec plus HNSW |
| Retrieval k | 8 | Chunks shown to the reasoner per question, ask and chat alike |
| Chat history | 12 messages | Context carried per conversation turn |
| Claim extraction | 10 episodes, 1500 chars each, 0 to 6 claims | Per pass, newest unclaimed first |
| Corroboration window | 96 h either side, at most 40 observations | Evidence considered around a claim's assertion time |
| Reflection material | 20 episodes, 1200 chars each, 2 to 5 beliefs | Per nightly reflect step |
| Belief similarity | 0.90 strengthen, 0.80 supersede, else new | Cosine against active beliefs, embedding-based |
| GitHub sync | 3 pages of 100 events | At most 300 recent events per sync, deduped by key |
| Nightly time | 02:00 local, env-overridable | Read once at boot; changing it needs a restart |
| Size limits | md 2 MB, audio and PDF 48 MB, 200 files per batch | Enforced client-side and server-side |
| Index batch | 500 episodes per pass, embed 16 at a time | Pull-based; no chunks means not indexed |

## The schema, one line per table

| Table | What it holds |
| --- | --- |
| `sources` | Unique ingested bodies: kind, vault path, unique SHA-256, byte count |
| `episodes` | Append-only memory events: body, kind, occurred and ingested times, language, media ref, duration, segment meta |
| `chunks` | Retrieval units: text, `halfvec(512)` embedding under HNSW, generated `tsvector` (unused so far), token estimate |
| `claims` | Typed assertions extracted from episodes, with a testable flag and assertion time |
| `observations` | External records (GitHub events), deduped by a partial unique key |
| `corroborations` | One verdict per checked claim: verdict, note, the observation ids the judge saw |
| `beliefs` | Concluded statements with confidence, stability, evidence ids, status, own embedding, supersede link |
| `reflections` | One row per reflect run: episodes considered, beliefs formed, model |
| `nightly_runs` | Run log: started and finished times, overall ok, per-step JSON |
| `turns`, `retrievals` | Telemetry: every search, ask and chat, plus per-chunk rank, scores, was-cited |
| `signals` | Voice prosody per episode: pauses, words per minute, speech ratio |
| `conversations`, `messages` | Chat history with citations, model and latency per assistant message |
| `settings` | Four reasoner keys that win over env, hot-swapped on write |
| `facts` | A full temporal knowledge-graph table (subject, predicate, validity range): defined in the first migration, touched by no code yet |

## Sharp edges worth knowing

- Hybrid search is plumbing without a pump: chunks carry a generated
  `tsvector` and GIN index, and `retrievals` has a `score_text` column, but
  retrieval is vector-only today.
- Claims never converge: beliefs dedupe and supersede by similarity, claims
  are insert-only, so restating an intention creates a sibling, not an
  update.
- The companion does not learn from itself: assistant replies persist as
  messages but never become episodes or chunks.
- Two routes speak snake_case: `/v1/status` and `/v1/episodes` serialize
  snake_case while everything else is camelCase; the Swift client papers over
  it with coding keys.
- Redis is ceremonial: opened at boot, pinged by the doctor, used for nothing
  else yet.
- Real retrieval scores are discarded: ask and chat log a synthetic
  reciprocal-rank value as the vector score; the true cosine distance never
  reaches telemetry.
- An unclosed `<think>` eats the tail: if a local model opens a think block
  and never closes it, the stream filter drops everything after it by design.
- Front-matter dates latch on the first key: `date: someday` followed by a
  valid `created:` yields no date at all; the scanner stops at the first
  matching key even when its value fails to parse.

## Further reading

- [pgvector](https://github.com/pgvector/pgvector): the Postgres extension
  behind `halfvec` and the vector distance operators.
- [HNSW, Malkov and Yashunin](https://arxiv.org/abs/1603.09320): the
  approximate nearest-neighbor graph index on chunks and beliefs.
- [Matryoshka Representation Learning](https://arxiv.org/abs/2205.13147):
  why truncating 1024-dim embeddings to 512 works.
- [Qwen3-Embedding-0.6B](https://huggingface.co/Qwen/Qwen3-Embedding-0.6B):
  the embedding model Ollama serves.
- [Ollama API](https://github.com/ollama/ollama/blob/main/docs/api.md): the
  embed endpoint the indexer calls.
- [whisper.cpp](https://github.com/ggml-org/whisper.cpp): the transcription
  server behind voice ingest.
- [Retrieval-Augmented Generation](https://arxiv.org/abs/2005.11401): the
  retrieve-then-generate pattern ask and chat implement.
- [Generative Agents, Park et al.](https://arxiv.org/abs/2304.03442): the
  memory-stream-plus-reflection idea beliefs descend from.
- [Server-sent events](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events):
  the streaming transport for chat.
- [Postgres full-text search](https://www.postgresql.org/docs/current/textsearch.html):
  the dormant `tsvector` half of future hybrid retrieval.
- [Content-addressable storage](https://en.wikipedia.org/wiki/Content-addressable_storage):
  the vault's layout and dedupe model.
- [GitHub Events API](https://docs.github.com/en/rest/activity/events):
  where observations come from.
