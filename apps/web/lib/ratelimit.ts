import { z } from "zod";

const WINDOW_MS = 60_000;
const MAX_REQUESTS = 20;
const requestTimes = new Map<string, number[]>();
const forwardedIpSchema = z.string().trim().min(1).max(200);

export type RateLimitResult = {
  allowed: boolean;
  retryAfterSeconds: number;
};

export function getClientIp(headers: Headers): string {
  const forwarded = headers.get("x-forwarded-for")?.split(",")[0];
  const realIp = headers.get("x-real-ip");
  const parsed = forwardedIpSchema.safeParse(forwarded ?? realIp ?? "unknown");
  return parsed.success ? parsed.data : "unknown";
}

export function checkRateLimit(
  ip: string,
  route: string,
  now = Date.now(),
): RateLimitResult {
  const key = `${ip}:${route}`;
  const windowStart = now - WINDOW_MS;
  const activeTimes = (requestTimes.get(key) ?? []).filter(
    (requestTime) => requestTime > windowStart,
  );

  if (activeTimes.length >= MAX_REQUESTS) {
    requestTimes.set(key, activeTimes);
    const retryAfterMilliseconds = activeTimes[0] + WINDOW_MS - now;
    return {
      allowed: false,
      retryAfterSeconds: Math.max(
        1,
        Math.ceil(retryAfterMilliseconds / 1_000),
      ),
    };
  }

  activeTimes.push(now);
  requestTimes.set(key, activeTimes);
  return { allowed: true, retryAfterSeconds: 0 };
}
