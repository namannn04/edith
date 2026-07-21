UPDATE "plans"
SET "provider" = 'polar',
    "external_product_id" = NULL,
    "external_price_id" = NULL,
    "updated_at" = now()
WHERE "provider" = 'lemonsqueezy';

INSERT INTO "plans" ("id", "name", "provider", "external_product_id", "external_price_id", "max_machines", "billing_model")
VALUES ('custom', 'Custom', 'polar', NULL, NULL, 50, 'one_time')
ON CONFLICT ("id") DO NOTHING;
