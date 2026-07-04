# Billing-cycle Filter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `Cycle` dropdown next to the `Month` filter that scopes the whole dashboard to a billing period (start day editable in the UI, default 26), leaving all KPIs calendar-month.

**Architecture:** Isolate the error-prone cycle date math into a new pure, DOM-free module `js/cycles.js` (unit-tested with `bun test`). The rest is wiring the existing filter machinery: a new `cycle` range mode in `state`, a `cycle` case in `activeWindow()`, URL-param round-tripping in `params.js`, and a dropdown + number input in the controls. `dashboard.html` is regenerated from sources via `bun build.mjs`.

**Tech Stack:** Vanilla ES modules bundled by `bun build.mjs` into a self-contained `dashboard.html`; Chart.js (unaffected); `bun test` for unit tests.

---

## File Structure

- **Create `js/cycles.js`** — pure date helpers: `cycleStart(date, day)`, `cycleEnd(start, day)`, `cyclesFromBounds(earliest, latest, day)`. No DOM, no `state`. Imports only `ymd`, `MON` from `format.js`.
- **Create `tests/cycles.test.js`** — `bun test` coverage for the three helpers (rollover, year boundary, short-month clamping).
- **Modify `js/state.js`** — add `DEFAULT_BILLING_DAY = 26` export and `billingDay` field; document the new `cycle` range mode.
- **Modify `js/data.js`** — add `cyclesInData(day)` (thin wrapper over `cyclesFromBounds` using `EARLIEST`/`LATEST`).
- **Modify `js/compute.js`** — add the `cycle` case to `activeWindow()`.
- **Modify `js/params.js`** — read/write `range=cy:<start>` and `cycleDay=<n>`.
- **Modify `dashboard.template.html`** — add the `Cycle` + `Billing day` control group next to `Month`.
- **Modify `js/controls.js`** — `buildCycleSelect()`, wire the two new controls, extend `syncRangeControls()`.
- **Modify `js/app.js`** — call `buildCycleSelect()` during init.
- **Rebuild** `dashboard.html` via `bun build.mjs`.

All commands below are run from the repo root: `/Users/pulkit/scripts/ccusage-dashboard/usage-repo`.

---

### Task 1: Pure cycle date module (`js/cycles.js`) — TDD

**Files:**
- Create: `tests/cycles.test.js`
- Create: `js/cycles.js`

- [ ] **Step 1: Write the failing tests**

Create `tests/cycles.test.js`:

```js
import { test, expect } from "bun:test";
import { cycleStart, cycleEnd, cyclesFromBounds } from "../js/cycles.js";

const d = (s) => { const [y, m, day] = s.split("-").map(Number); return new Date(y, m - 1, day); };
const iso = (dt) => `${dt.getFullYear()}-${String(dt.getMonth() + 1).padStart(2, "0")}-${String(dt.getDate()).padStart(2, "0")}`;

test("cycleStart: date after the billing day -> this month's anchor", () => {
  expect(iso(cycleStart(d("2026-06-06"), 26))).toBe("2026-05-26"); // before the 26th -> previous anchor
  expect(iso(cycleStart(d("2026-06-26"), 26))).toBe("2026-06-26"); // exactly on the anchor
  expect(iso(cycleStart(d("2026-06-30"), 26))).toBe("2026-06-26"); // after the anchor
});

test("cycleStart: crosses year boundary backwards", () => {
  expect(iso(cycleStart(d("2026-01-06"), 26))).toBe("2025-12-26");
});

test("cycleStart: clamps when the month is shorter than the billing day", () => {
  expect(iso(cycleStart(d("2026-02-15"), 31))).toBe("2026-01-31"); // Feb has no 31st
  expect(iso(cycleStart(d("2026-03-01"), 31))).toBe("2026-02-28"); // before March anchor -> Feb's clamped anchor
});

test("cycleEnd: day before the next anchor, inclusive", () => {
  expect(iso(cycleEnd(d("2026-05-26"), 26))).toBe("2026-06-25");
  expect(iso(cycleEnd(d("2025-12-26"), 26))).toBe("2026-01-25"); // forward across year boundary
  expect(iso(cycleEnd(d("2026-01-31"), 31))).toBe("2026-02-27"); // next anchor clamps to Feb 28
});

test("cyclesFromBounds: newest-first list with labels", () => {
  const cs = cyclesFromBounds(d("2026-05-01"), d("2026-06-06"), 26);
  expect(cs.map(c => c.start)).toEqual(["2026-05-26", "2026-04-26"]);
  expect(cs[0]).toEqual({ start: "2026-05-26", end: "2026-06-25", label: "26 May – 25 Jun 2026" });
});

test("cyclesFromBounds: labels show both years when a cycle spans New Year", () => {
  const cs = cyclesFromBounds(d("2025-12-30"), d("2026-01-02"), 26);
  expect(cs[0].label).toBe("26 Dec 2025 – 25 Jan 2026");
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bun test tests/cycles.test.js`
Expected: FAIL — `Cannot find module "../js/cycles.js"` (module not created yet).

- [ ] **Step 3: Implement `js/cycles.js`**

Create `js/cycles.js`:

```js
import { ymd, MON } from "./format.js";

  // ---------- billing-cycle date math (pure; no DOM, no state) ----------
  // A cycle anchored on day D starts on day D of a month and ends the day before
  // day D of the next month. Months shorter than D clamp to their last day
  // (e.g. D=31 in February -> the 28th/29th).

  const daysInMonth = (y, m) => new Date(y, m + 1, 0).getDate(); // m is 0-based
  const anchorFor = (y, m, day) => new Date(y, m, Math.min(day, daysInMonth(y, m)));

  // Start (a Date at local midnight) of the cycle that contains `date`.
  export function cycleStart(date, day) {
    const y = date.getFullYear(), m = date.getMonth();
    const anchor = Math.min(day, daysInMonth(y, m));
    if (date.getDate() >= anchor) return new Date(y, m, anchor);
    return anchorFor(m === 0 ? y - 1 : y, m === 0 ? 11 : m - 1, day);
  }

  // Inclusive end (a Date) of the cycle that starts at `start`: day before the
  // next anchor.
  export function cycleEnd(start, day) {
    const y = start.getFullYear(), m = start.getMonth();
    const next = anchorFor(m === 11 ? y + 1 : y, m === 11 ? 0 : m + 1, day);
    const end = new Date(next);
    end.setDate(end.getDate() - 1);
    return end;
  }

  function label(start, end) {
    const s = `${start.getDate()} ${MON[start.getMonth()]}` +
      (start.getFullYear() !== end.getFullYear() ? ` ${start.getFullYear()}` : "");
    return `${s} – ${end.getDate()} ${MON[end.getMonth()]} ${end.getFullYear()}`;
  }

  // Every cycle overlapping [earliest, latest], newest first:
  // [{ start:"YYYY-MM-DD", end:"YYYY-MM-DD", label }]
  export function cyclesFromBounds(earliest, latest, day) {
    const out = [];
    let start = cycleStart(earliest, day);
    while (start <= latest) {
      const end = cycleEnd(start, day);
      out.push({ start: ymd(start), end: ymd(end), label: label(start, end) });
      start = new Date(end); start.setDate(start.getDate() + 1);
    }
    return out.reverse();
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bun test tests/cycles.test.js`
Expected: PASS — all 6 tests green.

- [ ] **Step 5: Commit**

```bash
git add js/cycles.js tests/cycles.test.js
git commit -m "feat: pure billing-cycle date helpers + tests"
```

---

### Task 2: Billing-day state + cycle range mode

**Files:**
- Modify: `js/state.js`

- [ ] **Step 1: Add the default constant, `billingDay`, and document the new mode**

In `js/state.js`, update the imports/comment and the `state` object. Change the range comment line and the `range` field, and add `billingDay`:

Replace:
```js
  // range is now an object: {mode:'all'|'today'|'yesterday'|'thisWeek'|'lastWeek'|'month'|'custom', month?, from?, to?}
  export const state = {
    range: { mode: "all" },
    models: new Set(ALL_MODELS),
    sources: new Set(SOURCES),
```
with:
```js
  // range is now an object: {mode:'all'|'today'|'yesterday'|'thisWeek'|'lastWeek'|'month'|'custom'|'cycle', month?, from?, to?, cycle?}
  // 'cycle' mode: {mode:'cycle', cycle:'YYYY-MM-DD'} where cycle is the cycle's START date.
  export const DEFAULT_BILLING_DAY = 26;
  export const state = {
    range: { mode: "all" },
    billingDay: DEFAULT_BILLING_DAY,
    models: new Set(ALL_MODELS),
    sources: new Set(SOURCES),
```

- [ ] **Step 2: Verify the module still parses**

Run: `bun build.mjs`
Expected: prints `built dashboard.html — self-contained (… KB)` with no bundle errors. (We rebuild here only to confirm the edit didn't break the bundle; the UI isn't wired yet.)

- [ ] **Step 3: Commit**

```bash
git add js/state.js
git commit -m "feat: add billingDay state + cycle range mode"
```

---

### Task 3: `cyclesInData()` + `activeWindow()` cycle case

**Files:**
- Modify: `js/data.js`
- Modify: `js/compute.js`

- [ ] **Step 1: Add `cyclesInData()` to `js/data.js`**

At the top of `js/data.js`, extend the existing format import:
```js
  import { parseDate, MONTH_NAMES } from "./format.js";
```
to:
```js
  import { parseDate, MONTH_NAMES } from "./format.js";
  import { cyclesFromBounds } from "./cycles.js";
```

Then, immediately after the existing `monthsInData()` function (end of file), add:
```js
  // Every billing cycle (start day = `day`) overlapping the data range, newest
  // first. Empty when there's no data. Mirrors monthsInData().
  export function cyclesInData(day) {
    if (!EARLIEST || !LATEST) return [];
    return cyclesFromBounds(EARLIEST, LATEST, day);
  }
```

- [ ] **Step 2: Add the `cycle` case to `activeWindow()` in `js/compute.js`**

At the top of `js/compute.js`, extend the format import:
```js
  import { parseDate, ymd } from "./format.js";
```
to:
```js
  import { parseDate, ymd } from "./format.js";
  import { cycleEnd } from "./cycles.js";
```

In `activeWindow()`, add a `cycle` case immediately before the `custom` case:
```js
      case "cycle":     { const start = parseDate(r.cycle); return { from: start, to: cycleEnd(start, state.billingDay) }; }
      case "custom":    return { from: parseDate(r.from), to: parseDate(r.to) };
```

Note: `inRangeDays()` and `derive()` already route every non-`all` mode through `activeWindow()`, so no other changes are needed there.

- [ ] **Step 3: Verify the bundle builds**

Run: `bun build.mjs`
Expected: prints `built dashboard.html — self-contained (… KB)`, no errors.

- [ ] **Step 4: Commit**

```bash
git add js/data.js js/compute.js
git commit -m "feat: cyclesInData() + cycle window in activeWindow()"
```

---

### Task 4: URL-param round-tripping for cycle + billing day

**Files:**
- Modify: `js/params.js`

- [ ] **Step 1: Import the default constant**

At the top of `js/params.js`, extend the state import:
```js
  import { state } from "./state.js";
```
to:
```js
  import { state, DEFAULT_BILLING_DAY } from "./state.js";
```

- [ ] **Step 2: Parse `cy:` range and `cycleDay` in `readParams()`**

In `readParams()`, inside the `if (r) { … }` block, add a `cy:` branch next to the existing `c:` branch:
```js
      else if (r.startsWith("m:")) state.range = { mode: "month", month: r.slice(2) };
      else if (r.startsWith("cy:")) state.range = { mode: "cycle", cycle: r.slice(3) };
      else if (r.startsWith("c:")) {
```

Then, just after the `theme` param is read (near the end of `readParams()`), add:
```js
    const cd = q.get("cycleDay");
    if (cd && /^\d+$/.test(cd)) { const n = +cd; if (n >= 1 && n <= 31) state.billingDay = n; }
```

- [ ] **Step 3: Emit `cy:` from `rangeToParam()`**

In `rangeToParam()`, add the `cycle` line next to `month`/`custom`:
```js
    if (r.mode === "month") return "m:" + r.month;
    if (r.mode === "cycle") return "cy:" + r.cycle;
    if (r.mode === "custom") return "c:" + r.from + "~" + r.to;
```

- [ ] **Step 4: Write `cycleDay` in `writeParams()`**

In `writeParams()`, just before the `theme` line, add:
```js
    state.billingDay === DEFAULT_BILLING_DAY ? q.delete("cycleDay") : q.set("cycleDay", String(state.billingDay));
```

- [ ] **Step 5: Verify the bundle builds**

Run: `bun build.mjs`
Expected: prints `built dashboard.html — self-contained (… KB)`, no errors.

- [ ] **Step 6: Commit**

```bash
git add js/params.js
git commit -m "feat: URL sync for cycle range + cycleDay"
```

---

### Task 5: Controls — Cycle dropdown + Billing-day input

**Files:**
- Modify: `dashboard.template.html`
- Modify: `js/controls.js`
- Modify: `js/app.js`

- [ ] **Step 1: Add the markup next to `Month`**

In `dashboard.template.html`, after the `Month` control group (the `</div>` closing the block that contains `id="month-select"`, currently around line 56) and before the `Custom` control group, insert:
```html
      <div class="ctl-group">
        <span class="ctl-label">Cycle</span>
        <select class="chip" id="cycle-select" style="padding-right:9px"></select>
      </div>
      <div class="ctl-group">
        <span class="ctl-label">Billing day</span>
        <input type="number" class="chip" id="billing-day" min="1" max="31" value="26"
               style="width:60px;padding:5px 9px"/>
      </div>
```

- [ ] **Step 2: Add `buildCycleSelect()` and extend imports in `js/controls.js`**

In `js/controls.js`, extend the data import:
```js
  import { sourceLabel, SOURCES, ALL_MODELS, monthsInData } from "./data.js";
```
to:
```js
  import { sourceLabel, SOURCES, ALL_MODELS, monthsInData, cyclesInData } from "./data.js";
```
and extend the state import:
```js
  import { state } from "./state.js";
```
to:
```js
  import { state, DEFAULT_BILLING_DAY } from "./state.js";
```

Immediately after the existing `buildMonthSelect()` function, add:
```js
  export function buildCycleSelect() {
    const sel = document.getElementById("cycle-select");
    sel.innerHTML = `<option value="">— pick cycle —</option>` +
      cyclesInData(state.billingDay).map(c => `<option value="${c.start}">${c.label}</option>`).join("");
  }
```

- [ ] **Step 3: Reflect cycle + billing day in `syncRangeControls()`**

In `syncRangeControls()`, after the existing `date-to` line, add:
```js
    document.getElementById("date-to").value   = r.mode === "custom" ? r.to   : "";
    document.getElementById("cycle-select").value = r.mode === "cycle" ? r.cycle : "";
    document.getElementById("billing-day").value  = String(state.billingDay);
```
(The first line above already exists — add the two new lines after it.)

- [ ] **Step 4: Wire the two new controls in `wireControls()`**

In `wireControls()`, right after the `month-select` change listener block, add:
```js
  document.getElementById("cycle-select").addEventListener("change", e => {
    const v = e.target.value;
    state.range = v ? { mode: "cycle", cycle: v } : { mode: "all" };
    syncRangeControls(); renderAll(); writeParams();
  });
  document.getElementById("billing-day").addEventListener("change", e => {
    let n = parseInt(e.target.value, 10);
    if (!Number.isFinite(n)) n = DEFAULT_BILLING_DAY;
    n = Math.min(31, Math.max(1, n));
    state.billingDay = n;
    e.target.value = String(n);                       // reflect clamping back to the input
    if (state.range.mode === "cycle") state.range = { mode: "all" }; // old start may be stale
    buildCycleSelect();
    syncRangeControls(); renderAll(); writeParams();
  });
```

- [ ] **Step 5: Build the cycle dropdown on init**

In `js/app.js`, extend the controls import:
```js
  import { wireControls, applyTheme, buildMonthSelect, syncRangeControls, buildSourceChips, buildChips } from "./controls.js";
```
to:
```js
  import { wireControls, applyTheme, buildMonthSelect, buildCycleSelect, syncRangeControls, buildSourceChips, buildChips } from "./controls.js";
```
and, in the `if (HAS_DATA) { … }` init block, add `buildCycleSelect();` right after the existing `buildMonthSelect();` call:
```js
    buildMonthSelect();
    buildCycleSelect();
```

- [ ] **Step 6: Rebuild the dashboard**

Run: `bun build.mjs`
Expected: prints `built dashboard.html — self-contained (… KB)`, no errors.

- [ ] **Step 7: Verify the controls are present in the built artifact**

Run: `grep -c -e 'id="cycle-select"' -e 'id="billing-day"' dashboard.html`
Expected: prints `2` (both control IDs are inlined into the generated HTML).

- [ ] **Step 8: Manual browser verification**

Run: `open dashboard.html`
Confirm, with the dashboard open:
- A `Cycle` dropdown and a `Billing day` field (showing `26`) appear next to `Month`.
- The `Cycle` dropdown lists cycles labeled like `26 May – 25 Jun 2026`, newest first.
- Selecting `26 May – 25 Jun 2026` rescopes every chart and the models table to that window; the `Month` dropdown and segment buttons clear; KPIs (incl. `Month to date`) are unchanged.
- The URL gains `range=cy:2026-05-26`. Reloading restores the same view.
- Changing `Billing day` to `1` relists the dropdown as calendar months; to `15`, as 15th→14th cycles. The URL gains `cycleDay=15` (and drops it when set back to `26`).
- `⟲ Reset` clears the cycle selection (back to the default view) but leaves `Billing day` as set.

- [ ] **Step 9: Commit**

```bash
git add dashboard.template.html js/controls.js js/app.js dashboard.html
git commit -m "feat: Cycle dropdown + editable billing day in controls"
```

---

## Notes for the executor

- `dashboard.html` is a **generated artifact** — never hand-edit it; only `bun build.mjs` regenerates it. It may already show as modified in `git status` from a data refresh (`data/usage.json` too); the build preserves the inlined `<script id="usage-data">` data block, so rebuilding is safe. Commit `dashboard.html` only in Task 5 (after the final rebuild); leave `data/usage.json` untouched/uncommitted.
- KPIs are intentionally untouched (per spec non-goals) — do not add a "cycle to date" KPI.
- All work happens on the `feat/billing-cycle-filter` branch created during brainstorming.
