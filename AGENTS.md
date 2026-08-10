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

## Layout

Every Swift source lives in one SwiftPM package, `Packages/Edith`: `Sources/Edith`
(main app UI), `Sources/EdithKit` (shared core), `Sources/EdithCLI`, the vendored
`Vendor/Highlighter`, thin `Sources/{EdithMain,EdithFiles,EdithHelper,ed,edh}`
entry points, and `Tests/EdithTests`. `edth.xcodeproj` builds the app bundles from
those same directories through folder-synchronized groups, so a new file needs no
project edit: drop it in the target's directory and it builds. Never add a second
copy of a source tree; there is one.

## Checks

- `bun run check-comments` - no disallowed comments (all tracked source).
- Swift checks: `make ci-swift-check` runs all of it. Individually, from `Packages/Edith`:
  `swift format lint --strict --recursive Sources Tests Package.swift` (format + lint),
  `./test.sh` (tests); and from the root
  `xcodebuild -project edth.xcodeproj -scheme <EdithMain|EdithHelper|EdithFiles|ed|edh>
  -configuration Debug build` (type-check per target).
- `bun run lint` - Biome format + lint for the dashboard.
- `bun test apps/dashboard/tests scripts` - JS tests.
- `cd apps/promo-video && npm ci && npx tsc --noEmit` - promo-video (Remotion) type-check.
