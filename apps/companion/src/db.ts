import postgres from "postgres";

const databaseUrl =
  process.env.DATABASE_URL ??
  "postgres://companion:companion-dev@127.0.0.1:5432/companion";

export const sql = postgres(databaseUrl);
export type Database = typeof sql;
