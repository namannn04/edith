import { Hono } from "hono";
import type Redis from "ioredis";
import type { Database } from "./db";
import { runDoctor } from "./doctor";
import { type IngestFile, ingestFiles } from "./ingest";

export interface AppDependencies {
  sql: Database;
  redis: Pick<Redis, "ping">;
  vaultDir: string;
}

function validFile(value: unknown): value is IngestFile {
  if (typeof value !== "object" || value === null) {
    return false;
  }

  const file = value as Record<string, unknown>;
  return (
    typeof file.name === "string" &&
    file.name.length > 0 &&
    typeof file.text === "string" &&
    (file.mtime === undefined ||
      (typeof file.mtime === "string" &&
        !Number.isNaN(new Date(file.mtime).getTime())))
  );
}

function requestedLimit(value: string | undefined): number {
  const numeric = value === undefined ? 20 : Number(value);
  const integral = Number.isFinite(numeric) ? Math.trunc(numeric) : 20;
  return Math.min(200, Math.max(1, integral));
}

export function createApp(dependencies: AppDependencies): Hono {
  const app = new Hono();

  app.get("/v1/health", async (context) => {
    const result = await runDoctor(dependencies);
    return context.json(result, result.ok ? 200 : 503);
  });

  app.post("/v1/ingest", async (context) => {
    let body: unknown;
    try {
      body = await context.req.json();
    } catch {
      return context.json({ error: "Invalid JSON body" }, 400);
    }

    if (typeof body !== "object" || body === null) {
      return context.json({ error: "Body must be an object" }, 400);
    }

    const files = (body as Record<string, unknown>).files;
    if (!Array.isArray(files)) {
      return context.json({ error: "files must be an array" }, 400);
    }
    if (files.length > 200) {
      return context.json(
        { error: "files must contain at most 200 items" },
        400,
      );
    }
    if (!files.every(validFile)) {
      return context.json({ error: "Each file requires name and text" }, 400);
    }
    if (
      files.some(
        (file) => Buffer.byteLength(file.text, "utf8") > 2 * 1024 * 1024,
      )
    ) {
      return context.json({ error: "Each file must be at most 2MB" }, 400);
    }

    const results = await ingestFiles(
      dependencies.sql,
      dependencies.vaultDir,
      files,
    );
    return context.json(results);
  });

  app.get("/v1/status", async (context) => {
    const [status] = await dependencies.sql<
      {
        sources: number;
        episodes: number;
        claims: number;
        observations: number;
        latest_ingested_at: Date | null;
      }[]
    >`
      SELECT
        (SELECT count(*)::int FROM sources) AS sources,
        (SELECT count(*)::int FROM episodes) AS episodes,
        (SELECT count(*)::int FROM claims) AS claims,
        (SELECT count(*)::int FROM observations) AS observations,
        (SELECT max(ingested_at) FROM episodes) AS latest_ingested_at
    `;
    return context.json(status);
  });

  app.get("/v1/episodes", async (context) => {
    const limit = requestedLimit(context.req.query("limit"));
    const episodes = await dependencies.sql<
      {
        id: string;
        occurred_at: Date;
        kind: string;
        title: string;
        sha256: string;
      }[]
    >`
      SELECT e.id, e.occurred_at, e.kind, e.title, s.sha256
      FROM episodes e
      JOIN sources s ON s.id = e.source_id
      ORDER BY e.occurred_at DESC
      LIMIT ${limit}
    `;
    return context.json(episodes);
  });

  return app;
}
