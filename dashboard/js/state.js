import { DEFAULT_MODELS, DEFAULT_SOURCES } from "./data.js";
import { systemTheme } from "./palette.js";

// ---------- state (in-memory only) ----------
// range is now an object: {mode:'all'|'today'|'yesterday'|'thisWeek'|'lastWeek'|'month'|'custom'|'cycle', month?, from?, to?, cycle?}
// 'cycle' mode: {mode:'cycle', cycle:'YYYY-MM-DD'} where cycle is the cycle's START date.
export const DEFAULT_BILLING_DAY = 26;
export const state = {
  range: { mode: "all" },
  billingDay: DEFAULT_BILLING_DAY,
  models: new Set(DEFAULT_MODELS), // default view = Claude Code models only
  sources: new Set(DEFAULT_SOURCES), // default view = Claude Code tool only
  theme: systemTheme,
  sort: { key: "cost", dir: -1 },
  projSort: { key: "cost", dir: -1 },
  projListOpen: false, // whole By-project TABLE collapsed behind a toggle by default
  projExpanded: new Set(), // expanded tree keys: "proj:<name>" / "wt:<name><wt>"
};

export const charts = {};
