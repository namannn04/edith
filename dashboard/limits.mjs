// Pure helpers for the limits-history JSONL ({"ts","s","w","sr","wr"} per
// line, written by the Edith app on every poll). Used by render.mjs (node,
// to build the inline payload) and by js/limitsChart.js (browser bundle).
// Lives at the dashboard root like merge.mjs: node needs the .mjs extension
// to treat it as ESM (no package.json here). No DOM.

export function parseLimitsJSONL(text) {
  const out = [];
  for (const line of String(text || "").split("\n")) {
    if (!line.trim()) continue;
    let o;
    try { o = JSON.parse(line); } catch { continue; }
    const t = Date.parse(o.ts);
    if (!Number.isFinite(t)) continue;
    out.push({
      t,
      s: typeof o.s === "number" ? o.s : null,
      w: typeof o.w === "number" ? o.w : null,
      sr: o.sr ? Date.parse(o.sr) : null,
      wr: o.wr ? Date.parse(o.wr) : null,
    });
  }
  out.sort((a, b) => a.t - b.t);
  return out;
}

// Raw rows within rawWindowMs of now; older rows collapse to hourly buckets
// keeping each field's MAX (peaks are what matter) and the bucket's last resets.
export function downsampleLimits(rows, nowMs, rawWindowMs = 7 * 864e5) {
  const cutoff = nowMs - rawWindowMs;
  const buckets = new Map();
  const raw = [];
  for (const r of rows) {
    if (r.t >= cutoff) { raw.push(r); continue; }
    const b = Math.floor(r.t / 36e5) * 36e5;
    const cur = buckets.get(b);
    if (!cur) { buckets.set(b, { ...r, t: b }); continue; }
    if (r.s != null && (cur.s == null || r.s > cur.s)) cur.s = r.s;
    if (r.w != null && (cur.w == null || r.w > cur.w)) cur.w = r.w;
    cur.sr = r.sr; cur.wr = r.wr;
  }
  return [...buckets.values(), ...raw].sort((a, b) => a.t - b.t);
}

export function sliceRange(points, nowMs, ms) {
  return ms == null ? points : points.filter((p) => p.t >= nowMs - ms);
}

// A change in a reset timestamp between consecutive points = that window rolled.
export function resetMarkers(points) {
  const out = [];
  for (let i = 1; i < points.length; i++) {
    const p = points[i - 1], q = points[i];
    if (p.sr && q.sr && p.sr !== q.sr) out.push({ t: q.t, kind: "session" });
    if (p.wr && q.wr && p.wr !== q.wr) out.push({ t: q.t, kind: "weekly" });
  }
  return out;
}
