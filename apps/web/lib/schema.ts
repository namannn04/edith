import {
  boolean,
  integer,
  pgTable,
  text,
  timestamp,
  unique,
  uuid,
} from "drizzle-orm/pg-core";

export const licenses = pgTable("licenses", {
  id: uuid("id").primaryKey().defaultRandom(),
  key: text("key").notNull().unique(),
  label: text("label"),
  maxMachines: integer("max_machines").notNull().default(1),
  active: boolean("active").notNull().default(true),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow(),
});

export const machines = pgTable(
  "machines",
  {
    id: uuid("id").primaryKey(),
    licenseId: uuid("license_id")
      .notNull()
      .references(() => licenses.id),
    hardwareUuid: text("hardware_uuid").notNull(),
    hostname: text("hostname"),
    firstSeen: timestamp("first_seen", { withTimezone: true }).defaultNow(),
    lastSeen: timestamp("last_seen", { withTimezone: true }).defaultNow(),
  },
  (table) => [unique().on(table.licenseId, table.hardwareUuid)],
);
