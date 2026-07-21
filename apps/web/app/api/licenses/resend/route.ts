import { z } from "zod";
import { licenseStore } from "@/lib/db";
import { sendLicenseRecoveryEmail } from "@/lib/email";
import { apiJson } from "@/lib/http";
import { planNameFor } from "@/lib/payments";
import { effectiveAllowance } from "@/lib/plans";
import {
  checkRateLimit,
  checkRecoveryRateLimit,
  getClientIp,
} from "@/lib/ratelimit";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const route = "/api/licenses/resend";

const bodySchema = z.object({
  email: z.string().trim().toLowerCase().email().max(320),
});

const accepted = {
  ok: true,
  message:
    "If that email has an Edith licence, the key is on its way to it.",
};

export async function POST(request: Request): Promise<Response> {
  const limit = await checkRateLimit(getClientIp(request.headers), route);

  if (!limit.allowed) {
    return apiJson(accepted, 200);
  }

  let payload: unknown;

  try {
    payload = await request.json();
  } catch {
    return apiJson(accepted, 200);
  }

  const parsed = bodySchema.safeParse(payload);

  if (!parsed.success) {
    return apiJson(accepted, 200);
  }

  const email = parsed.data.email;
  const perEmail = await checkRecoveryRateLimit(email);

  if (!perEmail.allowed) {
    return apiJson(accepted, 200);
  }

  try {
    const licences = await licenseStore.getActiveLicensesByEmail(email);

    if (licences.length > 0) {
      await sendLicenseRecoveryEmail(
        email,
        licences.map((licence) => ({
          licenseKey: licence.key,
          planName: planNameFor(licence.planId),
          maxMachines: effectiveAllowance(licence),
        })),
      );
    }
  } catch {
    return apiJson(accepted, 200);
  }

  return apiJson(accepted, 200);
}
