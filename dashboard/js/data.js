import { parseDate, MONTH_NAMES } from "./format.js";
import { cyclesFromBounds } from "./cycles.js";

// ---------- load injected data ----------
export let RAW = {};
try {
  RAW = JSON.parse(document.getElementById("usage-data").textContent || "{}");
} catch (e) {
  RAW = {};
}
export const DAILY = Array.isArray(RAW.daily) ? RAW.daily.slice() : [];
export const SESSIONS = Array.isArray(RAW.sessions) ? RAW.sessions : [];

// ---------- sources / tools (with v1/v2 back-compat) ----------
// Each source is one ccusage agent stream; cli+cowork roll up under the
// "Claude Code" tool. render.mjs ships per-source {label,tool} in sourceMeta
// and the first-load filter set in defaultSources (the Claude Code tool only).
// v1 rows had a flat modelBreakdowns[] (treated as a single "cli" source);
// pre-multitool data files have no sourceMeta/defaultSources - fall back to the
// original Code/Cowork labels and an all-sources default view.
const LEGACY_LABEL = { cli: "Code", cowork: "Cowork" };
const SRC_META = RAW.sourceMeta || {};
DAILY.forEach((d) => {
  if (!d.bySource) d.bySource = { cli: d.modelBreakdowns || [] };
});
export let SOURCES = (
  Array.isArray(RAW.sources) && RAW.sources.length ? RAW.sources : ["cli"]
).filter((s) => DAILY.some((d) => (d.bySource[s] || []).length));
if (!SOURCES.length) SOURCES = ["cli"];
export const SOURCE_LABEL = {};
export const SOURCE_TOOL = {};
SOURCES.forEach((s) => {
  SOURCE_LABEL[s] = (SRC_META[s] && SRC_META[s].label) || LEGACY_LABEL[s] || s;
  SOURCE_TOOL[s] = (SRC_META[s] && SRC_META[s].tool) || SOURCE_LABEL[s];
});
export const sourceLabel = (s) => SOURCE_LABEL[s] || s;
// First-load / Reset source filter: the Claude Code tool only when the data
// declares it, else every source (legacy behavior).
const _def =
  Array.isArray(RAW.defaultSources) && RAW.defaultSources.length
    ? RAW.defaultSources.filter((s) => SOURCES.includes(s))
    : [];
export const DEFAULT_SOURCES = _def.length ? _def : SOURCES.slice();

// all models, ranked by total cost (stable color assignment)
export const modelTotals = {};
for (const d of DAILY)
  for (const s of SOURCES)
    for (const b of d.bySource[s] || []) {
      modelTotals[b.modelName] =
        (modelTotals[b.modelName] || 0) + (+b.cost || 0);
    }
export const ALL_MODELS = Object.keys(modelTotals).sort(
  (a, b) => modelTotals[b] - modelTotals[a],
);

// First-load / Reset model filter: only models used by the default (Claude Code)
// sources, so non-Claude models (e.g. gpt-5.5 from Codex/OpenCode) aren't checked
// by default - they'd otherwise sit selected but invisible since their sources
// are off by default. Same cost-ranked order as ALL_MODELS; falls back to all
// models if (legacy data) nothing matches.
const _defModels = new Set();
for (const d of DAILY)
  for (const s of DEFAULT_SOURCES)
    for (const b of d.bySource[s] || []) _defModels.add(b.modelName);
export const DEFAULT_MODELS = _defModels.size
  ? ALL_MODELS.filter((m) => _defModels.has(m))
  : ALL_MODELS.slice();

// data bounds (sorted ascending) + month list, computed once
const _sortedDays = DAILY.slice().sort((a, b) =>
  a.period < b.period ? -1 : 1,
);
export const EARLIEST = _sortedDays.length
  ? parseDate(_sortedDays[0].period)
  : null;
export const LATEST = _sortedDays.length
  ? parseDate(_sortedDays[_sortedDays.length - 1].period)
  : null;
export const ALL_SPAN_DAYS =
  EARLIEST && LATEST ? Math.round((LATEST - EARLIEST) / 86400000) + 1 : 0;
export function monthsInData() {
  const set = new Set();
  DAILY.forEach((d) => set.add(d.period.slice(0, 7)));
  return [...set]
    .sort()
    .reverse()
    .map((ym) => {
      const [y, m] = ym.split("-").map(Number);
      return { ym, label: `${MONTH_NAMES[m - 1]} ${y}` };
    });
}

// Every billing cycle (start day = `day`) overlapping the data range, newest
// first. Empty when there's no data. Mirrors monthsInData().
export function cyclesInData(day) {
  if (!EARLIEST || !LATEST) return [];
  return cyclesFromBounds(EARLIEST, LATEST, day);
}
