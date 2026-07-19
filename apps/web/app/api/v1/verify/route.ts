import { licenseStore } from "@/lib/db";
import { apiJson } from "@/lib/http";
import { verifyLicense } from "@/lib/license";
import { checkRateLimit, getClientIp } from "@/lib/ratelimit";
import { verificationBodySchema } from "@/lib/validation";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(request: Request): Promise<Response> {
  const rateLimit = checkRateLimit(
    getClientIp(request.headers),
    "/api/v1/verify",
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

  const parsed = verificationBodySchema.safeParse(body);

  if (!parsed.success) {
    return apiJson({ error: "invalid_request" }, 400);
  }

  let ok: boolean;

  try {
    ok = await verifyLicense(
      licenseStore,
      parsed.data.key,
      parsed.data.hardwareUuid,
    );
  } catch {
    return apiJson({ error: "internal" }, 500);
  }

  return apiJson({ ok });
}
