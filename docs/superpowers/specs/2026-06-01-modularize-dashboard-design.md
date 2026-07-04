# Modularize the dashboard page - design

**Date:** 2026-06-01
**Status:** Approved (pending spec review)

## Goal

`dashboard.html` is a single 1601-line file: ~225 lines of CSS, ~180 lines of
HTML, an inlined JSON data block, and one ~1165-line JavaScript IIFE containing
~40 functions that all share closure state. Editing it is painful. Split it into
focused, single-purpose files so the code is easier to read, navigate, and change.

This is a **behavior-preserving refactor**. The rendered page must look and
behave identically - same charts, filters, theme toggle, URL params, tooltips.

## Constraints / what must NOT change

- **`render.mjs` is untouched.** It inlines `data/usage.json` into the
  `<script id="usage-data" type="application/json">` block, which stays in
  `dashboard.html`. The data layer reads that block from the DOM. The
  `cc-update` pipeline (`git add data/usage.json dashboard.html`) keeps working
  as-is - `render.mjs` never touches the new `css/` or `js/` files.
- **The head theme-flash script stays inline** in `<head>`. It must run before
  first paint (sets `data-theme` to avoid a flash); a deferred module would be
  too late.
- **No bundler, no build step for JS.** Files are served directly as native
  `<script type="module">`. Chart.js stays a CDN `<script>`.
- **Output is multiple files served over HTTP** (the site is served at
  cc.pulkitxm.com). `file://` will not work for ES modules (CORS) - local dev
  uses a static server (`python3 -m http.server`).

## Target structure

```
dashboard.html      # markup + inline data block + inline theme-flash + <script type="module" src="js/app.js">
css/
  styles.css        # the <style> block, verbatim
js/
  data.js           # RAW load from #usage-data, DAILY/SESSIONS/SOURCES/ALL_MODELS,
                    #   modelTotals, EARLIEST/LATEST/ALL_SPAN_DAYS, sourceColor/sourceLabel,
                    #   dayBreakdowns, monthsInData
  format.js         # fmtUSD/USDfull/Tok/TokFull/Pct, shortModel, parseDate, ymd, fmtDate,
                    #   MON/DOW/MONTH_NAMES, hexA   (pure, no state)
  palette.js        # PALETTES, OTHER_COLOR, MODEL_COLOR, setPalette, and the mutable
                    #   palette bindings (PALETTE, SLATE, TOKEN_COLORS, SOURCE_COLOR)
  state.js          # the `state` object, systemTheme, charts registry {}
  params.js         # readParams, writeParams, rangeToParam, shortToFull (URL sync)
  compute.js        # activeWindow, inRangeDays, derive, deriveBySource, rolling, tokensOf
  charts.js         # chart.js defaults, mount, dualScales, sizeChartInner, autoScrollRight,
                    #   readThemeColors, liveRetheme, applyChartTheme, cssVar
  render.js         # all render*/heat* view functions + renderAll
  controls.js       # buildSourceChips/buildChips/skinChips, setSeg, buildMonthSelect,
                    #   syncRangeControls, applyTheme, switchTheme, event listeners, reset
  app.js            # entry point: INIT sequence + initHourly; imports & wires everything
```

~10 JS modules (coarse split). `render.js` stays one file.

## Import graph (single direction, no cycles)

```
format.js  ──┐
data.js    ──┼─→ palette.js ─→ state.js ─→ compute.js ─→ charts.js ─→ render.js ─→ controls.js ─→ app.js
             └──────────────────────────────────────────────────────────────────────┘
```

Lower layers never import higher ones. `app.js` is the only entry point and the
only file referenced by `dashboard.html`.

## Shared mutable state - the key mechanism

ES modules don't share a closure, so shared state moves to owning modules and is
reached via **live bindings**:

- **Objects/Sets mutated by reference** - `state` (and `state.models`,
  `state.sources`, `state.projExpanded` Sets), `charts`, `MODEL_COLOR`,
  `modelTotals` - exported once; importers mutate the same object. No special
  handling.
- **Primitives reassigned at runtime** - `PALETTE`, `SLATE`, `TOKEN_COLORS`,
  `SOURCE_COLOR`. Each is reassigned **only inside `setPalette`**, which lives in
  `palette.js`. Exported `let` bindings are live: importers see the new value
  after `setPalette` runs, but never reassign them themselves. This invariant
  (a mutable `let` is reassigned only in its owning module) already holds in the
  current code and must be preserved.

If any consumer needs to *reassign* one of these primitives, that's a smell -
wrap it in an object or add a setter in the owning module instead.

## Migration approach

Mechanical extraction, function bodies copied verbatim (no logic rewrites):

1. Extract `<style>` → `css/styles.css`; link it from `<head>`.
2. Carve the IIFE body into the modules above, top-of-graph first, adding
   `import`/`export` lines. Keep function bodies byte-for-byte where possible.
3. Replace the inline `<script>…IIFE…</script>` with
   `<script type="module" src="js/app.js"></script>`. The IIFE wrapper goes away
   (module scope is already isolated); the INIT sequence becomes `app.js`'s
   top-level body.
4. Keep the inline head theme-flash script and the `<script id="usage-data">`
   data block exactly as they are.

## Verification (manual visual check)

After the split, serve locally and confirm the page is identical to before:

```
cd usage-repo && python3 -m http.server 8000   # then open http://localhost:8000/dashboard.html
```

Checklist - every item must behave as it did pre-split:
- No errors in the browser console; all chart canvases mount.
- KPIs, daily chart, donut, tokens, model-time, day-of-week, heatmap, table,
  source card, projects tree, hourly card all render.
- Range filter (all / 7 / 30 / 90 / month), model chips, source chips, metric
  toggle all update the views.
- Theme toggle recolors live (no rebuild flash); reset button restores defaults.
- URL query params round-trip (reload preserves the view; sharing a URL works).
- Heatmap hover tooltip positions and shows correct numbers.

Compare against the current committed `dashboard.html` (open both side by side).

## Deployment note

The static host must now serve `css/` and `js/` alongside `dashboard.html`
(trivial for a static site - it already serves the repo). No path changes to the
data pipeline. The pre-split `dashboard.html` remains in git history as the
reference if a regression appears.

## Out of scope (YAGNI)

- No bundler/minifier, no TypeScript, no framework.
- No splitting `render.js` further (revisit only if it stays unwieldy).
- No CSS restructuring beyond moving the block to its own file.
- No changes to `render.mjs`, `cc-update`, or the data schema.
