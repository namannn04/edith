import { describe, expect, test } from "bun:test";
import { createHash, randomUUID } from "node:crypto";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { Database } from "../src/db";
import { ingestFiles } from "../src/ingest";

interface SourceRow {
  id: string;
  uri: string;
  sha256: string;
  bytes: number;
}

interface EpisodeRow {
  id: string;
  sourceId: string;
  occurredAt: Date;
  title: string;
  body: string;
}

interface StubSql {
  (strings: TemplateStringsArray, ...values: unknown[]): Promise<unknown[]>;
  begin<T>(operation: (transaction: StubSql) => Promise<T>): Promise<T>;
}

function createSqlStub(): {
  sql: Database;
  sources: SourceRow[];
  episodes: EpisodeRow[];
} {
  const sources: SourceRow[] = [];
  const episodes: EpisodeRow[] = [];

  const query = async (
    strings: TemplateStringsArray,
    ...values: unknown[]
  ): Promise<unknown[]> => {
    const statement = strings.join("?").replace(/\s+/g, " ").trim();

    if (statement.startsWith("SELECT e.id, e.occurred_at")) {
      const source = sources.find((item) => item.sha256 === values[0]);
      const episode = episodes.find((item) => item.sourceId === source?.id);
      return episode
        ? [{ id: episode.id, occurred_at: episode.occurredAt }]
        : [];
    }

    if (statement.startsWith("INSERT INTO sources")) {
      const sha256 = String(values[1]);
      if (sources.some((item) => item.sha256 === sha256)) {
        return [];
      }
      const source = {
        id: randomUUID(),
        uri: String(values[0]),
        sha256,
        bytes: Number(values[2]),
      };
      sources.push(source);
      return [{ id: source.id }];
    }

    if (statement.startsWith("INSERT INTO episodes")) {
      const episode = {
        id: randomUUID(),
        sourceId: String(values[0]),
        occurredAt: values[1] as Date,
        title: String(values[2]),
        body: String(values[3]),
      };
      episodes.push(episode);
      return [{ id: episode.id, occurred_at: episode.occurredAt }];
    }

    throw new Error(`Unexpected query: ${statement}`);
  };

  let stub: StubSql;
  stub = Object.assign(query, {
    begin: async <T>(operation: (transaction: StubSql) => Promise<T>) =>
      operation(stub),
  });

  return {
    sql: stub as unknown as Database,
    sources,
    episodes,
  };
}

describe("ingestFiles", () => {
  test("stores the SHA and deduplicates identical text", async () => {
    const vaultDir = await mkdtemp(join(tmpdir(), "companion-ingest-"));
    const stub = createSqlStub();
    const text = "---\ndate: 2026-08-09\n---\n# Daily note\nContent";

    try {
      const first = await ingestFiles(stub.sql, vaultDir, [
        { name: "daily.md", text },
      ]);
      const second = await ingestFiles(stub.sql, vaultDir, [
        { name: "copy.md", text },
      ]);

      expect(first[0].status).toBe("ingested");
      expect(second[0].status).toBe("duplicate");
      expect(second[0].episodeId).toBe(first[0].episodeId);
      expect(stub.sources).toHaveLength(1);
      expect(stub.episodes).toHaveLength(1);
      expect(stub.sources[0].sha256).toBe(
        createHash("sha256").update(text).digest("hex"),
      );
      expect(stub.sources[0].bytes).toBe(Buffer.byteLength(text, "utf8"));
      expect(stub.episodes[0].title).toBe("Daily note");
    } finally {
      await rm(vaultDir, { recursive: true, force: true });
    }
  });

  test("uses mtime and filename when metadata is absent", async () => {
    const vaultDir = await mkdtemp(join(tmpdir(), "companion-ingest-"));
    const stub = createSqlStub();

    try {
      const [result] = await ingestFiles(stub.sql, vaultDir, [
        {
          name: "meeting-notes.md",
          text: "Notes",
          mtime: "2026-08-01T12:00:00Z",
        },
      ]);

      expect(result.occurredAt.toISOString()).toBe("2026-08-01T12:00:00.000Z");
      expect(stub.episodes[0].title).toBe("meeting-notes");
    } finally {
      await rm(vaultDir, { recursive: true, force: true });
    }
  });
});
