import { licenseStore } from "@/lib/db";
import { apiJson } from "@/lib/http";
import { activateLicense, type ActivationResult } from "@/lib/license";
import { checkRateLimit, getClientIp } from "@/lib/ratelimit";
import { activationBodySchema } from "@/lib/validation";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(request: Request): Promise<Response> {
  const rateLimit = checkRateLimit(
    getClientIp(request.headers),
    "/api/v1/activate",
  );

  if (!rateLimit.allowed) {
    return apiJson({ error: "rate_limited" }, 429, {
      "retry-after": String(rateLimit.retryAfterSeconds),
    });
  }

  let body: unknown;

  try {
    body = await request.json();
  } catch {
    return apiJson({ error: "invalid_request" }, 400);
  }

  const parsed = activationBodySchema.safeParse(body);

  if (!parsed.success) {
    return apiJson({ error: "invalid_request" }, 400);
  }

  let result: ActivationResult;

  try {
    result = await activateLicense(licenseStore, parsed.data);
  } catch {
    return apiJson({ error: "internal" }, 500);
  }

  if (!result.ok) {
    return apiJson({ error: result.error }, 403);
  }

  return apiJson(result);
}
