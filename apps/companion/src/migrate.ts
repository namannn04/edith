import { basename, join } from "node:path";
import { type Database, sql as database } from "./db";

const migrationsDirectory = join(import.meta.dir, "..", "migrations");

export interface MigrationFile {
  version: string;
  sql: string;
}

export async function readMigrationFiles(): Promise<MigrationFile[]> {
  const glob = new Bun.Glob("*.sql");
  const names = Array.from(
    glob.scanSync({ cwd: migrationsDirectory, onlyFiles: true }),
  ).sort();

  return Promise.all(
    names.map(async (name) => ({
      version: basename(name, ".sql"),
      sql: await Bun.file(join(migrationsDirectory, name)).text(),
    })),
  );
}

export async function runMigrations(sql: Database): Promise<void> {
  await sql.unsafe(
    "CREATE TABLE IF NOT EXISTS schema_migrations (version text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())",
  );

  const appliedRows = await sql<{ version: string }[]>`
    SELECT version
    FROM schema_migrations
  `;
  const applied = new Set(appliedRows.map((row) => row.version));

  for (const migration of await readMigrationFiles()) {
    if (applied.has(migration.version)) {
      continue;
    }

    await sql.begin(async (transaction) => {
      await transaction.unsafe(migration.sql);
      await transaction`
        INSERT INTO schema_migrations (version)
        VALUES (${migration.version})
      `;
    });
  }
}

if (import.meta.main) {
  try {
    await runMigrations(database);
  } finally {
    await database.end();
  }
}
