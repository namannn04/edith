import { randomUUID } from "node:crypto";
import { mkdir, open, unlink } from "node:fs/promises";
import { join } from "node:path";
import type Redis from "ioredis";
import type { Database } from "./db";
import { readMigrationFiles } from "./migrate";

export interface DoctorDependencies {
  sql: Database;
  redis: Pick<Redis, "ping">;
  vaultDir: string;
}

export interface DoctorCheck {
  name: string;
  ok: boolean;
  detail: string;
}

export interface DoctorResult {
  ok: boolean;
  checks: DoctorCheck[];
}

function errorDetail(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

async function check(
  name: string,
  operation: () => Promise<string>,
): Promise<DoctorCheck> {
  try {
    return { name, ok: true, detail: await operation() };
  } catch (error) {
    return { name, ok: false, detail: errorDetail(error) };
  }
}

export async function runDoctor(
  dependencies: DoctorDependencies,
): Promise<DoctorResult> {
  const checks = await Promise.all([
    check("postgres", async () => {
      await dependencies.sql`SELECT 1`;
      return "connected";
    }),
    check("migrations", async () => {
      const [row] = await dependencies.sql<{ count: number }[]>`
        SELECT count(*)::int AS count
        FROM schema_migrations
      `;
      const expected = (await readMigrationFiles()).length;
      if (row.count !== expected) {
        throw new Error(`${row.count} of ${expected} migrations applied`);
      }
      return `${row.count} of ${expected} migrations applied`;
    }),
    check("pgvector", async () => {
      const [row] = await dependencies.sql<{ present: boolean }[]>`
        SELECT EXISTS (
          SELECT 1
          FROM pg_extension
          WHERE extname = 'vector'
        ) AS present
      `;
      if (!row.present) {
        throw new Error("vector extension is not installed");
      }
      return "installed";
    }),
    check("redis", async () => {
      const response = await dependencies.redis.ping();
      if (response !== "PONG") {
        throw new Error(`unexpected response: ${response}`);
      }
      return "connected";
    }),
    check("vault", async () => {
      await mkdir(dependencies.vaultDir, { recursive: true });
      const path = join(dependencies.vaultDir, `.doctor-${randomUUID()}`);
      const file = await open(path, "wx");
      try {
        await file.writeFile("ok");
      } finally {
        await file.close();
        await unlink(path);
      }
      return "writable";
    }),
  ]);

  return { ok: checks.every((item) => item.ok), checks };
}
