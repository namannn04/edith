import { randomUUID } from "node:crypto";
import { countDistinct, eq, sql } from "drizzle-orm";
import { drizzle, type PostgresJsDatabase } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import type { LicenseAccess, LicenseStore } from "@/lib/license";
import * as schema from "@/lib/schema";
import { licenses, machines } from "@/lib/schema";

type Database = PostgresJsDatabase<typeof schema>;
type PostgresClient = ReturnType<typeof postgres>;
type DatabaseState = {
  client: PostgresClient;
  database: Database;
};

let databaseState: DatabaseState | undefined;

function getDatabaseState(): DatabaseState {
  if (databaseState) {
    return databaseState;
  }

  const databaseUrl = process.env.DATABASE_URL;

  if (!databaseUrl) {
    throw new Error("DATABASE_URL is required");
  }

  const client = postgres(databaseUrl, { prepare: false });
  const database = drizzle(client, { schema });
  databaseState = { client, database };
  return databaseState;
}

export function getDb(): Database {
  return getDatabaseState().database;
}

export async function closeDatabase(): Promise<void> {
  if (!databaseState) {
    return;
  }

  await databaseState.client.end({ timeout: 5 });
  databaseState = undefined;
}

function createAccess(database: Database): LicenseAccess {
  return {
    async getLicenseByKey(key) {
      const [license] = await database
        .select({
          id: licenses.id,
          label: licenses.label,
          maxMachines: licenses.maxMachines,
          active: licenses.active,
        })
        .from(licenses)
        .where(eq(licenses.key, key))
        .limit(1);

      return license ?? null;
    },
    async getMachine(licenseId, hardwareUuid) {
      const [machine] = await database
        .select({
          licenseId: machines.licenseId,
          hardwareUuid: machines.hardwareUuid,
        })
        .from(machines)
        .where(
          sql`${machines.licenseId} = ${licenseId} and ${machines.hardwareUuid} = ${hardwareUuid}`,
        )
        .limit(1);

      return machine ?? null;
    },
    async countMachines(licenseId) {
      const [result] = await database
        .select({ value: countDistinct(machines.hardwareUuid) })
        .from(machines)
        .where(eq(machines.licenseId, licenseId));

      return result?.value ?? 0;
    },
    async upsertMachine(input) {
      const now = new Date();

      await database
        .insert(machines)
        .values({
          id: randomUUID(),
          licenseId: input.licenseId,
          hardwareUuid: input.hardwareUuid,
          hostname: input.hostname,
          lastSeen: now,
        })
        .onConflictDoUpdate({
          target: [machines.licenseId, machines.hardwareUuid],
          set: {
            hostname: input.hostname,
            lastSeen: now,
          },
        });
    },
  };
}

export const licenseStore: LicenseStore = {
  async getLicenseByKey(key) {
    return createAccess(getDb()).getLicenseByKey(key);
  },
  async getMachine(licenseId, hardwareUuid) {
    return createAccess(getDb()).getMachine(licenseId, hardwareUuid);
  },
  async countMachines(licenseId) {
    return createAccess(getDb()).countMachines(licenseId);
  },
  async upsertMachine(input) {
    return createAccess(getDb()).upsertMachine(input);
  },
  async runExclusive(key, operation) {
    return getDb().transaction(async (transaction) => {
      await transaction.execute(
        sql`select pg_advisory_xact_lock(hashtextextended(${key}, 0))`,
      );
      const access = createAccess(transaction as Database);
      return operation(access);
    });
  },
};
