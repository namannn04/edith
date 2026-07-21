import { createHmac, timingSafeEqual } from "node:crypto";
import { z } from "zod";
import { customTier, tiers } from "@/lib/pricing";

export const polarProvider = "polar";

const signatureToleranceSeconds = 300;

const productEnvByPlan: Record<string, string> = {
  individual_1: "POLAR_PRODUCT_INDIVIDUAL_1",
  personal_3: "POLAR_PRODUCT_PERSONAL_3",
  power_5: "POLAR_PRODUCT_POWER_5",
  [customTier.id]: "POLAR_PRODUCT_CUSTOM",
};

export function polarApiBase(): string {
  return process.env.POLAR_SERVER === "production"
    ? "https://api.polar.sh"
    : "https://sandbox-api.polar.sh";
}

export function productIdForPlan(planId: string): string {
  const name = productEnvByPlan[planId];
  const value = name ? process.env[name] : undefined;

  if (!value) {
    throw new Error(`Missing Polar product id for plan ${planId}`);
  }

  return value;
}

export function planIdForProduct(productId: string): string | null {
  for (const [planId, name] of Object.entries(productEnvByPlan)) {
    if (process.env[name] && process.env[name] === productId) {
      return planId;
    }
  }

  return null;
}

export function verifyPolarSignature(
  rawBody: string,
  headers: Headers,
  now: Date = new Date(),
): boolean {
  const secret = process.env.POLAR_WEBHOOK_SECRET;
  const id = headers.get("webhook-id");
  const timestamp = headers.get("webhook-timestamp");
  const signature = headers.get("webhook-signature");

  if (!secret || !id || !timestamp || !signature) {
    return false;
  }

  const sentAt = Number(timestamp);

  if (!Number.isFinite(sentAt)) {
    return false;
  }

  const age = Math.abs(Math.floor(now.getTime() / 1000) - sentAt);

  if (age > signatureToleranceSeconds) {
    return false;
  }

  const expected = createHmac("sha256", Buffer.from(secret, "utf8"))
    .update(`${id}.${timestamp}.${rawBody}`, "utf8")
    .digest();

  return signature.split(" ").some((entry) => {
    const [version, value] = entry.split(",");

    if (version !== "v1" || !value) {
      return false;
    }

    const provided = Buffer.from(value, "base64");

    return (
      provided.length === expected.length &&
      timingSafeEqual(expected, provided)
    );
  });
}

const metadataValueSchema = z.union([z.string(), z.number(), z.boolean()]);

export const polarEventSchema = z
  .object({
    type: z.string().min(1).max(100),
    data: z
      .object({
        id: z.string().min(1).max(255),
        status: z.string().max(50).optional(),
        paid: z.boolean().optional(),
        product_id: z.string().max(255).nullish(),
        customer_id: z.string().max(255).nullish(),
        subtotal_amount: z.number().int().nullish(),
        total_amount: z.number().int().nullish(),
        currency: z.string().max(10).nullish(),
        billing_reason: z.string().max(50).nullish(),
        customer: z
          .object({
            email: z.string().max(320).nullish(),
            name: z.string().max(255).nullish(),
          })
          .passthrough()
          .nullish(),
        metadata: z.record(metadataValueSchema).nullish(),
      })
      .passthrough(),
  })
  .passthrough();

export type PolarEvent = z.infer<typeof polarEventSchema>;

export type CheckoutRequest = {
  planId: string;
  machines: number;
  priceCents: number;
  successUrl: string;
  customerEmail?: string;
};

export type CheckoutSession = {
  id: string;
  url: string;
};

const checkoutResponseSchema = z.object({
  id: z.string().min(1),
  url: z.string().url(),
});

export async function createCheckoutSession(
  request: CheckoutRequest,
): Promise<CheckoutSession> {
  const token = process.env.POLAR_ACCESS_TOKEN;

  if (!token) {
    throw new Error("Missing POLAR_ACCESS_TOKEN");
  }

  const productId = productIdForPlan(request.planId);
  const body: Record<string, unknown> = {
    products: [productId],
    success_url: request.successUrl,
    metadata: {
      plan_id: request.planId,
      machines: request.machines,
    },
  };

  if (request.customerEmail) {
    body.customer_email = request.customerEmail;
  }

  if (request.planId === customTier.id) {
    body.prices = {
      [productId]: [
        {
          amount_type: "fixed",
          price_amount: request.priceCents,
          price_currency: "usd",
        },
      ],
    };
  }

  const response = await fetch(`${polarApiBase()}/v1/checkouts/`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    throw new Error(`Polar checkout failed with status ${response.status}`);
  }

  return checkoutResponseSchema.parse(await response.json());
}

export function knownPlanIds(): string[] {
  return [...tiers.map((tier) => tier.id), customTier.id];
}
