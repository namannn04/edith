# Contributing to Edith

Issues and pull requests are welcome.

## Build and run

```bash
./build.sh            # build and run from build/Build/Products/Debug
./build.sh --install  # build, copy to /Applications, launch
```

Needs Xcode, not just Command Line Tools — `edth.xcodeproj` is a full Xcode
project at the repo root. `build.sh` drives `xcodebuild` for the `EdithMain`
scheme, which also builds and embeds `EdithHelper` (the always-on menu bar
companion, nested at `Contents/Library/LoginItems`), `EdithFiles` (nested at
`Contents/Library/Applications`), and the `ed`/`edh` CLI tools
(`Contents/MacOS`). Signing is `CODE_SIGN_STYLE = Automatic`, so it picks up
whatever Apple Development identity Xcode already trusts on this Mac — no
manual certificate setup needed for local builds.

`apps/macos` is an older, parallel SwiftPM layout of the same app. It is
still what `make release` and the release workflows build and sign (see
Releases below) until that migration finishes, and it is still where the
Swift test suite lives (`cd apps/macos && ./test.sh`). Day-to-day building
and running should use `edth.xcodeproj` / `./build.sh` above.

## Checks

Run `make ci` before pushing; the pre-push hook runs the same gates.

| Target | What it does |
| --- | --- |
| `make ci` | Everything below, after `bun install --frozen-lockfile`. |
| `make ci-comments` | Fails on any disallowed comment in tracked source. |
| `make ci-secrets` | Scans every tracked file for leaked secrets. |
| `make ci-lint` | Biome format and lint for `scripts/` and `apps/site`. |
| `make ci-scripts` | The `bun test` suite for `scripts/`. |
| `make ci-promo` | `npm ci` and type check for the Remotion promo video. |
| `make ci-swift-check` | apps/macos: `swift format lint --strict`, `swift build` and the tests. |
| `make ci-swift` | `ci-swift-check` plus a full `build.sh` with bundle and codesign assertions. |
| `make ci-xcode-check` | edth.xcodeproj: `swift format lint --strict` and a build of every target. |
| `make ci-xcode` | `ci-xcode-check` plus bundle and codesign assertions against the xcodebuild output. |

Other targets: `make build`, `make install`, `make reset`, `make reinstall`,
`make site-dev` (serves `apps/site` on port 8000), `make loc`.

This repo is kept comment-free and CI enforces it. Run `bun run strip-comments`
if one slips in. Write names and structure that do not need prose.

## Releases

Releases still build from `apps/macos`, not `edth.xcodeproj` — that part of
the migration hasn't happened yet. Merging anything under `apps/macos/` into
`main` publishes a new patch version
automatically. The `Release on merge` workflow bumps the last version component
(`0.0.1` becomes `0.0.2`, never `0.1.1`), builds and signs the app, generates a
signed Sparkle appcast, commits the bump, tags it, and publishes the release.

`make release V=1.8.0` does the same sequence locally when you need to cut one by
hand.

### Required secrets

| Secret | Why |
| --- | --- |
| `SPARKLE_PRIVATE_KEY` | Signs the appcast. Without it the workflow refuses to publish. |
| `MACOS_CERT_P12` | Base64 of the exported signing certificate and private key. |
| `MACOS_CERT_PASSWORD` | The password on that `.p12`. |

`SPARKLE_PRIVATE_KEY` is the EdDSA key `generate_keys -x` exports, the private
half of `SUPublicEDKey` in `Info.plist`:

```bash
gh secret set SPARKLE_PRIVATE_KEY < sparkle-private.key
```

The workflow refuses to publish without it because a release whose `appcast.xml`
is missing or unsigned breaks in-app updates for everyone: Sparkle resolves the
feed from `releases/latest/download/appcast.xml`, so the newest release always
owns the feed.

The signing certificate is exported with:

```bash
security export -k ~/Library/Keychains/login.keychain-db -t identities \
  -f pkcs12 -P "<pick-a-password>" -o cert.p12
gh secret set MACOS_CERT_P12 < <(base64 -i cert.p12)
printf %s "<pick-a-password>" | gh secret set MACOS_CERT_PASSWORD
```

The DMG is published as `Edith.dmg` rather than a versioned name so
`releases/latest/download/Edith.dmg` always resolves to the newest build, which
is what the website's download button uses.

### Why signing identity matters

macOS ties each permission grant to the app's code-signing designated
requirement, and a grant survives a reinstall only if the new build still
satisfies it. An ad-hoc signature pins the requirement to the binary hash, which
changes every build, so an ad-hoc DMG resets every permission on reinstall.

By default `codesign` writes a requirement naming the exact leaf certificate, so
grants still evaporate when that certificate is re-issued. When the identity
carries a team id, `build.sh` pins the requirement to bundle id plus team id
instead:

```
identifier "com.pulkit.edith" and anchor apple generic
  and certificate leaf[subject.OU] = "<team id>"
```

Every certificate the team owns satisfies that, so grants survive renewals and
the move to Developer ID. macOS records the requirement at the moment a
permission is granted, so reset once after installing a build made with this
change:

```bash
tccutil reset All com.pulkit.edith
tccutil reset All com.pulkit.edith.statusbar
```

## Website

`apps/site` is hand-written static HTML, CSS and JS with no framework, no build
step and no dependencies. GitHub Pages serves the folder as-is. `apps/site/CNAME`
must keep naming `edith.pulkit.page` or the deploy guard fails.
