# Edith

Native SwiftUI menu bar app for the Mac (the eyeglasses icon next to the
system controls) — a personal control center with two tabs, one folder per
feature so more slot in later:

- **Agent Usage** (`Sources/Edith/Usage/`) — session (5h) and weekly limit
  bars with live second countdowns ("2d 3:45:12" past 24h) from the OAuth
  usage endpoint (token read silently via `/usr/bin/security`, auto-refresh
  every 5 min + on wake), a full-history activity-calendar heatmap, token/cost
  stats for today / yesterday / this week / this billing cycle from
  `dashboard/data/usage.json`, a source filter, a ↻ button that runs
  `dashboard/cc-update` (with a collapsible live log), and ↗ which opens the
  dashboard in the browser carrying the panel's filters as `?sources=`.
- **Music** (`Sources/Edith/Music/`) — lists every playable file in
  `local/music/` straight from the folder (mp3/m4a/mp4/webm/wav/flac/…, no
  manifest), thumbnails from embedded art or a video frame, drag-to-seek,
  play/pause with short fades, prev/next, auto-advance loop, volume, media-key
  / Now Playing integration, and a folder button to open the directory.

## Layout

| Path | What it is |
|---|---|
| `Package.swift`, `Sources/Edith/` | The app — plain SwiftUI executable, no Xcode project. |
| `build.sh`, `Info.plist`, `make-icon.swift`, `AppIcon.icns` | Build script, bundle bits, locally-generated icon. |
| `dashboard/` | The self-contained usage dashboard + data pipeline (`cc-update` → `data/usage.json` → `dashboard.html`). See `dashboard/README.md`. |
| `local/` | Gitignored personal files: `local/music/`, `local/extras/`. |
| `docs/` | Design notes and specs. |

## Build & install

```bash
./build.sh            # build + run from dist/
./build.sh --install  # build + copy to /Applications + launch
```

Needs only Xcode Command Line Tools (Swift 6). The bundle is assembled by the
script and ad-hoc signed.

## Data & paths

- Usage data never leaves the machine: `dashboard/data/` and the generated
  `dashboard/dashboard.html` are gitignored; the template's data block is
  empty. Refresh locally with `dashboard/cc-update`.
- The app finds everything relative to this repo. If the repo moves:
  `defaults write com.pulkit.control-center repoPath /new/path`
  (bundle id predates the Edith name so saved preferences carry over).

## Notes

- Dark-mode UI only; panel centers under the menu bar icon.
- Runs 24/7 as a login item: timers pause during sleep, a wake observer
  refreshes immediately, no polling beyond the 5-minute limits call, stats
  re-parse only when `usage.json`'s mtime changes, per-second countdowns tick
  only while the panel is visible.
- On a 429 from the usage endpoint the poll backs off (Retry-After or 30 min).
- Presenter view (gear menu) blurs track names and spend figures for screen
  sharing.
