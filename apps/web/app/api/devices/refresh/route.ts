import { licenseStore } from "@/lib/db";
import { apiJson } from "@/lib/http";
import {
  type DeviceFailure,
  type DeviceSessionSuccess,
  refreshDevice,
} from "@/lib/license";
import {
  authFailureResponse,
  deviceSessionJson,
  ipGuard,
  readJsonBody,
  subjectGuard,
} from "@/lib/device-session";
import { refreshBodySchema } from "@/lib/validation";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const route = "/api/devices/refresh";

export async function POST(request: Request): Promise<Response> {
  const guard = await ipGuard(request.headers, route);

  if (guard) {
    return guard;
  }

  const parsed = refreshBodySchema.safeParse(await readJsonBody(request));

  if (!parsed.success) {
    return apiJson({ error: "invalid_request" }, 400);
  }

  let result: DeviceSessionSuccess | DeviceFailure;

  try {
    const keyed = await subjectGuard(parsed.data.deviceId, route);

    if (keyed) {
      return keyed;
    }

    result = await refreshDevice(licenseStore, parsed.data);
  } catch {
    return apiJson({ error: "internal" }, 500);
  }

  if (!result.ok) {
    return authFailureResponse(request.headers, route);
  }

  try {
    return deviceSessionJson(parsed.data.deviceId, result);
  } catch {
    return apiJson({ error: "internal" }, 500);
  }
}
