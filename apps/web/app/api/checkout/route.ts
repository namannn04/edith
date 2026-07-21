import { z } from "zod";
import { rateLimited } from "@/lib/device-session";
import { apiJson, siteUrl } from "@/lib/http";
import { createCheckoutSession, PolarConfigError } from "@/lib/polar";
import { priceCentsFor, resolveMachines } from "@/lib/pricing";
import { checkRateLimit, getClientIp } from "@/lib/ratelimit";

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
    const session = await createCheckoutSession({
      planId: parsed.data.planId,
      machines,
      priceCents: priceCentsFor(parsed.data.planId, machines),
      successUrl: `${siteUrl()}/thanks?checkout_id={CHECKOUT_ID}`,
      customerEmail: parsed.data.email,
      customerIp: clientIp,
    });

    return apiJson({ ok: true, url: session.url, checkoutId: session.id }, 200);
  } catch (error) {
    const reason = error instanceof Error ? error.message : "unknown";
    console.error(`checkout failed for ${parsed.data.planId}: ${reason}`);

    if (error instanceof PolarConfigError) {
      return apiJson({ error: "checkout_unavailable" }, 503);
    }

    return apiJson({ error: "checkout_failed" }, 502);
  }
}
