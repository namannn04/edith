import { z } from "zod";
import { rateLimited } from "@/lib/device-session";
import { apiJson } from "@/lib/http";
import { createCheckoutSession } from "@/lib/polar";
import {
  customMachinesSchema,
  customTier,
  getTier,
  priceCentsFor,
} from "@/lib/pricing";
import { checkRateLimit, getClientIp } from "@/lib/ratelimit";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const route = "/api/checkout";

const bodySchema = z.object({
  planId: z.string().min(1).max(50),
  machines: z.coerce.number().int().optional(),
  email: z.string().email().max(320).optional(),
});

export function siteUrl(): string {
  return process.env.SITE_URL ?? "https://edith.pulkit.page";
}

export function resolveMachines(
  planId: string,
  requested: number | undefined,
): number | null {
  if (planId === customTier.id) {
    const parsed = customMachinesSchema.safeParse(requested);
    return parsed.success ? parsed.data : null;
  }

  const tier = getTier(planId);

  if (!tier) {
    return null;
  }

  if (requested !== undefined && requested !== tier.maxMachines) {
    return null;
  }

  return tier.maxMachines;
}

export async function POST(request: Request): Promise<Response> {
  const limit = await checkRateLimit(getClientIp(request.headers), route);

  if (!limit.allowed) {
    return rateLimited(limit.retryAfterSeconds);
  }

  let payload: unknown;

  try {
    payload = await request.json();
  } catch {
    return apiJson({ error: "invalid_request" }, 400);
  }

  const parsed = bodySchema.safeParse(payload);

  if (!parsed.success) {
    return apiJson({ error: "invalid_request" }, 400);
  }

  const machines = resolveMachines(parsed.data.planId, parsed.data.machines);

  if (machines === null) {
    return apiJson({ error: "invalid_plan" }, 400);
  }

  try {
    const session = await createCheckoutSession({
      planId: parsed.data.planId,
      machines,
      priceCents: priceCentsFor(parsed.data.planId, machines),
      successUrl: `${siteUrl()}/thanks?checkout_id={CHECKOUT_ID}`,
      customerEmail: parsed.data.email,
    });

    return apiJson({ ok: true, url: session.url, checkoutId: session.id }, 200);
  } catch {
    return apiJson({ error: "checkout_failed" }, 502);
  }
}
