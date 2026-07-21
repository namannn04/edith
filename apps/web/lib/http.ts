export function siteUrl(): string {
  const configured = process.env.SITE_URL;

  if (configured) {
    return configured.replace(/\/+$/, "");
  }

  const deployment =
    process.env.VERCEL_BRANCH_URL ?? process.env.VERCEL_URL ?? null;

  if (deployment) {
    return `https://${deployment.replace(/^https?:\/\//, "").replace(/\/+$/, "")}`;
  }

  return "https://edith.pulkit.page";
}

export function apiHeaders(initial?: HeadersInit): Headers {
  const headers = new Headers(initial);
  headers.set("cache-control", "no-store");
  headers.set("x-robots-tag", "noindex");
  return headers;
}

export function attachmentHeader(filename: string): string {
  const safeFilename = filename.replace(/["\\\r\n]/g, "_");
  return `attachment; filename="${safeFilename}"`;
}

export function apiJson(
  body: unknown,
  status = 200,
  initialHeaders?: HeadersInit,
): Response {
  return Response.json(body, {
    status,
    headers: apiHeaders(initialHeaders),
  });
}
