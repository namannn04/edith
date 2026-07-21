import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { resolveMachines } from "@/lib/pricing";

const checkoutRoute = await import("@/app/api/checkout/route");

type Captured = {
  url: string;
  authorization: string | null;
  body: Record<string, unknown>;
};

const originalFetch = globalThis.fetch;
let captured: Captured[] = [];
let nextStatus = 200;
let ipCounter = 0;

function nextIp(): string {
  ipCounter += 1;
  return `10.9.${Math.floor(ipCounter / 250)}.${ipCounter % 250}`;
}

function checkoutRequest(body: unknown): Request {
  return new Request("https://edith.test/api/checkout", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-forwarded-for": nextIp(),
    },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

beforeEach(() => {
  process.env.RAZORPAY_KEY_ID = "rzp_test_checkout";
  process.env.RAZORPAY_KEY_SECRET = "checkout_secret";
  captured = [];
  nextStatus = 200;
  globalThis.fetch = (async (input: RequestInfo | URL, init?: RequestInit) => {
    captured.push({
      url: String(input),
      authorization: new Headers(init?.headers).get("authorization"),
      body: JSON.parse(String(init?.body ?? "{}")),
    });

    if (nextStatus !== 200) {
      return new Response("nope", { status: nextStatus });
    }

    return Response.json({
      id: "plink_1",
      short_url: "https://rzp.io/i/plink_1",
    });
  }) as typeof fetch;
});

afterEach(() => {
  globalThis.fetch = originalFetch;
  delete process.env.RAZORPAY_KEY_ID;
  delete process.env.RAZORPAY_KEY_SECRET;
});

describe("machine resolution", () => {
  test("fixed tiers use their own seat count", () => {
    expect(resolveMachines("individual_1", undefined)).toBe(1);
    expect(resolveMachines("power_5", 5)).toBe(5);
  });

  test("a fixed tier rejects a mismatched seat count", () => {
    expect(resolveMachines("personal_3", 2)).toBeNull();
  });

  test("custom accepts 6 through 50 only", () => {
    expect(resolveMachines("custom", 6)).toBe(6);
    expect(resolveMachines("custom", 50)).toBe(50);
    expect(resolveMachines("custom", 5)).toBeNull();
    expect(resolveMachines("custom", 51)).toBeNull();
    expect(resolveMachines("custom", undefined)).toBeNull();
  });
});

describe("checkout route", () => {
  test("creates a Razorpay payment link for a fixed tier", async () => {
    const response = await checkoutRoute.POST(
      checkoutRequest({ planId: "personal_3" }),
    );

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({
      ok: true,
      url: "https://rzp.io/i/plink_1",
      checkoutId: "plink_1",
    });
    expect(captured).toHaveLength(1);
    expect(captured[0]?.url).toBe(
      "https://api.razorpay.com/v1/payment_links",
    );
    expect(captured[0]?.authorization).toBe(
      `Basic ${Buffer.from("rzp_test_checkout:checkout_secret").toString("base64")}`,
    );
    expect(captured[0]?.body).toEqual({
      amount: 380000,
      currency: "INR",
      accept_partial: false,
      description: "Edith Personal licence for 3 Macs",
      notes: { plan_id: "personal_3", machines: "3" },
      callback_url: "https://edith.pulkit.page/thanks",
      callback_method: "get",
    });
  });

  test("uses the server-computed INR amount for custom seats", async () => {
    const response = await checkoutRoute.POST(
      checkoutRequest({ planId: "custom", machines: 12 }),
    );

    expect(response.status).toBe(200);
    expect(captured[0]?.body).toMatchObject({
      amount: 1145000,
      currency: "INR",
      notes: { plan_id: "custom", machines: "12" },
    });
  });

  test("passes the buyer email through when supplied", async () => {
    await checkoutRoute.POST(
      checkoutRequest({ planId: "personal_3", email: "buyer@example.com" }),
    );

    expect(captured[0]?.body.customer).toEqual({ email: "buyer@example.com" });
  });

  test("rejects a mismatched fixed-tier seat count", async () => {
    const response = await checkoutRoute.POST(
      checkoutRequest({ planId: "personal_3", machines: 2 }),
    );

    expect(response.status).toBe(400);
    expect(await response.json()).toEqual({ error: "invalid_plan" });
    expect(captured).toHaveLength(0);
  });

  test("rejects custom seat counts below and above the allowed range", async () => {
    for (const machines of [5, 51]) {
      const response = await checkoutRoute.POST(
        checkoutRequest({ planId: "custom", machines }),
      );

      expect(response.status).toBe(400);
      expect(await response.json()).toEqual({ error: "invalid_plan" });
    }

    expect(captured).toHaveLength(0);
  });

  test("accepts both custom range boundaries", async () => {
    for (const machines of [6, 50]) {
      const response = await checkoutRoute.POST(
        checkoutRequest({ planId: "custom", machines }),
      );

      expect(response.status).toBe(200);
    }

    expect(captured).toHaveLength(2);
  });

  test("rejects an unknown plan without calling Razorpay", async () => {
    const response = await checkoutRoute.POST(
      checkoutRequest({ planId: "enterprise" }),
    );

    expect(response.status).toBe(400);
    expect(captured).toHaveLength(0);
  });

  test("rejects malformed JSON", async () => {
    const response = await checkoutRoute.POST(checkoutRequest("not json"));

    expect(response.status).toBe(400);
    expect(await response.json()).toEqual({ error: "invalid_request" });
  });

  test("surfaces an upstream failure as 502", async () => {
    nextStatus = 500;

    const response = await checkoutRoute.POST(
      checkoutRequest({ planId: "personal_3" }),
    );

    expect(response.status).toBe(502);
    expect(await response.json()).toEqual({ error: "checkout_failed" });
  });

  test("surfaces missing configuration as 503", async () => {
    delete process.env.RAZORPAY_KEY_SECRET;

    const response = await checkoutRoute.POST(
      checkoutRequest({ planId: "personal_3" }),
    );

    expect(response.status).toBe(503);
    expect(await response.json()).toEqual({ error: "checkout_unavailable" });
    expect(captured).toHaveLength(0);
  });
});
