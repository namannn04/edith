import { licenseStore } from "@/lib/db";
import { rateLimited } from "@/lib/device-session";
import { apiJson } from "@/lib/http";
import { processPolarWebhook } from "@/lib/payments";
import { verifyPolarSignature } from "@/lib/polar";
import { checkRateLimit, getClientIp } from "@/lib/ratelimit";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const route = "/api/payments/polar/webhook";

export async function POST(request: Request): Promise<Response> {
  const limit = await checkRateLimit(getClientIp(request.headers), route);

  if (!limit.allowed) {
    return rateLimited(limit.retryAfterSeconds);
  }

  const rawBody = await request.text();

  if (!verifyPolarSignature(rawBody, request.headers)) {
    return apiJson({ error: "invalid_signature" }, 401);
  }

  let payload: unknown;

  try {
    payload = JSON.parse(rawBody);
  } catch {
    return apiJson({ error: "invalid_request" }, 400);
  }

  try {
    const result = await processPolarWebhook(licenseStore, payload);
    return apiJson(result.body, result.status);
  } catch {
    return apiJson({ error: "internal" }, 500);
  }
}
