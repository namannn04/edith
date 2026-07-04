// merge.mjs - pure helpers for combining ccusage's per-agent output into the
// dashboard's per-source model.
//
// ccusage 2.x exposes one subcommand per coding agent (claude, opencode, codex,
// copilot, gemini, …). Their daily JSON comes in three shapes:
//   • claude:    row.totalCost + row.modelBreakdowns:[{modelName, …, cost}]  (full per-model)
//   • codex:     row.costUSD   + row.models:{ name:{ …tokens, reasoningOutputTokens } }
//                              (per-model tokens, one row-level cost)
//   • opencode:  row.totalCost + row-level tokens + row.modelsUsed:[names]   (NO per-model split)
// normalizeAgentDaily() collapses all three into one shape so render.mjs can
// treat every agent identically. Kept pure (no fs/argv) so it's unit-testable.

export const tokensOf = (b) =>
  (+b.inputTokens || 0) + (+b.outputTokens || 0) + (+b.cacheCreationTokens || 0) + (+b.cacheReadTokens || 0);

const tokensOfModelObj = (m) =>
  (+m.inputTokens || 0) +
  (+m.outputTokens || 0) +
  (+m.reasoningOutputTokens || 0) +
  (+m.cacheCreationTokens || 0) +
  (+m.cacheReadTokens || 0);

// One normalized breakdown row. reasoningOutputTokens (codex) folds into output
// so token totals stay internally consistent with tokensOf().
const breakdown = (modelName, m, cost) => ({
  modelName,
  inputTokens: +m.inputTokens || 0,
  outputTokens: (+m.outputTokens || 0) + (+m.reasoningOutputTokens || 0),
  cacheCreationTokens: +m.cacheCreationTokens || 0,
  cacheReadTokens: +m.cacheReadTokens || 0,
  cost: +cost || 0,
});

// row (one daily entry from any `ccusage <agent> daily --json`) -> { period, breakdowns[] }
export function normalizeAgentDaily(row) {
  const period = row.period || row.date; // plain `daily` uses period; per-agent uses date
  let breakdowns = [];

  if (Array.isArray(row.modelBreakdowns)) {
    // claude: full per-model breakdown incl. per-model cost.
    breakdowns = row.modelBreakdowns.map((b) => breakdown(b.modelName, b, b.cost));
  } else if (row.models && typeof row.models === "object") {
    // codex: per-model token objects + a single row-level cost (costUSD). Split
    // the cost by token share - exact for a single-model day, proportional else.
    const entries = Object.entries(row.models);
    const rowCost = +row.totalCost || +row.costUSD || 0;
    const totalTok = entries.reduce((a, [, m]) => a + tokensOfModelObj(m), 0) || 1;
    breakdowns = entries.map(([name, m]) =>
      breakdown(name, m, (rowCost * tokensOfModelObj(m)) / totalTok),
    );
  } else if (Array.isArray(row.modelsUsed) && row.modelsUsed.length) {
    // opencode: only row-level tokens + a flat modelsUsed list (no per-model
    // split at all). Attribute the row to its model(s): exact for the common
    // single-model day, equal-split otherwise.
    // ponytail: equal split across models on multi-model days - ccusage's
    // opencode daily exposes no per-model breakdown; upgrade if it ever does.
    const names = row.modelsUsed;
    const n = names.length;
    const rowCost = (+row.totalCost || +row.costUSD || 0) / n;
    const share = (v) => (+v || 0) / n;
    breakdowns = names.map((name) =>
      breakdown(name, {
        inputTokens: share(row.inputTokens),
        outputTokens: share(row.outputTokens),
        cacheCreationTokens: share(row.cacheCreationTokens),
        cacheReadTokens: share(row.cacheReadTokens),
      }, rowCost),
    );
  }
  return { period, breakdowns };
}

// ---- source identity: label + which tool a source rolls up under ----------
// cli + cowork are both Claude Code (cowork = Claude Code run under the desktop
// app); every other ccusage agent is its own tool. defaultSources (the dashboard's
// first-load filter) = the Claude Code group.
export const SOURCE_META = {
  cli:        { label: "Claude Code",       tool: "Claude Code" },
  "cc-cloud": { label: "Claude Code Cloud", tool: "Claude Code" },
  cowork:     { label: "Cowork",            tool: "Claude Code" },
  opencode: { label: "OpenCode",    tool: "OpenCode" },
  codex:    { label: "Codex",       tool: "Codex" },
  copilot:  { label: "Copilot",     tool: "Copilot" },
  gemini:   { label: "Gemini CLI",  tool: "Gemini CLI" },
  amp:      { label: "Amp",         tool: "Amp" },
  droid:    { label: "Droid",       tool: "Droid" },
  goose:    { label: "Goose",       tool: "Goose" },
  kilo:     { label: "Kilo",        tool: "Kilo" },
  qwen:     { label: "Qwen",        tool: "Qwen" },
  kimi:     { label: "Kimi",        tool: "Kimi" },
};

export const metaFor = (s) =>
  SOURCE_META[s] || { label: s.charAt(0).toUpperCase() + s.slice(1), tool: s.charAt(0).toUpperCase() + s.slice(1) };

// sources -> the subset whose tool is Claude Code (the default-on filter).
export const claudeCodeSources = (sources) => sources.filter((s) => metaFor(s).tool === "Claude Code");
