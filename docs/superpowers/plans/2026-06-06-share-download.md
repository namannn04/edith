# Download / Share Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `⤓ Card` button that downloads a branded PNG of the current filtered usage stats (for posting on X), plus a per-chart `⤓` button that saves any chart as a PNG.

**Architecture:** Isolate the summary math in a pure, DOM-free module `js/stats.js` (`bun test`ed). A second module `js/share.js` does the canvas work: draws the theme-matched share card, exports per-chart PNGs (chart canvas composited on a solid background), and wires/injects the buttons. Both read the same filtered `derive()` rows the charts use, so they respect all active filters. Rebuild the self-contained `dashboard.html` with `bun build.mjs`.

**Tech Stack:** Vanilla ES modules bundled by `bun build.mjs`; HTML canvas 2D + Chart.js's existing chart canvases; `bun test`. No new external dependencies.

---

## File Structure

- **Create `js/stats.js`** — pure `statsSummary(rows)` over `derive()` rows → headline numbers. No DOM.
- **Create `tests/stats.test.js`** — `bun test` coverage for `statsSummary`.
- **Create `js/share.js`** — DOM/canvas: `rangeLabel()`, `drawShareCard()`, `downloadChart(id)`, `wireShareButtons()`.
- **Modify `dashboard.template.html`** — add the `⤓ Card` button.
- **Modify `css/styles.css`** — `.chart-dl` icon button + card positioning.
- **Modify `js/app.js`** — call `wireShareButtons()` on init.
- **Rebuild** `dashboard.html` via `bun build.mjs`.

All commands run from repo root: `/Users/pulkit/scripts/ccusage-dashboard/usage-repo`.

---

### Task 1: Pure summary stats (`js/stats.js`) — TDD

**Files:**
- Create: `tests/stats.test.js`
- Create: `js/stats.js`

- [ ] **Step 1: Write the failing tests**

Create `tests/stats.test.js`:

```js
import { test, expect } from "bun:test";
import { statsSummary } from "../js/stats.js";

const rows = [
  { date:"2026-05-26", cost:1, input:100, output:50, cacheCreate:200, cacheRead:300, tokens:650, byModel:{ "claude-opus-4-8":{cost:1, tokens:650} } },
  { date:"2026-05-27", cost:0, input:0,   output:0,  cacheCreate:0,   cacheRead:0,   tokens:0,   byModel:{} },
  { date:"2026-05-28", cost:3, input:100, output:10, cacheCreate:0,   cacheRead:100, tokens:210, byModel:{ "claude-haiku-4-5":{cost:3, tokens:210} } },
];

test("statsSummary: totals and token breakdown", () => {
  const s = statsSummary(rows);
  expect(s.totalCost).toBe(4);
  expect(s.totalTokens).toBe(860);
  expect(s.input).toBe(200);
  expect(s.output).toBe(60);
  expect(s.cacheCreate).toBe(200);
  expect(s.cacheRead).toBe(400);
  expect(s.cache).toBe(600);
});

test("statsSummary: cacheRate = read/(read+input)", () => {
  expect(statsSummary(rows).cacheRate).toBeCloseTo(400/600, 10);
});

test("statsSummary: activeDays ignores zero-token days; dailyAvg = cost/activeDays", () => {
  const s = statsSummary(rows);
  expect(s.activeDays).toBe(2);
  expect(s.dailyAvg).toBe(2); // 4 / 2
});

test("statsSummary: topModel by summed cost; peakDay by tokens", () => {
  const s = statsSummary(rows);
  expect(s.topModel).toBe("claude-haiku-4-5"); // cost 3 > 1
  expect(s.peakDay).toEqual({ date:"2026-05-26", tokens:650, cost:1 });
});

test("statsSummary: all-zero and empty -> safe zeros, null topModel/peakDay", () => {
  const z = statsSummary([{ date:"2026-05-26", cost:0, input:0, output:0, cacheCreate:0, cacheRead:0, tokens:0, byModel:{} }]);
  expect(z.totalCost).toBe(0);
  expect(z.cacheRate).toBe(0);
  expect(z.dailyAvg).toBe(0);
  expect(z.activeDays).toBe(0);
  expect(z.topModel).toBeNull();
  expect(z.peakDay).toBeNull();
  const e = statsSummary([]);
  expect(e.topModel).toBeNull();
  expect(e.peakDay).toBeNull();
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bun test tests/stats.test.js`
Expected: FAIL — `Cannot find module "../js/stats.js"`.

- [ ] **Step 3: Implement `js/stats.js`**

Create `js/stats.js`:

```js
  // ---------- summary stats over derive() rows (pure; no DOM, no state) ----------
  // rows: [{date, cost, input, output, cacheCreate, cacheRead, tokens, byModel:{m:{cost,tokens}}}]
  export function statsSummary(rows) {
    const s = {
      totalCost:0, totalTokens:0, input:0, output:0, cacheCreate:0, cacheRead:0,
      cache:0, cacheRate:0, topModel:null, activeDays:0, dailyAvg:0, peakDay:null,
    };
    const modelCost = {};
    let peak = null;
    for (const r of rows) {
      s.totalCost   += r.cost   || 0;
      s.totalTokens += r.tokens || 0;
      s.input       += r.input  || 0;
      s.output      += r.output || 0;
      s.cacheCreate += r.cacheCreate || 0;
      s.cacheRead   += r.cacheRead   || 0;
      for (const m in (r.byModel || {})) modelCost[m] = (modelCost[m] || 0) + (r.byModel[m].cost || 0);
      if ((r.tokens || 0) > 0) {
        s.activeDays += 1;
        if (!peak || r.tokens > peak.tokens) peak = { date:r.date, tokens:r.tokens, cost:r.cost };
      }
    }
    s.cache = s.cacheCreate + s.cacheRead;
    const denom = s.cacheRead + s.input;
    s.cacheRate = denom > 0 ? s.cacheRead / denom : 0;
    s.dailyAvg  = s.activeDays > 0 ? s.totalCost / s.activeDays : 0;
    const models = Object.keys(modelCost);
    s.topModel = models.length ? models.reduce((a, b) => (modelCost[b] > modelCost[a] ? b : a)) : null;
    s.peakDay  = peak;
    return s;
  }
```

(The leading 2-space module-body indent matches the repo's other `js/*.js` files.)

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bun test tests/stats.test.js`
Expected: PASS — all 5 tests green.

- [ ] **Step 5: Commit**

```bash
git add js/stats.js tests/stats.test.js
git commit -m "feat: pure statsSummary() over filtered rows + tests"
```
End the commit body with:
```
Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
```

---

### Task 2: Share/export module (`js/share.js`)

**Files:**
- Create: `js/share.js`

Read `js/charts.js` (theme-color reading pattern), `js/compute.js` (`derive`, `activeWindow`), `js/state.js` (`state`, `charts`), and `js/format.js` (formatters) first to confirm the imports below exist.

- [ ] **Step 1: Create `js/share.js`**

```js
  import { statsSummary } from "./stats.js";
  import { derive, activeWindow } from "./compute.js";
  import { charts, state } from "./state.js";
  import { fmtUSD, fmtTok, fmtPct, shortModel, fmtDate, MON } from "./format.js";

  // read a CSS custom property off <body>, with a fallback (mirrors charts.js)
  const cssVar = (n, fallback) => (getComputedStyle(document.body).getPropertyValue(n).trim() || fallback);
  function cardTheme() {
    return {
      bg:     cssVar("--paper-2", "#fffdf8"),
      ink:    cssVar("--ink", "#241f1a"),
      soft:   cssVar("--ink-soft", "#5c5247"),
      faint:  cssVar("--ink-faint", "#9a8f80"),
      gold:   cssVar("--gold", "#c89b3c"),
      accent: cssVar("--accent", "#d97757"),
      mono:   cssVar("--mono", "monospace"),
      serif:  cssVar("--serif", "Georgia, serif"),
    };
  }

  const dlabel = (d, withYear) => `${d.getDate()} ${MON[d.getMonth()]}` + (withYear ? ` ${d.getFullYear()}` : "");

  // Subtitle for the share card: "All time" or "26 May – 25 Jun 2026".
  export function rangeLabel() {
    if (state.range.mode === "all") return "All time";
    const w = activeWindow();
    const sameYear = w.from.getFullYear() === w.to.getFullYear();
    return `${dlabel(w.from, !sameYear)} – ${dlabel(w.to, true)}`;
  }

  const fileYmd = (d) => `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,"0")}-${String(d.getDate()).padStart(2,"0")}`;

  function triggerDownload(canvas, filename) {
    canvas.toBlob((blob) => {
      if (!blob) return;
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url; a.download = filename;
      document.body.appendChild(a); a.click(); a.remove();
      URL.revokeObjectURL(url);
    }, "image/png");
  }

  // ---------- branded share card (current filtered stats) ----------
  export function drawShareCard() {
    const s = statsSummary(derive());
    const t = cardTheme();
    const W = 1200, H = 630, SCALE = 2;
    const canvas = document.createElement("canvas");
    canvas.width = W * SCALE; canvas.height = H * SCALE;
    const ctx = canvas.getContext("2d");
    ctx.scale(SCALE, SCALE);

    ctx.fillStyle = t.bg; ctx.fillRect(0, 0, W, H);
    ctx.fillStyle = t.accent; ctx.fillRect(0, 0, W, 6); // accent top rule

    const PAD = 72, COL2 = W / 2 + 30;

    ctx.fillStyle = t.ink;  ctx.font = `600 40px ${t.serif}`;
    ctx.fillText("Claude Code · Usage", PAD, 110);
    ctx.fillStyle = t.soft; ctx.font = `20px ${t.mono}`;
    ctx.fillText(rangeLabel(), PAD, 146);

    // hero numbers
    const heroY = 280;
    ctx.font = `700 92px ${t.mono}`;
    ctx.fillStyle = t.gold; ctx.fillText(fmtUSD(s.totalCost), PAD, heroY);
    ctx.fillStyle = t.ink;  ctx.fillText(fmtTok(s.totalTokens), COL2, heroY);
    ctx.fillStyle = t.soft; ctx.font = `20px ${t.mono}`;
    ctx.fillText("total cost", PAD, heroY + 34);
    ctx.fillText("total tokens", COL2, heroY + 34);

    // secondary lines
    ctx.fillStyle = t.ink;  ctx.font = `22px ${t.mono}`;
    ctx.fillText(`in ${fmtTok(s.input)}   ·   out ${fmtTok(s.output)}   ·   cache ${fmtTok(s.cache)}`, PAD, 420);
    ctx.fillStyle = t.soft;
    ctx.fillText(`cache hit ${fmtPct(s.cacheRate)}   ·   top ${s.topModel ? shortModel(s.topModel) : "—"}`, PAD, 460);
    const peak = s.peakDay ? fmtDate(s.peakDay.date) : "—";
    ctx.fillText(`avg ${fmtUSD(s.dailyAvg)}/day   ·   ${s.activeDays} active day${s.activeDays===1?"":"s"}   ·   peak ${peak}`, PAD, 500);

    ctx.fillStyle = t.faint; ctx.font = `20px ${t.mono}`;
    ctx.fillText("cc.pulkitxm.com", PAD, H - 54);

    let name = "cc-usage_all.png";
    if (state.range.mode !== "all") { const w = activeWindow(); name = `cc-usage_${fileYmd(w.from)}_${fileYmd(w.to)}.png`; }
    triggerDownload(canvas, name);
  }

  // ---------- per-chart PNG (chart canvas on a solid theme background) ----------
  export function downloadChart(canvasId) {
    const chart = charts[canvasId];
    if (!chart) return;
    const src = chart.canvas;
    const out = document.createElement("canvas");
    out.width = src.width; out.height = src.height;
    const ctx = out.getContext("2d");
    ctx.fillStyle = cssVar("--paper-2", "#fffdf8");
    ctx.fillRect(0, 0, out.width, out.height);
    ctx.drawImage(src, 0, 0);
    const card = src.closest(".card");
    const titleEl = card && card.querySelector(".card-title");
    const slug = ((titleEl && titleEl.textContent) || canvasId)
      .toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
    triggerDownload(out, `cc-usage_${slug}.png`);
  }

  // ---------- wiring (called once on init) ----------
  export function wireShareButtons() {
    const share = document.getElementById("btn-share");
    if (share) share.addEventListener("click", drawShareCard);
    document.querySelectorAll(".card").forEach((card) => {
      const cv = card.querySelector("canvas");
      if (!cv || !cv.id) return;                 // skip cards without a chart canvas (heatmap, tables)
      const head = card.querySelector(".card-head");
      if (!head) return;
      const btn = document.createElement("button");
      btn.className = "chart-dl";
      btn.type = "button";
      btn.title = "Download PNG";
      btn.setAttribute("aria-label", "Download chart as PNG");
      btn.textContent = "⤓";
      btn.dataset.canvas = cv.id;
      btn.addEventListener("click", () => downloadChart(cv.id));
      head.appendChild(btn);
    });
  }
```

- [ ] **Step 2: Verify the module compiles and imports resolve**

Run: `bun build js/share.js --target=browser --outfile=/tmp/share-check.js && echo OK && rm /tmp/share-check.js`
Expected: a bundle line then `OK` — no "could not resolve" / syntax errors. (`bun build` only resolves+bundles; it does not execute DOM code, so this is a safe compile check even though the module uses `document`/`getComputedStyle` at call time.)

- [ ] **Step 3: Commit**

```bash
git add js/share.js
git commit -m "feat: share.js — branded stats card + per-chart PNG export"
```
End the commit body with:
```
Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
```

---

### Task 3: Wire the buttons (markup, styles, init) + build

**Files:**
- Modify: `dashboard.template.html`
- Modify: `css/styles.css`
- Modify: `js/app.js`

- [ ] **Step 1: Add the `⤓ Card` button next to Reset**

In `dashboard.template.html`, find the reset button inside the controls bar:
```html
      <button class="btn-reset" id="btn-reset">⟲ Reset</button>
```
Add the share button immediately AFTER it:
```html
      <button class="btn-reset" id="btn-reset">⟲ Reset</button>
      <button class="btn-reset" id="btn-share">⤓ Card</button>
```

- [ ] **Step 2: Add styles for the per-chart button**

In `css/styles.css`, append these rules at the END of the file (they reuse the existing palette vars already used by `.btn-reset`):
```css
  /* download buttons (share card reuses .btn-reset; per-chart icon below) */
  .card{position:relative}
  .card-head{padding-right:30px}                 /* reserve room for the corner button */
  .chart-dl{
    position:absolute; top:14px; right:14px;
    appearance:none; cursor:pointer;
    width:26px; height:24px; display:inline-flex; align-items:center; justify-content:center;
    font-family:var(--mono); font-size:13px; line-height:1;
    border:1px solid var(--line-strong); border-radius:8px;
    background:transparent; color:var(--ink-soft); transition:.12s;
  }
  .chart-dl:hover{ color:var(--accent-deep); border-color:var(--accent); }
```

- [ ] **Step 3: Call `wireShareButtons()` on init**

In `js/app.js`, add the import after the existing `controls.js` import line:
```js
  import { wireShareButtons } from "./share.js";
```
Then, inside the `if (HAS_DATA) { ... }` init block, find the `renderAll();` call and add `wireShareButtons();` immediately after it:
```js
    renderAll();
    wireShareButtons();
```

- [ ] **Step 4: Rebuild**

Run: `bun build.mjs`
Expected: `built dashboard.html — self-contained (… KB)`, no errors.

- [ ] **Step 5: Verify the controls landed in the built artifact**

Run: `grep -c -e 'id="btn-share"' -e 'chart-dl' dashboard.html`
Expected: prints a number `>= 2` (the button id + the `.chart-dl` style/refs are inlined).

- [ ] **Step 6: Confirm the full test suite still passes**

Run: `bun test`
Expected: all tests pass (the `cycles` + `stats` suites).

- [ ] **Step 7: Manual browser verification (controller)**

Run: `open dashboard.html`
Confirm:
- A `⤓ Card` button sits next to `⟲ Reset`. Clicking it downloads a theme-matched PNG of the current filtered stats (title, range subtitle, cost + tokens heroes, breakdown line, `cc.pulkitxm.com` footer).
- Each chart card shows a small `⤓` at its top-right; clicking downloads that chart as a PNG with a solid (non-transparent) background.
- Changing theme (light/dark) and filters (range/cycle/models/sources) is reflected in a freshly downloaded card; the heatmap and data tables have no `⤓` button.

- [ ] **Step 8: Commit**

```bash
git add dashboard.template.html css/styles.css js/app.js dashboard.html
git commit -m "feat: wire ⤓ Card + per-chart PNG download buttons"
```
End the commit body with:
```
Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
```

---

## Notes for the executor

- `dashboard.html` is a generated artifact — never hand-edit it; `bun build.mjs` regenerates it (preserving the inlined `<script id="usage-data">` data block). Commit it only in Task 3. Leave `data/usage.json` unstaged (it's an unrelated local data refresh).
- `render.js`/KPIs are intentionally NOT modified — the card computes its own numbers via `statsSummary(derive())`.
- The exact pixel coordinates in `drawShareCard()` are a sensible starting layout; the Task 3 manual check is where you confirm nothing clips and tune spacing if needed (keep the content/structure from the spec).
- All work happens on the `feat/share-download` branch.
