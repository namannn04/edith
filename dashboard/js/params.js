import { state, DEFAULT_BILLING_DAY } from "./state.js";
import {
  ALL_MODELS,
  DEFAULT_MODELS,
  SOURCES,
  DEFAULT_SOURCES,
  LATEST,
} from "./data.js";
import { shortModel, ymd } from "./format.js";
import { systemTheme } from "./palette.js";
import { cycleStart } from "./cycles.js";

// ---------- URL query-param sync ----------
// Filters live in the URL (not localStorage) so a view is shareable and
// survives reload. Params: ?range=cy:YYYY-MM-DD &metric=tokens &models=opus-4-8,haiku-4-5
// A *clean* URL (no range) means the default view = the CURRENT billing cycle;
// "All" is NOT the default, so it persists explicitly as ?range=all. Past cycles
// persist as ?range=cy:<start>. Default models/sources are omitted to keep URLs clean.
export const shortToFull = {};
ALL_MODELS.forEach((m) => {
  shortToFull[shortModel(m)] = m;
});

export function readParams() {
  let q;
  try {
    q = new URLSearchParams(location.search);
  } catch (e) {
    return;
  }
  const r = q.get("range");
  if (r) {
    if (r === "all") state.range = { mode: "all" };
    else if (/^\d+$/.test(r)) {
      // back-compat: old 7/30/90 → custom window ending at LATEST
      const n = +r;
      const to = new Date(LATEST);
      const from = new Date(LATEST);
      from.setDate(from.getDate() - (n - 1));
      state.range = { mode: "custom", from: ymd(from), to: ymd(to) };
    } else if (["today", "yesterday", "thisWeek", "lastWeek"].includes(r))
      state.range = { mode: r };
    else if (r.startsWith("m:"))
      state.range = { mode: "month", month: r.slice(2) };
    else if (r.startsWith("cy:"))
      state.range = { mode: "cycle", cycle: r.slice(3) };
    else if (r.startsWith("c:")) {
      const [from, to] = r.slice(2).split("~");
      if (from && to) state.range = { mode: "custom", from, to };
    }
  }
  const ms = q.get("models");
  if (ms) {
    const wanted = ms
      .split(",")
      .map((s) => shortToFull[s] || (ALL_MODELS.includes(s) ? s : null))
      .filter(Boolean);
    if (wanted.length) state.models = new Set(wanted);
  }
  const ss = q.get("sources");
  if (ss) {
    const wanted = ss.split(",").filter((s) => SOURCES.includes(s));
    if (wanted.length) state.sources = new Set(wanted);
  }
  const th = q.get("theme");
  if (th === "dark" || th === "light") state.theme = th;
  const cd = q.get("cycleDay");
  if (cd && /^\d+$/.test(cd)) {
    const n = +cd;
    if (n >= 1 && n <= 31) state.billingDay = n;
  }
}

export function rangeToParam() {
  const r = state.range;
  if (r.mode === "all") return "all"; // All is NOT the default → persist it
  if (r.mode === "month") return "m:" + r.month;
  if (r.mode === "cycle") {
    // The current cycle (containing the latest data day, for the active billing
    // day) is the implicit default, so a clean URL already means it - omit it.
    // Past cycles persist explicitly so they survive reload / sharing.
    if (LATEST && r.cycle === ymd(cycleStart(LATEST, state.billingDay)))
      return "";
    return "cy:" + r.cycle;
  }
  if (r.mode === "custom") return "c:" + r.from + "~" + r.to;
  return r.mode; // today / yesterday / thisWeek / lastWeek
}
export function writeParams() {
  let url;
  try {
    url = new URL(location.href);
  } catch (e) {
    return;
  }
  const q = url.searchParams;
  const rp = rangeToParam();
  rp ? q.set("range", rp) : q.delete("range");
  // Clean URL = the default (Claude Code) model filter; any deviation persists.
  const isDefaultModels =
    state.models.size === DEFAULT_MODELS.length &&
    DEFAULT_MODELS.every((m) => state.models.has(m));
  if (isDefaultModels) q.delete("models");
  else
    q.set(
      "models",
      ALL_MODELS.filter((m) => state.models.has(m))
        .map(shortModel)
        .join(","),
    );
  // Clean URL = the default (Claude Code) source filter; any deviation persists.
  const isDefaultSources =
    state.sources.size === DEFAULT_SOURCES.length &&
    DEFAULT_SOURCES.every((s) => state.sources.has(s));
  if (isDefaultSources) q.delete("sources");
  else q.set("sources", SOURCES.filter((s) => state.sources.has(s)).join(","));
  state.billingDay === DEFAULT_BILLING_DAY
    ? q.delete("cycleDay")
    : q.set("cycleDay", String(state.billingDay));
  state.theme === systemTheme ? q.delete("theme") : q.set("theme", state.theme);
  try {
    history.replaceState(null, "", url.toString());
  } catch (e) {
    /* sandbox */
  }
}
