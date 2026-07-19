CREATE TABLE "licenses" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  "key" text NOT NULL UNIQUE,
  "label" text,
  "max_machines" integer NOT NULL DEFAULT 1,
  "active" boolean NOT NULL DEFAULT true,
  "created_at" timestamptz DEFAULT now()
);

CREATE TABLE "machines" (
  "id" uuid PRIMARY KEY,
  "license_id" uuid NOT NULL REFERENCES "licenses"("id"),
  "hardware_uuid" text NOT NULL,
  "hostname" text,
  "first_seen" timestamptz DEFAULT now(),
  "last_seen" timestamptz DEFAULT now(),
  UNIQUE ("license_id", "hardware_uuid")
);
