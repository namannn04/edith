import { licenseStore } from "@/lib/db";
import { apiJson } from "@/lib/http";
import { deactivateDevice, type DeviceFailure } from "@/lib/license";
import {
  authFailureResponse,
  ipGuard,
  readJsonBody,
  subjectGuard,
} from "@/lib/device-session";
import { deactivateBodySchema } from "@/lib/validation";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const route = "/api/devices/deactivate";

export async function POST(request: Request): Promise<Response> {
  const guard = await ipGuard(request.headers, route);

  if (guard) {
    return guard;
  }

  const parsed = deactivateBodySchema.safeParse(await readJsonBody(request));

  if (!parsed.success) {
    return apiJson({ error: "invalid_request" }, 400);
  }

  let result: { ok: true } | DeviceFailure;

  try {
    const keyed = await subjectGuard(parsed.data.deviceId, route);

    if (keyed) {
      return keyed;
    }

    result = await deactivateDevice(licenseStore, parsed.data);
  } catch {
    return apiJson({ error: "internal" }, 500);
  }

  if (!result.ok) {
    return authFailureResponse(request.headers, route);
  }

  return apiJson({ ok: true });
}
