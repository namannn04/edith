import { describe, expect, test } from "bun:test";
import { parseFrontMatter } from "../src/frontmatter";

describe("parseFrontMatter", () => {
  test("parses a plain date", () => {
    const result = parseFrontMatter("---\ndate: 2026-08-09\n---\n# Note");
    expect(result.date?.toISOString()).toBe("2026-08-09T00:00:00.000Z");
  });

  test("parses created and occurred_at ISO dates", () => {
    const created = parseFrontMatter(
      "---\ncreated: 2026-08-09T10:15:30+05:30\n---",
    );
    const occurred = parseFrontMatter(
      "---\noccurred_at: '2026-08-08T04:00:00Z'\n---",
    );
    expect(created.date?.toISOString()).toBe("2026-08-09T04:45:30.000Z");
    expect(occurred.date?.toISOString()).toBe("2026-08-08T04:00:00.000Z");
  });

  test("returns null fields without front matter or a heading", () => {
    expect(parseFrontMatter("ordinary text")).toEqual({
      date: null,
      title: null,
    });
  });

  test("uses the first h1 as a title fallback", () => {
    expect(parseFrontMatter("intro\n# First\n# Second").title).toBe("First");
  });

  test("prefers the front matter title", () => {
    const result = parseFrontMatter(
      '---\ntitle: "Front Matter"\n---\n# Heading',
    );
    expect(result.title).toBe("Front Matter");
  });
});
