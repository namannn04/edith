import { createHmac, timingSafeEqual } from "node:crypto";
import { z } from "zod";

export const razorpayProvider = "razorpay";
export const razorpayApiBase = "https://api.razorpay.com/v1";

export class RazorpayConfigError extends Error {}

function razorpayCredentials(): { keyId: string; keySecret: string } {
  const keyId = process.env.RAZORPAY_KEY_ID;
  const keySecret = process.env.RAZORPAY_KEY_SECRET;

  if (!keyId) {
    throw new RazorpayConfigError("Missing RAZORPAY_KEY_ID");
  }

  if (!keySecret) {
    throw new RazorpayConfigError("Missing RAZORPAY_KEY_SECRET");
  }

  return { keyId, keySecret };
}

export function razorpayMode(): "test" | "live" {
  const { keyId } = razorpayCredentials();

  if (keyId.startsWith("rzp_test_")) {
    return "test";
  }

  if (keyId.startsWith("rzp_live_")) {
    return "live";
  }

  throw new RazorpayConfigError("RAZORPAY_KEY_ID must be a test or live key");
}

export function verifyRazorpaySignature(
  rawBody: string,
  headers: Headers,
): boolean {
  const secret = process.env.RAZORPAY_WEBHOOK_SECRET;
  const signature = headers.get("x-razorpay-signature");

  if (!secret || !signature || !/^[a-f\d]{64}$/i.test(signature)) {
    return false;
  }

  const expected = createHmac("sha256", secret).update(rawBody, "utf8").digest();
  const provided = Buffer.from(signature, "hex");

  return (
    provided.length === expected.length && timingSafeEqual(expected, provided)
  );
}

const noteValueSchema = z.string().max(256);
const notesSchema = z.record(noteValueSchema);
const machinesNoteSchema = z
  .string()
  .regex(/^\d+$/)
  .refine((value) => {
    const machines = Number(value);
    return Number.isInteger(machines) && machines >= 1 && machines <= 50;
  });

const paymentLinkEntitySchema = z
  .object({
    id: z.string().min(1).max(255),
    amount: z.number().int().nonnegative(),
    amount_paid: z.number().int().nonnegative(),
    currency: z.string().min(1).max(10),
    status: z.string().min(1).max(50),
    notes: notesSchema.nullish(),
    customer: z
      .object({
        email: z.string().max(320).nullish(),
        name: z.string().max(255).nullish(),
      })
      .passthrough()
      .nullish(),
    order_id: z.string().max(255).nullish(),
  })
  .passthrough();

const paymentEntitySchema = z
  .object({
    id: z.string().min(1).max(255),
    amount: z.number().int().nonnegative(),
    amount_refunded: z.number().int().nonnegative().nullish(),
    base_amount: z.number().int().nonnegative().nullish(),
    currency: z.string().min(1).max(10),
    status: z.string().min(1).max(50),
    captured: z.boolean().nullish(),
    email: z.string().max(320).nullish(),
    contact: z.string().max(50).nullish(),
    customer_id: z.string().max(255).nullish(),
    order_id: z.string().max(255).nullish(),
    offer_id: z.string().max(255).nullish(),
  })
  .passthrough();

const orderEntitySchema = z
  .object({
    id: z.string().min(1).max(255),
    amount: z.number().int().nonnegative(),
    amount_paid: z.number().int().nonnegative(),
    currency: z.string().min(1).max(10),
    status: z.string().min(1).max(50),
    customer_id: z.string().max(255).nullish(),
    offer_id: z.string().max(255).nullish(),
  })
  .passthrough();

const refundEntitySchema = z
  .object({
    id: z.string().min(1).max(255),
    payment_id: z.string().min(1).max(255),
    amount: z.number().int().nonnegative(),
    currency: z.string().min(1).max(10),
    status: z.string().min(1).max(50),
  })
  .passthrough();

export const razorpayEventSchema = z
  .object({
    event: z.string().min(1).max(100),
    payload: z
      .object({
        payment_link: z
          .object({ entity: paymentLinkEntitySchema })
          .passthrough()
          .optional(),
        payment: z
          .object({ entity: paymentEntitySchema })
          .passthrough()
          .optional(),
        order: z
          .object({ entity: orderEntitySchema })
          .passthrough()
          .optional(),
        refund: z
          .object({ entity: refundEntitySchema })
          .passthrough()
          .optional(),
      })
      .passthrough(),
  })
  .passthrough()
  .superRefine((value, context) => {
    if (value.event === "payment_link.paid") {
      const link = value.payload.payment_link?.entity;
      const payment = value.payload.payment?.entity;
      const order = value.payload.order?.entity;

      if (!link || !payment || !order) {
        context.addIssue({ code: "custom", message: "Missing paid entities" });
        return;
      }

      const planId = link.notes?.plan_id;
      const machines = link.notes?.machines;

      if (!planId || !machinesNoteSchema.safeParse(machines).success) {
        context.addIssue({ code: "custom", message: "Invalid plan notes" });
      }
    }

    if (
      value.event === "refund.created" &&
      (!value.payload.refund || !value.payload.payment)
    ) {
      context.addIssue({ code: "custom", message: "Missing refund entities" });
    }
  });

export type RazorpayEvent = z.infer<typeof razorpayEventSchema>;

export type PaymentLinkRequest = {
  planId: string;
  planName: string;
  machines: number;
  amountPaise: number;
  callbackUrl: string;
  customerEmail?: string;
};

export type PaymentLink = {
  id: string;
  url: string;
};

const paymentLinkResponseSchema = z.object({
  id: z.string().min(1),
  short_url: z.string().url(),
});

export async function createPaymentLink(
  request: PaymentLinkRequest,
): Promise<PaymentLink> {
  const { keyId, keySecret } = razorpayCredentials();
  razorpayMode();
  const body: Record<string, unknown> = {
    amount: request.amountPaise,
    currency: "INR",
    accept_partial: false,
    description: `Edith ${request.planName} licence for ${request.machines} ${request.machines === 1 ? "Mac" : "Macs"}`,
    notes: {
      plan_id: request.planId,
      machines: String(request.machines),
    },
    callback_url: request.callbackUrl,
    callback_method: "get",
  };

  if (request.customerEmail) {
    body.customer = { email: request.customerEmail };
  }

  const authorization = Buffer.from(`${keyId}:${keySecret}`, "utf8").toString(
    "base64",
  );
  const response = await fetch(`${razorpayApiBase}/payment_links`, {
    method: "POST",
    headers: {
      Authorization: `Basic ${authorization}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    throw new Error(`Razorpay payment link failed with status ${response.status}`);
  }

  const parsed = paymentLinkResponseSchema.parse(await response.json());
  return { id: parsed.id, url: parsed.short_url };
}
