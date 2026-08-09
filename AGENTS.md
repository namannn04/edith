# Edith

## Code style: no comments

Do not write comments in code. This repo is kept comment-free and CI enforces it.

- Applies to Swift, JS/MJS, CSS, JSON, YAML, and HTML.
- Allowed exceptions are functional directives only: `// swift-tools-version`,
  `// swiftlint:...`, `// swift-format...`, `biome-ignore`, `@ts-*` / `eslint-*`,
  and `/*! ... */` license blocks.
- Clean stray comments with `bun run strip-comments`.
- `bun run check-comments` is what CI runs; it fails on any disallowed comment.

Write code clear enough not to need comments. If a name or a block needs
explaining, improve the name or the structure instead of adding prose.

## Checks

- `bun run check-comments` - no disallowed comments (all tracked source).
- Swift checks for `edth.xcodeproj` (the day-to-day project): `xcodebuild -project edth.xcodeproj
  -scheme <EdithMain|EdithHelper|EdithFiles|ed|edh> -configuration Debug build`,
  `swift format lint --strict --recursive EdithMain EdithHelper EdithFiles ed edh Packages/EdithKit
  Packages/EdithCLI` (format + lint). `make ci-xcode-check` runs all of it.
- Swift checks still also run from `apps/macos/` (the release source of truth until that migration
  finishes, and the only place the test suite lives): `swift build` (type-check), `swift test` /
  `./test.sh` (tests), `swift format lint --strict --recursive Sources Tests Package.swift`
  (format + lint). `make ci-swift-check` runs all of it.
- `bun run lint` - Biome format + lint for the dashboard.
- `bun test apps/dashboard/tests scripts` - JS tests.
- `cd apps/promo-video && npm ci && npx tsc --noEmit` - promo-video (Remotion) type-check.
