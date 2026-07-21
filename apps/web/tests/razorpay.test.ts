import { createHmac } from "node:crypto";
import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import {
  RazorpayConfigError,
  razorpayApiBase,
  razorpayEventSchema,
  razorpayMode,
  verifyRazorpaySignature,
} from "@/lib/razorpay";

const webhookSecret = "razorpay_webhook_test_secret";

function sign(rawBody: string, secret = webhookSecret): string {
  return createHmac("sha256", secret).update(rawBody, "utf8").digest("hex");
}

function signatureHeaders(rawBody: string, signature = sign(rawBody)): Headers {
  return new Headers({ "x-razorpay-signature": signature });
}

function paidEvent(overrides: Record<string, unknown> = {}): unknown {
  return {
    event: "payment_link.paid",
    payload: {
      payment_link: {
        entity: {
          id: "plink_1",
          amount: 380000,
          amount_paid: 380000,
          currency: "INR",
          status: "paid",
          notes: { plan_id: "personal_3", machines: "3" },
          customer: { email: "buyer@example.com", name: "Buyer" },
        },
      },
      payment: {
        entity: {
          id: "pay_1",
          amount: 380000,
          base_amount: 380000,
          currency: "INR",
          status: "captured",
          captured: true,
        },
      },
      order: {
        entity: {
          id: "order_1",
          amount: 380000,
          amount_paid: 380000,
          currency: "INR",
          status: "paid",
        },
      },
      ...overrides,
    },
  };
}

beforeEach(() => {
  process.env.RAZORPAY_WEBHOOK_SECRET = webhookSecret;
});

afterEach(() => {
  delete process.env.RAZORPAY_KEY_ID;
  delete process.env.RAZORPAY_KEY_SECRET;
  delete process.env.RAZORPAY_WEBHOOK_SECRET;
});

describe("razorpay webhook signatures", () => {
  test("accepts a valid signature", () => {
    const body = JSON.stringify(paidEvent());

    expect(verifyRazorpaySignature(body, signatureHeaders(body))).toBe(true);
  });

  test("rejects a signature made with the wrong secret", () => {
    const body = JSON.stringify(paidEvent());

    expect(
      verifyRazorpaySignature(body, signatureHeaders(body, sign(body, "wrong"))),
    ).toBe(false);
  });

  test("rejects a tampered body", () => {
    const body = JSON.stringify(paidEvent());

    expect(
      verifyRazorpaySignature(`${body} `, signatureHeaders(body)),
    ).toBe(false);
  });

  test("rejects malformed and empty signatures", () => {
    const body = JSON.stringify(paidEvent());

    for (const signature of ["", "not-hex", "abcd", `${sign(body)}00`]) {
      expect(
        verifyRazorpaySignature(body, signatureHeaders(body, signature)),
      ).toBe(false);
    }
  });

  test("rejects a missing webhook secret", () => {
    const body = JSON.stringify(paidEvent());
    delete process.env.RAZORPAY_WEBHOOK_SECRET;

    expect(verifyRazorpaySignature(body, signatureHeaders(body))).toBe(false);
  });

  test("does not throw for a length mismatch", () => {
    const body = JSON.stringify(paidEvent());

    expect(() =>
      verifyRazorpaySignature(body, signatureHeaders(body, "00")),
    ).not.toThrow();
    expect(
      verifyRazorpaySignature(body, signatureHeaders(body, "00")),
    ).toBe(false);
  });
});

describe("razorpay payload parsing", () => {
  test("accepts payment_link.paid", () => {
    const parsed = razorpayEventSchema.parse(paidEvent());

    expect(parsed.event).toBe("payment_link.paid");
    expect(parsed.payload.payment_link?.entity.notes?.machines).toBe("3");
  });

  test("tolerates unknown fields", () => {
    const parsed = razorpayEventSchema.parse({
      ...(paidEvent() as Record<string, unknown>),
      future_field: true,
    });

    expect(parsed.future_field).toBe(true);
  });

  test("rejects missing required paid fields", () => {
    expect(() =>
      razorpayEventSchema.parse({
        event: "payment_link.paid",
        payload: {},
      }),
    ).toThrow();
  });

  test("rejects a non-numeric machines note", () => {
    const event = paidEvent({
      payment_link: {
        entity: {
          id: "plink_1",
          amount: 380000,
          amount_paid: 380000,
          currency: "INR",
          status: "paid",
          notes: { plan_id: "personal_3", machines: "three" },
        },
      },
    });

    expect(() => razorpayEventSchema.parse(event)).toThrow();
  });
});

describe("razorpay environment", () => {
  test("uses one api base for test and live keys", () => {
    process.env.RAZORPAY_KEY_SECRET = "secret";
    process.env.RAZORPAY_KEY_ID = "rzp_test_example";
    expect(razorpayMode()).toBe("test");
    expect(razorpayApiBase).toBe("https://api.razorpay.com/v1");

    process.env.RAZORPAY_KEY_ID = "rzp_live_example";
    expect(razorpayMode()).toBe("live");
    expect(razorpayApiBase).toBe("https://api.razorpay.com/v1");
  });

  test("throws a clear config error when credentials are absent", () => {
    expect(() => razorpayMode()).toThrow(RazorpayConfigError);
    expect(() => razorpayMode()).toThrow("Missing RAZORPAY_KEY_ID");

    process.env.RAZORPAY_KEY_ID = "rzp_test_example";
    expect(() => razorpayMode()).toThrow("Missing RAZORPAY_KEY_SECRET");
  });

  test("rejects a key without a test or live prefix", () => {
    process.env.RAZORPAY_KEY_ID = "invalid_key";
    process.env.RAZORPAY_KEY_SECRET = "secret";

    expect(() => razorpayMode()).toThrow(RazorpayConfigError);
  });
});
