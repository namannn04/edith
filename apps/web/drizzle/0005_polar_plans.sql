INSERT INTO "plans" ("id", "name", "provider", "external_product_id", "external_price_id", "max_machines", "billing_model", "active")
VALUES
  ('individual_1', 'Individual', 'polar', NULL, NULL, 1, 'one_time', true),
  ('personal_3', 'Personal', 'polar', NULL, NULL, 3, 'one_time', true),
  ('power_5', 'Power', 'polar', NULL, NULL, 5, 'one_time', true),
  ('custom', 'Custom', 'polar', NULL, NULL, 50, 'one_time', true)
ON CONFLICT ("id") DO UPDATE SET
  "name" = EXCLUDED."name",
  "provider" = EXCLUDED."provider",
  "external_product_id" = NULL,
  "external_price_id" = NULL,
  "max_machines" = EXCLUDED."max_machines",
  "billing_model" = EXCLUDED."billing_model",
  "active" = true,
  "updated_at" = now();
