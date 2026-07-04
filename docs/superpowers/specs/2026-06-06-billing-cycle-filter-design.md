# Billing-cycle filter — design

**Date:** 2026-06-06
**Status:** Approved

## Problem

The dashboard's `Range` filter offers `Today / This week / Last week / All`, a
`Month` dropdown, and custom dates. None of these match a **billing cycle**,
which for this user resets on the **26th** of each month (current cycle:
May 26 → Jun 25). There is no way to filter the dashboard to a billing period.

## Goal

Add a billing-cycle option to the `Range` filter so the whole dashboard (every
chart, the models table, all range-scoped views) can be scoped to a single
billing cycle. The billing day is editable in the UI and defaults to 26.

## Non-goals

- **KPIs are unchanged.** The `Month to date` KPI and every other KPI stay
  keyed to the calendar month. We are *not* introducing a "cycle to date" KPI
  or a cycle-based projection.
- No changes to the existing `Today / This week / Last week / All` buttons, the
  `Month` dropdown, or the custom date pickers beyond the standard
  "picking one clears the others" behavior.

## Cycle semantics

For a billing day `D`:

- A cycle **starts** on day `D` of some month `M` and **ends** on the day
  before day `D` of month `M+1` (inclusive). With `D = 26`: `May 26 → Jun 25`.
- `cycleStart(date, D)` = the most recent occurrence of day `D` on-or-before
  `date`. If `date.getDate() >= D`, the start is `(date's year, month, D)`;
  otherwise it is `D` of the previous month.
- `cycleEnd(start, D)` = (start + 1 month) − 1 day.
- **Short-month clamping:** if a month has fewer than `D` days (e.g. `D = 31`
  in February), the cycle boundary clamps to that month's last day. For the
  default `D = 26` this never triggers.

## UI

In the controls bar, a new `Cycle` control group placed next to `Month`:

- **`Cycle` dropdown** (`#cycle-select`) — first option `— pick cycle —`, then
  every cycle that overlaps the data range, newest first, labeled like
  `26 May – 25 Jun`. Selecting one sets the range to that cycle; selecting the
  blank option reverts to `All`.
- **`Billing day` number field** (`#billing-day`) — `min=1 max=31`, default
  `26`. Editing it rebuilds the cycle dropdown immediately.

Picking a cycle clears the `Month` select, the custom date inputs, and the
segment buttons (same mutual-exclusion behavior the `Month` picker already has).

## State

`js/state.js`:

- `state.range` gains a new mode: `{ mode: "cycle", cycle: "YYYY-MM-DD" }`,
  where `cycle` is the cycle's **start date** (a stable key).
- New `state.billingDay = 26`.

## Behavior details

- **Default view:** on load, when the URL carries no explicit `range`, the
  dashboard selects the **current billing cycle** — the cycle containing the
  latest data day (`cycleStart(LATEST, billingDay)`). This replaces the prior
  "default to the latest month when the span is large" heuristic. The default is
  not written to the URL (so the URL stays clean); a reload re-derives it.
- `cyclesInData(day)` (new, in `js/data.js`, mirrors `monthsInData()`):
  enumerates every cycle from the one containing `EARLIEST` through the one
  containing `LATEST`, returning `{ start, end, label }` with `start`/`end` as
  `YYYY-MM-DD` strings.
- `activeWindow()` (`js/compute.js`) gains a `cycle` case returning
  `{ from: parseDate(r.cycle), to: cycleEnd(parseDate(r.cycle), state.billingDay) }`.
- Changing the billing day rebuilds the cycle dropdown. If the current range
  mode is `cycle` (its start may no longer be a valid boundary), the range
  resets to `{ mode: "all" }` for predictability.

## URL sync (`js/params.js`)

- Range: `range=cy:2026-05-26` (prefix `cy:` + cycle start date).
  - `readParams()` parses `cy:` → `{ mode: "cycle", cycle }`.
  - `rangeToParam()` emits `"cy:" + r.cycle`.
- Billing day: `cycleDay=29`. Omitted when it equals the default `26` to keep
  URLs clean (consistent with how other defaults are dropped).
  - `readParams()` reads `cycleDay` into `state.billingDay` (validate 1–31).
  - `writeParams()` writes `cycleDay` only when `!= 26`.

## Controls wiring (`js/controls.js`)

- `buildCycleSelect()` — populates `#cycle-select` from
  `cyclesInData(state.billingDay)`.
- `#cycle-select` `change` → set range to the chosen cycle (or `all` if blank),
  `syncRangeControls()`, `renderAll()`, `writeParams()`.
- `#billing-day` `change` → update `state.billingDay`, `buildCycleSelect()`,
  reset range to `all` if it was a cycle, `renderAll()`, `writeParams()`.
- `syncRangeControls()` — set `#cycle-select` value when mode is `cycle`
  (blank otherwise); always reflect `state.billingDay` in `#billing-day`.
- Reset button reverts the range to `All` (clearing any cycle selection) but
  **leaves `state.billingDay` as set** — it's a preference, not a filter.

## Files touched

`js/state.js`, `js/data.js`, `js/compute.js`, `js/params.js`,
`js/controls.js`, `dashboard.template.html`, then rebuild via
`bun build.mjs` to regenerate `dashboard.html`.

## Testing

- Default load: `Billing day` shows 26; cycle dropdown lists cycles covering the
  data; nothing selected → behaves as `All`.
- Selecting `26 May – 25 Jun` scopes every chart + the models table to that
  window; KPIs (incl. `Month to date`) are unchanged.
- Changing billing day to e.g. 1 relists cycles as calendar months; to 15
  relists 15th→14th cycles; an out-of-range/short month clamps correctly.
- URL reflects `range=cy:...` and `cycleDay=` (the latter only when ≠ 26);
  reloading restores the exact view; Reset clears the cycle but keeps the day.
