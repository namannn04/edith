# Edith licensing and distribution

This Next.js app is the public download and licensing layer for Edith. It serves the public installer, verifies licensed machines, and streams private release assets without exposing GitHub credentials.

## Setup

Install dependencies:

```sh
bun install
```

Copy `.env.example` to `.env.local` and set:

- `DATABASE_URL`: Neon or Vercel Postgres connection string with SSL enabled
- `GITHUB_TOKEN`: fine-grained token with read access to releases in the private repository
- `GITHUB_REPO`: `pulkitxm/edith`

Create the database schema with Drizzle:

```sh
bun run db:push
```

Alternatively, apply the handwritten migration directly:

```sh
psql "$DATABASE_URL" -f drizzle/0000_init.sql
```

Start the development server:

```sh
bun run dev
```

## Create a license

Create a key with a label and seat limit:

```sh
bun run create-license --machines 2 --label "Customer name"
```

The command writes the new key to standard output once. Store it securely and send it to the customer through the intended private channel.

## Tests

Run the unit tests:

```sh
bun test
```

The tests cover activation idempotency, seat limits, inactive licenses, and appcast enclosure rewriting.

## Deploy to Vercel

1. Import this project into Vercel with `web-staging` as the project root.
2. Connect a Neon or Vercel Postgres database.
3. Add `DATABASE_URL`, `GITHUB_TOKEN`, and `GITHUB_REPO` to the Production, Preview, and Development environments as needed.
4. Apply the database schema with `bun run db:push` from a trusted local environment, or run `drizzle/0000_init.sql` with `psql` against the production connection string.
5. Deploy the project.
6. Add `edith.pulkit.page` as a custom domain and configure the DNS record Vercel provides.

## Release interaction

Publish a GitHub release in the private `pulkitxm/edith` repository with these assets:

- `EdithInstaller.dmg` for the public first install
- `Edith-vX.Y.Z.dmg` for licensed app downloads and updates
- `appcast.xml` for Sparkle update discovery

The site reads the latest published release on each request. No site deployment is needed for a new Edith release. Licensed requests for the appcast and versioned DMG are verified against the database, while the installer remains public.
