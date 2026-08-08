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

## Delegating to Codex (make jobs finish fast)

Codex runs in a sandbox that HANGS on any command over ~10 minutes: `swift build`,
`./build.sh`, `bun run build`, `./test.sh`, full test runs. A hung job burns hours of
wall-clock while consuming almost no tokens (the tell: low token count + long elapsed +
its log going silent right after "File changes completed" or looping on `git diff`). To
avoid this:

- Give Codex WRITE-ONLY tasks. Every prompt says: "no `swift build`/`swift test`/
  `./test.sh`/`./build.sh` or any command over 60 seconds; `swift format lint --strict`
  and fast static checks only." The reviewer (main session) compiles, tests, and commits.
- Put a startup delay before polling a new job's status (it takes a few seconds to
  register; polling too early reports 0 running and fires waiters prematurely).
- If a job is quiet for a long stretch, treat it as wedged: cancel it and verify the
  changes it already applied to the working tree, rather than waiting.
- Codex processes have NO Screen Recording / Accessibility TCC grants; drive any UI
  screenshotting or synthetic-input testing from the main session, not Codex.

## Recurring integration fixes (apply before building)

- A Swift `switch` used as an expression in a function that returns a value needs an
  explicit `return switch ... { }`; Codex often omits it.
- Never leave `#Preview { }` macros in SwiftUI files: they fail the command-line SwiftPM
  build ("PreviewsMacros plugin not found").
- `swift test` fails with "no such module 'Testing'" under Command Line Tools; run
  `apps/macos/test.sh`, which adds the CLT Testing.framework search paths.

## Committing around protected work-in-progress

The tree often holds unrelated uncommitted work. Stage explicit paths, never `git add -A`;
after each Codex task, commit only that task's files. Committing a file DELETION (e.g. a
replaced stylesheet) is required or the `check-comments` pre-push hook ENOENTs on the still-
tracked path. The lefthook pre-push runs the full swift build + tests + comment check; when
it fails only because of another in-flight job's tree state, push with `--no-verify` AFTER
running build/tests/comment-check yourself on the staged files.

## Every UI action needs a CLI verb

The app and `ed` are peers over one shared core in `EdithKit`, not client and
server. Neither shells out to the other, so parity is a rule rather than a
consequence: anything the UI can change, `ed` must be able to change too, through
the same function.

- Mutations live in `EdithKit` (`ClipboardActions`, `MachineRegistry`, ...). Views
  and CLI commands call them; neither reads-modifies-writes a store file itself.
- Adding a UI action means adding a row to `UIParity.capabilities` in
  `Tests/EdithTests/CLIParityTests.swift` naming the `ed` verb that does the same
  thing. `everyMutatingCommandIsClaimedByAUIAction` fails when a mutating verb has
  no row, and `everyUIActionParsesWithTheArgumentsItClaims` fails when the verb it
  names does not exist or does not take those arguments.
- A new command also needs a `CommandNode` in `CommandTree.swift` (completion), a
  `JSONCase` in `CLIContractTests.swift` if it takes `--json`, and an entry in
  `docs/cli.md` and `Guide.swift`.

## Checks

- `bun run check-comments` - no disallowed comments (all tracked source).
- Swift checks run from `apps/macos/`: `swift build` (type-check), `swift test` / `./test.sh` (tests),
  `swift format lint --strict --recursive Sources Tests Package.swift` (format + lint).
- `bun run lint` - Biome format + lint for `scripts/` and `apps/site`.
- `bun test ./scripts` - JS tests. Do not pass a bare `scripts`; it also matches the
  gitignored `extras/` tree and reports unrelated failures.
- `cd apps/promo-video && npm ci && npx tsc --noEmit` - promo-video (Remotion) type-check.

## Website

`apps/site` is hand-written static HTML, CSS, and JS with no framework, no build step,
and no dependencies. GitHub Pages serves the folder as-is via `.github/workflows/pages.yml`,
which only runs when `apps/site` changes. `apps/site/CNAME` must keep naming
`edith.pulkit.page` or the deploy guard fails. Serve it locally with `make site-dev`.
