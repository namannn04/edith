import { z } from "zod";
import { rateLimited } from "@/lib/device-session";
import { apiJson, siteUrl } from "@/lib/http";
import { customTier, getTier, pricePaiseFor, resolveMachines } from "@/lib/pricing";
import { checkRateLimit, getClientIp } from "@/lib/ratelimit";
import { createPaymentLink, RazorpayConfigError } from "@/lib/razorpay";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const route = "/api/checkout";

const bodySchema = z.object({
  planId: z.string().min(1).max(50),
  machines: z.coerce.number().int().optional(),
  email: z.string().email().max(320).optional(),
});

export async function POST(request: Request): Promise<Response> {
  const clientIp = getClientIp(request.headers);
  const limit = await checkRateLimit(clientIp, route);

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
    const planName =
      parsed.data.planId === customTier.id
        ? customTier.name
        : (getTier(parsed.data.planId)?.name ?? parsed.data.planId);
    const session = await createPaymentLink({
      planId: parsed.data.planId,
      planName,
      machines,
      amountPaise: pricePaiseFor(parsed.data.planId, machines),
      callbackUrl: `${siteUrl()}/thanks`,
      customerEmail: parsed.data.email,
    });

    return apiJson({ ok: true, url: session.url, checkoutId: session.id }, 200);
  } catch (error) {
    const reason = error instanceof Error ? error.message : "unknown";
    console.error(`checkout failed for ${parsed.data.planId}: ${reason}`);

    if (error instanceof RazorpayConfigError) {
      return apiJson({ error: "checkout_unavailable" }, 503);
    }

    return apiJson({ error: "checkout_failed" }, 502);
  }
}
