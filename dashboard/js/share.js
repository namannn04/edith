import { statsSummary } from "./stats.js";
import { derive, activeWindow } from "./compute.js";
import { workSummary } from "./render.js";
import { charts, state } from "./state.js";
import { fmtUSD, fmtTok, shortModel, MON } from "./format.js";
import { toast } from "./toast.js";

// read a CSS custom property off <body>, with a fallback (mirrors charts.js)
const cssVar = (n, fallback) =>
  getComputedStyle(document.body).getPropertyValue(n).trim() || fallback;
function cardTheme() {
  return {
    bg: cssVar("--paper-2", "#fffdf8"),
    ink: cssVar("--ink", "#241f1a"),
    soft: cssVar("--ink-soft", "#5c5247"),
    faint: cssVar("--ink-faint", "#9a8f80"),
    gold: cssVar("--gold", "#c89b3c"),
    accent: cssVar("--accent", "#d97757"),
    mono: cssVar("--mono", "monospace"),
    serif: cssVar("--serif", "Georgia, serif"),
    line: cssVar("--line-strong", "#e7ddcb"),
  };
}

const dlabel = (d, withYear) =>
  `${d.getDate()} ${MON[d.getMonth()]}` +
  (withYear ? ` ${d.getFullYear()}` : "");

// Subtitle for the share card: "All time" or "26 May – 25 Jun 2026".
export function rangeLabel() {
  if (state.range.mode === "all") return "All time";
  const w = activeWindow();
  const sameYear = w.from.getFullYear() === w.to.getFullYear();
  return `${dlabel(w.from, !sameYear)} – ${dlabel(w.to, true)}`;
}

const fileYmd = (d) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;

function cardFilename() {
  if (state.range.mode === "all") return "cc-usage_all.png";
  const w = activeWindow();
  return `cc-usage_${fileYmd(w.from)}_${fileYmd(w.to)}.png`;
}

function triggerDownload(canvas, filename) {
  canvas.toBlob((blob) => {
    if (!blob) return;
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    a.remove();
    URL.revokeObjectURL(url);
  }, "image/png");
}

// Lay metric cells out in a centered, auto-balanced grid (≤3 per row). Partial
// last rows are centered, so the card reads well for any number of metrics.
function drawFlexGrid(ctx, t, cells, { PAD, W, blurCost, blurred }) {
  const n = cells.length;
  if (!n) return;
  const contentW = W - PAD * 2;
  const maxPerRow = 3;
  const rows = Math.ceil(n / maxPerRow);
  const cols = Math.ceil(n / rows); // balance: e.g. 4 → 2×2, 6 → 3×2
  const cellW = contentW / cols;
  const rowH = 112;
  const bandTop = 318,
    bandBottom = 560;
  const blockH = (rows - 1) * rowH + 60;
  const firstLabelY =
    Math.round(bandTop + (bandBottom - bandTop - blockH) / 2) + 14;

  for (let i = 0; i < n; i++) {
    const r = Math.floor(i / cols);
    const rowStart = r * cols;
    const rowCount = Math.min(cols, n - rowStart); // cells on this row
    const rowLeft = PAD + (contentW - rowCount * cellW) / 2;
    const x = rowLeft + (i - rowStart) * cellW;
    const yLabel = firstLabelY + r * rowH;

    ctx.fillStyle = t.faint;
    ctx.font = `15px ${t.mono}`;
    ctx.fillText(cells[i].label, x, yLabel);
    const drawVal = () => {
      ctx.fillStyle = t.ink;
      ctx.font = `600 42px ${t.mono}`;
      ctx.fillText(cells[i].value, x, yLabel + 46);
    };
    if (blurCost && cells[i].cost) blurred(14, drawVal);
    else drawVal();
  }
}

// ---------- branded share card (current filtered stats) → returns a canvas ----------
export function drawShareCard(opts = {}) {
  const { blurCost = false } = opts;
  const s = statsSummary(derive());
  const work = workSummary();
  const t = cardTheme();
  const W = 1200,
    H = 630,
    SCALE = 2;
  const canvas = document.createElement("canvas");
  canvas.width = W * SCALE;
  canvas.height = H * SCALE;
  const ctx = canvas.getContext("2d");
  ctx.scale(SCALE, SCALE);

  // Redact a $ value: draw it under a heavy blur, stamped a few times so it
  // stays visible as a smudge but is no longer legible. Radius scales with the
  // font size (≈0.45×) so digits merge into a blob at any size.
  const blurred = (radius, fn, stamps = 3) => {
    ctx.save();
    ctx.filter = `blur(${radius}px)`;
    for (let i = 0; i < stamps; i++) fn();
    ctx.restore();
  };

  ctx.fillStyle = t.bg;
  ctx.fillRect(0, 0, W, H);
  ctx.fillStyle = t.accent;
  ctx.fillRect(0, 0, W, 6); // accent top rule

  const PAD = 72,
    COL2 = PAD + 470;

  // header
  ctx.fillStyle = t.ink;
  ctx.font = `600 38px ${t.serif}`;
  ctx.fillText("Claude Code · Usage", PAD, 96);
  ctx.fillStyle = t.soft;
  ctx.font = `19px ${t.mono}`;
  ctx.fillText(rangeLabel(), PAD, 128);

  // hero numbers — big value on top, caption beneath (cost can be blurred)
  ctx.font = `700 84px ${t.mono}`;
  const drawCost = () => {
    ctx.fillStyle = t.gold;
    ctx.fillText(fmtUSD(s.totalCost), PAD, 232);
  };
  if (blurCost) blurred(38, drawCost);
  else drawCost();
  ctx.fillStyle = t.ink;
  ctx.fillText(fmtTok(s.totalTokens), COL2, 232);
  ctx.fillStyle = t.faint;
  ctx.font = `13px ${t.mono}`;
  ctx.fillText("TOTAL COST", PAD, 262);
  ctx.fillText("TOTAL TOKENS", COL2, 262);

  // hairline divider
  ctx.fillStyle = t.line;
  ctx.fillRect(PAD, 296, W - PAD * 2, 1);

  // metric grid — focused on work produced (auto-flex, centered)
  const cells = [
    {
      label: "INPUT / OUTPUT",
      value: `${fmtTok(s.input)} / ${fmtTok(s.output)}`,
    },
    { label: "SESSIONS", value: String(work.sessions) },
    { label: "PROJECTS", value: String(work.projects) },
    { label: "TOP MODEL", value: s.topModel ? shortModel(s.topModel) : "—" },
  ];
  drawFlexGrid(ctx, t, cells, { PAD, W, blurCost, blurred });

  return canvas;
}

// ---------- preview modal: shows the card + a blur-cost toggle before saving ----------
function openCardModal() {
  const overlay = document.createElement("div");
  overlay.className = "card-modal-overlay";
  overlay.innerHTML = `
      <div class="card-modal" role="dialog" aria-modal="true" aria-label="Share card preview">
        <div class="card-modal-preview"><img alt="Share card preview"></div>
        <div class="card-modal-bar">
          <label class="card-modal-toggle"><input type="checkbox" id="cm-blur"> Blur cost ($)</label>
          <div class="card-modal-actions">
            <button type="button" class="btn-reset" id="cm-cancel">Cancel</button>
            <button type="button" class="btn-reset cm-primary" id="cm-download">⤓ Download PNG</button>
          </div>
        </div>
      </div>`;
  document.body.appendChild(overlay);

  const img = overlay.querySelector("img");
  const blur = overlay.querySelector("#cm-blur");
  let canvas = null;
  const refresh = () => {
    canvas = drawShareCard({ blurCost: blur.checked });
    img.src = canvas.toDataURL("image/png");
  };
  refresh(); // blur off by default
  blur.addEventListener("change", refresh);

  const close = () => {
    overlay.remove();
    document.removeEventListener("keydown", onKey);
  };
  const onKey = (e) => {
    if (e.key === "Escape") close();
  };
  document.addEventListener("keydown", onKey);
  overlay.addEventListener("click", (e) => {
    if (e.target === overlay) close();
  });
  overlay.querySelector("#cm-cancel").addEventListener("click", close);
  overlay.querySelector("#cm-download").addEventListener("click", () => {
    triggerDownload(canvas, cardFilename());
    toast("Card downloaded");
    close();
  });
}

// ---------- activity-calendar PNG (the whole card box, exactly as rendered) ----------
// The calendar card is HTML/CSS (grid + a rich stats panel), not a <canvas>, so we
// can't export it like the charts. Instead we rasterize the live DOM: clone the
// card, inline the page styles + active theme variables, wrap it in an SVG
// <foreignObject>, and paint that onto a canvas. This captures the entire box —
// calendar grid, headline, model/source bars, sparkline — and stays correct as
// the panel evolves, with no external dependency.
export async function downloadHeatmap() {
  const card =
    document.getElementById("heat") &&
    document.getElementById("heat").closest(".card");
  if (!card) return;
  try {
    const SCALE = 2;
    const pageBg = cssVar("--paper", "#fff");

    // Clone the card, then strip / freeze the interactive chrome we don't want
    // baked into a static image.
    const clone = card.cloneNode(true);
    clone.querySelectorAll(".heat-dl").forEach((el) => el.remove()); // the download button itself
    clone.querySelectorAll(".heat-wrap").forEach((el) => {
      el.style.overflow = "visible";
    }); // include scrolled-off weeks
    // A live <select> renders unreliably inside foreignObject — replace it with a
    // static chip showing its current value.
    const liveSel = document.getElementById("heat-metric");
    const cloneSel = clone.querySelector("#heat-metric");
    if (liveSel && cloneSel) {
      const chip = document.createElement("span");
      chip.className = cloneSel.className;
      chip.setAttribute("style", cloneSel.getAttribute("style") || "");
      chip.textContent = liveSel.options[liveSel.selectedIndex]
        ? liveSel.options[liveSel.selectedIndex].text
        : "";
      cloneSel.replaceWith(chip);
    }

    // Measure at the live width (so the compact/wide layout decision matches), then
    // grow to include any calendar wider than its horizontal scroll.
    clone.style.boxSizing = "border-box";
    clone.style.width = card.offsetWidth + "px";
    clone.style.position = "fixed";
    clone.style.left = "-99999px";
    clone.style.top = "0";
    clone.style.margin = "0";
    document.body.appendChild(clone);
    const W = Math.ceil(Math.max(clone.scrollWidth, clone.offsetWidth));
    clone.style.width = W + "px"; // relayout so header/legend span the full width
    // Measure from the furthest descendant's bottom edge, not scrollHeight: the
    // stats column can overflow its flex box (visible overflow), and those pixels
    // — the DAILY sparkline — don't count toward scrollHeight, so it would crop.
    const cloneTop = clone.getBoundingClientRect().top;
    let maxBottom = clone.getBoundingClientRect().bottom;
    clone.querySelectorAll("*").forEach((el) => {
      const b = el.getBoundingClientRect().bottom;
      if (b > maxBottom) maxBottom = b;
    });
    const H = Math.ceil(maxBottom - cloneTop);
    // TEMP DEBUG — capture before clone is removed
    const _sp = clone.querySelector(".hs-spark");
    const _dbgSparkBottom = _sp
      ? Math.round(_sp.getBoundingClientRect().bottom - cloneTop)
      : -1;
    const _dbgScrollH = clone.scrollHeight;

    // foreignObject is its own root, so it doesn't inherit the page's :root/body
    // theme context. Resolve every CSS variable the stylesheet declares against the
    // active theme and pin them on the clone so var() works inside the SVG.
    const styleText = [...document.querySelectorAll("style")]
      .map((s) => s.textContent)
      .join("\n");
    const bodyCS = getComputedStyle(document.body);
    const varNames = new Set();
    let m;
    const re = /(--[\w-]+)\s*:/g;
    while ((m = re.exec(styleText))) varNames.add(m[1]);
    let vars = "";
    varNames.forEach((n) => {
      const v = bodyCS.getPropertyValue(n);
      if (v) vars += `${n}:${v.trim()};`;
    });

    // The card normally inherits its text color/font and color-scheme from
    // <body>/<html>; inside the foreignObject neither exists, so un-colored text
    // (e.g. the card title) falls back to the default black. Pin the resolved
    // values so inheritance matches the live page in either theme.
    const inherited =
      `color:${bodyCS.color};font-family:${bodyCS.fontFamily};` +
      `font-size:${bodyCS.fontSize};line-height:${bodyCS.lineHeight};` +
      `color-scheme:${getComputedStyle(document.documentElement).colorScheme || "light"};`;

    clone.style.position = "static";
    clone.style.left = "";
    clone.style.top = "";
    clone.setAttribute(
      "style",
      (clone.getAttribute("style") || "") + ";" + vars + inherited,
    );
    const xhtml = new XMLSerializer().serializeToString(clone);
    clone.remove();

    const svg =
      `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}">` +
      `<foreignObject x="0" y="0" width="${W}" height="${H}">` +
      // CDATA: the SVG is parsed as XML, so a stray `<`/`&` in the CSS (e.g. a
      // comment mentioning "<details>") would break the parse and the image
      // would fail to load. ponytail: breaks only on a literal `]]>` in CSS.
      `<div xmlns="http://www.w3.org/1999/xhtml"><style><![CDATA[${styleText}]]></style>${xhtml}</div>` +
      `</foreignObject>` +
      `</svg>`;

    const img = new Image();
    await new Promise((res, rej) => {
      img.onload = res;
      img.onerror = () => rej(new Error("foreignObject render failed"));
      img.src = "data:image/svg+xml;charset=utf-8," + encodeURIComponent(svg);
    });
    console.log(
      "[heatmap dbg] img natural=",
      img.naturalWidth,
      "x",
      img.naturalHeight,
    );

    const canvas = document.createElement("canvas");
    canvas.width = W * SCALE;
    canvas.height = H * SCALE;
    const ctx = canvas.getContext("2d");
    ctx.scale(SCALE, SCALE);
    ctx.fillStyle = pageBg;
    ctx.fillRect(0, 0, W, H); // page color behind the card's rounded corners
    ctx.drawImage(img, 0, 0, W, H);

    const title =
      (document.getElementById("t-heat") || {}).textContent ||
      "activity calendar";
    const slug = title
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "");
    triggerDownload(canvas, `cc-usage_${slug}.png`);
    toast(
      `H=${H} sparkBot=${_dbgSparkBottom} img=${img.naturalHeight} sh=${_dbgScrollH}`,
    );
  } catch (e) {
    console.error("[heatmap export]", e); // ponytail: console keeps the real cause; toast stays terse
    toast("Couldn't export calendar");
  }
}

// ---------- per-chart PNG (chart canvas on a solid theme background) ----------
export function downloadChart(canvasId) {
  const chart = charts[canvasId];
  if (!chart) return;
  const src = chart.canvas;
  const out = document.createElement("canvas");
  out.width = src.width;
  out.height = src.height;
  const ctx = out.getContext("2d");
  ctx.fillStyle = cssVar("--paper-2", "#fffdf8");
  ctx.fillRect(0, 0, out.width, out.height);
  ctx.drawImage(src, 0, 0);
  const card = src.closest(".card");
  const titleEl = card && card.querySelector(".card-title");
  const slug = ((titleEl && titleEl.textContent) || canvasId)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
  triggerDownload(out, `cc-usage_${slug}.png`);
}

// ---------- wiring (called once on init) ----------
export function wireShareButtons() {
  const share = document.getElementById("btn-share");
  if (share) share.addEventListener("click", openCardModal);
  document.querySelectorAll(".card").forEach((card) => {
    const cv = card.querySelector("canvas");
    if (!cv || !cv.id) return; // skip cards without a chart canvas (heatmap, tables)
    const head = card.querySelector(".card-head");
    if (!head) return;
    const btn = document.createElement("button");
    btn.className = "chart-dl";
    btn.type = "button";
    btn.title = "Download PNG";
    btn.setAttribute("aria-label", "Download chart as PNG");
    btn.textContent = "⤓";
    btn.dataset.canvas = cv.id;
    btn.addEventListener("click", () => downloadChart(cv.id));
    head.appendChild(btn);
  });

  // The activity calendar is an HTML/CSS heatmap (no <canvas>), so the loop above
  // skips it. Give it its own ⤓, placed inline beside the metric dropdown — the
  // top-right corner where .chart-dl normally sits is taken by that dropdown.
  const metricSel = document.getElementById("heat-metric");
  if (metricSel && document.getElementById("heat")) {
    const btn = document.createElement("button");
    btn.className = "chart-dl heat-dl";
    btn.type = "button";
    btn.title = "Download PNG";
    btn.setAttribute("aria-label", "Download activity calendar as PNG");
    btn.textContent = "⤓";
    btn.addEventListener("click", downloadHeatmap);
    metricSel.parentElement.appendChild(btn);
  }
}
