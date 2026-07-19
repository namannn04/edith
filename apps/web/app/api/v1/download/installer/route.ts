import {
  fetchReleaseAsset,
  findReleaseAsset,
  getLatestRelease,
} from "@/lib/github";
import { apiHeaders, apiJson } from "@/lib/http";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function attachmentHeader(filename: string): string {
  const safeFilename = filename.replace(/["\\\r\n]/g, "_");
  return `attachment; filename="${safeFilename}"`;
}

export async function GET(): Promise<Response> {
  try {
    const release = await getLatestRelease();
    const asset = findReleaseAsset(
      release.assets,
      (name) => name === "EdithInstaller.dmg",
    );

    if (!asset) {
      return apiJson({ error: "not_found" }, 404);
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
