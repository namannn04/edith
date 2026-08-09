import Redis from "ioredis";
import { sql } from "./db";
import { runMigrations } from "./migrate";
import { createApp } from "./server";

const redis = new Redis(process.env.REDIS_URL ?? "redis://127.0.0.1:6379");
const vaultDir = process.env.VAULT_DIR ?? "/vault";

await runMigrations(sql);

const app = createApp({ sql, redis, vaultDir });

Bun.serve({
  hostname: "0.0.0.0",
  port: 4820,
  fetch: app.fetch,
});

console.log("companion api listening on 0.0.0.0:4820");
