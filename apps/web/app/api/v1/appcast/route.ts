import { licenseStore } from "@/lib/db";
import {
  fetchReleaseAsset,
  findReleaseAsset,
  getLatestRelease,
  rewriteAppcastEnclosureUrls,
} from "@/lib/github";
import { apiHeaders, apiJson } from "@/lib/http";
import { verifyLicense } from "@/lib/license";
import { parseLicenseHeaders } from "@/lib/validation";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

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
    const asset = findReleaseAsset(
      release.assets,
      (name) => name === "appcast.xml",
    );

    if (!asset) {
      return apiJson({ error: "upstream" }, 502);
    }

    const upstream = await fetchReleaseAsset(asset);
    const appcast = rewriteAppcastEnclosureUrls(await upstream.text());

    return new Response(appcast, {
      status: 200,
      headers: apiHeaders({ "content-type": "text/xml; charset=utf-8" }),
    });
  } catch {
    return apiJson({ error: "upstream" }, 502);
  }
}
