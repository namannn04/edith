#!/usr/bin/env bun
/**
 * build.mjs — build a self-contained dashboard.html from the modular sources.
 *
 * Run with bun:  bun build.mjs   (or ./build.mjs)
 *
 * Inlines css/styles.css and the bundled js/app.js module graph into
 * dashboard.template.html, producing a single dashboard.html that works both
 * by double-clicking (file://) and when served over http. The
 * <script id="usage-data"> block is preserved from the existing dashboard.html
 * so a rebuild never drops the latest snapshot — render.mjs keeps writing the
 * real usage data into that block and does not need to know about this build.
 *
 * Edit the modules (js/*.js, css/styles.css) and re-run this; dashboard.html is
 * a generated artifact — don't hand-edit it.
 */
import { readFileSync, writeFileSync, existsSync } from "node:fs";

const root = import.meta.dir;
const p = (f) => `${root}/${f}`;

const tmpl = readFileSync(p("dashboard.template.html"), "utf8");
const css = readFileSync(p("css/styles.css"), "utf8");

// Bundle the ES modules into a single classic IIFE — no import statements remain,
// so it runs inline (works on file://, which native ES modules do not).
const out = await Bun.build({
  entrypoints: [p("js/app.js")],
  target: "browser",
  format: "iife",
  minify: false,
});
if (!out.success) {
  console.error("bundle failed:\n" + out.logs.join("\n"));
  process.exit(1);
}
// Neutralize any literal </script> in the JS so it can't terminate the inline tag.
const js = (await out.outputs[0].text()).replace(/<\/script>/g, "<\\/script>");

let html = tmpl
  .replace(
    '<link rel="stylesheet" href="css/styles.css">',
    `<style>\n${css}</style>`,
  )
  .replace(
    '<script type="module" src="js/app.js"></script>',
    `<script>\n${js}\n</script>`,
  );

// Preserve the live data block (render.mjs writes real usage data into it).
const dataRe =
  /<script id="usage-data" type="application\/json">[\s\S]*?<\/script>/;
if (existsSync(p("dashboard.html"))) {
  const m = readFileSync(p("dashboard.html"), "utf8").match(dataRe);
  if (m) html = html.replace(dataRe, m[0]);
}

writeFileSync(p("dashboard.html"), html);
console.log(
  `built dashboard.html — self-contained (${(html.length / 1024).toFixed(0)} KB)`,
);
