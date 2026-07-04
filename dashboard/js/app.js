"use strict";
import { ymd } from "./format.js";
import { cycleStart } from "./cycles.js";
import { DAILY, LATEST } from "./data.js";
import { setPalette } from "./palette.js";
import { state } from "./state.js";
import { readParams } from "./params.js";
import { readThemeColors } from "./charts.js";
import {
  renderMeta,
  renderAll,
  latestDayWithHours,
  renderHourly,
  renderHourlyAll,
} from "./render.js";
import {
  wireControls,
  applyTheme,
  buildMonthSelect,
  buildCycleSelect,
  syncRangeControls,
  buildSourceChips,
  buildChips,
} from "./controls.js";
import { wireShareButtons } from "./share.js";

// ---------- empty state ----------
// No data yet: show the placeholder and skip all rendering. This file is an ES
// module — top level can't use a bare `return`, so instead of early-returning
// we set HAS_DATA and guard the init block below with it. data.js is written to
// be empty-data-safe (EARLIEST/LATEST default to null), so importing it is fine.
const HAS_DATA = DAILY.length > 0;
if (!HAS_DATA) {
  document.getElementById("empty").style.display = "block";
  const m = document.getElementById("meta-row");
  if (m) m.textContent = "Awaiting first snapshot.";
} else {
  document.getElementById("dash").classList.remove("hidden");
}

// ============ INIT ============
// Everything here runs only when there is data (preserves the original
// early-return-on-empty behavior now that this is module top level).
if (HAS_DATA) {
  wireControls();
  readParams();
  applyTheme(state.theme);
  setPalette(state.theme);
  readThemeColors();
  buildMonthSelect();
  buildCycleSelect();
  // Default view: with no explicit range in the URL, select the current billing
  // cycle (the one containing the latest data day) for a clean, bill-aligned first paint.
  let _hasRangeParam = false;
  try {
    _hasRangeParam = new URLSearchParams(location.search).has("range");
  } catch (e) {}
  if (!_hasRangeParam && state.range.mode === "all" && LATEST) {
    state.range = {
      mode: "cycle",
      cycle: ymd(cycleStart(LATEST, state.billingDay)),
    };
  }
  syncRangeControls();
  renderMeta();
  buildSourceChips();
  buildChips();
  renderAll();
  wireShareButtons();
  // hourly card: default to the latest day with data, then render it
  (function initHourly() {
    const inp = document.getElementById("hourly-date");
    const def = latestDayWithHours();
    if (inp) {
      inp.value = def;
      inp.min = DAILY[0] ? DAILY[0].period : def;
      inp.max = ymd(LATEST);
    }
    renderHourly(def);
  })();
  renderHourlyAll();
}
