import { afterEach, beforeEach, describe, expect, test } from "bun:test";

const checkoutRoute = await import("@/app/api/checkout/route");

function setPolarEnv(): void {
  process.env.POLAR_ACCESS_TOKEN = "polar_test_token";
  process.env.POLAR_PRODUCT_INDIVIDUAL_1 = "prod_individual_1";
  process.env.POLAR_PRODUCT_PERSONAL_3 = "prod_personal_3";
  process.env.POLAR_PRODUCT_POWER_5 = "prod_power_5";
  process.env.POLAR_PRODUCT_CUSTOM = "prod_custom";
}

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
  setPolarEnv();
  captured = [];
  nextStatus = 200;
  globalThis.fetch = (async (input: RequestInfo | URL, init?: RequestInit) => {
    captured.push({
      url: String(input),
      authorization:
        new Headers(init?.headers).get("authorization") ?? null,
      body: JSON.parse(String(init?.body ?? "{}")),
    });

    if (nextStatus !== 200) {
      return new Response("nope", { status: nextStatus });
    }

    return new Response(
      JSON.stringify({
        id: "chk_1",
        url: "https://sandbox.polar.sh/checkout/chk_1",
      }),
      { status: 200, headers: { "content-type": "application/json" } },
    );
  }) as typeof fetch;
});

afterEach(() => {
  globalThis.fetch = originalFetch;
});

describe("machine resolution", () => {
  test("fixed tiers use their own seat count", () => {
    expect(checkoutRoute.resolveMachines("individual_1", undefined)).toBe(1);
    expect(checkoutRoute.resolveMachines("power_5", 5)).toBe(5);
  });

  test("a fixed tier rejects a mismatched seat count", () => {
    expect(checkoutRoute.resolveMachines("personal_3", 9)).toBeNull();
  });

  test("custom accepts its documented range only", () => {
    expect(checkoutRoute.resolveMachines("custom", 6)).toBe(6);
    expect(checkoutRoute.resolveMachines("custom", 50)).toBe(50);
    expect(checkoutRoute.resolveMachines("custom", 5)).toBeNull();
    expect(checkoutRoute.resolveMachines("custom", 51)).toBeNull();
    expect(checkoutRoute.resolveMachines("custom", undefined)).toBeNull();
  });

  test("unknown plans are rejected", () => {
    expect(checkoutRoute.resolveMachines("enterprise", 3)).toBeNull();
  });
});

describe("checkout route", () => {
  test("creates a catalog checkout for a fixed tier", async () => {
    const response = await checkoutRoute.POST(
      checkoutRequest({ planId: "personal_3" }),
    );

    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({
      ok: true,
      url: "https://sandbox.polar.sh/checkout/chk_1",
      checkoutId: "chk_1",
    });

    expect(captured).toHaveLength(1);
    expect(captured[0]?.url).toBe("https://sandbox-api.polar.sh/v1/checkouts/");
    expect(captured[0]?.authorization).toBe("Bearer polar_test_token");
    expect(captured[0]?.body).toMatchObject({
      products: ["prod_personal_3"],
      metadata: { plan_id: "personal_3", machines: 3 },
    });
  });

  test("does not send an ad-hoc price for a fixed tier", async () => {
    await checkoutRoute.POST(checkoutRequest({ planId: "individual_1" }));

    expect(captured[0]?.body.prices).toBeUndefined();
  });

  test("sends a server-computed ad-hoc price for the custom tier", async () => {
    const response = await checkoutRoute.POST(
      checkoutRequest({ planId: "custom", machines: 12 }),
    );

    expect(response.status).toBe(200);
    expect(captured[0]?.body).toMatchObject({
      products: ["prod_custom"],
      metadata: { plan_id: "custom", machines: 12 },
      prices: {
        prod_custom: [
          {
            amount_type: "fixed",
            price_amount: 13500,
            price_currency: "usd",
          },
        ],
      },
    });
  });

  test("passes the buyer email through when supplied", async () => {
    await checkoutRoute.POST(
      checkoutRequest({ planId: "personal_3", email: "buyer@example.com" }),
    );

    expect(captured[0]?.body.customer_email).toBe("buyer@example.com");
  });

  test("omits the email field when absent", async () => {
    await checkoutRoute.POST(checkoutRequest({ planId: "personal_3" }));

    expect(captured[0]?.body.customer_email).toBeUndefined();
  });

  test("includes the checkout id placeholder in the success url", async () => {
    await checkoutRoute.POST(checkoutRequest({ planId: "personal_3" }));

    expect(String(captured[0]?.body.success_url)).toContain(
      "{CHECKOUT_ID}",
    );
  });

  test("rejects a seat count outside the custom range without calling polar", async () => {
    const response = await checkoutRoute.POST(
      checkoutRequest({ planId: "custom", machines: 51 }),
    );

    expect(response.status).toBe(400);
    expect(await response.json()).toEqual({ error: "invalid_plan" });
    expect(captured).toHaveLength(0);
  });

  test("rejects an unknown plan without calling polar", async () => {
    const response = await checkoutRoute.POST(
      checkoutRequest({ planId: "enterprise" }),
    );

    expect(response.status).toBe(400);
    expect(captured).toHaveLength(0);
  });

  test("rejects a malformed body", async () => {
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
});
