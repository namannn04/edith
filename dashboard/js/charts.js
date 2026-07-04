import { charts } from "./state.js";
import { fmtTok, fmtUSD } from "./format.js";

// ---------- chart.js defaults ----------
Chart.defaults.font.family =
  getComputedStyle(document.body).getPropertyValue("--mono") || "monospace";
Chart.defaults.font.size = 11;
const cssVar = (n) =>
  getComputedStyle(document.body).getPropertyValue(n).trim();
export let GRIDC, CARD_BG, TICKC, INKC, COSTC;
// read theme-dependent colors into module globals (used at chart-build time)
export function readThemeColors() {
  GRIDC = cssVar("--grid") || "#ece5d8";
  CARD_BG = cssVar("--paper-2") || "#fffdf8";
  TICKC = cssVar("--ink-soft") || "#5c5247";
  INKC = cssVar("--ink") || "#241f1a";
  COSTC = cssVar("--gold") || "#c89b3c"; // cost line color
  Chart.defaults.color = TICKC;
}
// dual-axis scales: left (y) = tokens, right (y1) = cost
export function dualScales(stacked) {
  return {
    x: {
      stacked: !!stacked,
      grid: { display: false },
      ticks: { maxRotation: 60, minRotation: 0, autoSkip: false },
    },
    y: {
      stacked: !!stacked,
      position: "left",
      grid: { color: GRIDC },
      ticks: { callback: (v) => fmtTok(v) },
      beginAtZero: true,
    },
    y1: {
      position: "right",
      grid: { drawOnChartArea: false },
      ticks: { callback: (v) => fmtUSD(v) },
      beginAtZero: true,
    },
  };
}
const DAYPX = 34; // min px per day column before horizontal scroll kicks in
export function sizeChartInner(scrollId, numDays) {
  const sc = document.getElementById(scrollId);
  if (!sc) return;
  const inner = sc.querySelector(".chart-inner");
  if (!inner) return;
  inner.style.width = Math.max(sc.clientWidth, numDays * DAYPX) + "px";
}
export function autoScrollRight(scrollId) {
  const sc = document.getElementById(scrollId);
  if (sc) sc.scrollLeft = sc.scrollWidth;
}
// legacy name kept: now only reads globals (build-time). Theme switch uses liveRetheme().
export function applyChartTheme() {
  readThemeColors();
}
export function mount(id, cfg) {
  if (charts[id]) charts[id].destroy();
  charts[id] = new Chart(document.getElementById(id), cfg);
}
export const baseTooltip = {
  backgroundColor: "#241f1a",
  titleColor: "#fffdf8",
  bodyColor: "#f0e9dc",
  borderColor: "#d97757",
  borderWidth: 1,
  padding: 10,
  cornerRadius: 8,
  titleFont: { family: "var(--mono)" },
  bodyFont: { family: "var(--mono)" },
};
