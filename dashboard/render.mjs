#!/usr/bin/env node
/**
 * render.mjs - merge per-source ccusage output into data/usage.json and inline it
 * into dashboard.html (overwriting the <script id="usage-data"> block).
 *
 * Usage:
 *   node render.mjs <manifest.json>
 *
 * The manifest is an array, one entry per ccusage agent stream:
 *   [{ source, daily, session, configDirs }]
 *     source     - source id (cli, cowork, opencode, codex, …)
 *     daily      - file with raw stdout of `ccusage <agent> daily   --json`
 *     session    - file with raw stdout of `ccusage <agent> session --json`
 *     configDirs - comma-separated CLAUDE_CONFIG_DIR list, set ONLY for the
 *                  Claude Code sources whose raw transcripts feed the drilldown
 *                  (empty for opencode/codex/etc.).
 * cli + cowork roll up under the "Claude Code" tool (see merge.mjs SOURCE_META);
 * every other ccusage agent is its own tool. normalizeAgentDaily() in merge.mjs
 * absorbs each agent's schema differences (codex uses costUSD + models{}).
 *
 * Schema (superset of v2 - all v2 fields preserved):
 *   { schemaVersion, generatedAt, sources:["cli","cowork","opencode",…],
 *     sourceMeta:{ cli:{label,tool}, … }, defaultSources:[…Claude Code sources],
 *     totals:{...combined..., bySource:{ <source>:{cost,tokens} }},
 *     daily:[ {
 *       period,
 *       bySource:{ <source>:[{modelName,inputTokens,...,cost}] },
 *       projects:[ {projectName, tokens, cost} ],        // Claude Code sources only
 *       hours:[ {tokens, cost} x24 ],                     // local hour 0..23
 *     } ],
 *     sessions:[ {id,lastActivity,totalCost,totalTokens,models,source} ] }
 *
 * The dashboard derives everything (totals, model splits, charts) from
 * daily[].bySource, so the source filter and model filter both stay consistent.
 * The projects/hours come from the raw transcripts and reconcile with ccusage
 * via per-model unit prices derived from the session breakdowns (least squares).
 */
import { readFileSync, writeFileSync, mkdirSync, readdirSync, existsSync } from "node:fs";
import { dirname, resolve, join } from "node:path";
import { fileURLToPath } from "node:url";
import { execFileSync } from "node:child_process";
import { tokensOf, normalizeAgentDaily, metaFor, claudeCodeSources } from "./merge.mjs";
import { parseLimitsJSONL, downsampleLimits } from "./limits.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
if (args.length < 1) {
  console.error("usage: node render.mjs <manifest.json>");
  console.error("  manifest = [{ source, daily, session, configDirs }] - one entry per ccusage agent stream");
  process.exit(1);
}

const readJSON = (p) => (p ? JSON.parse(readFileSync(p, "utf8")) : {});

// Manifest: one entry per (source, ccusage daily+session stream). cc-update emits
// it after probing which agents have data. `configDirs` (comma-separated) is set
// only for the Claude Code sources whose raw transcripts feed the v3 drilldown.
const manifest = readJSON(args[0]);
if (!Array.isArray(manifest) || !manifest.length) {
  console.error("ERROR: manifest must be a non-empty array of { source, daily, session, configDirs }");
  process.exit(1);
}

// Optional arg: a JSON array of background/remote (cloud) Claude Code session ids
// (from `claude agents --json --all`, dumped by cc-update). These sessions run on
// Anthropic infra but sync their transcripts into the cli config dir, so ccusage
// folds them into the cli totals. We use this set to re-partition cli into a
// local "cli" source and a "cc-cloud" ("Claude Code Cloud") source. Absent/empty
// → no split (the dashboard just shows the combined Claude Code source as before).
const CLOUD_SOURCE = "cc-cloud";
const cloudIds = new Set();
if (args[1] && existsSync(args[1])) {
  try { for (const id of JSON.parse(readFileSync(args[1], "utf8")) || []) if (id) cloudIds.add(id); }
  catch (e) { console.error("warning: could not read cloud-session ids:", e.message); }
}

// date -> { [source]: normalizedBreakdown[] }
const byDate = {};
const sessionBySource = {}; // source -> raw session JSON (for sessions list + price derivation)
const sourcesWithData = [];

for (const entry of manifest) {
  const src = entry.source;
  const rows = readJSON(entry.daily).daily || [];
  sessionBySource[src] = entry.session ? readJSON(entry.session) : { sessions: [] };
  if (rows.length) sourcesWithData.push(src);
  for (const row of rows) {
    const { period, breakdowns } = normalizeAgentDaily(row);
    if (period) (byDate[period] ||= {})[src] = breakdowns;
  }
}
// advertise cli always (canonical Claude Code source); every other source only
// when it actually has data, in manifest order.
const sources = ["cli", ...manifest.map((e) => e.source).filter((s) => s !== "cli" && sourcesWithData.includes(s))];

const daily = Object.keys(byDate)
  .sort()
  .map((period) => {
    const bySource = {};
    for (const src of sources) bySource[src] = byDate[period][src] || [];
    return { period, bySource };
  });

// combined + per-source totals
const blank = () => ({ cost: 0, tokens: 0, inputTokens: 0, outputTokens: 0, cacheCreationTokens: 0, cacheReadTokens: 0 });
const totals = blank();
totals.bySource = {};
for (const src of sources) totals.bySource[src] = { cost: 0, tokens: 0 };
for (const d of daily) {
  for (const src of sources) {
    for (const b of d.bySource[src]) {
      const t = tokensOf(b);
      totals.cost += b.cost; totals.tokens += t;
      totals.inputTokens += b.inputTokens; totals.outputTokens += b.outputTokens;
      totals.cacheCreationTokens += b.cacheCreationTokens; totals.cacheReadTokens += b.cacheReadTokens;
      totals.bySource[src].cost += b.cost; totals.bySource[src].tokens += t;
    }
  }
}

// sessions (tagged by source) - used for the footer count; kept lightweight.
// ccusage 2.x returns { sessions:[{ sessionId, lastActivity, … }] }; older
// output used { session:[{ period, metadata.lastActivity }] } - accept both.
const mapSessions = (obj, src) =>
  (obj.sessions || obj.session || []).map((s) => ({
    id: s.sessionId || s.period,
    lastActivity: s.lastActivity || (s.metadata && s.metadata.lastActivity),
    totalCost: s.totalCost,
    totalTokens: s.totalTokens,
    models: s.modelsUsed,
    source: src,
  }));
const sessions = sources.flatMap((src) => mapSessions(sessionBySource[src] || {}, src));

// =====================================================================
// v3: per-project + per-hour drilldowns, derived from the raw transcripts
// (logic borrowed from ccusage-total.mjs: walkJsonl + derivePrices). Costs
// are derived from ccusage SESSION data so they reconcile with ccusage.
// =====================================================================

// --- per-model unit pricing (derive from session data, least squares) ---
const FALLBACK_PRICE_PER_MTOK = {
  // fable-5 sessions mix 5m- and 1h-TTL cache writes (priced 1.25x vs 2x input),
  // so the least-squares fit degenerates and this fallback is what actually prices it.
  "claude-fable-5": [10, 50, 12.5, 1],
  "claude-opus-4-8": [5, 25, 6.25, 0.5],
  "claude-opus-4-7": [5, 25, 6.25, 0.5],
  "claude-sonnet-4-6": [3, 15, 3.75, 0.3],
  "claude-haiku-4-5-20251001": [1, 5, 1.25, 0.1],
};

function leastSquares4(rows) {
  const M = [[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]];
  const v = [0, 0, 0, 0];
  for (const { x, y } of rows) {
    for (let i = 0; i < 4; i++) {
      v[i] += x[i] * y;
      for (let j = 0; j < 4; j++) M[i][j] += x[i] * x[j];
    }
  }
  const A = M.map((r, i) => [...r, v[i]]);
  for (let c = 0; c < 4; c++) {
    let piv = c;
    for (let r = c + 1; r < 4; r++)
      if (Math.abs(A[r][c]) > Math.abs(A[piv][c])) piv = r;
    [A[c], A[piv]] = [A[piv], A[c]];
    if (Math.abs(A[c][c]) < 1e-9) return null;
    for (let r = 0; r < 4; r++) {
      if (r === c) continue;
      const f = A[r][c] / A[c][c];
      for (let k = c; k <= 4; k++) A[r][k] -= f * A[c][k];
    }
  }
  return [0, 1, 2, 3].map((i) => A[i][4] / A[i][i]);
}

// Returns Map<model, {in,out,cw,cr}> as per-single-token prices.
function derivePrices(...sessionDatas) {
  const rowsByModel = new Map();
  for (const sessionData of sessionDatas) {
    for (const s of sessionData.sessions ?? sessionData.session ?? []) {
      for (const b of s.modelBreakdowns ?? []) {
        const arr = rowsByModel.get(b.modelName) ?? [];
        arr.push({
          x: [
            b.inputTokens || 0,
            b.outputTokens || 0,
            b.cacheCreationTokens || 0,
            b.cacheReadTokens || 0,
          ],
          y: b.cost || 0,
        });
        rowsByModel.set(b.modelName, arr);
      }
    }
  }
  const prices = new Map();
  for (const [model, rows] of rowsByModel) {
    let p = rows.length >= 4 ? leastSquares4(rows) : null;
    if (p) {
      let actual = 0, dev = 0;
      for (const { x, y } of rows) {
        const pred = x[0] * p[0] + x[1] * p[1] + x[2] * p[2] + x[3] * p[3];
        actual += y; dev += Math.abs(pred - y);
      }
      if (!(actual > 0 && dev / actual < 0.02)) p = null;
      if (p && p.some((z) => z < 0)) p = null;
    }
    if (!p) {
      const fb = FALLBACK_PRICE_PER_MTOK[model];
      p = fb ? fb.map((z) => z / 1e6) : null;
    }
    if (p) prices.set(model, { in: p[0], out: p[1], cw: p[2], cr: p[3] });
  }
  return prices;
}

function costOfTokens(prices, model, t) {
  const p = prices.get(model);
  if (!p) return 0;
  return t.input * p.in + t.output * p.out + t.cw * p.cw + t.cr * p.cr;
}

// --- raw transcript walking ---
function walkJsonl(dir) {
  const out = [];
  let entries;
  try { entries = readdirSync(dir, { withFileTypes: true }); } catch { return out; }
  // Sort by name so the walk order (and therefore dedup attribution at the
  // `seen` check below) is stable across runtimes - readdirSync order differs
  // between node and bun, which would otherwise shuffle per-chat token sums.
  entries.sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0));
  for (const e of entries) {
    const p = join(dir, e.name);
    if (e.isDirectory()) out.push(...walkJsonl(p));
    else if (e.name.endsWith(".jsonl")) out.push(p);
  }
  return out;
}

// Local YYYY-MM-DD (matches how ccusage labels daily periods).
function localDateStr(d) {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

const splitDirs = (s) => (s || "").split(",").map((x) => x.trim()).filter(Boolean);
// Only the Claude Code sources carry configDirs (their raw transcripts feed the
// v3 drilldown); other agents have none, so they contribute nothing to it.
const configDirsFor = {};
for (const entry of manifest) configDirsFor[entry.source] = splitDirs(entry.configDirs);

// --- map a transcript cwd to a stable project name --------------------
// A git worktree (e.g. <repo>/.claude/worktrees/<branch>) and any subdirectory
// of a repo (e.g. <repo>/apps/web/app) should all roll up under the repo's
// name rather than appearing as separate projects. We resolve each cwd to its
// git *main* repo root: `--git-common-dir` is shared by every linked worktree
// and points at the main repo's .git, so its parent is the main working tree
// regardless of which worktree or subdir the session ran in.
// Falls back to a path heuristic (for worktrees whose dir was since deleted,
// where git can no longer be queried) and finally to the cwd's own basename.
const WORKTREE_MARKERS = ["/.claude/worktrees/", "/.cursor/worktrees/"];
const projectNameCache = new Map();

function gitMainRepoRoot(cwd) {
  let commonDir;
  try {
    commonDir = execFileSync(
      "git",
      ["-C", cwd, "rev-parse", "--path-format=absolute", "--git-common-dir"],
      { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] },
    ).trim();
  } catch {
    return null; // not a git repo (or git unavailable)
  }
  if (!commonDir) return null;
  // commonDir is "<mainRepo>/.git" for normal repos, subdirs, and linked
  // worktrees alike, so its parent is the main working tree.
  if (commonDir.endsWith("/.git")) return dirname(commonDir);
  // bare/unusual layout: best-effort top-level
  try {
    return (
      execFileSync(
        "git",
        ["-C", cwd, "rev-parse", "--path-format=absolute", "--show-toplevel"],
        { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] },
      ).trim() || null
    );
  } catch {
    return null;
  }
}

function repoRootFromPath(cwd) {
  for (const m of WORKTREE_MARKERS) {
    const i = cwd.indexOf(m);
    if (i > 0) return cwd.slice(0, i);
  }
  return null;
}

function projectNameFromCwd(cwd) {
  if (!cwd) return "(unknown)";
  const cached = projectNameCache.get(cwd);
  if (cached !== undefined) return cached;
  // Cowork (local-agent mode) runs each chat in an ephemeral sandbox whose cwd is
  // .../local-agent-mode-sessions/<ids>/outputs. That dir is not a git repo, so the
  // basename fallback below would label every cowork chat "outputs". Collapse them
  // under a single readable "Cowork" project instead.
  let name;
  if (cwd.includes("/local-agent-mode-sessions/")) {
    name = "Cowork";
  } else {
    let root = existsSync(cwd) ? gitMainRepoRoot(cwd) : null;
    if (!root) root = repoRootFromPath(cwd);
    name = (root || cwd).split("/").filter(Boolean).pop() || "(unknown)";
  }
  projectNameCache.set(cwd, name);
  return name;
}

// If a cwd lives inside a git worktree we host under the repo (e.g.
// <repo>/.claude/worktrees/<name>), return that worktree's folder name;
// otherwise null (the chat ran in the repo's main checkout / a subdir of it).
function worktreeOf(cwd) {
  if (!cwd) return null;
  for (const m of WORKTREE_MARKERS) {
    const i = cwd.indexOf(m);
    if (i >= 0) return cwd.slice(i + m.length).split("/").filter(Boolean)[0] || null;
  }
  return null;
}

// First human-readable text block of a user message (used as a title fallback).
function userText(o) {
  const c = o.message?.content;
  if (typeof c === "string") return c.trim();
  if (Array.isArray(c)) {
    for (const b of c) if (b?.type === "text" && typeof b.text === "string") return b.text.trim();
  }
  return "";
}

// Walk all transcripts for the active sources and build, per local date:
//   projects: Map<projectName, { tokens, cost,
//                                main: Map<sessionId,{tokens,cost}>,
//                                worktrees: Map<name,{tokens,cost,chats:Map<sessionId,..>}> }>
//   hours:    [{tokens,cost} x24]   (local hour of the assistant message)
// Chats are keyed by sessionId; titles are resolved from `ai-title` lines (or the
// first user prompt) collected in the same pass. Assistant usage is deduped by
// message.id|requestId (the key ccusage uses).
function buildDrilldown(prices) {
  const byDate = new Map(); // date -> { projects: Map, hours: [...] }
  const seen = new Set();
  const titleBySession = new Map();     // sessionId -> aiTitle
  const firstTextBySession = new Map(); // sessionId -> first user prompt snippet
  // date -> Map<model, {input,output,cw,cr,cost,tokens}> for cloud (background) sessions
  // only - used downstream to split the cli source into local + Claude Code Cloud.
  const cloudByDateModel = new Map();
  const getDay = (date) => {
    let d = byDate.get(date);
    if (!d) {
      d = { projects: new Map(), hours: Array.from({ length: 24 }, () => ({ tokens: 0, cost: 0 })) };
      byDate.set(date, d);
    }
    return d;
  };
  const blankProj = () => ({ tokens: 0, cost: 0, main: new Map(), worktrees: new Map() });
  const blankChat = () => ({ tokens: 0, cost: 0, firstTs: 0, lastTs: 0, source: "" });

  for (const src of sources) {
    for (const cfg of configDirsFor[src] || []) {
      for (const file of walkJsonl(join(cfg, "projects"))) {
        let text;
        try { text = readFileSync(file, "utf8"); } catch { continue; }
        for (const line of text.split("\n")) {
          if (!line.trim()) continue;
          let o;
          try { o = JSON.parse(line); } catch { continue; }

          // Capture chat titles regardless of line type (one pass, all sources).
          if (o.type === "ai-title" && o.aiTitle && o.sessionId) {
            titleBySession.set(o.sessionId, String(o.aiTitle).trim());
            continue;
          }
          if (o.type === "user" && o.sessionId && !firstTextBySession.has(o.sessionId)) {
            const txt = userText(o);
            if (txt && !txt.startsWith("<")) firstTextBySession.set(o.sessionId, txt.slice(0, 80));
          }
          if (o.type !== "assistant") continue;

          const ts = o.timestamp;
          const u = o.message?.usage;
          if (!ts || !u) continue;
          const key = o.message?.id && o.requestId ? `${o.message.id}|${o.requestId}` : null;
          if (key) { if (seen.has(key)) continue; seen.add(key); }

          const dt = new Date(ts);
          const date = localDateStr(dt);
          const hour = dt.getHours();
          const model = o.message?.model ?? "unknown";
          const t = {
            input: u.input_tokens || 0,
            output: u.output_tokens || 0,
            cw: u.cache_creation_input_tokens || 0,
            cr: u.cache_read_input_tokens || 0,
          };
          const tokens = t.input + t.output + t.cw + t.cr;
          const cost = costOfTokens(prices, model, t);

          const projectName = projectNameFromCwd(o.cwd);
          const wt = worktreeOf(o.cwd);
          const sid = o.sessionId || "(no-session)";

          // Cloud (background/remote) sessions: accumulate per day/model so we can
          // carve them out of the cli source as "Claude Code Cloud" below. Uses the
          // same deduped turn + derived cost as the cli drilldown, so the carve-out
          // reconciles with cli.
          if (cloudIds.has(sid)) {
            let cm = cloudByDateModel.get(date);
            if (!cm) cloudByDateModel.set(date, (cm = new Map()));
            let agg = cm.get(model);
            if (!agg) cm.set(model, (agg = { input: 0, output: 0, cw: 0, cr: 0, cost: 0, tokens: 0 }));
            agg.input += t.input; agg.output += t.output; agg.cw += t.cw; agg.cr += t.cr;
            agg.cost += cost; agg.tokens += tokens;
          }

          const day = getDay(date);

          const p = day.projects.get(projectName) ?? blankProj();
          p.tokens += tokens; p.cost += cost;
          let chats;
          if (wt) {
            const w = p.worktrees.get(wt) ?? { tokens: 0, cost: 0, chats: new Map() };
            w.tokens += tokens; w.cost += cost;
            p.worktrees.set(wt, w);
            chats = w.chats;
          } else {
            chats = p.main;
          }
          const c = chats.get(sid) ?? blankChat();
          c.tokens += tokens; c.cost += cost;
          // Source of this chat = its config-dir source (cli/cowork), or cc-cloud
          // when it's a background/remote session. Lets the dashboard filter the
          // project tree by source. A session is entirely one source, so this is
          // stable across the chat's turns.
          c.source = cloudIds.has(sid) ? CLOUD_SOURCE : src;
          // first/last activity for this chat fragment (this day). Time-spent is
          // derived downstream as last-first; fragments are merged by session id
          // in the dashboard so a chat spanning midnight gets its true span.
          const tms = dt.getTime();
          if (!c.firstTs || tms < c.firstTs) c.firstTs = tms;
          if (tms > c.lastTs) c.lastTs = tms;
          chats.set(sid, c);
          day.projects.set(projectName, p);

          day.hours[hour].tokens += tokens;
          day.hours[hour].cost += cost;
        }
      }
    }
  }

  // Merge a session's fragments (main checkout + worktrees of the same project,
  // same day) into one chat row under the location with most of its tokens.
  // A chat that cd's into a worktree seconds after starting otherwise leaves a
  // near-empty stub row in the main checkout with the same title as the real one.
  for (const day of byDate.values()) {
    for (const p of day.projects.values()) {
      const locs = [{ chats: p.main, wt: null }];
      for (const w of p.worktrees.values()) locs.push({ chats: w.chats, wt: w });
      const bySid = new Map(); // sid -> [{loc, c}] across locations
      for (const loc of locs) {
        for (const [sid, c] of loc.chats) {
          if (sid === "(no-session)") continue;
          const arr = bySid.get(sid) ?? [];
          arr.push({ loc, c });
          bySid.set(sid, arr);
        }
      }
      for (const [sid, frags] of bySid) {
        if (frags.length < 2) continue;
        let winner = frags[0];
        for (const f of frags) if (f.c.tokens > winner.c.tokens) winner = f;
        for (const f of frags) {
          if (f === winner) continue;
          winner.c.tokens += f.c.tokens;
          winner.c.cost += f.c.cost;
          if (f.c.firstTs && (!winner.c.firstTs || f.c.firstTs < winner.c.firstTs)) winner.c.firstTs = f.c.firstTs;
          if (f.c.lastTs > winner.c.lastTs) winner.c.lastTs = f.c.lastTs;
          f.loc.chats.delete(sid);
          // keep each container's aggregate equal to the sum of its chats
          if (f.loc.wt) { f.loc.wt.tokens -= f.c.tokens; f.loc.wt.cost -= f.c.cost; }
          if (winner.loc.wt) { winner.loc.wt.tokens += f.c.tokens; winner.loc.wt.cost += f.c.cost; }
        }
      }
      for (const [name, w] of [...p.worktrees]) {
        if (!w.chats.size && w.tokens <= 0) p.worktrees.delete(name);
      }
    }
  }

  // Attach a title resolver so the emit step can name chats consistently.
  byDate.titleFor = (id) =>
    titleBySession.get(id) ||
    firstTextBySession.get(id) ||
    (id && id !== "(no-session)" ? `Chat ${id.slice(0, 8)}` : "Untitled chat");
  byDate.cloudByDateModel = cloudByDateModel;
  return byDate;
}

let drilldownAvailable = false;
if (Object.values(configDirsFor).some((a) => a.length)) {
  try {
    const prices = derivePrices(...Object.values(sessionBySource));
    const dd = buildDrilldown(prices);
    // All sorts carry a stable id/name tie-breaker so equal-token entries keep
    // a deterministic order regardless of JS runtime / Map iteration order.
    const chatList = (m) =>
      [...m.entries()]
        .map(([id, v]) => ({ id, title: dd.titleFor(id), tokens: v.tokens, cost: v.cost, firstTs: v.firstTs || 0, lastTs: v.lastTs || 0, source: v.source || "" }))
        .sort((a, b) => b.tokens - a.tokens || a.id.localeCompare(b.id));
    for (const d of daily) {
      const day = dd.get(d.period);
      if (day) {
        d.projects = [...day.projects.entries()]
          .map(([projectName, v]) => ({
            projectName, tokens: v.tokens, cost: v.cost,
            chats: chatList(v.main),
            worktrees: [...v.worktrees.entries()]
              .map(([name, w]) => ({ name, tokens: w.tokens, cost: w.cost, chats: chatList(w.chats) }))
              .sort((a, b) => b.tokens - a.tokens || a.name.localeCompare(b.name)),
          }))
          .sort((a, b) => b.tokens - a.tokens || a.projectName.localeCompare(b.projectName));
        d.hours = day.hours.map((h) => ({ tokens: h.tokens, cost: h.cost }));
      } else {
        d.projects = [];
        d.hours = Array.from({ length: 24 }, () => ({ tokens: 0, cost: 0 }));
      }
    }

    // --- split cli into local "cli" + "cc-cloud" (Claude Code Cloud) ----------
    // Re-partition each day/model: cc-cloud gets the transcript-derived cloud
    // usage (capped at the cli amount), cli keeps the remainder. cli + cc-cloud
    // therefore equals the original cli exactly, so the Claude Code grand total
    // is unchanged - only the local/cloud split point is approximate (the cap
    // keeps cli ≥ 0 and the total exact).
    // ponytail: capped derived-price split; exact only if ccusage ever exposes
    // per-session daily breakdowns.
    const cbm = dd.cloudByDateModel;
    let splitAny = false;
    if (cloudIds.size && cbm && cbm.size) {
      for (const d of daily) {
        const cm = cbm.get(d.period);
        if (!cm || !cm.size) continue;
        const cli = d.bySource.cli || [];
        const cloudBreakdowns = [];
        for (const [model, agg] of cm) {
          const b = cli.find((x) => x.modelName === model);
          const cIn = b ? Math.min(agg.input, b.inputTokens) : agg.input;
          const cOut = b ? Math.min(agg.output, b.outputTokens) : agg.output;
          const cCw = b ? Math.min(agg.cw, b.cacheCreationTokens) : agg.cw;
          const cCr = b ? Math.min(agg.cr, b.cacheReadTokens) : agg.cr;
          const cCost = b ? Math.min(agg.cost, b.cost) : agg.cost;
          if (cIn + cOut + cCw + cCr <= 0 && cCost <= 0) continue;
          cloudBreakdowns.push({ modelName: model, inputTokens: cIn, outputTokens: cOut, cacheCreationTokens: cCw, cacheReadTokens: cCr, cost: cCost });
          if (b) {
            b.inputTokens -= cIn; b.outputTokens -= cOut;
            b.cacheCreationTokens -= cCw; b.cacheReadTokens -= cCr;
            b.cost -= cCost;
          }
        }
        if (cloudBreakdowns.length) { d.bySource[CLOUD_SOURCE] = cloudBreakdowns; splitAny = true; }
      }
    }
    if (splitAny) {
      sources.splice(1, 0, CLOUD_SOURCE); // right after cli
      for (const d of daily) d.bySource[CLOUD_SOURCE] ||= [];
      // recompute totals (combined unchanged; per-source now includes cc-cloud)
      const t2 = blank(); t2.bySource = {};
      for (const src of sources) t2.bySource[src] = { cost: 0, tokens: 0 };
      for (const d of daily) for (const src of sources) for (const b of d.bySource[src]) {
        const tk = tokensOf(b);
        t2.cost += b.cost; t2.tokens += tk;
        t2.inputTokens += b.inputTokens; t2.outputTokens += b.outputTokens;
        t2.cacheCreationTokens += b.cacheCreationTokens; t2.cacheReadTokens += b.cacheReadTokens;
        t2.bySource[src].cost += b.cost; t2.bySource[src].tokens += tk;
      }
      Object.assign(totals, t2);
      // re-tag cloud sessions in the lightweight sessions list
      for (const s of sessions) if (s.source === "cli" && cloudIds.has(s.id)) s.source = CLOUD_SOURCE;
    }

    drilldownAvailable = true;
  } catch (e) {
    console.error("warning: failed to build v3 drilldown (projects/hours):", e.message);
  }
}

const payload = {
  schemaVersion: drilldownAvailable ? 4 : 2,
  generatedAt: new Date().toISOString(),
  sources, totals, daily, sessions,
  // per-source label + tool grouping, and the dashboard's first-load filter
  // (the Claude Code tool only - falls back to all sources if none qualify).
  sourceMeta: Object.fromEntries(sources.map((s) => [s, metaFor(s)])),
  defaultSources: claudeCodeSources(sources).length ? claudeCodeSources(sources) : sources,
};

// 1. historical data file
mkdirSync(resolve(here, "data"), { recursive: true });
writeFileSync(resolve(here, "data", "usage.json"), JSON.stringify(payload, null, 2) + "\n");

// 2. inline into dashboard.html (regex-match the data blocks - contract)
const htmlPath = resolve(here, "dashboard.html");
let html = readFileSync(htmlPath, "utf8");
const safe = JSON.stringify(payload).replace(/<\/script>/g, "<\\/script>");
const re = /(<script id="usage-data" type="application\/json">)([\s\S]*?)(<\/script>)/;
if (!re.test(html)) {
  console.error('ERROR: could not find <script id="usage-data"> block in dashboard.html');
  process.exit(1);
}
html = html.replace(re, `$1\n${safe}\n$3`);

// limits history (written by the Edith app; may not exist yet)
const limitsPath = resolve(here, "data", "limits-history.jsonl");
let limitsPayload = { points: [] };
if (existsSync(limitsPath)) {
  const rows = parseLimitsJSONL(readFileSync(limitsPath, "utf8"));
  limitsPayload = { points: downsampleLimits(rows, Date.now()) };
}
const reL = /(<script id="limits-data" type="application\/json">)([\s\S]*?)(<\/script>)/;
if (reL.test(html)) {
  const safeL = JSON.stringify(limitsPayload).replace(/<\/script>/g, "<\\/script>");
  html = html.replace(reL, `$1\n${safeL}\n$3`);
} else {
  console.error('warning: no <script id="limits-data"> block (rebuild dashboard.html with bun build.mjs)');
}
writeFileSync(htmlPath, html);

const bs = sources.map((s) => `${s} $${totals.bySource[s].cost.toFixed(2)}`).join(" · ");
console.log(`rendered: schema v${payload.schemaVersion} · ${daily.length} days, ${sessions.length} sessions · ${bs} · $${totals.cost.toFixed(2)} total`);
