import {
  fetchReleaseAsset,
  findReleaseAsset,
  getLatestRelease,
} from "@/lib/github";
import { apiHeaders, apiJson } from "@/lib/http";
import { licenseStore } from "@/lib/db";
import { verifyLicense } from "@/lib/license";
import { parseLicenseHeaders } from "@/lib/validation";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function attachmentHeader(filename: string): string {
  const safeFilename = filename.replace(/["\\\r\n]/g, "_");
  return `attachment; filename="${safeFilename}"`;
}

export async function GET(request: Request): Promise<Response> {
  const credentials = parseLicenseHeaders(request.headers);

  if (!credentials.success) {
    return apiJson({ error: "unlicensed" }, 403);
  }

  let licensed: boolean;

  try {
    licensed = await verifyLicense(
      licenseStore,
      credentials.data.key,
      credentials.data.hardwareUuid,
    );
  } catch {
    return apiJson({ error: "internal" }, 500);
  }

  if (!licensed) {
    return apiJson({ error: "unlicensed" }, 403);
  }

  try {
    const release = await getLatestRelease();
    const asset = findReleaseAsset(release.assets, (name) =>
      /^Edith-v[^/]+\.dmg$/.test(name),
    );

    if (!asset) {
      return apiJson({ error: "upstream" }, 502);
    }

    const upstream = await fetchReleaseAsset(asset);

    return new Response(upstream.body, {
      status: 200,
      headers: apiHeaders({
        "content-type": "application/octet-stream",
        "content-disposition": attachmentHeader(asset.name),
      }),
    });
  } catch {
    return apiJson({ error: "upstream" }, 502);
  }
}
