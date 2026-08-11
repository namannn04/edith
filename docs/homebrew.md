# Homebrew

The Edith repository is its own Homebrew tap. There is no second repository to
maintain: `Casks/edith.rb` sits beside the source, and the release workflow rewrites
its version and checksum from the disk image it just published, so the cask always
points at the newest release.

## Install

```
brew tap pulkitxm/edith https://github.com/pulkitxm/edith
brew install --cask edith
```

The tap URL is required because the repository is named `edith` rather than
`homebrew-edith`. Tapping clones the full repository, roughly 50 MB.

The cask installs `Edith.app` into `/Applications` and links the two command line
tools that ship inside the bundle:

```
ed      the full CLI, everything the UI can do
edh     the same binary under its short name
```

Both land in Homebrew's `bin` directory, which sits ahead of `/usr/bin` on the
default `PATH`. `ed` therefore shadows the POSIX line editor of the same name; run
`/usr/bin/ed` when you want that one. Nothing is copied into `~/.local/bin`, so
`ed install` is only needed when Edith was not installed through Homebrew.

Requirements are declared in the cask and enforced by Homebrew: macOS 14 or later
on Apple Silicon.

## Update

Edith updates itself through Sparkle, so the cask is marked `auto_updates true` and
a routine `brew upgrade` leaves it alone rather than fighting the in-app updater.
Refresh the tap and force Homebrew to reinstall the newest release with:

```
brew update
brew upgrade --cask --greedy edith
```

`brew update` alone only refreshes the tap; it changes nothing on disk. To reinstall
the version the cask currently names, without waiting for a new release:

```
brew reinstall --cask edith
```

## Inspect

```
brew info --cask edith          version, checksum, what the cask installs
brew list --cask edith          the paths Homebrew put on disk
brew outdated --cask --greedy   whether a newer release exists
```

## Uninstall

```
brew uninstall --cask edith
```

That removes the app and the two symlinks, quitting Edith, its menu bar helper and
the Files helper first. To also delete settings, caches and usage history:

```
brew uninstall --cask --zap edith
```

Stop tracking the tap entirely with:

```
brew untap pulkitxm/edith
```

## Releasing

Nothing about the cask is hand-edited. The `cask` job in
`.github/workflows/release.yml` runs after the release is published, hashes the
`Edith.dmg` it built, rewrites the `version` and `sha256` lines, and commits the
result to `main`. That commit touches only `Casks/`, which is outside the paths that
trigger a release, so it cannot loop.
