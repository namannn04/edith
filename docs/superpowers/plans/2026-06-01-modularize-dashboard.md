# Modularize Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the monolithic `dashboard.html` (1601 lines: CSS + HTML + one ~1165-line JS IIFE) into `css/styles.css` and ~10 focused ES modules under `js/`, with no behavior change.

**Architecture:** Native ES modules served over HTTP, no bundler. The inline IIFE becomes `js/app.js` (the single `<script type="module">` entry), then leaf-first carving moves functions into focused modules. Shared mutable state moves to owning modules and is reached via ES-module live bindings. `dashboard.html` keeps its inline head theme-flash script and its `<script id="usage-data">` data block, so `render.mjs` / `cc-update` are untouched.

**Tech Stack:** Vanilla JS (ES modules), Chart.js via CDN, plain CSS. No build, no test framework — verification is manual visual check via `python3 -m http.server`.

**Reference spec:** `docs/superpowers/specs/2026-06-01-modularize-dashboard-design.md`

---

## Working conventions for every task

- **Bodies are copied verbatim.** This is a mechanical extraction. Move each function/const exactly as written; only add `export`/`import` lines and delete the moved lines from their old home. Do not rewrite logic, rename, or "improve" anything.
- **The page must work at every commit.** After each task, the dashboard renders identically.
- **Per-task verification ("the test"):** from `usage-repo/`, run `python3 -m http.server 8000`, open `http://localhost:8000/dashboard.html`, and confirm:
  - DevTools console shows **zero errors** (especially no `is not defined` / failed module fetches).
  - The views touched by that task still render and interact correctly.
  - For the final task, run the full checklist from the spec's "Verification" section.
- **Commit message prefix:** `refactor:` (this changes structure, not behavior).
- **Import order within a file:** group imports at the top, lowest-layer modules first.

## Dependency layering (extract in this order — lower layers first)

```
format  →  data  →  palette  →  state  →  params  →  compute  →  charts  →  render  →  controls  →  app
```

A module only ever imports from layers to its left. `app.js` is the only file `dashboard.html` references.

## Module ownership map (what each file exports)

- **format.js** — `fmtUSD`, `fmtUSDfull`, `fmtTok`, `fmtTokFull`, `fmtPct`, `shortModel`, `parseDate`, `ymd`, `fmtDate`, `MON`, `DOW`, `MONTH_NAMES`, `hexA`. Pure; imports nothing.
- **data.js** — `RAW`, `DAILY`, `SESSIONS`, `SOURCES`, `SOURCE_LABEL`, `sourceLabel`, `modelTotals`, `ALL_MODELS`, `EARLIEST`, `LATEST`, `ALL_SPAN_DAYS`, `monthsInData`. Imports: `parseDate` from format. (Loads `RAW` from `#usage-data`.)
- **palette.js** — `PALETTES`, `OTHER_COLOR`, `MODEL_COLOR`, `SOURCE_COLOR`, `PALETTE`, `SLATE`, `TOKEN_COLORS`, `setPalette`, `sourceColor`, `systemTheme`. Imports: `hexA` from format; `ALL_MODELS` from data. **`setPalette` is the only place the `let` bindings are reassigned.**
- **state.js** — `state`, `charts`. Imports: `ALL_MODELS`, `SOURCES` from data; `systemTheme` from palette.
- **params.js** — `shortToFull`, `readParams`, `writeParams`, `rangeToParam`. Imports: `state`; `ALL_MODELS`, `SOURCES` from data; `shortModel` from format.
- **compute.js** — `tokensOf`, `dayBreakdowns`, `activeWindow`, `inRangeDays`, `derive`, `deriveBySource`, `rolling`. Imports: `DAILY`, `SOURCES`, `EARLIEST`, `LATEST` from data; `state`; `parseDate` from format.
- **charts.js** — `cssVar`, `readThemeColors`, `dualScales`, `sizeChartInner`, `autoScrollRight`, `liveRetheme`, `applyChartTheme`, `mount` (+ Chart.js global defaults setup). Imports: `charts` from state; `MODEL_COLOR`, `TOKEN_COLORS`, `SOURCE_COLOR`, `PALETTE`, `SLATE` from palette; format helpers. Uses global `Chart` (CDN).
- **render.js** — all `render*`, `heat*`, `wireHeat`, `mergeChats`, `aggregateProjects`, `nameCell`, `chatRows`, `latestDayWithHours`, `openHourly`, `dualLabel`, `renderAll`. Imports from compute, data, format, palette, charts, state, params as needed.
- **controls.js** — `buildSourceChips`, `buildChips`, `skinChips`, `setSeg`, `buildMonthSelect`, `syncRangeControls`, `applyTheme`, `switchTheme`, `wireControls` (attaches theme-toggle + reset listeners). Imports from state, data, palette, compute, render, charts, params.
- **app.js** — entry point. Imports init/build/render fns; runs the `INIT` sequence and `initHourly`. The only file referenced by `dashboard.html`.

---

## Task 1: Extract CSS to its own file

**Files:**
- Create: `css/styles.css`
- Modify: `dashboard.html` (lines 20–245, the `<style>…</style>` block; `<head>`)

- [ ] **Step 1: Create `css/styles.css`** with the exact contents between `<style>` and `</style>` (lines 21–244, not the tags themselves).

- [ ] **Step 2: Replace the inline block in `dashboard.html`.** Delete lines 20–245 (`<style>` … `</style>`) and in their place add, inside `<head>`:

```html
<link rel="stylesheet" href="css/styles.css">
```

- [ ] **Step 3: Verify (serve + visual).** From `usage-repo/`: `python3 -m http.server 8000`, open `http://localhost:8000/dashboard.html`. Confirm the page is styled identically (fonts, colors, layout, both themes via the toggle) and the console has no errors.

- [ ] **Step 4: Commit.**

```bash
git add css/styles.css dashboard.html
git commit -m "refactor: extract dashboard CSS into css/styles.css"
```

---

## Task 2: Move the JS IIFE into a single external module `js/app.js`

This makes the JS a module without splitting it yet — the safe pivot point.

**Files:**
- Create: `js/app.js`
- Modify: `dashboard.html` (lines 435–1599, the big `<script>…</script>`)

- [ ] **Step 1: Create `js/app.js`.** Copy the entire body **inside** the IIFE (everything between `(() => {` on line 436 and the closing `})();` at the end) into `js/app.js`. **Drop the IIFE wrapper** — module scope already isolates these bindings. The file therefore starts at the old line `let RAW = {};` and ends with the `initHourly` IIFE call. Do not change any logic.

- [ ] **Step 2: Confirm the data read still works.** The first lines load injected data from the DOM, e.g. `RAW = JSON.parse(document.getElementById("usage-data").textContent)`. Modules are deferred, so the DOM is ready — no change needed. Leave it as-is.

- [ ] **Step 3: Replace the inline script in `dashboard.html`.** Delete lines 435–1599 (the whole application `<script>…</script>`, **not** the `<script id="usage-data">` data block on 431–433 and **not** the head theme-flash script) and replace with:

```html
<script type="module" src="js/app.js"></script>
```

- [ ] **Step 4: Verify (serve + visual).** Reload `http://localhost:8000/dashboard.html`. Confirm **everything** works exactly as before (all charts, filters, theme toggle, URL params, hourly card, tooltips) and the console is clean. This is the key regression gate before carving begins.

- [ ] **Step 5: Commit.**

```bash
git add js/app.js dashboard.html
git commit -m "refactor: move dashboard JS into js/app.js as an ES module"
```

---

## Task 3: Extract `js/format.js` (pure helpers)

**Files:**
- Create: `js/format.js`
- Modify: `js/app.js`

- [ ] **Step 1: Create `js/format.js`.** Move these declarations verbatim from `app.js`, each prefixed with `export`: `fmtUSD`, `fmtUSDfull`, `fmtTok`, `fmtTokFull`, `fmtPct`, `shortModel`, `parseDate`, `ymd`, `MON`, `fmtDate`, `DOW`, `MONTH_NAMES`, `hexA`. (`fmtDate` uses `MON`; keep `MON` above it. `format.js` imports nothing.)

- [ ] **Step 2: Add imports to `app.js`.** At the top of `app.js` add:

```js
import { fmtUSD, fmtUSDfull, fmtTok, fmtTokFull, fmtPct, shortModel, parseDate, ymd, fmtDate, MON, DOW, MONTH_NAMES, hexA } from "./format.js";
```

Delete the now-moved declarations from `app.js`.

- [ ] **Step 3: Verify (serve + visual).** Reload. Confirm formatted dollar/token values, model labels, dates, and chart axes all render correctly; console clean.

- [ ] **Step 4: Commit.**

```bash
git add js/format.js js/app.js
git commit -m "refactor: extract format helpers into js/format.js"
```

---

## Task 4: Extract `js/data.js` (data layer)

**Files:**
- Create: `js/data.js`
- Modify: `js/app.js`

- [ ] **Step 1: Create `js/data.js`.** Add `import { parseDate } from "./format.js";` at the top. Move verbatim, prefixed with `export`: the `RAW` load (the `let RAW = …; RAW = JSON.parse(document.getElementById("usage-data").textContent)` lines), `DAILY`, `SESSIONS`, `SOURCES`, `SOURCE_LABEL`, `sourceLabel`, `modelTotals` (and its fill loop), `ALL_MODELS`, the `_sortedDays`/`EARLIEST`/`LATEST`/`ALL_SPAN_DAYS` block, and `monthsInData`. Keep the internal `_sortedDays` as a non-exported `const` in this file. `MON` is needed by `monthsInData` → import it from format too if used there.

- [ ] **Step 2: Add imports to `app.js`.**

```js
import { RAW, DAILY, SESSIONS, SOURCES, SOURCE_LABEL, sourceLabel, modelTotals, ALL_MODELS, EARLIEST, LATEST, ALL_SPAN_DAYS, monthsInData } from "./data.js";
```

Delete the moved declarations from `app.js`.

- [ ] **Step 3: Verify (serve + visual).** Reload. Confirm KPIs, charts, month dropdown, and source labels render; console clean.

- [ ] **Step 4: Commit.**

```bash
git add js/data.js js/app.js
git commit -m "refactor: extract data layer into js/data.js"
```

---

## Task 5: Extract `js/palette.js` (theme colors)

**Files:**
- Create: `js/palette.js`
- Modify: `js/app.js`

- [ ] **Step 1: Create `js/palette.js`.** Add imports:

```js
import { hexA } from "./format.js";
import { ALL_MODELS } from "./data.js";
```

Move verbatim, prefixed with `export`: `PALETTES`, `OTHER_COLOR`, the mutable bindings `MODEL_COLOR` (object), `SOURCE_COLOR` (`let`), `PALETTE`/`SLATE`/`TOKEN_COLORS` (`let`), `setPalette`, `sourceColor`, and `systemTheme`. **Confirm `setPalette` is the only function that reassigns `PALETTE`/`SLATE`/`TOKEN_COLORS`/`SOURCE_COLOR`/`MODEL_COLOR` contents** — if any consumer reassigns them, stop and flag it (the design forbids this).

- [ ] **Step 2: Add imports to `app.js`.**

```js
import { PALETTES, OTHER_COLOR, MODEL_COLOR, SOURCE_COLOR, PALETTE, SLATE, TOKEN_COLORS, setPalette, sourceColor, systemTheme } from "./palette.js";
```

Delete the moved declarations from `app.js`.

- [ ] **Step 3: Verify (serve + visual).** Reload, then toggle the theme. Confirm both themes color correctly, chips/swatches recolor, and the live retheme has no flash; console clean.

- [ ] **Step 4: Commit.**

```bash
git add js/palette.js js/app.js
git commit -m "refactor: extract palette/theme colors into js/palette.js"
```

---

## Task 6: Extract `js/state.js` (shared mutable state)

**Files:**
- Create: `js/state.js`
- Modify: `js/app.js`

- [ ] **Step 1: Create `js/state.js`.** Add imports:

```js
import { ALL_MODELS, SOURCES } from "./data.js";
import { systemTheme } from "./palette.js";
```

Move verbatim, prefixed with `export`: the `state` object literal and the `charts` registry (`const charts = {};`). These are mutated by reference everywhere — exporting the objects is sufficient.

- [ ] **Step 2: Add imports to `app.js`.**

```js
import { state, charts } from "./state.js";
```

Delete the moved declarations from `app.js`.

- [ ] **Step 3: Verify (serve + visual).** Reload. Confirm filters/sorting/expansion still drive the views and charts mount; console clean.

- [ ] **Step 4: Commit.**

```bash
git add js/state.js js/app.js
git commit -m "refactor: extract shared state into js/state.js"
```

---

## Task 7: Extract `js/params.js` (URL sync)

**Files:**
- Create: `js/params.js`
- Modify: `js/app.js`

- [ ] **Step 1: Create `js/params.js`.** Add imports:

```js
import { state } from "./state.js";
import { ALL_MODELS, SOURCES } from "./data.js";
import { shortModel } from "./format.js";
```

Move verbatim, prefixed with `export`: `shortToFull` (and its fill loop), `readParams`, `rangeToParam`, `writeParams`.

- [ ] **Step 2: Add imports to `app.js`.**

```js
import { shortToFull, readParams, writeParams, rangeToParam } from "./params.js";
```

Delete the moved declarations from `app.js`.

- [ ] **Step 3: Verify (serve + visual).** Reload with a query string, e.g. `http://localhost:8000/dashboard.html?range=30&metric=tokens`. Confirm the view reflects the params, and that changing filters updates the URL (reload preserves the view); console clean.

- [ ] **Step 4: Commit.**

```bash
git add js/params.js js/app.js
git commit -m "refactor: extract URL param sync into js/params.js"
```

---

## Task 8: Extract `js/compute.js` (derivations/selectors)

**Files:**
- Create: `js/compute.js`
- Modify: `js/app.js`

- [ ] **Step 1: Create `js/compute.js`.** Add imports:

```js
import { DAILY, SOURCES, EARLIEST, LATEST } from "./data.js";
import { state } from "./state.js";
import { parseDate } from "./format.js";
```

Move verbatim, prefixed with `export`: `tokensOf`, `dayBreakdowns` (it reads `SOURCES` + `state.sources`), `activeWindow`, `inRangeDays`, `derive`, `deriveBySource`, `rolling`.

- [ ] **Step 2: Add imports to `app.js`.**

```js
import { tokensOf, dayBreakdowns, activeWindow, inRangeDays, derive, deriveBySource, rolling } from "./compute.js";
```

Delete the moved declarations from `app.js`.

- [ ] **Step 3: Verify (serve + visual).** Reload. Confirm range windows (all / 7 / 30 / 90 / month), rolling averages, and per-source series all compute correctly across the charts; console clean.

- [ ] **Step 4: Commit.**

```bash
git add js/compute.js js/app.js
git commit -m "refactor: extract derivations into js/compute.js"
```

---

## Task 9: Extract `js/charts.js` (Chart.js infrastructure)

**Files:**
- Create: `js/charts.js`
- Modify: `js/app.js`

- [ ] **Step 1: Create `js/charts.js`.** Add imports (include exactly the palette/format names the moved functions use):

```js
import { charts } from "./state.js";
import { MODEL_COLOR, TOKEN_COLORS, SOURCE_COLOR, PALETTE, SLATE } from "./palette.js";
```

Move verbatim, prefixed with `export`: `cssVar`, `readThemeColors`, `dualScales`, `sizeChartInner`, `autoScrollRight`, `liveRetheme`, `applyChartTheme`, `mount`, plus any Chart.js global-defaults setup statements (e.g. `Chart.defaults...`). `Chart` is the global from the CDN `<script>` — leave it as a free global (do not import it).

- [ ] **Step 2: Add imports to `app.js`.**

```js
import { cssVar, readThemeColors, dualScales, sizeChartInner, autoScrollRight, liveRetheme, applyChartTheme, mount } from "./charts.js";
```

Delete the moved declarations from `app.js`.

- [ ] **Step 3: Verify (serve + visual).** Reload. Confirm all canvases mount, dual axes scale, horizontal scroll auto-positions to the right, and theme toggle recolors live charts; console clean.

- [ ] **Step 4: Commit.**

```bash
git add js/charts.js js/app.js
git commit -m "refactor: extract Chart.js infrastructure into js/charts.js"
```

---

## Task 10: Extract `js/render.js` (all view renderers)

**Files:**
- Create: `js/render.js`
- Modify: `js/app.js`

- [ ] **Step 1: Create `js/render.js`.** Add imports for every name the renderers reference — assemble them from the modules already created:

```js
import { DAILY, SESSIONS, SOURCES, SOURCE_LABEL, sourceLabel, ALL_MODELS, LATEST } from "./data.js";
import { fmtUSD, fmtUSDfull, fmtTok, fmtTokFull, fmtPct, shortModel, parseDate, ymd, fmtDate, DOW } from "./format.js";
import { MODEL_COLOR, SOURCE_COLOR, OTHER_COLOR, TOKEN_COLORS, sourceColor } from "./palette.js";
import { state, charts } from "./state.js";
import { tokensOf, dayBreakdowns, inRangeDays, derive, deriveBySource, rolling } from "./compute.js";
import { mount, dualScales, sizeChartInner, autoScrollRight } from "./charts.js";
```

Move verbatim, prefixed with `export` (or unexported if only used within render — but export the ones `controls.js`/`app.js` call): `dualLabel`, `renderMeta`, `renderKPIs`, `renderDaily`, `renderDonut`, `renderTokens`, `renderModelTime`, `renderDOW`, `heatDayDetail`, `heatTipHTML`, `wireHeat`, `renderHeat`, `renderTable`, `renderSource`, `mergeChats`, `aggregateProjects`, `renderProjects`, `nameCell`, `chatRows`, `renderProjectsTable`, `latestDayWithHours`, `renderHourly`, `openHourly`, `renderAll`. At minimum export those called from outside render: `renderMeta`, `renderAll`, `renderHourly`, `latestDayWithHours`, `wireHeat`, `openHourly` (verify against `app.js`/`controls.js` usage and export any others referenced there).

- [ ] **Step 2: Reconcile imports.** After moving, scan `render.js` for any still-undefined identifier and add the matching import. Then add to `app.js` an import line pulling whatever `app.js`'s remaining init code calls (e.g. `import { renderMeta, renderAll, renderHourly, latestDayWithHours } from "./render.js";`). Delete the moved declarations from `app.js`.

- [ ] **Step 3: Verify (serve + visual).** Reload. Confirm **every card renders**: KPIs, daily, donut, tokens, model-time, day-of-week, heatmap (+ hover tooltip), table, source card, projects tree (expand/collapse), hourly card. Console clean.

- [ ] **Step 4: Commit.**

```bash
git add js/render.js js/app.js
git commit -m "refactor: extract view renderers into js/render.js"
```

---

## Task 11: Extract `js/controls.js` (chips, segments, theme/reset wiring)

**Files:**
- Create: `js/controls.js`
- Modify: `js/app.js`

- [ ] **Step 1: Create `js/controls.js`.** Add imports for the names these functions reference, e.g.:

```js
import { state, charts } from "./state.js";
import { ALL_MODELS, SOURCES, monthsInData } from "./data.js";
import { setPalette, sourceColor, MODEL_COLOR, systemTheme } from "./palette.js";
import { shortModel } from "./format.js";
import { liveRetheme } from "./charts.js";
import { renderAll, renderMeta } from "./render.js";
import { writeParams } from "./params.js";
```

Move verbatim, prefixed with `export`: `buildSourceChips`, `buildChips`, `skinChips`, `setSeg`, `buildMonthSelect`, `syncRangeControls`, `applyTheme`, `switchTheme`. Wrap the two standalone listener attachments (the `theme-toggle` click handler and the `btn-reset` click handler, currently bare statements in the IIFE) into an exported `function wireControls() { … }` containing both `addEventListener` calls verbatim. Also move any other bare `addEventListener` wiring for chips/segments/month-select into `wireControls` (or keep them inside their build functions if that's where they already live — do not relocate listeners that are already inside a build function).

- [ ] **Step 2: Add imports + call to `app.js`.**

```js
import { buildSourceChips, buildChips, skinChips, setSeg, buildMonthSelect, syncRangeControls, applyTheme, switchTheme, wireControls } from "./controls.js";
```

Delete the moved declarations from `app.js`. Ensure `wireControls()` is invoked in the init sequence at the same point the original inline listeners were attached (after the elements exist — anywhere in the INIT body is fine since the DOM is ready).

- [ ] **Step 3: Verify (serve + visual).** Reload. Confirm: model chips toggle, source chips toggle, metric/range segments switch, month dropdown changes range, theme toggle works, **reset button** restores defaults (range=all, all models/sources, default sort) and re-renders. Console clean.

- [ ] **Step 4: Commit.**

```bash
git add js/controls.js js/app.js
git commit -m "refactor: extract controls + listener wiring into js/controls.js"
```

---

## Task 12: Finalize `js/app.js` as the entry point + full regression check

**Files:**
- Modify: `js/app.js`

- [ ] **Step 1: Confirm `app.js` is now just imports + init.** It should contain only: the import lines from Tasks 3–11, the `INIT` sequence (`readParams()`, `applyTheme(state.theme)`, `setPalette(state.theme)`, `readThemeColors()`, `buildMonthSelect()`, the default-range heuristic, `syncRangeControls()`, `renderMeta()`, `buildSourceChips()`, `buildChips()`, `wireControls()`, `renderAll()`), and the `initHourly` IIFE. Remove any now-unused imports (anything imported but not referenced in `app.js`).

- [ ] **Step 2: Full regression — run the spec's verification checklist.** With `python3 -m http.server 8000`, open `http://localhost:8000/dashboard.html` and walk every item in the spec's "Verification (manual visual check)" section:
  - Console: zero errors; all canvases mount.
  - Every card renders (KPIs, daily, donut, tokens, model-time, DOW, heatmap, table, source, projects, hourly).
  - Range filter (all/7/30/90/month), model chips, source chips, metric toggle all update views.
  - Theme toggle recolors live (no rebuild flash); reset restores defaults.
  - URL params round-trip (reload preserves view; shared URL works).
  - Heatmap hover tooltip positions and shows correct numbers.
  - Open the **pre-split** `dashboard.html` from git for a side-by-side parity check. Find the commit just before Task 1 (`git log --oneline | grep -n "modularize dashboard into ES modules"` points at the spec commit; the commit immediately after it — or simply the last commit whose `dashboard.html` still contains the inline `<script>` app — is the pre-split monolith). Example: `git show <that-sha>:dashboard.html > /tmp/old-dashboard.html`, serve/open, confirm visual parity.

- [ ] **Step 3: Confirm the data pipeline is untouched.** Run `render.mjs` against the existing snapshot inputs the way `cc-update` does (or at minimum re-read `render.mjs` and confirm its regex still targets the unchanged `<script id="usage-data">` block in `dashboard.html`). The new `css/` and `js/` files must not be referenced by `render.mjs`. No code change expected here — this is a verification step.

- [ ] **Step 4: Commit.**

```bash
git add js/app.js
git commit -m "refactor: finalize js/app.js as the module entry point"
```

---

## Final notes

- **Deployment:** ensure the static host for cc.pulkitxm.com serves `css/` and `js/` alongside `dashboard.html` (it already serves the repo; this is automatic for a directory-served static site). No data-pipeline change.
- **Local dev going forward:** open via `python3 -m http.server` (or any static server), not `file://` — ES modules don't load over `file://`.
- **If a regression appears:** the pre-split `dashboard.html` is in git history (the commit just before Task 1) as the reference.
