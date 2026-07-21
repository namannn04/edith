import { licenseStore } from "@/lib/db";
import { rateLimited } from "@/lib/device-session";
import { apiJson } from "@/lib/http";
import { processRazorpayWebhook } from "@/lib/payments";
import { checkRateLimit, getClientIp } from "@/lib/ratelimit";
import { verifyRazorpaySignature } from "@/lib/razorpay";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(request: Request): Promise<Response> {
  const limit = await checkRateLimit(
    getClientIp(request.headers),
    "/api/payments/razorpay/webhook",
  );

  if (!limit.allowed) {
    return rateLimited(limit.retryAfterSeconds);
  }

  const rawBody = await request.text();

  if (!verifyRazorpaySignature(rawBody, request.headers)) {
    return apiJson({ error: "invalid_signature" }, 401);
  }

  let payload: unknown;

  try {
    payload = JSON.parse(rawBody);
  } catch {
    return apiJson({ error: "invalid_request" }, 400);
  }

  try {
    const result = await processRazorpayWebhook(
      licenseStore,
      payload,
      request.headers.get("x-razorpay-event-id"),
    );
    return apiJson(result.body, result.status);
  } catch {
    return apiJson({ error: "internal" }, 500);
  }
}
