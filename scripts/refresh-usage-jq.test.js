import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const script = readFileSync(
  join(import.meta.dir, "..", "apps", "macos", "Resources", "refresh-usage"),
  "utf8",
);

function extractBlock(name) {
  const m = script.match(new RegExp(`\\n\\s*${name}='([\\s\\S]*?)\\n\\s*'`));
  expect(m).not.toBeNull();
  return m[1];
}

const NORM = extractBlock("NORM");
const WALK = extractBlock("WALK");

function jq(program, input, args = []) {
  const proc = Bun.spawnSync(["jq", "-c", ...args, program], {
    stdin: Buffer.from(input),
  });
  expect(proc.exitCode).toBe(0);
  return proc.stdout
    .toString()
    .trim()
    .split("\n")
    .filter(Boolean)
    .map((l) => JSON.parse(l));
}

const walk = (lines, src = "cli", off = 0) =>
  jq(WALK, lines.map((l) => JSON.stringify(l)).join("\n"), [
    "--argjson",
    "off",
    String(off),
    "--arg",
    "src",
    src,
  ]);

const assistant = (over = {}) => ({
  type: "assistant",
  timestamp: "2026-06-10T12:30:00.123Z",
  sessionId: "sess-1",
  cwd: "/repo/app",
  requestId: "req-1",
  message: {
    id: "msg-1",
    model: "claude-opus-4-8",
    usage: {
      input_tokens: 10,
      output_tokens: 20,
      cache_creation_input_tokens: 30,
      cache_read_input_tokens: 40,
    },
  },
  ...over,
});

describe("WALK", () => {
  test("assistant line becomes a rec with token sum, epoch ms, and source", () => {
    const [rec] = walk([assistant()]);
    expect(rec.t).toBe("rec");
    expect(rec.tok).toBe(100);
    expect(rec.ts).toBe(Date.parse("2026-06-10T12:30:00Z"));
    expect(rec.date).toBe("2026-06-10");
    expect(rec.hour).toBe(12);
    expect(rec.src).toBe("cli");
    expect(rec.sid).toBe("sess-1");
    expect(rec.wt).toBeNull();
  });

  test("timezone offset shifts date and hour", () => {
    const [rec] = walk(
      [assistant({ timestamp: "2026-06-10T23:30:00Z" })],
      "cli",
      3600,
    );
    expect(rec.date).toBe("2026-06-11");
    expect(rec.hour).toBe(0);
  });

  test("worktree name extracted from claude and cursor markers", () => {
    const [a, b, c] = walk([
      assistant({ cwd: "/repo/app/.claude/worktrees/featx/sub" }),
      assistant({ cwd: "/repo/app/.cursor/worktrees/fix-1" }),
      assistant({ cwd: "/repo/app/src" }),
    ]);
    expect(a.wt).toBe("featx");
    expect(b.wt).toBe("fix-1");
    expect(c.wt).toBeNull();
  });

  test("assistant without usage or without any id is skipped", () => {
    const recs = walk([
      assistant({ message: { id: "m2", model: "m", usage: null } }),
      assistant({
        requestId: null,
        message: { model: "m", usage: { input_tokens: 1 } },
      }),
      assistant(),
    ]);
    expect(recs.length).toBe(1);
    expect(recs[0].id).toBe("msg-1");
  });

  test("ai-title lines become trimmed title records", () => {
    const out = walk([
      { type: "ai-title", aiTitle: "  Fix the bug  ", sessionId: "s1" },
      { type: "ai-title", aiTitle: "", sessionId: "s2" },
      { type: "ai-title", aiTitle: "No session" },
    ]);
    expect(out).toEqual([{ t: "title", sid: "s1", title: "Fix the bug" }]);
  });

  test("user text records: string + array content, tag-prefixed skipped, 80-char cap", () => {
    const long = "x".repeat(200);
    const out = walk([
      {
        type: "user",
        sessionId: "s1",
        timestamp: "t1",
        message: { content: "hello" },
      },
      {
        type: "user",
        sessionId: "s2",
        timestamp: "t2",
        message: {
          content: [
            { type: "tool_result" },
            { type: "text", text: " block text " },
          ],
        },
      },
      {
        type: "user",
        sessionId: "s3",
        message: { content: "<system-reminder>hi" },
      },
      { type: "user", sessionId: "s4", message: { content: long } },
      { type: "user", message: { content: "no session" } },
    ]);
    expect(out[0]).toEqual({ t: "text", sid: "s1", tms: "t1", text: "hello" });
    expect(out[1].text).toBe("block text");
    expect(out.length).toBe(3);
    expect(out[2].text.length).toBe(80);
  });
});

describe("NORM", () => {
  const norm = (daily) =>
    jq(
      `${NORM} [.daily[] | normDay | .breakdowns |= dropSynthetic]`,
      JSON.stringify({ daily }),
    )[0];

  test("claude shape keeps per-model rows and folds reasoning into output", () => {
    const [day] = norm([
      {
        date: "2026-06-10",
        modelBreakdowns: [
          {
            modelName: "opus",
            inputTokens: 1,
            outputTokens: 2,
            reasoningOutputTokens: 3,
            cacheCreationTokens: 4,
            cacheReadTokens: 5,
            cost: 9,
          },
        ],
      },
    ]);
    expect(day.period).toBe("2026-06-10");
    expect(day.breakdowns[0].outputTokens).toBe(5);
    expect(day.breakdowns[0].cost).toBe(9);
  });

  test("codex shape splits row cost by token share", () => {
    const [day] = norm([
      {
        date: "2026-06-10",
        costUSD: 10,
        models: {
          a: { inputTokens: 30, outputTokens: 0 },
          b: { inputTokens: 10, outputTokens: 0 },
        },
      },
    ]);
    const byName = Object.fromEntries(
      day.breakdowns.map((b) => [b.modelName, b]),
    );
    expect(byName.a.cost).toBeCloseTo(7.5);
    expect(byName.b.cost).toBeCloseTo(2.5);
  });

  test("opencode shape splits row evenly across modelsUsed", () => {
    const [day] = norm([
      {
        date: "2026-06-10",
        totalCost: 8,
        inputTokens: 100,
        outputTokens: 20,
        modelsUsed: ["a", "b"],
      },
    ]);
    expect(day.breakdowns.length).toBe(2);
    expect(day.breakdowns[0].inputTokens).toBe(50);
    expect(day.breakdowns[0].cost).toBe(4);
  });

  test("zero-token zero-cost synthetic rows dropped, tokened ones kept", () => {
    const [day] = norm([
      {
        date: "2026-06-10",
        modelBreakdowns: [
          {
            modelName: "<synthetic>",
            inputTokens: 0,
            outputTokens: 0,
            cost: 0,
          },
          {
            modelName: "<synthetic>",
            inputTokens: 7,
            outputTokens: 0,
            cost: 0,
          },
          { modelName: "real", inputTokens: 0, outputTokens: 0, cost: 0 },
        ],
      },
    ]);
    expect(day.breakdowns.map((b) => b.modelName)).toEqual([
      "<synthetic>",
      "real",
    ]);
    expect(day.breakdowns[0].inputTokens).toBe(7);
  });
});
