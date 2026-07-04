# Edith

Personal control center for the Mac menu bar (the eyeglasses icon), plus the
usage dashboard it reads from.

| Directory | What it is |
|---|---|
| `edith/` | The menu bar app — native SwiftUI, two tabs (Agent Usage, Music). See `edith/README.md`. |
| `dashboard/` | The self-contained coding-agent usage dashboard and its data pipeline (`cc-update` → `data/usage.json` → `dashboard.html`). See `dashboard/README.md`. |
| `local/` | Gitignored personal files: `local/music/` (what the Music tab plays), `local/extras/` (reference clones). |
| `docs/` | Design notes and specs. |

## Quick start

```bash
edith/build.sh --install       # build Edith.app → /Applications, launch
dashboard/cc-update            # refresh usage data locally
dashboard/cc-update --push     # refresh + commit + push the snapshot
```

Edith shows session/weekly rate limits (5-min auto-refresh), token/cost stats
and an activity heatmap from `dashboard/data/usage.json`, and plays whatever
is in `local/music/`. The ↗ button opens the full dashboard in the browser
with the panel's filters applied.
