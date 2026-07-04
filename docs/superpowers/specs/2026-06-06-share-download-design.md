# Download / Share - design

**Date:** 2026-06-06
**Status:** Approved

## Problem

There is no way to export the dashboard for sharing. The user wants to post their
Claude Code usage on X (Twitter): a clean, branded stats image of the **current
filtered view**, plus the ability to grab any individual chart as an image.

## Goal

1. A **share card**: one button that downloads a branded PNG summarizing the
   current filtered stats (cost, tokens, breakdowns), theme-matched, footer
   `cc.pulkitxm.com`.
2. **Per-chart PNG**: a small download button on each chart that saves that chart
   as a PNG (composited on a solid theme background).

Keep the UI clean: one primary button + subtle per-chart icons. No external
dependencies (pure canvas 2D + Chart.js's existing canvases).

## Non-goals

- No CSV/JSON data export (image only).
- KPIs / `render.js` are not changed.
- The activity-calendar heatmap (`#heat`, a DOM grid) and the data tables are
  not Chart.js canvases, so they get no per-chart button.

## Cycle/stats data source

Both features reflect the active filters because they read the same per-day rows
the charts use: `derive()` from `js/compute.js` (zero-filled, range/model/source
filtered). Row shape:
`{date, cost, input, output, cacheCreate, cacheRead, tokens, byModel:{model:{cost,tokens}}}`.

## Component 1 - `statsSummary(rows)` (pure)

New pure module `js/stats.js` (no DOM, no app-state; imports nothing from the
DOM layer) exporting `statsSummary(rows)`. Given `derive()` rows it returns:

- `totalCost` = Σ `row.cost`
- `totalTokens` = Σ `row.tokens`
- `input` = Σ `row.input`; `output` = Σ `row.output`;
  `cacheCreate` = Σ `row.cacheCreate`; `cacheRead` = Σ `row.cacheRead`;
  `cache` = `cacheCreate + cacheRead`
- `cacheRate` = `cacheRead / (cacheRead + input)`, or `0` when the denominator is 0
- `topModel` = model name with the greatest summed `byModel[m].cost` across rows,
  or `null` when there are no models
- `activeDays` = count of rows where `row.tokens > 0`
- `dailyAvg` = `totalCost / activeDays`, or `0` when `activeDays` is 0 (cost per active day)
- `peakDay` = `{date, tokens, cost}` of the row with the most tokens among active
  rows, or `null` when none

Pure and unit-tested with `bun test` (`tests/stats.test.js`).

## Component 2 - `js/share.js` (DOM / canvas)

New module `js/share.js`. Imports: `statsSummary` (stats.js), `derive` +
`activeWindow` (compute.js), `charts` (state.js), format helpers (format.js), and
theme color readers from charts.js (or reads CSS vars directly).

### `rangeLabel()`
Returns the card subtitle string:
- range mode `all` → `"All time"`.
- otherwise → `"<from> – <to>"` where from/to come from `activeWindow()` formatted
  like `26 May – 25 Jun 2026` (day + short month, end year always shown, start year
  only when it differs from end). For `cycle` mode this is exactly the cycle span.

### `drawShareCard()`
- Creates an offscreen `<canvas>` sized **1200×630 logical, scaled 2×** (backing
  store 2400×1260; `ctx.scale(2,2)`), for a crisp retina PNG.
- Reads theme colors at draw time (`--paper`/`--paper-2`, `--ink`, `--ink-soft`,
  `--gold`, accent `--cat`/source orange) via `getComputedStyle`, so the card
  matches the active light/dark theme.
- Draws, using the dashboard's mono font:
  - Title `Claude Code · Usage` + subtitle `rangeLabel()`.
  - Two hero figures: **total cost** (`fmtUSD`, gold) and **total tokens** (`fmtTok`),
    each as a big value with a small uppercase caption beneath.
  - A thin hairline divider, then an **aligned stat grid - 4 columns × 2 rows**, each
    cell an uppercase muted label on top with its value beneath (left-aligned on fixed
    column x-positions, so values line up rather than scattering):
    `INPUT / OUTPUT / CACHE / CACHE HIT` then
    `AVG / DAY / ACTIVE / TOP MODEL / PEAK` (`-` when `topModel`/`peakDay` are null).
  - No footer/branding link (GitHub Pages was removed).
- Exports via `canvas.toBlob` → object URL → a synthetic `<a download>` click →
  `URL.revokeObjectURL`. Filename: `cc-usage_<from>_<to>.png` (or
  `cc-usage_all.png` for All time), dates as `YYYY-MM-DD`.
- No external images are drawn, so the canvas is never tainted (works on `file://`).

### `downloadChart(canvasId)`
- Looks up `charts[canvasId]`; returns early if absent (not yet mounted).
- Creates a temp canvas matching the chart canvas's pixel size, fills it with the
  theme card background (`--paper-2`), draws the chart canvas onto it, then
  `toBlob` → download `cc-usage_<chart-name>.png` (chart-name derived from the
  card title, slugified).

### `wireShareButtons()`
Called once from `app.js` init (only when there is data):
- Wires the `#btn-share` "⤓ Card" button → `drawShareCard()`.
- Injects a per-chart button: for each `.card` that contains a `<canvas>`, append
  a small `⤓` button (class `chart-dl`) into that card's `.card-head`, with
  `data-canvas="<canvasId>"`; on click → `downloadChart(canvasId)`. Done once at
  init; works across chart re-mounts because `charts[id]` is looked up at click
  time and the canvas id is stable. Cards without a canvas (heatmap, tables) are
  naturally skipped.

## UI / markup / styles

- `dashboard.template.html`: add `<button class="btn-reset" id="btn-share">⤓ Card</button>`
  immediately after the existing `#btn-reset` button (reuses the reset button's
  styling for a consistent, clean look).
- `css/styles.css`: add a `.chart-dl` style - a small, subtle icon button placed
  at the top-right of `.card-head` (the card-head becomes a positioning context;
  card title/note are unaffected). Hover-emphasized, low-key by default.

## Files touched

- Create: `js/stats.js`, `tests/stats.test.js`, `js/share.js`
- Modify: `dashboard.template.html`, `css/styles.css`, `js/app.js`
- Rebuild: `dashboard.html` via `bun build.mjs`

## Testing

- **Unit (`bun test tests/stats.test.js`):** `statsSummary` over synthetic rows -
  totals, `cacheRate` (incl. zero-denominator), `topModel` selection, `activeDays`,
  `dailyAvg`, `peakDay`, and the all-zero/empty case (`topModel`/`peakDay` null,
  no divide-by-zero).
- **Build/static:** `bun build.mjs` succeeds; built `dashboard.html` contains
  `id="btn-share"` and the `chart-dl` wiring.
- **Manual (controller):** open `dashboard.html`; the `⤓ Card` button downloads a
  theme-matched PNG of the current filtered stats; each chart's `⤓` downloads that
  chart as a PNG; switching theme/range/filters is reflected in both.
