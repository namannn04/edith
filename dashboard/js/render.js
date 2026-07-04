import {
  fmtUSD,
  fmtUSDfull,
  fmtTok,
  fmtTokFull,
  fmtPct,
  fmtDur,
  shortModel,
  parseDate,
  ymd,
  fmtDate,
  DOW,
} from "./format.js";
import {
  RAW,
  DAILY,
  SESSIONS,
  sourceLabel,
  SOURCES,
  ALL_MODELS,
  EARLIEST,
  LATEST,
} from "./data.js";
import {
  sourceColor,
  OTHER_COLOR,
  TOKEN_COLORS,
  MODEL_COLOR,
} from "./palette.js";
import { state, charts } from "./state.js";
import {
  dayBreakdowns,
  tokensOf,
  inRangeDays,
  derive,
  deriveBySource,
  activeWindow,
} from "./compute.js";
import {
  GRIDC,
  CARD_BG,
  TICKC,
  COSTC,
  readThemeColors,
  dualScales,
  sizeChartInner,
  autoScrollRight,
  mount,
  baseTooltip,
} from "./charts.js";

// Recolor EXISTING chart instances from current CSS vars and update without
// animation - used on theme toggle so charts don't rebuild/recompute.
export function liveRetheme() {
  readThemeColors();
  Object.values(charts).forEach((ch) => {
    if (!ch || !ch.options) return;
    const o = ch.options;
    if (o.scales)
      for (const k of Object.keys(o.scales)) {
        const sc = o.scales[k];
        if (
          sc.grid &&
          sc.grid.drawOnChartArea !== false &&
          sc.grid.display !== false
        )
          sc.grid.color = GRIDC;
        if (sc.ticks) sc.ticks.color = TICKC;
      }
    // datasets whose colors derive from theme CSS vars
    ch.data.datasets.forEach((d) => {
      if (ch.config.type === "doughnut") {
        d.borderColor = CARD_BG;
        return;
      }
      if (d._costLine) d.borderColor = COSTC;
      if (d._modelColors)
        d.backgroundColor = d._modelColors.map(
          (m) => MODEL_COLOR[m] || OTHER_COLOR,
        );
      if (d._tokenKey) d.backgroundColor = TOKEN_COLORS[d._tokenKey];
      if (d._srcKey) d.backgroundColor = sourceColor(d._srcKey);
      if (d._accentBar) d.backgroundColor = "rgba(217,119,87,.55)";
    });
    ch.update("none");
  });
  renderHeat(); // DOM heatmap text colors are JS-driven; cheap re-render (no Chart.js)
}

// ============ HEADER / META ============
export function renderMeta() {
  const t = RAW.totals || {};
  const tCost = t.cost ?? t.totalCost,
    tTok = t.tokens ?? t.totalTokens;
  const first = DAILY[0]?.period,
    last = DAILY[DAILY.length - 1]?.period;
  const gen = RAW.generatedAt ? new Date(RAW.generatedAt) : null;
  const genStr = gen
    ? gen.toLocaleString("en-US", {
        month: "short",
        day: "numeric",
        hour: "numeric",
        minute: "2-digit",
      })
    : "-";
  const srcStr = SOURCES.map(sourceLabel).join(" + ");
  document.getElementById("meta-row").innerHTML =
    `Updated <b>${genStr}</b>` +
    ` · <b class="num">${fmtUSDfull(tCost)}</b> across <b>${DAILY.length}</b> active days` +
    ` · <b class="num">${fmtTok(tTok)}</b> tokens` +
    ` · ${ALL_MODELS.length} models · ${srcStr} · window <b>${first}</b> → <b>${last}</b>`;
  document.getElementById("foot-left").textContent =
    `schema v${RAW.schemaVersion || 1} · ${SESSIONS.length} sessions · ${DAILY.length} days`;
}

// ============ KPI CARDS ============
function renderKPIs() {
  const rows = derive();
  const totalCost = rows.reduce((a, r) => a + r.cost, 0);
  const totalTok = rows.reduce((a, r) => a + r.tokens, 0);
  const nDays = rows.length || 1;
  const avg = totalCost / nDays;
  const totIn = rows.reduce((a, r) => a + r.input, 0);
  const totRead = rows.reduce((a, r) => a + r.cacheRead, 0);
  const cacheRate = totRead + totIn ? totRead / (totRead + totIn) : 0;
  // most-used model + per-source cost (by $), within current source/model/range filters
  const mcost = {};
  const srcCost = {};
  SOURCES.forEach((s) => (srcCost[s] = 0));
  inRangeDays().forEach((d) =>
    SOURCES.forEach((s) => {
      if (!state.sources.has(s)) return;
      (d.bySource[s] || []).forEach((b) => {
        if (!state.models.has(b.modelName)) return;
        mcost[b.modelName] = (mcost[b.modelName] || 0) + (+b.cost || 0);
        srcCost[s] += +b.cost || 0;
      });
    }),
  );
  const topModel = Object.keys(mcost).sort((a, b) => mcost[b] - mcost[a])[0];
  // busiest day = most TOKENS (ignore zero-filled days)
  const active = rows.filter((r) => r.tokens > 0);
  const activeDays = active.length || 1;
  let big = active[0] || { date: "-", cost: 0, tokens: 0 };
  active.forEach((r) => {
    if (r.tokens > big.tokens) big = r;
  });
  // month to date - based on the latest month present in full data
  const ym = ymd(LATEST).slice(0, 7);
  let mtdCost = 0,
    mtdTok = 0;
  DAILY.forEach((d) => {
    if (d.period.slice(0, 7) === ym) {
      for (const s of SOURCES)
        for (const b of d.bySource[s] || []) {
          mtdCost += +b.cost || 0;
          mtdTok += tokensOf(b);
        }
    }
  });

  const cards = [
    {
      l: "Total tokens",
      v: fmtTok(totalTok),
      s: `${fmtUSDfull(totalCost)} · ${activeDays} active day${activeDays === 1 ? "" : "s"}`,
      hot: true,
    },
    {
      l: "Total cost",
      v: fmtUSDfull(totalCost),
      s: `${fmtTokFull(totalTok)} tokens`,
    },
    {
      l: "Busiest day",
      v: big.date === "-" ? "-" : big.date.slice(5),
      s: big.date === "-" ? "" : `${fmtTok(big.tokens)} · ${fmtUSD(big.cost)}`,
    },
    {
      l: "Daily average",
      v: fmtTok(totalTok / activeDays),
      s: `${fmtUSD(totalCost / activeDays)} / active day`,
    },
    {
      l: `Month to date (${ym})`,
      v: fmtUSD(mtdCost),
      s: `${fmtTok(mtdTok)} tokens`,
    },
    {
      l: "Cache hit rate",
      v: fmtPct(cacheRate),
      s: `${fmtTok(totRead)} read vs ${fmtTok(totIn)} fresh`,
    },
    {
      l: "Top model",
      v: shortModel(topModel) || "-",
      s: `${fmtUSD(mcost[topModel] || 0)} of spend`,
    },
  ];
  // Cowork-share KPI only when Cowork data exists
  if (SOURCES.includes("cowork")) {
    const cw = srcCost.cowork || 0,
      tot = SOURCES.reduce((a, s) => a + (srcCost[s] || 0), 0) || 1;
    cards.push({
      l: "Cowork share",
      v: fmtPct(cw / tot),
      s: `${fmtUSD(cw)} of ${fmtUSD(tot)} spend`,
    });
  }
  document.getElementById("kpis").innerHTML = cards
    .map(
      (c) =>
        `<div class="kpi ${c.hot ? "hot" : ""}">
         <div class="k-label">${c.l}</div>
         <div class="k-val num">${c.v}</div>
         <div class="k-sub">${c.s}</div>
       </div>`,
    )
    .join("");
}

// dual-axis tooltip label: cost datasets (y1) show $, token datasets show tokens
const dualLabel = (c) =>
  c.dataset.yAxisID === "y1"
    ? ` ${c.dataset.label}: ${fmtUSDfull(c.parsed.y)}`
    : ` ${c.dataset.label}: ${fmtTokFull(c.parsed.y)}`;

// ============ DAILY USAGE (dual axis) ============
function renderDaily() {
  const rows = derive();
  const labels = rows.map((r) => r.date.slice(5));
  const toks = rows.map((r) => r.tokens);
  const costs = rows.map((r) => r.cost);
  sizeChartInner("scroll-daily", rows.length);
  mount("c-daily", {
    data: {
      labels,
      datasets: [
        {
          type: "bar",
          label: "Tokens",
          data: toks,
          yAxisID: "y",
          _accentBar: true,
          backgroundColor: "rgba(217,119,87,.55)",
          borderColor: "#d97757",
          borderWidth: 1,
          borderRadius: 3,
          order: 3,
        },
        {
          type: "line",
          label: "Cost",
          data: costs,
          yAxisID: "y1",
          _costLine: true,
          borderColor: COSTC,
          borderWidth: 2,
          pointRadius: 0,
          tension: 0.35,
          order: 1,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      interaction: { mode: "index", intersect: false },
      plugins: {
        legend: {
          display: true,
          position: "top",
          align: "end",
          labels: { boxWidth: 10, boxHeight: 10, usePointStyle: true },
        },
        tooltip: { ...baseTooltip, callbacks: { label: dualLabel } },
      },
      scales: dualScales(false),
    },
  });
  autoScrollRight("scroll-daily");
}

// ============ DONUT: token share by model (tooltip shows tokens% + cost) ============
function renderDonut() {
  const rows = derive();
  const agg = {};
  rows.forEach((r) =>
    Object.entries(r.byModel).forEach(([m, v]) => {
      const a = agg[m] || (agg[m] = { cost: 0, tokens: 0 });
      a.cost += v.cost;
      a.tokens += v.tokens;
    }),
  );
  const entries = Object.entries(agg).sort((a, b) => b[1].tokens - a[1].tokens);
  const modelNames = entries.map(([m]) => m);
  const labels = entries.map(([m]) => shortModel(m));
  const data = entries.map(([, v]) => v.tokens);
  const costData = entries.map(([, v]) => v.cost);
  const colors = entries.map(([m]) => MODEL_COLOR[m] || OTHER_COLOR);
  const total = data.reduce((a, b) => a + b, 0) || 1;
  document.getElementById("t-donut").textContent = "Share by model";
  mount("c-donut", {
    type: "doughnut",
    data: {
      labels,
      datasets: [
        {
          data,
          _cost: costData,
          _modelColors: modelNames,
          backgroundColor: colors,
          borderColor: CARD_BG,
          borderWidth: 2,
          hoverOffset: 6,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      cutout: "62%",
      plugins: {
        legend: {
          position: "bottom",
          labels: {
            boxWidth: 10,
            boxHeight: 10,
            usePointStyle: true,
            padding: 12,
          },
        },
        tooltip: {
          ...baseTooltip,
          callbacks: {
            label: (c) =>
              ` ${c.label}: ${fmtTokFull(c.parsed)} (${fmtPct(c.parsed / total)}) · ${fmtUSDfull(c.dataset._cost[c.dataIndex] || 0)}`,
          },
        },
      },
    },
  });
}

// ============ TOKEN MIX STACKED (+ cost line on right axis) ============
function renderTokens() {
  const rows = derive();
  const labels = rows.map((r) => r.date.slice(5));
  const ds = [
    { key: "input", label: "Input" },
    { key: "output", label: "Output" },
    { key: "cacheCreate", label: "Cache write" },
    { key: "cacheRead", label: "Cache read" },
  ].map((k) => ({
    type: "bar",
    label: k.label,
    data: rows.map((r) => r[k.key]),
    yAxisID: "y",
    _tokenKey: k.key,
    backgroundColor: TOKEN_COLORS[k.key],
    borderWidth: 0,
    stack: "t",
  }));
  ds.push({
    type: "line",
    label: "Cost",
    data: rows.map((r) => r.cost),
    yAxisID: "y1",
    _costLine: true,
    borderColor: COSTC,
    borderWidth: 2,
    pointRadius: 0,
    tension: 0.35,
  });
  sizeChartInner("scroll-tokens", rows.length);
  mount("c-tokens", {
    type: "bar",
    data: { labels, datasets: ds },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      interaction: { mode: "index", intersect: false },
      plugins: {
        legend: {
          position: "top",
          align: "end",
          labels: { boxWidth: 10, boxHeight: 10, usePointStyle: true },
        },
        tooltip: {
          ...baseTooltip,
          callbacks: {
            label: dualLabel,
            footer: (items) => {
              const tk = items
                .filter((i) => i.dataset.yAxisID !== "y1")
                .reduce((a, b) => a + b.parsed.y, 0);
              return "Σ " + fmtTokFull(tk);
            },
          },
        },
      },
      scales: dualScales(true),
    },
  });
  autoScrollRight("scroll-tokens");
}

// ============ MODEL USAGE OVER TIME (stacked tokens + cost line) ============
function renderModelTime() {
  const rows = derive();
  const labels = rows.map((r) => r.date.slice(5));
  const active = ALL_MODELS.filter((m) => state.models.has(m));
  const ds = active.map((m) => ({
    type: "bar",
    label: shortModel(m),
    data: rows.map((r) => (r.byModel[m] ? r.byModel[m].tokens : 0)),
    yAxisID: "y",
    _modelColors: [m],
    backgroundColor: MODEL_COLOR[m],
    borderWidth: 0,
    stack: "m",
  }));
  ds.push({
    type: "line",
    label: "Cost",
    data: rows.map((r) => r.cost),
    yAxisID: "y1",
    _costLine: true,
    borderColor: COSTC,
    borderWidth: 2,
    pointRadius: 0,
    tension: 0.35,
  });
  document.getElementById("t-model-time").textContent = "Model usage over time";
  sizeChartInner("scroll-modeltime", rows.length);
  mount("c-modeltime", {
    type: "bar",
    data: { labels, datasets: ds },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      interaction: { mode: "index", intersect: false },
      plugins: {
        legend: {
          position: "top",
          align: "end",
          labels: { boxWidth: 10, boxHeight: 10, usePointStyle: true },
        },
        tooltip: { ...baseTooltip, callbacks: { label: dualLabel } },
      },
      scales: dualScales(true),
    },
  });
  autoScrollRight("scroll-modeltime");
}

// ============ DAY OF WEEK (TOTAL tokens + total cost, dual axis) ============
function renderDOW() {
  const rows = derive();
  const tok = [0, 0, 0, 0, 0, 0, 0],
    cost = [0, 0, 0, 0, 0, 0, 0],
    cnt = [0, 0, 0, 0, 0, 0, 0];
  rows.forEach((r) => {
    const w = parseDate(r.date).getDay();
    tok[w] += r.tokens;
    cost[w] += r.cost;
    if (r.tokens > 0) cnt[w]++;
  });
  document.getElementById("t-dow").textContent = "By day of week";
  mount("c-dow", {
    data: {
      labels: DOW,
      datasets: [
        {
          type: "bar",
          label: "Tokens",
          data: tok,
          yAxisID: "y",
          _accentBar: true,
          backgroundColor: "rgba(217,119,87,.55)",
          borderColor: "#d97757",
          borderWidth: 1,
          borderRadius: 4,
        },
        {
          type: "line",
          label: "Cost",
          data: cost,
          yAxisID: "y1",
          _costLine: true,
          borderColor: COSTC,
          borderWidth: 2,
          pointRadius: 3,
          tension: 0.3,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      interaction: { mode: "index", intersect: false },
      plugins: {
        legend: {
          position: "top",
          align: "end",
          labels: { boxWidth: 10, boxHeight: 10, usePointStyle: true },
        },
        tooltip: {
          ...baseTooltip,
          callbacks: {
            label: dualLabel,
            afterBody: (items) => {
              const i = items[0].dataIndex;
              return `${cnt[i]} active day${cnt[i] === 1 ? "" : "s"}`;
            },
          },
        },
      },
      scales: {
        x: { grid: { display: false } },
        y: {
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
      },
    },
  });
}

// ============ CALENDAR HEATMAP ============
// full per-day breakdown across selected sources × models (metric-independent)
function heatDayDetail(d) {
  const sources = {},
    models = {};
  let cost = 0,
    input = 0,
    output = 0,
    cc = 0,
    cr = 0;
  for (const s of SOURCES) {
    if (!state.sources.has(s)) continue;
    for (const b of d.bySource[s] || []) {
      if (!state.models.has(b.modelName)) continue;
      const c = +b.cost || 0,
        t = tokensOf(b);
      cost += c;
      input += +b.inputTokens || 0;
      output += +b.outputTokens || 0;
      cc += +b.cacheCreationTokens || 0;
      cr += +b.cacheReadTokens || 0;
      models[b.modelName] ||= { cost: 0, tokens: 0 };
      models[b.modelName].cost += c;
      models[b.modelName].tokens += t;
      sources[s] ||= { cost: 0, tokens: 0 };
      sources[s].cost += c;
      sources[s].tokens += t;
    }
  }
  // Project / chat / hour rollups are NOT split by model or source in the data,
  // so they reflect the whole day regardless of the source/model filters above.
  const projects = [];
  let chatCount = 0;
  for (const p of d.projects || []) {
    const ptok = +p.tokens || 0,
      pcost = +p.cost || 0;
    if (ptok <= 0 && pcost <= 0) continue;
    let pchats = (p.chats || []).length;
    for (const w of p.worktrees || []) pchats += (w.chats || []).length;
    chatCount += pchats;
    projects.push({
      name: p.projectName || "(unknown)",
      tokens: ptok,
      cost: pcost,
      chats: pchats,
    });
  }
  projects.sort((a, b) => b.tokens - a.tokens);
  // busiest hour of the day (index into the 24-slot hours array)
  let peakHour = -1,
    peakTok = 0;
  (d.hours || []).forEach((h, i) => {
    const t = +h.tokens || 0;
    if (t > peakTok) {
      peakTok = t;
      peakHour = i;
    }
  });
  return {
    cost,
    tokens: input + output + cc + cr,
    input,
    output,
    cc,
    cr,
    models,
    sources,
    projects,
    chatCount,
    projCount: projects.length,
    peakHour,
    peakTok,
  };
}
// deterministic warm-ish dot color per project name (no semantic palette exists
// for projects, so hash the name into a stable hue that reads in both themes).
function projDot(name) {
  let h = 0;
  for (let i = 0; i < name.length; i++) h = (h * 31 + name.charCodeAt(i)) | 0;
  return `hsl(${((h % 360) + 360) % 360} 48% 60%)`;
}
const fmtHour = (h) => (h < 0 ? "" : `${h % 12 || 12} ${h < 12 ? "AM" : "PM"}`);
const PROJ_TIP_CAP = 4; // top projects shown in the calendar tooltip
function heatTipHTML(key, det) {
  const head = parseDate(key).toLocaleDateString("en-US", {
    weekday: "short",
    month: "short",
    day: "numeric",
    year: "numeric",
  });
  if (!det || (det.cost === 0 && det.tokens === 0))
    return `<div class="ht-head">${head}</div><div class="ht-empty">no activity</div>`;
  const row = (l, v) =>
    `<div class="ht-row"><span>${l}</span><span class="num">${v}</span></div>`;
  const tag = (color, label, val) =>
    `<div class="ht-row"><span class="ht-tag"><i style="background:${color}"></i>${label}</span><span class="num">${val}</span></div>`;
  const models = Object.entries(det.models)
    .sort((a, b) => b[1].cost - a[1].cost)
    .map(([m, x]) =>
      tag(
        MODEL_COLOR[m] || OTHER_COLOR,
        shortModel(m),
        `${fmtUSD(x.cost)} · ${fmtTok(x.tokens)}`,
      ),
    )
    .join("");
  const srcs =
    SOURCES.length > 1
      ? Object.entries(det.sources)
          .sort((a, b) => b[1].cost - a[1].cost)
          .map(([s, x]) =>
            tag(
              sourceColor(s),
              sourceLabel(s),
              `${fmtUSD(x.cost)} · ${fmtTok(x.tokens)}`,
            ),
          )
          .join("")
      : "";
  // top projects for the day (capped), with the rest lumped into "+N more"
  const projTop = det.projects.slice(0, PROJ_TIP_CAP),
    projRest = det.projects.slice(PROJ_TIP_CAP);
  let projHTML = projTop
    .map((p) =>
      tag(
        projDot(p.name),
        escHtml(p.name),
        `${fmtUSD(p.cost)} · ${fmtTok(p.tokens)}`,
      ),
    )
    .join("");
  if (projRest.length) {
    const tk = projRest.reduce((a, b) => a + b.tokens, 0),
      ct = projRest.reduce((a, b) => a + b.cost, 0);
    projHTML += tag(
      OTHER_COLOR,
      `+${projRest.length} more`,
      `${fmtUSD(ct)} · ${fmtTok(tk)}`,
    );
  }
  // quick insights chips: how many projects / chats touched, and the peak hour
  const chips = [];
  if (det.projCount)
    chips.push(`${det.projCount} project${det.projCount > 1 ? "s" : ""}`);
  if (det.chatCount)
    chips.push(`${det.chatCount} chat${det.chatCount > 1 ? "s" : ""}`);
  if (det.peakHour >= 0)
    chips.push(`peak ${fmtHour(det.peakHour)} · ${fmtTok(det.peakTok)}`);
  const insights = chips.length
    ? `<div class="ht-insights">${chips.map((c) => `<span>${c}</span>`).join("")}</div>`
    : "";
  return `
      <div class="ht-head">${head}</div>
      <div class="ht-big num">${fmtTokFull(det.tokens)} tokens · ${fmtUSDfull(det.cost)}</div>
      ${insights}
      <div class="ht-sec">
        ${row("Input", fmtTok(det.input))}${row("Output", fmtTok(det.output))}
        ${row("Cache write", fmtTok(det.cc))}${row("Cache read", fmtTok(det.cr))}
      </div>
      <div class="ht-sec">${models}</div>
      ${srcs ? `<div class="ht-sec">${srcs}</div>` : ""}
      ${projHTML ? `<div class="ht-sec"><div class="ht-lbl">Projects</div>${projHTML}</div>` : ""}`;
}

// Activity-calendar metric: "tokens" (default) or "cost". Transient UI state -
// intentionally NOT synced to the URL (unlike the top filters).
let heatMetric = "tokens";
export function setHeatMetric(m) {
  heatMetric = m === "cost" ? "cost" : "tokens";
  renderHeat();
}

let _heatTip,
  _heatWired = false,
  _heatHTML = {};
function wireHeat() {
  if (_heatWired) return;
  _heatWired = true;
  _heatTip = document.createElement("div");
  _heatTip.className = "heat-tip";
  _heatTip.hidden = true;
  document.body.appendChild(_heatTip);
  const heat = document.getElementById("heat");
  const place = (e) => {
    const pad = 14,
      w = _heatTip.offsetWidth,
      h = _heatTip.offsetHeight;
    let x = e.clientX + pad,
      y = e.clientY + pad;
    if (x + w > innerWidth) x = e.clientX - w - pad;
    if (y + h > innerHeight) y = e.clientY - h - pad;
    // clamp to the viewport on every side so the tip is never clipped
    x = Math.max(4, Math.min(x, innerWidth - w - 4));
    y = Math.max(4, Math.min(y, innerHeight - h - 4));
    _heatTip.style.left = x + "px";
    _heatTip.style.top = y + "px";
  };
  heat.addEventListener("mouseover", (e) => {
    // Dateless cells (week-padding / future days) carry no tooltip - hide any
    // open tip instead of leaving the previous day's tip stuck to the cursor.
    const cell = e.target.closest(".cell");
    if (!cell || !cell.dataset.date) {
      _heatTip.hidden = true;
      return;
    }
    _heatTip.innerHTML = _heatHTML[cell.dataset.date] || "";
    _heatTip.hidden = false;
    place(e);
  });
  heat.addEventListener("mousemove", (e) => {
    if (!_heatTip.hidden) place(e);
  });
  heat.addEventListener("mouseleave", () => {
    _heatTip.hidden = true;
  });
}

function renderHeat() {
  wireHeat();
  readThemeColors();
  // Metric is toggled by the calendar's own dropdown (transient, not URL-synced).
  const isCost = heatMetric === "cost";
  const metricOf = (det) => (isCost ? det.cost : det.tokens);
  document.getElementById("t-heat").textContent =
    "Activity calendar - " + (isCost ? "cost" : "tokens");
  // Follow the active range filter (clamped to data bounds), like the table/charts.
  // 'all' still spans the full history. Day values respect the source/model filters.
  const detail = {},
    valByDate = {};
  DAILY.forEach((d) => {
    const det = heatDayDetail(d);
    detail[d.period] = det;
    valByDate[d.period] = metricOf(det);
  });
  const w = activeWindow();
  const winFrom = new Date(Math.max(w.from.getTime(), EARLIEST.getTime()));
  const winTo = new Date(Math.min(w.to.getTime(), LATEST.getTime()));
  // Intensity ramp scales to the busiest day WITHIN the window, so a narrow
  // filter still shows useful day-to-day contrast (same idea as the bar charts).
  let max = 1;
  for (let d = new Date(winFrom); d <= winTo; d.setDate(d.getDate() + 1)) {
    const v = valByDate[ymd(d)] || 0;
    if (v > max) max = v;
  }
  const level = (v) => (v <= 0 ? 0 : Math.min(4, Math.ceil((v / max) * 4)));
  // Fixed light→orange ramp (identical in both themes). Level 0 is the empty/
  // zero level (subtle background, no text). The per-level TEXT color is chosen
  // for contrast against each cell's OWN background - NOT the page theme - so
  // the in-cell token numbers stay legible in dark mode too. Index 4 must have
  // a real (non-transparent) background or the busiest cell goes invisible.
  const SCALE = ["var(--grid)", "#f6d9bf", "#f0b384", "#e2884f", "#c75e36"];
  const SCALE_FG = ["transparent", "#000", "#000", "#fff", "#fff"]; // pure black/white chosen by cell bg luminance
  // span the window, padded to whole weeks (Mon-start) so the 7-row grid aligns.
  // getDay() is Sun=0…Sat=6; (getDay()+6)%7 is days back to Monday, (7-getDay())%7
  // is days forward to Sunday.
  const start = new Date(winFrom);
  start.setDate(start.getDate() - ((start.getDay() + 6) % 7));
  const end = new Date(winTo);
  end.setDate(end.getDate() + ((7 - end.getDay()) % 7));
  const cells = [];
  _heatHTML = {};
  for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
    const key = ymd(d);
    const inWindow = d >= winFrom && d <= winTo; // week-padding cells fall outside
    const det = inWindow ? detail[key] : undefined;
    const v = det ? metricOf(det) : 0;
    const has = inWindow && det !== undefined;
    const active = has && v > 0;
    const lv = active ? level(v) : 0;
    if (inWindow) _heatHTML[key] = heatTipHTML(key, det || null);
    // contrast text from the cell's own level; empty/zero cells carry no text
    const txt = active ? SCALE_FG[lv] : "transparent";
    const label = active ? (isCost ? fmtUSD(v) : fmtTok(v)) : "";
    // active cells get the ramp color; in-window empty days keep a visible
    // (theme-aware) background; out-of-window padding & gap days stay faint.
    const bg = active ? SCALE[lv] : "var(--grid)";
    cells.push(
      `<div class="cell"${inWindow ? ` data-date="${key}"` : ""} data-l="${lv}"${active ? "" : ' data-empty="1"'} style="background:${bg};color:${txt};${!has ? "opacity:.5" : ""}">${label}</div>`,
    );
  }
  const heatEl = document.getElementById("heat");
  heatEl.innerHTML = cells.join("");
  document
    .querySelectorAll(".heat-legend .cell")
    .forEach((el, i) => (el.style.background = SCALE[i]));

  // ---- axis labels (GitHub-style) ----
  // Weekday labels down the left, one per row, matching the grid's
  // Mon(row 0)…Sun(row 6) order so each sits beside its row. (Our 32px-tall
  // cells leave room for all 7, unlike GitHub's cramped Mon/Wed/Fri.)
  document.getElementById("heat-days").innerHTML = [
    "Mon",
    "Tue",
    "Wed",
    "Thu",
    "Fri",
    "Sat",
    "Sun",
  ]
    .map((l) => `<span>${l}</span>`)
    .join("");

  // ---- compact mode: narrow range (≤6 columns) gets the rich stats panel ----
  // Cells stay tidy/GitHub-sized; the freed-up row is filled with content (the
  // stats panel below), not with stretched tiles.
  const numCols = cells.length / 7;
  const compact = numCols <= 6;
  const heatCard = heatEl.closest(".card");
  heatCard.classList.toggle("heat-compact", compact);
  const COLW = 48; // 42px cell + 6px gap

  // Month labels across the top: one per column (week), placed above the first
  // column whose Monday falls in a new month, at COLW-pixel intervals.
  const MONTHS = [
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec",
  ];
  const mLabels = [];
  let lastM = -1,
    lastY = null;
  const wk = new Date(start); // 'start' is a Monday → matches grid row 0
  for (let c = 0; c < numCols; c++) {
    const m = wk.getMonth(),
      y = wk.getFullYear();
    if (m !== lastM) {
      // disambiguate years (e.g. the 'all' range) by tagging the month that
      // crosses into a new year; within a single year no suffix is shown.
      const txt =
        lastY !== null && y !== lastY
          ? `${MONTHS[m]} '${String(y).slice(-2)}`
          : MONTHS[m];
      mLabels.push(`<span style="left:${c * COLW}px">${txt}</span>`);
      lastM = m;
      lastY = y;
    }
    wk.setDate(wk.getDate() + 7);
  }
  document.getElementById("heat-months").innerHTML = mLabels.join("");

  // ---- rich stats panel: fills the freed-up row with a headline + breakdowns ----
  const statsEl = document.getElementById("heat-stats");
  if (compact) {
    // aggregate over the active window; also collect a per-day series for the spark
    let totalVal = 0,
      activeDays = 0,
      busiestDate = "",
      busiestVal = 0;
    const modelTotals = {},
      srcTotals = {},
      series = [];
    for (let d = new Date(winFrom); d <= winTo; d.setDate(d.getDate() + 1)) {
      const key = ymd(d),
        det = detail[key],
        v = det ? metricOf(det) : 0;
      series.push({ key, v });
      if (det && v > 0) {
        totalVal += v;
        activeDays++;
        if (v > busiestVal) {
          busiestVal = v;
          busiestDate = key;
        }
        for (const [m, mx] of Object.entries(det.models))
          modelTotals[m] =
            (modelTotals[m] || 0) + (isCost ? mx.cost : mx.tokens);
        for (const [s, sx] of Object.entries(det.sources))
          srcTotals[s] = (srcTotals[s] || 0) + (isCost ? sx.cost : sx.tokens);
      }
    }
    const fmt = isCost ? fmtUSD : fmtTok,
      fmtBig = isCost ? fmtUSDfull : fmtTokFull;
    const totalDays = series.length,
      avgVal = activeDays ? totalVal / activeDays : 0;
    const periodLabel =
      ymd(winFrom) === ymd(winTo)
        ? fmtDate(ymd(winFrom))
        : `${fmtDate(ymd(winFrom))} – ${fmtDate(ymd(winTo))}`;

    // headline column: big total + the at-a-glance numbers
    const headCol = `
        <div class="hs-head">
          <div class="hs-period">${periodLabel}</div>
          <div class="hs-kpi">${activeDays ? fmtBig(totalVal) : "-"}</div>
          <div class="hs-sub">${isCost ? "total cost" : "total tokens"}</div>
          ${
            activeDays
              ? `<div class="hs-meta">${activeDays} active day${activeDays !== 1 ? "s" : ""} of ${totalDays}</div>
               ${activeDays > 1 ? `<div class="hs-meta">${fmt(avgVal)} avg / active day</div>` : ""}
               ${activeDays > 1 && busiestDate ? `<div class="hs-meta">peak ${fmtDate(busiestDate)} · ${fmt(busiestVal)}</div>` : ""}`
              : `<div class="hs-meta" style="color:var(--ink-faint)">no activity in range</div>`
          }
        </div>`;

    // a labelled horizontal bar, width ∝ value / section max
    const barRow = (color, name, val, frac) =>
      `<div class="hs-bar-row"><span class="hs-bar-name"><i style="background:${color}"></i>${name}</span>` +
      `<span class="hs-bar"><b style="width:${Math.max(2, frac * 100).toFixed(1)}%;background:${color}"></b></span>` +
      `<span class="hs-bar-val">${fmt(val)}</span></div>`;

    const models = Object.entries(modelTotals)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5);
    const maxModel = models.length ? models[0][1] : 1;
    const modelBars = models
      .map(([m, v]) =>
        barRow(MODEL_COLOR[m] || OTHER_COLOR, shortModel(m), v, v / maxModel),
      )
      .join("");

    // source split only when more than one source exists in the data
    const srcs =
      SOURCES.length > 1
        ? Object.entries(srcTotals).sort((a, b) => b[1] - a[1])
        : [];
    const maxSrc = srcs.length ? srcs[0][1] : 1;
    const srcBars = srcs
      .map(([s, v]) => barRow(sourceColor(s), sourceLabel(s), v, v / maxSrc))
      .join("");

    // daily sparkline (skip for very short ranges where it's just 1–2 stubs).
    // Each bar is colored by the same intensity level as its calendar cell.
    let spark = "";
    if (totalDays >= 5) {
      const bars = series
        .map((p) => {
          const h =
            max > 0 ? (p.v > 0 ? Math.max(6, (p.v / max) * 100) : 0) : 0;
          return `<i title="${fmtDate(p.key)} · ${fmt(p.v)}" style="height:${h.toFixed(0)}%;background:${SCALE[level(p.v)]}"></i>`;
        })
        .join("");
      spark = `<div class="hs-lbl" style="margin-top:14px">Daily</div><div class="hs-spark">${bars}</div>`;
    }

    const detailCol = activeDays
      ? `
        <div class="hs-detail">
          <div class="hs-lbl">Top models</div>${modelBars}
          ${srcBars ? `<div class="hs-lbl" style="margin-top:14px">By source</div>${srcBars}` : ""}
          ${spark}
        </div>`
      : "";

    statsEl.innerHTML = headCol + detailCol;
  } else {
    statsEl.innerHTML = "";
  }
}

// ============ MODELS TABLE ============
export function renderTable() {
  const agg = {};
  inRangeDays().forEach((d) => {
    dayBreakdowns(d).forEach((b) => {
      if (!state.models.has(b.modelName)) return;
      const a =
        agg[b.modelName] ||
        (agg[b.modelName] = {
          name: b.modelName,
          cost: 0,
          tokens: 0,
          input: 0,
          output: 0,
          cacheRead: 0,
          days: 0,
          _days: new Set(),
        });
      a.cost += +b.cost || 0;
      a.input += +b.inputTokens || 0;
      a.output += +b.outputTokens || 0;
      a.cacheRead += +b.cacheReadTokens || 0;
      a.tokens += tokensOf(b);
      a._days.add(d.period);
    });
  });
  let list = Object.values(agg);
  list.forEach((x) => (x.days = x._days.size));
  const totCost = list.reduce((a, b) => a + b.cost, 0) || 1;
  list.forEach((x) => (x.share = x.cost / totCost));
  const { key, dir } = state.sort;
  list.sort((a, b) =>
    key === "name"
      ? dir * a.name.localeCompare(b.name)
      : dir * ((a[key] || 0) - (b[key] || 0)),
  );
  const tb = document.querySelector("#tbl-models tbody");
  tb.innerHTML = list
    .map(
      (x) =>
        `<tr>
        <td><span class="model-tag"><span class="swatch" style="background:${MODEL_COLOR[x.name] || OTHER_COLOR}"></span>${shortModel(x.name)}</span></td>
        <td class="num">${fmtUSDfull(x.cost)}</td>
        <td class="num">${fmtPct(x.share)}</td>
        <td class="num">${fmtTok(x.tokens)}</td>
        <td class="num">${fmtTok(x.input)}</td>
        <td class="num">${fmtTok(x.output)}</td>
        <td class="num">${fmtTok(x.cacheRead)}</td>
        <td class="num">${x.days}</td>
      </tr>`,
    )
    .join("");
  // header arrows
  document.querySelectorAll("#tbl-models thead th").forEach((th) => {
    const active = th.dataset.key === key;
    th.dataset.active = active ? "1" : "0";
    th.querySelector(".arr").textContent = active ? (dir < 0 ? "▼" : "▲") : "";
  });
}

// ============ USAGE BY SOURCE (stacked tokens + total cost line) ============
function renderSource() {
  if (SOURCES.length < 2) return;
  const rows = derive();
  const { labels, series } = deriveBySource(rows);
  const ds = SOURCES.filter((s) => state.sources.has(s)).map((s) => ({
    type: "bar",
    label: sourceLabel(s),
    data: series[s],
    yAxisID: "y",
    _srcKey: s,
    backgroundColor: sourceColor(s),
    borderWidth: 0,
    stack: "src",
  }));
  ds.push({
    type: "line",
    label: "Cost",
    data: rows.map((r) => r.cost),
    yAxisID: "y1",
    _costLine: true,
    borderColor: COSTC,
    borderWidth: 2,
    pointRadius: 0,
    tension: 0.35,
  });
  document.getElementById("t-source").textContent = "Usage by source over time";
  sizeChartInner("scroll-source", rows.length);
  mount("c-source", {
    type: "bar",
    data: { labels, datasets: ds },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      interaction: { mode: "index", intersect: false },
      plugins: {
        legend: {
          position: "top",
          align: "end",
          labels: { boxWidth: 10, boxHeight: 10, usePointStyle: true },
        },
        tooltip: {
          ...baseTooltip,
          callbacks: {
            label: dualLabel,
            footer: (items) => {
              const tk = items
                .filter((i) => i.dataset.yAxisID !== "y1")
                .reduce((a, b) => a + b.parsed.y, 0);
              return "Σ " + fmtTokFull(tk);
            },
          },
        },
      },
      scales: dualScales(true),
    },
  });
  autoScrollRight("scroll-source");
}

// ============ BY PROJECT (v3/v4) ============
// v3 daily[].projects = [{projectName, tokens, cost}]. v4 deepens each to
// {..., chats:[{id,title,tokens,cost}], worktrees:[{name,tokens,cost,chats:[…]}]}
// so project rows expand into their chats + worktrees. Older snapshots omit
// these → degrade gracefully (flat, non-expandable; hide all if no projects).
// Project rows are per-day so the date-range filter is respected; the rollups
// aren't split by model/source, so those filters don't subdivide the totals.
const HAS_PROJECTS = DAILY.some((d) => Array.isArray(d.projects));
const HAS_TREE = DAILY.some(
  (d) =>
    Array.isArray(d.projects) &&
    d.projects.some(
      (p) => Array.isArray(p.chats) || Array.isArray(p.worktrees),
    ),
);
const HAS_HOURS = DAILY.some((d) => Array.isArray(d.hours));
const PROJ_TOPN = 15;
const CHATS_PER_GROUP = 20; // cap chats shown per group; rest → "+N more"

// Inline Lucide icons (v1.17.0, ISC) - folder=project, branch=worktree, msg=chat.
const ICONS = {
  "folder-git-2":
    '<path d="M18 19a5 5 0 0 1-5-5v8"/><path d="M9 20H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h3.9a2 2 0 0 1 1.69.9l.81 1.2a2 2 0 0 0 1.67.9H20a2 2 0 0 1 2 2v5"/><circle cx="13" cy="12" r="2"/><circle cx="20" cy="19" r="2"/>',
  "git-branch":
    '<path d="M15 6a9 9 0 0 0-9 9V3"/><circle cx="18" cy="6" r="3"/><circle cx="6" cy="18" r="3"/>',
  "message-square":
    '<path d="M22 17a2 2 0 0 1-2 2H6.828a2 2 0 0 0-1.414.586l-2.202 2.202A.71.71 0 0 1 2 21.286V5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2z"/>',
  "chevron-right": '<path d="m9 18 6-6-6-6"/>',
};
const icon = (name, cls = "") =>
  `<svg class="${cls}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${ICONS[name] || ""}</svg>`;

// merge chat lists (by sessionId) across days; chatArr → tokens-desc array.
// `period` (the day being merged) advances each chat's lastActive.
function mergeChats(map, list, period) {
  for (const c of list || []) {
    const id = c.id || "(no-session)";
    const x =
      map.get(id) ||
      (map.set(id, {
        id,
        title: c.title || "",
        tokens: 0,
        cost: 0,
        source: c.source || "",
        lastActive: "",
        firstTs: 0,
        lastTs: 0,
        _days: new Set(),
      }),
      map.get(id));
    x.tokens += +c.tokens || 0;
    x.cost += +c.cost || 0;
    if (c.source) x.source = c.source;
    if (c.title) x.title = c.title;
    if (period && period > x.lastActive) x.lastActive = period;
    // span across day-fragments: earliest first, latest last (time-spent = last-first)
    const f = +c.firstTs || 0,
      l = +c.lastTs || 0;
    if (f && (!x.firstTs || f < x.firstTs)) x.firstTs = f;
    if (l > x.lastTs) x.lastTs = l;
    if (period && ((+c.tokens || 0) > 0 || (+c.cost || 0) > 0))
      x._days.add(period);
  }
}
const chatDur = (c) =>
  c.firstTs && c.lastTs && c.lastTs > c.firstTs ? c.lastTs - c.firstTs : 0;
const sumDur = (arr) => arr.reduce((s, c) => s + (c.dur || 0), 0);
const chatArr = (map) =>
  [...map.values()]
    .map((c) => ({ ...c, days: c._days.size, dur: chatDur(c) }))
    .sort((a, b) => b.tokens - a.tokens);

function aggregateProjects() {
  const agg = {}; // name -> {tokens, cost, main:Map, wts:Map}
  const dayset = {}; // name -> Set(dates)
  for (const d of inRangeDays()) {
    if (!Array.isArray(d.projects)) continue;
    for (const p of d.projects) {
      const name = p.projectName || "(unknown)";
      const a =
        agg[name] ||
        (agg[name] = { tokens: 0, cost: 0, main: new Map(), wts: new Map() });
      a.tokens += +p.tokens || 0;
      a.cost += +p.cost || 0;
      if ((+p.tokens || 0) > 0 || (+p.cost || 0) > 0)
        (dayset[name] || (dayset[name] = new Set())).add(d.period);
      mergeChats(a.main, p.chats, d.period);
      for (const w of p.worktrees || []) {
        const wa =
          a.wts.get(w.name) ||
          (a.wts.set(w.name, { tokens: 0, cost: 0, chats: new Map() }),
          a.wts.get(w.name));
        wa.tokens += +w.tokens || 0;
        wa.cost += +w.cost || 0;
        mergeChats(wa.chats, w.chats, d.period);
      }
    }
  }
  const chatsMaxDate = (arr) => {
    let m = "";
    for (const c of arr) if (c.lastActive > m) m = c.lastActive;
    return m;
  };
  const daysOf = (arr) => {
    const s = new Set();
    for (const c of arr) for (const d of c._days || []) s.add(d);
    return s.size;
  };
  // Keep only chats whose source is selected (chats carry a `source` tag - cli /
  // cc-cloud / cowork). Legacy data without the tag stays visible. Project and
  // worktree totals/shares/days are recomputed from the VISIBLE chats so the
  // whole drilldown is consistent with the source filter (e.g. picking only
  // "Claude Code Cloud" shows just the projects with cloud sessions).
  const srcVisible = (c) => !c.source || state.sources.has(c.source);
  const sumTok = (arr) => arr.reduce((s, c) => s + (+c.tokens || 0), 0);
  const sumCost = (arr) => arr.reduce((s, c) => s + (+c.cost || 0), 0);
  const projs = Object.keys(agg)
    .map((name) => {
      const mainChats = chatArr(agg[name].main).filter(srcVisible);
      const worktrees = [...agg[name].wts.entries()]
        .map(([n, w]) => {
          const ch = chatArr(w.chats).filter(srcVisible);
          return {
            name: n,
            chats: ch,
            tokens: sumTok(ch),
            cost: sumCost(ch),
            days: daysOf(ch),
            lastActive: chatsMaxDate(ch),
            dur: sumDur(ch),
          };
        })
        .filter((w) => w.chats.length)
        .sort((a, b) => b.tokens - a.tokens);
      const allChats = mainChats.concat(...worktrees.map((w) => w.chats));
      return {
        name,
        chats: mainChats,
        worktrees,
        tokens: sumTok(mainChats) + worktrees.reduce((s, w) => s + w.tokens, 0),
        cost: sumCost(mainChats) + worktrees.reduce((s, w) => s + w.cost, 0),
        days: daysOf(allChats),
        lastActive: chatsMaxDate(allChats),
        // total time spent in the project = sum of every chat span, worktrees included
        dur:
          sumDur(mainChats) + worktrees.reduce((s, w) => s + (w.dur || 0), 0),
      };
    })
    .filter((p) => p.chats.length || p.worktrees.length);
  // shares are relative to the filtered total so they sum to 100% in-view
  const totalCost = projs.reduce((s, p) => s + p.cost, 0) || 1;
  const setShare = (arr) => arr.forEach((c) => (c.share = c.cost / totalCost));
  for (const p of projs) {
    p.share = p.cost / totalCost;
    setShare(p.chats);
    for (const w of p.worktrees) {
      w.share = w.cost / totalCost;
      setShare(w.chats);
    }
  }
  return projs.sort((a, b) => b.tokens - a.tokens);
}

// Work-output rollup for the share card: distinct sessions (chats) and projects
// touched over the current filtered range. Reuses the By-project aggregation, so
// it is date-range AND source scoped (chats are filtered by the source filter;
// model filtering still doesn't split the tree).
export function workSummary() {
  let sessions = 0,
    projects = 0;
  for (const p of aggregateProjects()) {
    if ((p.tokens || 0) <= 0 && (p.cost || 0) <= 0) continue;
    projects += 1;
    sessions += p.chats.length;
    for (const w of p.worktrees) sessions += w.chats.length;
  }
  return { sessions, projects };
}

function renderProjects() {
  const card = document.getElementById("card-projects");
  const emptyEl = document.getElementById("proj-empty");
  const chartBox = card.querySelector(".chart-box");
  const toggleBtn = document.getElementById("proj-toggle");
  const tableWrap = document.getElementById("proj-table-wrap");
  if (!HAS_PROJECTS) {
    if (charts["c-projects"]) {
      charts["c-projects"].destroy();
      delete charts["c-projects"];
    }
    chartBox.style.display = "none";
    if (toggleBtn) toggleBtn.style.display = "none";
    if (tableWrap) tableWrap.style.display = "none";
    emptyEl.style.display = "";
    return;
  }
  chartBox.style.display = "";
  emptyEl.style.display = "none";

  let rows = aggregateProjects();
  const projCount = rows.length; // in-range project count (pre top-N cap)
  if (rows.length > PROJ_TOPN) {
    // cap to top-N, lump rest
    const head = rows.slice(0, PROJ_TOPN),
      rest = rows.slice(PROJ_TOPN);
    const o = rest.reduce(
      (acc, r) => {
        acc.tokens += r.tokens;
        acc.cost += r.cost;
        acc.share += r.share;
        acc.days = Math.max(acc.days, r.days);
        acc.dur += r.dur || 0;
        if (r.lastActive > acc.lastActive) acc.lastActive = r.lastActive;
        return acc;
      },
      {
        name: `others (${rest.length})`,
        tokens: 0,
        cost: 0,
        share: 0,
        days: 0,
        dur: 0,
        lastActive: "",
      },
    );
    rows = head.concat([o]);
  }

  const labels = rows.map((r) => r.name);
  mount("c-projects", {
    data: {
      labels,
      datasets: [
        {
          type: "bar",
          label: "Tokens",
          data: rows.map((r) => r.tokens),
          yAxisID: "y",
          _accentBar: true,
          backgroundColor: "rgba(217,119,87,.55)",
          borderColor: "#d97757",
          borderWidth: 1,
          borderRadius: 3,
          order: 2,
        },
        {
          type: "line",
          label: "Cost",
          data: rows.map((r) => r.cost),
          yAxisID: "y1",
          _costLine: true,
          borderColor: COSTC,
          borderWidth: 2,
          pointRadius: 3,
          tension: 0.3,
          order: 1,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      interaction: { mode: "index", intersect: false },
      plugins: {
        legend: {
          position: "top",
          align: "end",
          labels: { boxWidth: 10, boxHeight: 10, usePointStyle: true },
        },
        tooltip: { ...baseTooltip, callbacks: { label: dualLabel } },
      },
      scales: {
        x: {
          grid: { display: false },
          ticks: { maxRotation: 60, minRotation: 30, autoSkip: false },
        },
        y: {
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
      },
    },
  });

  renderProjectsTable();
  if (toggleBtn) {
    toggleBtn.style.display = "";
    toggleBtn.dataset.count = String(projCount);
  }
  toggleProjList(); // apply collapsed/expanded visibility + sync the label/count
}

// Show/hide the whole By-project table (collapsed by default) and sync the toggle's
// label + count. The tbody is always rendered (cheap), so expanding is instant.
export function toggleProjList() {
  const btn = document.getElementById("proj-toggle");
  const wrap = document.getElementById("proj-table-wrap");
  if (!btn || !wrap) return;
  const open = state.projListOpen;
  wrap.style.display = open ? "" : "none";
  const n = btn.dataset.count || "0";
  btn.textContent =
    (open ? "▾ Hide projects" : "▸ Show projects") + " (" + n + ")";
  btn.setAttribute("aria-expanded", open ? "true" : "false");
}

// Table is rendered separately so expand/collapse re-renders rows only (no chart).
const escHtml = (s) =>
  String(s == null ? "" : s).replace(
    /[&<>"]/g,
    (m) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[m],
  );

function nameCell(
  depth,
  { expandable, iconName, iconCls, label, count, copyId },
) {
  const chev = expandable
    ? `<span class="chev">${icon("chevron-right")}</span>`
    : `<span class="chev spacer">${icon("chevron-right")}</span>`;
  const badge =
    count > 0 ? `<sup class="icount">${count > 99 ? "99+" : count}</sup>` : "";
  // Chat icons carry their session id so ⌘/Ctrl-click can copy it (wired in controls.js).
  const copyAttrs = copyId
    ? ` data-chat-id="${escHtml(copyId)}" title="⌘/Ctrl-click to copy chat id"`
    : "";
  const ic = iconName
    ? `<span class="ticon${copyId ? " copyable" : ""}"${copyAttrs}>${icon(iconName, iconCls)}${badge}</span>`
    : "";
  return `<td><span class="tname" style="padding-left:${depth * 20}px">${chev}${ic}<span class="tlabel">${escHtml(label)}</span></span></td>`;
}

// chat leaf rows (+ a lumped "+N more" row past the cap), indented to `depth`
function chatRows(chats, depth) {
  let out = "";
  const top = chats.slice(0, CHATS_PER_GROUP),
    rest = chats.slice(CHATS_PER_GROUP);
  for (const c of top) {
    out +=
      `<tr class="tr-chat">` +
      nameCell(depth, {
        expandable: false,
        iconName: "message-square",
        iconCls: "ic-chat",
        label: c.title || "Untitled chat",
        copyId: c.id,
      }) +
      `<td class="num">${fmtTokFull(c.tokens)}</td><td class="num">${fmtUSDfull(c.cost)}</td><td class="num">${fmtPct(c.share)}</td><td class="num">${c.days}</td><td class="num">${fmtDur(c.dur)}</td><td class="num">${fmtDate(c.lastActive)}</td></tr>`;
  }
  if (rest.length) {
    const tk = rest.reduce((s, c) => s + c.tokens, 0),
      ct = rest.reduce((s, c) => s + c.cost, 0);
    const sh = rest.reduce((s, c) => s + (c.share || 0), 0);
    const du = rest.reduce((s, c) => s + (c.dur || 0), 0);
    const dsz = (() => {
      const s = new Set();
      for (const c of rest) for (const d of c._days || []) s.add(d);
      return s.size;
    })();
    out +=
      `<tr class="tr-more">` +
      nameCell(depth, {
        expandable: false,
        iconName: "message-square",
        iconCls: "ic-chat",
        label: `+${rest.length} more chats`,
      }) +
      `<td class="num">${fmtTokFull(tk)}</td><td class="num">${fmtUSDfull(ct)}</td><td class="num">${fmtPct(sh)}</td><td class="num">${dsz}</td><td class="num">${fmtDur(du)}</td><td class="num"></td></tr>`;
  }
  return out;
}

export function renderProjectsTable() {
  let rows = aggregateProjects();
  const { key, dir } = state.projSort;
  // One comparator for every level of the tree. Chats carry `title` rather
  // than `name`, so fall back to it for name sorting.
  const cmp = (a, b) =>
    key === "name"
      ? dir *
        String(a.name || a.title || "").localeCompare(
          String(b.name || b.title || ""),
        )
      : key === "lastActive"
        ? dir *
          String(a.lastActive || "").localeCompare(String(b.lastActive || ""))
        : dir * ((a[key] || 0) - (b[key] || 0));
  rows.sort(cmp);

  let html = "";
  for (const r of rows) {
    const hasKids = HAS_TREE && (r.chats.length > 0 || r.worktrees.length > 0);
    const pkey = "proj:" + r.name;
    const open = state.projExpanded.has(pkey);
    // total items nested under the project: direct chats + each worktree + the chats inside those worktrees
    const projCount =
      r.chats.length +
      r.worktrees.length +
      r.worktrees.reduce((s, w) => s + w.chats.length, 0);
    html +=
      `<tr class="${hasKids ? "tr-expandable" : ""}"${hasKids ? ` data-expand="${escHtml(pkey)}"` : ""} data-open="${open ? 1 : 0}">` +
      nameCell(0, {
        expandable: hasKids,
        iconName: "folder-git-2",
        iconCls: "ic-proj",
        label: r.name,
        count: projCount,
      }) +
      `<td class="num">${fmtTokFull(r.tokens)}</td><td class="num">${fmtUSDfull(r.cost)}</td>` +
      `<td class="num">${fmtPct(r.share)}</td><td class="num">${r.days}</td><td class="num">${fmtDur(r.dur)}</td><td class="num">${fmtDate(r.lastActive)}</td></tr>`;
    if (hasKids && open) {
      html += chatRows(r.chats.slice().sort(cmp), 1);
      for (const w of r.worktrees.slice().sort(cmp)) {
        const wkey = "wt:" + r.name + "::" + w.name;
        const wopen = state.projExpanded.has(wkey);
        const wKids = w.chats.length > 0;
        html +=
          `<tr class="tr-wt ${wKids ? "tr-expandable" : ""}"${wKids ? ` data-expand="${escHtml(wkey)}"` : ""} data-open="${wopen ? 1 : 0}">` +
          nameCell(1, {
            expandable: wKids,
            iconName: "git-branch",
            iconCls: "ic-wt",
            label: w.name,
            count: w.chats.length,
          }) +
          `<td class="num">${fmtTokFull(w.tokens)}</td><td class="num">${fmtUSDfull(w.cost)}</td><td class="num">${fmtPct(w.share)}</td><td class="num">${w.days}</td><td class="num">${fmtDur(w.dur)}</td><td class="num">${fmtDate(w.lastActive)}</td></tr>`;
        if (wopen && wKids) html += chatRows(w.chats.slice().sort(cmp), 2);
      }
    }
  }
  document.querySelector("#tbl-projects tbody").innerHTML = html;

  document.querySelectorAll("#tbl-projects thead th").forEach((th) => {
    const active = th.dataset.key === key;
    th.dataset.active = active ? "1" : "0";
    const arr = th.querySelector(".arr");
    if (arr) arr.textContent = active ? (dir < 0 ? "▼" : "▲") : "";
  });
}

// ============ HOURLY (v3, single-day) ============
export function latestDayWithHours() {
  const days = DAILY.slice().sort((a, b) => (a.period < b.period ? 1 : -1));
  for (const d of days)
    if (Array.isArray(d.hours) && d.hours.some((h) => (+h.tokens || 0) > 0))
      return d.period;
  return days[0] ? days[0].period : ymd(LATEST);
}

export function renderHourly(dateKey) {
  const emptyEl = document.getElementById("hourly-empty");
  const chartBox = document
    .getElementById("card-hourly")
    .querySelector(".chart-box");
  if (!HAS_HOURS) {
    if (charts["c-hourly"]) {
      charts["c-hourly"].destroy();
      delete charts["c-hourly"];
    }
    chartBox.style.display = "none";
    emptyEl.textContent =
      "No hourly data in this snapshot. Re-run ./cc-update to populate it.";
    emptyEl.style.display = "";
    return;
  }
  const d = DAILY.find((x) => x.period === dateKey);
  const hours = d && Array.isArray(d.hours) ? d.hours : null;
  const has = hours && hours.some((h) => (+h.tokens || 0) > 0);
  chartBox.style.display = "";
  emptyEl.textContent = "No hourly data for this day.";
  emptyEl.style.display = has ? "none" : "";

  const labels = Array.from(
    { length: 24 },
    (_, h) => String(h).padStart(2, "0") + ":00",
  );
  const toks = Array.from({ length: 24 }, (_, h) =>
    hours ? +hours[h].tokens || 0 : 0,
  );
  const costs = Array.from({ length: 24 }, (_, h) =>
    hours ? +hours[h].cost || 0 : 0,
  );
  document.getElementById("t-hourly").textContent = "Hourly - " + dateKey;
  mount("c-hourly", {
    data: {
      labels,
      datasets: [
        {
          type: "bar",
          label: "Tokens",
          data: toks,
          yAxisID: "y",
          _accentBar: true,
          backgroundColor: "rgba(217,119,87,.55)",
          borderColor: "#d97757",
          borderWidth: 1,
          borderRadius: 2,
          order: 2,
        },
        {
          type: "line",
          label: "Cost",
          data: costs,
          yAxisID: "y1",
          _costLine: true,
          borderColor: COSTC,
          borderWidth: 2,
          pointRadius: 0,
          tension: 0.3,
          order: 1,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      interaction: { mode: "index", intersect: false },
      plugins: {
        legend: {
          position: "top",
          align: "end",
          labels: { boxWidth: 10, boxHeight: 10, usePointStyle: true },
        },
        tooltip: { ...baseTooltip, callbacks: { label: dualLabel } },
      },
      scales: dualScales(false),
    },
  });
}

// ============ HOURLY - ALL TIME (aggregate across every recorded day) ============
// Hour rollups are not split by source/model in the data, so like the
// single-day hourly card this ignores the source/model/range filters and is
// rendered once at init.
export function renderHourlyAll() {
  const emptyEl = document.getElementById("hourly-all-empty");
  const chartBox = document
    .getElementById("card-hourly-all")
    .querySelector(".chart-box");
  if (!HAS_HOURS) {
    if (charts["c-hourly-all"]) {
      charts["c-hourly-all"].destroy();
      delete charts["c-hourly-all"];
    }
    chartBox.style.display = "none";
    emptyEl.style.display = "";
    return;
  }
  chartBox.style.display = "";
  emptyEl.style.display = "none";

  const toks = new Array(24).fill(0),
    costs = new Array(24).fill(0),
    cnt = new Array(24).fill(0);
  for (const d of DAILY) {
    if (!Array.isArray(d.hours)) continue;
    for (let h = 0; h < 24; h++) {
      const t = +d.hours[h]?.tokens || 0;
      toks[h] += t;
      costs[h] += +d.hours[h]?.cost || 0;
      if (t > 0) cnt[h]++;
    }
  }
  const labels = Array.from(
    { length: 24 },
    (_, h) => String(h).padStart(2, "0") + ":00",
  );
  mount("c-hourly-all", {
    data: {
      labels,
      datasets: [
        {
          type: "bar",
          label: "Tokens",
          data: toks,
          yAxisID: "y",
          _accentBar: true,
          backgroundColor: "rgba(217,119,87,.55)",
          borderColor: "#d97757",
          borderWidth: 1,
          borderRadius: 2,
          order: 2,
        },
        {
          type: "line",
          label: "Cost",
          data: costs,
          yAxisID: "y1",
          _costLine: true,
          borderColor: COSTC,
          borderWidth: 2,
          pointRadius: 0,
          tension: 0.3,
          order: 1,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      interaction: { mode: "index", intersect: false },
      plugins: {
        legend: {
          position: "top",
          align: "end",
          labels: { boxWidth: 10, boxHeight: 10, usePointStyle: true },
        },
        tooltip: {
          ...baseTooltip,
          callbacks: {
            label: dualLabel,
            afterBody: (items) => {
              const i = items[0].dataIndex;
              return `${cnt[i]} active day${cnt[i] === 1 ? "" : "s"}`;
            },
          },
        },
      },
      scales: dualScales(false),
    },
  });
}

// open the hourly view for a date (wired to heat-cell clicks)
export function openHourly(dateKey) {
  if (!dateKey) return;
  const inp = document.getElementById("hourly-date");
  if (inp) inp.value = dateKey;
  renderHourly(dateKey);
  const card = document.getElementById("card-hourly");
  if (card && card.scrollIntoView) {
    try {
      card.scrollIntoView({ behavior: "smooth", block: "nearest" });
    } catch (e) {}
  }
}

// ============ RENDER ALL ============
export function renderAll() {
  renderKPIs();
  renderDaily();
  renderDonut();
  renderTokens();
  renderModelTime();
  renderSource();
  renderDOW();
  renderHeat();
  renderTable();
  renderProjects();
}
