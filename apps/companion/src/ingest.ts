import { createHash } from "node:crypto";
import { basename, extname } from "node:path";
import type { Database } from "./db";
import { parseFrontMatter } from "./frontmatter";
import { writeVaultFile } from "./vault";

export interface IngestFile {
  name: string;
  text: string;
  mtime?: string;
}

export interface IngestResult {
  name: string;
  status: "ingested" | "duplicate";
  episodeId: string;
  occurredAt: Date;
}

interface ExistingEpisode {
  id: string;
  occurred_at: Date;
}

function fileTitle(name: string): string {
  const fileName = basename(name);
  const extension = extname(fileName);
  return extension ? fileName.slice(0, -extension.length) : fileName;
}

function fileDate(mtime: string | undefined): Date | null {
  if (!mtime) {
    return null;
  }

  const date = new Date(mtime);
  return Number.isNaN(date.getTime()) ? null : date;
}

export async function ingestFiles(
  sql: Database,
  vaultDir: string,
  files: IngestFile[],
): Promise<IngestResult[]> {
  const results: IngestResult[] = [];

  for (const file of files) {
    const sha256 = createHash("sha256").update(file.text).digest("hex");
    const result = await sql.begin(async (transaction) => {
      const existing = await transaction<ExistingEpisode[]>`
        SELECT e.id, e.occurred_at
        FROM sources s
        JOIN episodes e ON e.source_id = s.id
        WHERE s.sha256 = ${sha256}
        ORDER BY e.ingested_at
        LIMIT 1
      `;

      if (existing[0]) {
        return {
          name: file.name,
          status: "duplicate" as const,
          episodeId: existing[0].id,
          occurredAt: existing[0].occurred_at,
        };
      }

      const uri = await writeVaultFile(vaultDir, sha256, file.name, file.text);
      const insertedSources = await transaction<{ id: string }[]>`
        INSERT INTO sources (kind, uri, sha256, bytes)
        VALUES ('md', ${uri}, ${sha256}, ${Buffer.byteLength(file.text, "utf8")})
        ON CONFLICT (sha256) DO NOTHING
        RETURNING id
      `;

      if (!insertedSources[0]) {
        const racedEpisode = await transaction<ExistingEpisode[]>`
          SELECT e.id, e.occurred_at
          FROM sources s
          JOIN episodes e ON e.source_id = s.id
          WHERE s.sha256 = ${sha256}
          ORDER BY e.ingested_at
          LIMIT 1
        `;

        if (!racedEpisode[0]) {
          throw new Error(`Source ${sha256} exists without an episode`);
        }

        return {
          name: file.name,
          status: "duplicate" as const,
          episodeId: racedEpisode[0].id,
          occurredAt: racedEpisode[0].occurred_at,
        };
      }

      const frontMatter = parseFrontMatter(file.text);
      const occurredAt = frontMatter.date ?? fileDate(file.mtime) ?? new Date();
      const title = frontMatter.title ?? fileTitle(file.name);
      const episodes = await transaction<{ id: string; occurred_at: Date }[]>`
        INSERT INTO episodes (
          source_id,
          occurred_at,
          kind,
          title,
          body_original,
          langs
        )
        VALUES (
          ${insertedSources[0].id},
          ${occurredAt},
          'md',
          ${title},
          ${file.text},
          ARRAY['en']::text[]
        )
        RETURNING id, occurred_at
      `;

      return {
        name: file.name,
        status: "ingested" as const,
        episodeId: episodes[0].id,
        occurredAt: episodes[0].occurred_at,
      };
    });

    results.push(result);
  }

  return results;
}
