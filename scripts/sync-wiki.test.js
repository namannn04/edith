import { expect, test } from "bun:test";
import { readdirSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { buildPages, collect, mapTarget, rewriteLinks } from "./sync-wiki.mjs";

const repoRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);

const docs = collect();
const slugMap = new Map(docs.map((d) => [d.src, d.slug]));
const dirMap = new Map([["docs/cli", "CLI"]]);
const options = {
  root: repoRoot,
  slugMap,
  dirMap,
  blobBase: "https://github.com/pulkitxm/edith/blob/main",
};

test("every markdown file under docs/cli becomes a page", () => {
  const files = readdirSync(path.join(repoRoot, "docs/cli")).filter((f) =>
    f.endsWith(".md"),
  );
  expect(docs.length).toBe(files.length);
});

test("the index page is the section slug and comes first", () => {
  const index = docs.find((d) => d.src === "docs/cli/README.md");
  expect(index.slug).toBe("CLI");
  expect(index.isIndex).toBe(true);
  expect(index.order).toBe(-1);
});

test("page slugs are prefixed and title cased", () => {
  const machines = docs.find((d) => d.src === "docs/cli/machines-docker.md");
  expect(machines.slug).toBe("CLI-Machines-Docker");
  expect(machines.title).toBe("Machines Docker");
});

test("slugs are unique", () => {
  const slugs = docs.map((d) => d.slug);
  expect(new Set(slugs).size).toBe(slugs.length);
});

test("sibling doc links become wiki slugs", () => {
  expect(mapTarget("./config.md", "docs/cli", options)).toBe("CLI-Config");
  expect(mapTarget("./README.md", "docs/cli", options)).toBe("CLI");
});

test("anchors and link titles survive rewriting", () => {
  expect(mapTarget("./usage.md#ed-usage-daily", "docs/cli", options)).toBe(
    "CLI-Usage#ed-usage-daily",
  );
});

test("external and anchor-only links are left alone", () => {
  expect(mapTarget("https://example.com", "docs/cli", options)).toBeNull();
  expect(mapTarget("#install", "docs/cli", options)).toBeNull();
  expect(
    mapTarget("mailto:someone@example.com", "docs/cli", options),
  ).toBeNull();
});

test("links to repo files outside docs become blob urls", () => {
  expect(mapTarget("../../README.md", "docs/cli", options)).toBe(
    "https://github.com/pulkitxm/edith/blob/main/README.md",
  );
});

test("links inside fenced blocks are not rewritten", () => {
  const source = ["```", "[a](./config.md)", "```", "[b](./config.md)"].join(
    "\n",
  );
  const rewritten = rewriteLinks(source, "docs/cli", options);
  expect(rewritten).toContain("[a](./config.md)");
  expect(rewritten).toContain("[b](CLI-Config)");
});

test("wiki build emits Home, sidebar and footer", () => {
  const pages = buildPages();
  expect(pages.has("Home.md")).toBe(true);
  expect(pages.has("_Sidebar.md")).toBe(true);
  expect(pages.has("_Footer.md")).toBe(true);
  expect(pages.has("CLI.md")).toBe(true);
});

test("the sidebar lists getting started before the machine pages", () => {
  const sidebar = buildPages().get("_Sidebar.md");
  expect(sidebar.indexOf("CLI-Getting-Started")).toBeLessThan(
    sidebar.indexOf("CLI-Machines-Docker"),
  );
});

test("every page ends with exactly one newline", () => {
  for (const [name, content] of buildPages()) {
    expect(content.endsWith("\n")).toBe(true);
    expect(content.endsWith("\n\n")).toBe(false);
    expect(name.endsWith(".md")).toBe(true);
  }
});
