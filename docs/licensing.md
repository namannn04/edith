# Licensing

How Edith is licensed, how a Mac is activated, and how the app proves it stays licensed
offline. One unified system: device keys and signed entitlements. There is no separate
protocol version, no hardware-UUID activation, no migration path, and no signed "receipt".

## The pieces

- **edith.pulkit.page** (`apps/web`, Next.js on Vercel): the public site plus a set of
  unversioned `/api` endpoints. It owns the Postgres database, signs entitlements, and
  proxies the private release DMG and Sparkle appcast.
- **Edith.app** (`apps/macos`, target `Edith`): the product. It verifies its entitlement
  offline on every launch and refreshes in the background.
- **Edith Installer.app** (`apps/macos`, target `EdithInstaller`): the small public
  download. It runs the same device-activation flow, gets a Bearer access token,
  downloads the real DMG, opens it, and quits. It persists nothing.
- **The signing keypair**: an Ed25519 pair. The private key lives only in the server env
  (`LICENSE_SIGNING_PRIVATE_KEY`) and never leaves it. The public key is compiled into
  the app (`EntitlementVerifier`). The server signs entitlements; the app verifies them.

## Data model

Schema in `apps/web/lib/schema.ts`; migrations in `apps/web/drizzle/` (`0000_init`,
`0001_licensing_v2`, `0002_license_user_info`, `0003_users_table`, `0004_drop_machines`).

- `licenses`: `id`, `key` (unique, `EDITH-XXXX-XXXX`), `key_digest` (unique HMAC lookup
  digest), `key_last4`, `label`, `user_id` -> `users.id`, `plan_id` -> `plans.id`,
  `max_machines` (validated plan allowance snapshot), `custom_max_machines` (explicit
  override), `pending_max_machines` / `pending_effective_at`, `active`, `status`,
  `status_reason`, `policy_version` (default 2), timestamps.
- `users`: `id`, `email` (unique), `name`, `phone`. Customer contact details live here,
  referenced by `licenses.user_id`.
- `devices`: `id` (random device id, primary key), `license_id`, `public_key` (SPKI DER
  base64url), `public_key_thumbprint` (base64url SHA-256 of the SPKI DER),
  `hardware_uuid_digest`, `device_name`, `status` (`active` / `deactivated` / ...),
  `first_activated_at`, `last_verified_at`, `deactivated_at`, `credential_generation`,
  `last_app_version`.
- `plans`: `id`, `name`, `provider`, `external_product_id`, `external_price_id`,
  `max_machines`, `billing_model`, `active`.
- `device_credentials`: rotating refresh credentials stored as `token_digest` with a
  `generation`, `issued_at`, `expires_at`, `revoked_at`, `revocation_reason`.
- `activation_challenges`: `purpose`, `nonce_digest`, `license_id`, `device_id`,
  `expires_at`, `consumed_at`, `attempts`. Single-use, 5-minute lifetime.
- `payment_events`: idempotency and audit for the payments webhook, unique on
  `provider_event_id`.
- `security_events`: append-only audit of status transitions and device lifecycle.

A **seat is one active device**. `countActiveSeats(licenseId)` counts distinct devices
with `status = active` for the license; deactivated and revoked devices never count.
Concurrent activations serialize on a per-license Postgres advisory lock
(`runExclusive`), so the seat count cannot be raced.

## Device identity

`apps/macos/Sources/EdithKit/Core/DeviceIdentity.swift`:

- Each install generates a **random device id** (`UUID().uuidString`) and a **P-256
  device key** (Secure Enclave when available, software key otherwise). No hostname is
  sent to the server; `device_name` is optional and cosmetic.
- Public key on the wire is `base64url(SPKI DER)`; its thumbprint is
  `base64url(SHA-256(SPKI DER))`. Device signatures are base64url DER ECDSA over SHA-256.
- The **hardware digest** is `lowercase-hex SHA-256("edith:" + IOPlatformUUID)`. The raw
  `IOPlatformUUID` is never sent, and the digest is never an auth credential. It is only
  a same-Mac dedupe signal.

### Reinstall dedupe

`IOPlatformUUID` is stable across OS reinstalls; the device id is not. A fresh install
gets a brand new device id, but it sends the same hardware digest. On activation the
server calls `reclaimSeatsByHardwareDigest`: it deactivates any other active device on
the same license that carries this hardware digest before counting seats, so the same
Mac never consumes a second seat. The installer and the app run the identical flow and
send the identical hardware digest, so downloading through the installer and then
launching the app does not burn two seats.

## API endpoints

All under `apps/web/app/api/`, unversioned. No `/api/v1` or `/api/v2` exists. Every route
is `no-store`, `nodejs` runtime, strict-zod validated, and rate limited (per-ip, per
subject key/device, and a stricter failure bucket; Upstash Redis in production, in-memory
in dev).

Every mutating call is challenge-response. The client first requests a challenge, then
signs the message

```
edith-v2.<purpose>.<challengeId>.<nonce>
```

with the device private key. Challenges expire in 5 minutes, are single-use, and the
`nonce` is echoed back and matched against `nonce_digest`. The `edith-v2` literal here is
just the fixed message prefix, not a URL or protocol version.

- `POST /api/activation/challenge` `{licenseKey, devicePublicKey, deviceId, purpose?}`
  -> `{challengeId, nonce, expiresAt}`.
- `POST /api/activation` `{licenseKey, challengeId, nonce, deviceId, devicePublicKey,
  signature, appVersion, deviceName?, hardwareUuidDigest?}` -> device session
  (`{ok, planId, machinesUsed, maxMachines, entitlement, refreshCredential, accessToken,
  accessTokenExpiresAt}`). Seat-limit failures return `403 machine_limit_reached` only
  for a valid, active key; anything else returns a generic `invalid_credentials`.
- `POST /api/devices/refresh/challenge` `{deviceId, refreshCredential, purpose?}`
  -> `{challengeId, nonce, expiresAt}`.
- `POST /api/devices/refresh` `{deviceId, challengeId, nonce, signature, appVersion}`
  -> a fresh device session (rotates the credential, re-issues entitlement and token).
- `POST /api/devices/deactivate` `{deviceId, challengeId, nonce, signature}` -> `{ok}`.
  Marks the device deactivated, revokes its credentials, frees the seat, records a
  security event.
- `POST /api/checkout` `{planId, machines?, email?}` -> `{ok, url, checkoutId}`. Creates a
  Razorpay hosted Payment Link (see below).
- `POST /api/licenses/resend` `{email}` -> always `{ok, message}`. Emails every active key
  for that address (see below).
- `POST /api/payments/razorpay/webhook`: signature-verified, idempotent (see below).
- `GET /api/download/dmg`: **Bearer access token only**. Streams the latest `Edith-v*.dmg`
  from the private GitHub release using the server `GITHUB_TOKEN`. 403 `unlicensed`
  otherwise.
- `GET /api/appcast`: **Bearer access token only**. Streams the Sparkle feed and rewrites
  DMG enclosure URLs to point back at `download/dmg`, so updates also flow through the
  authorized endpoint.
- `GET /api/download/installer`: **public**, no auth. Streams `EdithInstaller.dmg` from
  the latest release; serves a friendly 503 holding page when the asset is not published
  yet. This is what the website Download button links to.

## Key and credential storage

- **License keys**: stored server-side only as `key_digest =
  lowercase-hex HMAC-SHA256(LICENSE_KEY_LOOKUP_PEPPER, normalized key)`, plus `key_last4`
  for support. Lookups are by digest (`lib/license-key.ts`).
- **Refresh credentials**: `edithrc_` + base64url random, stored as an HMAC digest in
  `device_credentials`. They rotate on every activation and refresh; the previous
  generation stays valid for a 60-second overlap so an in-flight rotation cannot lock a
  client out (`lib/refresh-credential.ts`, `issueCredential` in `lib/license.ts`).
- **Access tokens**: HMAC-signed `b64url(json).b64url(sig)` with scopes
  `["download","appcast"]`, secret `LICENSE_ACCESS_TOKEN_SECRET`. Default TTL is
  `LICENSE_ACCESS_TOKEN_TTL_MINUTES`, which defaults to **840 minutes** (14 hours). Used
  as `Authorization: Bearer` for downloads and appcast only (`lib/access-token.ts`).

On the Mac these live as plain 0600 files in the app support directory
(`FileLicenseCredentialStore`, items: `device-id`, `device-key`, `refresh-credential`,
`access-token`, `entitlement`, `trusted-time`).

## Entitlement format

The entitlement is the app's offline proof. Format is `b64url(json).b64url(ed25519 sig)`
with a fixed key order (`lib/entitlement.ts`):

```json
{"version":2,"keyId":"edith-2026-07","receiptId":"<uuid>","licenseId":"<uuid>","deviceId":"<device id>","deviceKeyThumbprint":"<b64url sha256 spki>","productId":"edith","planId":"personal_3","maxMachines":3,"features":["edith-core"],"issuedAt":0,"notBefore":0,"expiresAt":0,"policyVersion":2}
```

The `"version":2` field versions the entitlement payload format itself. It is not a URL
or an API version. `keyId` selects the signing key from a static `(keyId, publicKey)`
trust list in the client (`EntitlementVerifier.productionKeys`, currently
`edith-2026-07`), so the keypair can rotate by shipping a new build that trusts both.
`keyId` defaults to `LICENSE_SIGNING_KEY_ID`. TTL defaults to 30 days
(`LICENSE_ENTITLEMENT_TTL_DAYS`).

The client (`LicenseEntitlement.swift`) verifies the Ed25519 signature over the exact
payload bytes, then checks `version == 2`, the trusted `keyId`, `productId`, the
`deviceId` and `deviceKeyThumbprint` match this install, `notBefore`, and expiry against
its trusted clock.

## Client state machine

`LicenseCoordinator.riskState` derives one shared state from the stored entitlement plus a
`TrustedTime` record (last server time, wall clock at sync, monotonic uptime anchor, boot
session id):

- `valid`: signature good and not expired under trusted time.
- `graceActive(remainingDays, warn)`: entitlement expired but inside the 30-day offline
  grace (`defaultGraceDays = 30`). Silent until the last 5 days (`warnWindowDays = 5`),
  which flip `warn` on. Refresh runs in the background. A valid entitlement with no
  trusted-time record yet is also treated as grace until the first sync.
- `recovery`: grace exhausted, or entitlement not-yet-valid / unknown key. The app stops
  feature engines but keeps data, export, settings, and support reachable.
- `revoked`: the entitlement failed to parse or verify (tampered).
- `noLicense`: no entitlement stored.

`launchDecision` starts the app for `valid` and `graceActive` and gates for `noLicense`,
`recovery`, and `revoked`.

**Trusted-time rollback cap**: `effectiveNow` takes the max of the wall clock and the
anchored trusted time, so moving the clock forward cannot fake expiry away. Moving it
backward more than 24 hours behind the last server time
(`TrustedTime.rollbackToleranceSeconds = 86_400`) is capped, so a rollback cannot escape
the grace ceiling.

## Plans and ceilings

The price ladder lives in `lib/pricing.ts` and is the single source of truth; `lib/plans.ts`
derives its catalog from it.

| Plan | Macs | USD price | INR price |
| --- | --- | --- | --- |
| `individual_1` | 1 | $25 | Rs 2,100 |
| `personal_3` | 3 | $45 | Rs 3,800 |
| `power_5` | 5 | $65 | Rs 5,500 |
| `custom` | 6 to 50 | $65 + $10 per Mac above 5 | Rs 5,500 + Rs 850 per Mac above 5 |

`custom` allowances live on the license as an explicit `custom_max_machines` override;
`effectiveAllowance` is `custom_max_machines ?? max_machines`.

Env ceilings `LICENSE_STANDARD_MAX_MACHINES_CAP` (default 5) and
`LICENSE_CUSTOM_MAX_MACHINES_CAP` (default 50) are **validated, never clamped**: an
allowance above its ceiling throws at issuance rather than being silently reduced
(`validatePlanAllowance`).

Razorpay Payment Links carry `plan_id` and `machines` as string values in their `notes`
object. Razorpay does not use a product id for this flow, so the plan remains an Edith
identifier and the database schema does not depend on Razorpay catalogue data.

## Checkout

`POST /api/checkout` (`app/api/checkout/route.ts`) takes `{ planId, machines?, email? }`
and returns a Razorpay hosted Payment Link `short_url`.

Every link uses INR and an integer amount in paise. Fixed tiers use the INR ladder, while
the custom tier uses the server-computed `customPricePaise` value. Partial payments are
disabled. Checkout creation uses HTTP Basic authentication with
`RAZORPAY_KEY_ID:RAZORPAY_KEY_SECRET` against `https://api.razorpay.com/v1`; test and live
mode use the same host and are selected by the `rzp_test_` or `rzp_live_` key prefix.

Seat counts are validated before Razorpay is called: a fixed tier rejects any count other
than its own, and custom accepts 6 to 50 only.

## Payments webhook

`POST /api/payments/razorpay/webhook` (`lib/payments.ts`):

- Verifies `x-razorpay-signature` against the raw request body with HMAC-SHA256 and
  `RAZORPAY_WEBHOOK_SECRET` before parsing anything. The hex digest is compared in constant
  time after checking its length.
- Razorpay does not sign a timestamp header. The endpoint therefore cannot enforce a
  replay-age window. Signature validation proves authenticity but not freshness;
  persistent idempotency is the replay defence.
- Idempotent on `provider_event_id`: it uses `x-razorpay-event-id` when present and falls
  back to `<event>:<payment link id>`. The official refund payload has no Payment Link
  entity, so `refund.created` falls back to its refund id. A replay returns the stored
  result, and a unique-violation race falls back to the recorded outcome.
- Fulfils only on **`payment_link.paid`**. The link, order, and payment must report paid or
  captured state before a licence is minted.
- Resolves the plan only from Payment Link notes (`plan_id`, `machines`). Notes are
  strings; non-integer, out-of-range, unknown, or allowance-breaking values are refused.
- Re-derives the expected INR price from the ladder and compares it to the signed
  `payment_link.amount`, the original amount configured on the link. Razorpay reports
  `amount_paid` and whether an offer is associated, but the Payment Link webhook does not
  provide a numeric discount amount or a customer-tax subtotal that can reconstruct list
  price from the gross charge. Comparing the original link amount preserves the list-price
  check, permits a valid offer to reduce `amount_paid`, and avoids treating Razorpay fee
  tax as customer tax.
- Links the buyer to a `users` row by email, mints the key, and stores its digest and
  last4. `refund.created` moves the license to `refunded`, using the refund's payment id to
  locate the original paid event. Every transition writes a `security_events` row.
- Sends the key through Resend **after** the transaction commits, so a delivery failure
  never rolls back a paid order. The outcome is recorded as `license_delivered`,
  `license_delivery_failed`, or `license_delivery_skipped` when no buyer email is present.

## Key recovery

`POST /api/licenses/resend` lets a buyer have their key emailed again from the
`/license` page.

It **always returns the same 200 body**, whatever happens: unknown address, malformed
input, rate limited, or database error. That is deliberate. A differing status, body, or
error would turn the endpoint into an oracle for "does this person own Edith", which is
customer data we do not owe an anonymous caller.

Only `active` licences are sent, so a refunded or charged-back key is not recoverable. All
of an address's keys go in one email, so a buyer with several licences gets one message
rather than several.

Because the caller chooses the recipient, this endpoint can mail a third party. It is
therefore limited twice: the normal per-IP route limit, plus `checkRecoveryRateLimit`, a
tighter per-address bucket (2 per minute) so an attacker cannot use it to flood someone
else's inbox.

## Operations

**Required env** (`lib/required-env.ts`): `DATABASE_URL`, `GITHUB_TOKEN`, `GITHUB_REPO`,
`LICENSE_SIGNING_PRIVATE_KEY`, `LICENSE_KEY_LOOKUP_PEPPER`, `LICENSE_ACCESS_TOKEN_SECRET`.

**Optional env**: `LICENSE_SIGNING_KEY_ID` (default `edith-2026-07`),
`LICENSE_ENTITLEMENT_TTL_DAYS` (30), `LICENSE_ACCESS_TOKEN_TTL_MINUTES` (840),
`LICENSE_STANDARD_MAX_MACHINES_CAP` (5), `LICENSE_CUSTOM_MAX_MACHINES_CAP` (50),
`SITE_URL` (default `https://edith.pulkit.page`), `UPSTASH_REDIS_REST_URL`,
`UPSTASH_REDIS_REST_TOKEN`.

**Payments env**: `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`,
`RAZORPAY_WEBHOOK_SECRET`, `RESEND_API_KEY`, `LICENSE_EMAIL_FROM`.

**Test mode**: use a Razorpay `rzp_test_` key id with its secret. The API remains
`https://api.razorpay.com/v1`; there is no separate sandbox host. Configure a test-mode
webhook for `/api/payments/razorpay/webhook` with a dedicated webhook secret and subscribe
to `payment_link.paid` and `refund.created`.

**Mint a license by hand** (billing mints the rest automatically):

```
make license MACHINES=3 LABEL="Pulkit" NAME="Pulkit Garg" EMAIL="pulkit@example.com" PHONE="+911234567890"
```

`scripts/mint-license.sh` generates the key, computes its digest and last4 with the app's
own helpers, upserts the user, and inserts the license. Only `MACHINES` is required.

**Apply a migration**:

```
make db-migrate FILE=apps/web/drizzle/0004_drop_machines.sql
```

`db-migrate` reads `DATABASE_URL` from `apps/web/.env` (stripping `channel_binding`, which
postgres over `psql` needs) and runs the file with `ON_ERROR_STOP`.

**Env tooling**:

- `make env-generate`: fills missing generated secrets (`LICENSE_KEY_LOOKUP_PEPPER`,
  `LICENSE_ACCESS_TOKEN_SECRET`) into `apps/web/.env`.
- `make env-rotate CONFIRM=1`: rotates those generated secrets. Rotating the pepper
  invalidates every stored key digest and refresh credential, so every customer must
  re-activate; it is a break-glass operation.
- `make env-sync CONFIRM=1`: pushes `apps/web/.env` to the Vercel environment after a
  required-env check.

**Release** (`make release V=x.y.z`): bumps the plist versions, builds and signs the app,
packages `Edith-v*.dmg`, generates and signs the Sparkle appcast, builds
`EdithInstaller.dmg`, tags, pushes, and uploads all three assets to the GitHub release. It
refuses to release without a Developer ID Application signing identity unless
`EDITH_RELEASE_ALLOW_DEV_SIGNING=1` is set, which produces a dev-signed, non-notarized
build for use until a Developer ID exists.

**Go-live checklist still pending**:

- Complete Razorpay account activation and settlement configuration.
- Set the live `RAZORPAY_KEY_ID` and `RAZORPAY_KEY_SECRET`.
- Set `RAZORPAY_WEBHOOK_SECRET` and register the production webhook for
  `payment_link.paid` and `refund.created`.
- Verify card and UPI Payment Link checkout end to end in test mode and live mode.
- Verify the `pulkit.page` sending domain in Resend and set `RESEND_API_KEY`.
- Obtain a Developer ID Application identity and drop `EDITH_RELEASE_ALLOW_DEV_SIGNING`.
- Provision Upstash Redis env vars for production rate limiting.

## What it protects and does not

It makes casual sharing useless: a shared DMG sits at activation, an unactivated device
gets nothing, and a leaked key burns one of its finite seats the moment it is used. The
entitlement is signed and device-bound, so a local flag cannot be flipped to fake
activation; the binary itself would have to be patched. This is client-side enforcement:
a determined attacker who patches the app and stays offline can still run a cracked copy.
The goal is to raise the effort past where casual piracy happens, not to make it
impossible.
