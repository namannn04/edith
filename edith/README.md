# Edith (menu bar app)

Native SwiftUI menu bar app (the eyeglasses icon next to the system controls).
Two tabs today, one folder per feature so more slot in later:

- **Agent Usage** (`Sources/Edith/Usage/`) — session (5h) and weekly
  limit bars with live second countdowns ("2d 3:45:12" past 24h) from the
  OAuth usage endpoint (token read silently via `/usr/bin/security`,
  auto-refresh every 5 min + on wake), a full-history activity-calendar
  heatmap, token/cost stats for today / yesterday / this week / this billing
  cycle from `../dashboard/data/usage.json`, a source filter, a ↻ button that
  runs `../dashboard/cc-update` (with a collapsible live log), and ↗ which
  opens `../dashboard/dashboard.html` in the browser carrying the panel's
  filters as `?sources=` (same param scheme the dashboard already uses).
- **Music** (`Sources/Edith/Music/`) — lists every playable file in
  `../local/music/` straight from the folder (mp3/m4a/mp4/webm/wav/flac/…, no
  manifest), thumbnails from embedded art or a video frame, drag-to-seek,
  play/pause with short fades, prev/next, auto-advance loop, volume, and a
  folder button to open the directory in Finder.

## Build & install

```bash
./build.sh            # build + run from dist/
./build.sh --install  # build + copy to /Applications + launch
```

Needs only Xcode Command Line Tools (Swift 6). The bundle is assembled by the
script (no Xcode project) and ad-hoc signed.

## Paths

The app assumes it lives inside this repo and finds everything relative to the
repo root. If the repo ever moves:

```bash
defaults write com.pulkit.control-center repoPath /new/path/to/control-center
```

(The bundle id stays `com.pulkit.control-center` from before the Edith rename
so saved preferences — volume, tab, repoPath — carry over.)

## Notes

- Dark-mode UI only (forced via `.preferredColorScheme(.dark)`).
- Runs 24/7: registered as a login item; timers pause during sleep and a
  wake observer refreshes immediately on lid-open. No polling beyond the
  5-minute limits call; stats re-parse only when `usage.json`'s mtime changes.
- On a 429 from the usage endpoint the poll backs off (Retry-After or 30 min).
