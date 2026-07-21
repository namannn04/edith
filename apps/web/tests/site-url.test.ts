import { afterEach, describe, expect, test } from "bun:test";
import { siteUrl } from "@/lib/http";

afterEach(() => {
  delete process.env.SITE_URL;
  delete process.env.VERCEL_BRANCH_URL;
  delete process.env.VERCEL_URL;
});

describe("site url resolution", () => {
  test("prefers an explicit SITE_URL", () => {
    process.env.SITE_URL = "http://localhost:3000";
    process.env.VERCEL_URL = "edith-abc123.vercel.app";

    expect(siteUrl()).toBe("http://localhost:3000");
  });

  test("falls back to the stable branch url on preview", () => {
    process.env.VERCEL_BRANCH_URL = "edith-git-polar-payments.vercel.app";
    process.env.VERCEL_URL = "edith-abc123.vercel.app";

    expect(siteUrl()).toBe("https://edith-git-polar-payments.vercel.app");
  });

  test("falls back to the deployment url when no branch url exists", () => {
    process.env.VERCEL_URL = "edith-abc123.vercel.app";

    expect(siteUrl()).toBe("https://edith-abc123.vercel.app");
  });

  test("falls back to production when nothing is set", () => {
    expect(siteUrl()).toBe("https://edith.pulkit.page");
  });

  test("never emits a double slash before the path", () => {
    process.env.SITE_URL = "https://edith.pulkit.page/";

    expect(`${siteUrl()}/thanks`).toBe("https://edith.pulkit.page/thanks");
  });

  test("tolerates a scheme already present on the vercel host", () => {
    process.env.VERCEL_URL = "https://edith-abc123.vercel.app";

    expect(siteUrl()).toBe("https://edith-abc123.vercel.app");
  });
});
