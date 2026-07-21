import { createHmac } from "node:crypto";
import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import {
  planIdForProduct,
  polarApiBase,
  polarEventSchema,
  productIdForPlan,
  verifyPolarSignature,
} from "@/lib/polar";

const secret = "polar_whsec_test_value";

function sign(
  rawBody: string,
  id: string,
  timestamp: number,
  withSecret = secret,
): string {
  return createHmac("sha256", Buffer.from(withSecret, "utf8"))
    .update(`${id}.${timestamp}.${rawBody}`, "utf8")
    .digest("base64");
}

function headersFor(
  rawBody: string,
  options: {
    id?: string;
    timestamp?: number;
    signature?: string;
  } = {},
): Headers {
  const id = options.id ?? "msg_123";
  const timestamp = options.timestamp ?? 1_700_000_000;
  const signature = options.signature ?? `v1,${sign(rawBody, id, timestamp)}`;

  return new Headers({
    "webhook-id": id,
    "webhook-timestamp": String(timestamp),
    "webhook-signature": signature,
  });
}

const now = new Date(1_700_000_000 * 1000);

const productEnvNames = [
  "POLAR_PRODUCT_INDIVIDUAL_1",
  "POLAR_PRODUCT_PERSONAL_3",
  "POLAR_PRODUCT_POWER_5",
  "POLAR_PRODUCT_CUSTOM",
];

function clearProductEnv(): void {
  for (const name of productEnvNames) {
    delete process.env[name];
  }
}

beforeEach(clearProductEnv);

afterEach(() => {
  delete process.env.POLAR_WEBHOOK_SECRET;
  delete process.env.POLAR_SERVER;
  clearProductEnv();
});

describe("polar webhook signatures", () => {
  test("accepts a correctly signed payload", () => {
    process.env.POLAR_WEBHOOK_SECRET = secret;
    const body = '{"type":"order.paid"}';

    expect(verifyPolarSignature(body, headersFor(body), now)).toBe(true);
  });

  test("rejects a payload signed with a different secret", () => {
    process.env.POLAR_WEBHOOK_SECRET = secret;
    const body = '{"type":"order.paid"}';
    const forged = `v1,${sign(body, "msg_123", 1_700_000_000, "wrong")}`;

    expect(
      verifyPolarSignature(body, headersFor(body, { signature: forged }), now),
    ).toBe(false);
  });

  test("rejects a tampered body", () => {
    process.env.POLAR_WEBHOOK_SECRET = secret;
    const body = '{"type":"order.paid"}';
    const headers = headersFor(body);

    expect(
      verifyPolarSignature('{"type":"order.refunded"}', headers, now),
    ).toBe(false);
  });

  test("rejects a signature bound to a different message id", () => {
    process.env.POLAR_WEBHOOK_SECRET = secret;
    const body = '{"type":"order.paid"}';
    const headers = headersFor(body);
    headers.set("webhook-id", "msg_other");

    expect(verifyPolarSignature(body, headers, now)).toBe(false);
  });

  test("rejects timestamps outside the tolerance window", () => {
    process.env.POLAR_WEBHOOK_SECRET = secret;
    const body = '{"type":"order.paid"}';
    const stale = 1_700_000_000 - 301;
    const ahead = 1_700_000_000 + 301;

    expect(
      verifyPolarSignature(body, headersFor(body, { timestamp: stale }), now),
    ).toBe(false);
    expect(
      verifyPolarSignature(body, headersFor(body, { timestamp: ahead }), now),
    ).toBe(false);
  });

  test("accepts timestamps inside the tolerance window", () => {
    process.env.POLAR_WEBHOOK_SECRET = secret;
    const body = '{"type":"order.paid"}';
    const recent = 1_700_000_000 - 299;

    expect(
      verifyPolarSignature(body, headersFor(body, { timestamp: recent }), now),
    ).toBe(true);
  });

  test("accepts when one of several signatures matches", () => {
    process.env.POLAR_WEBHOOK_SECRET = secret;
    const body = '{"type":"order.paid"}';
    const valid = sign(body, "msg_123", 1_700_000_000);
    const signature = `v1,${sign(body, "msg_123", 1_700_000_000, "other")} v1,${valid}`;

    expect(
      verifyPolarSignature(body, headersFor(body, { signature }), now),
    ).toBe(true);
  });

  test("ignores signatures with an unknown version prefix", () => {
    process.env.POLAR_WEBHOOK_SECRET = secret;
    const body = '{"type":"order.paid"}';
    const signature = `v2,${sign(body, "msg_123", 1_700_000_000)}`;

    expect(
      verifyPolarSignature(body, headersFor(body, { signature }), now),
    ).toBe(false);
  });

  test("rejects malformed and empty signature headers", () => {
    process.env.POLAR_WEBHOOK_SECRET = secret;
    const body = '{"type":"order.paid"}';

    for (const signature of ["", "garbage", "v1,", "v1,!!!!not-base64"]) {
      expect(
        verifyPolarSignature(body, headersFor(body, { signature }), now),
      ).toBe(false);
    }
  });

  test("rejects a non-numeric timestamp", () => {
    process.env.POLAR_WEBHOOK_SECRET = secret;
    const body = '{"type":"order.paid"}';
    const headers = headersFor(body);
    headers.set("webhook-timestamp", "not-a-number");

    expect(verifyPolarSignature(body, headers, now)).toBe(false);
  });

  test("rejects when any required header is missing", () => {
    process.env.POLAR_WEBHOOK_SECRET = secret;
    const body = '{"type":"order.paid"}';

    for (const header of [
      "webhook-id",
      "webhook-timestamp",
      "webhook-signature",
    ]) {
      const headers = headersFor(body);
      headers.delete(header);
      expect(verifyPolarSignature(body, headers, now)).toBe(false);
    }
  });

  test("accepts a whsec_ secret hashed as raw utf8 bytes", () => {
    const prefixed = "whsec_7PxkYhXUqm0rBrMf6THmujRtZ8BEtGLXsEfxQ0Qxugj";
    process.env.POLAR_WEBHOOK_SECRET = prefixed;
    const body = '{"type":"order.paid"}';
    const signature = `v1,${sign(body, "msg_123", 1_700_000_000, prefixed)}`;

    expect(
      verifyPolarSignature(body, headersFor(body, { signature }), now),
    ).toBe(true);
  });

  test("accepts a whsec_ secret hashed as base64-decoded bytes", () => {
    const prefixed = "whsec_7PxkYhXUqm0rBrMf6THmujRtZ8BEtGLXsEfxQ0Qxugj";
    process.env.POLAR_WEBHOOK_SECRET = prefixed;
    const body = '{"type":"order.paid"}';
    const decodedKey = Buffer.from(prefixed.slice(6), "base64");
    const signature = `v1,${createHmac("sha256", decodedKey)
      .update(`msg_123.1700000000.${body}`, "utf8")
      .digest("base64")}`;

    expect(
      verifyPolarSignature(body, headersFor(body, { signature }), now),
    ).toBe(true);
  });

  test("still rejects a wrong secret even with both encodings tried", () => {
    process.env.POLAR_WEBHOOK_SECRET = "whsec_realsecretvalue";
    const body = '{"type":"order.paid"}';
    const forged = `v1,${sign(body, "msg_123", 1_700_000_000, "whsec_attackerguess")}`;

    expect(
      verifyPolarSignature(body, headersFor(body, { signature: forged }), now),
    ).toBe(false);
  });

  test("rejects when no secret is configured", () => {
    const body = '{"type":"order.paid"}';

    expect(verifyPolarSignature(body, headersFor(body), now)).toBe(false);
  });
});

describe("polar environment", () => {
  test("defaults to the sandbox api", () => {
    expect(polarApiBase()).toBe("https://sandbox-api.polar.sh");
  });

  test("uses production only when explicitly selected", () => {
    process.env.POLAR_SERVER = "production";
    expect(polarApiBase()).toBe("https://api.polar.sh");
  });

  test("maps plans to configured product ids and back", () => {
    process.env.POLAR_PRODUCT_INDIVIDUAL_1 = "prod_individual";
    process.env.POLAR_PRODUCT_CUSTOM = "prod_custom";

    expect(productIdForPlan("individual_1")).toBe("prod_individual");
    expect(planIdForProduct("prod_individual")).toBe("individual_1");
    expect(planIdForProduct("prod_custom")).toBe("custom");
    expect(planIdForProduct("prod_unknown")).toBeNull();
  });

  test("throws when a product id is not configured", () => {
    expect(() => productIdForPlan("power_5")).toThrow();
  });

  test("does not match an unset product env against an empty id", () => {
    expect(planIdForProduct("")).toBeNull();
  });
});

describe("polar event parsing", () => {
  test("accepts an order with a null customer email", () => {
    const parsed = polarEventSchema.parse({
      type: "order.paid",
      data: {
        id: "ord_1",
        status: "paid",
        paid: true,
        product_id: "prod_individual",
        customer: { email: null, name: null },
        metadata: { plan_id: "individual_1", machines: 1 },
      },
    });

    expect(parsed.data.customer?.email).toBeNull();
    expect(parsed.data.metadata?.machines).toBe(1);
  });

  test("keeps unknown fields without failing", () => {
    const parsed = polarEventSchema.parse({
      type: "order.paid",
      data: { id: "ord_1", something_new: true },
    });

    expect(parsed.data.id).toBe("ord_1");
  });

  test("rejects an event without a type or order id", () => {
    expect(() => polarEventSchema.parse({ data: { id: "ord_1" } })).toThrow();
    expect(() =>
      polarEventSchema.parse({ type: "order.paid", data: {} }),
    ).toThrow();
  });
});
