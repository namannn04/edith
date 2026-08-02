# Contributing to Edith

Issues and pull requests are welcome.

## Build and run

```bash
cd apps/macos
./build.sh            # build and run from dist/
./build.sh --install  # build, copy to /Applications, launch
./test.sh             # run the Swift test suite
```

Needs only Xcode Command Line Tools (Swift 6). Use `./test.sh` rather than
`swift test`; it adds the search paths for the Testing framework that ship with
Command Line Tools.

`build.sh` also assembles a small `Edith.app` login item nested inside the main
bundle (`Contents/Library/LoginItems`), the always-on menu bar companion that
keeps running after the main app quits.

Both bundles are signed ad-hoc by default. Ad-hoc signatures change on every
rebuild, which resets permission grants (Accessibility, Screen Recording, and so
on) and can duplicate login-item registrations. To avoid that, create a
self-signed certificate once through Keychain Access → Certificate Assistant →
Create a Certificate, name it "Edith Dev", Identity Type "Self Signed Root",
Certificate Type "Code Signing", then build with:

```bash
EDITH_SIGN_IDENTITY="Edith Dev" ./build.sh --install
```

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
| `make ci-swift-check` | `swift format lint --strict`, `swift build` and the tests. |
| `make ci-swift` | `ci-swift-check` plus a full `build.sh` with bundle and codesign assertions. |

Other targets: `make build`, `make install`, `make reset`, `make reinstall`,
`make site-dev` (serves `apps/site` on port 8000), `make loc`.

This repo is kept comment-free and CI enforces it. Run `bun run strip-comments`
if one slips in. Write names and structure that do not need prose.

## Releases

Merging anything under `apps/macos/` into `main` publishes a new patch version
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
