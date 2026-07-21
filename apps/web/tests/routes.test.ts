import { createHmac, randomBytes } from "node:crypto";
import { beforeEach, describe, expect, mock, test } from "bun:test";
import { signAccessToken } from "@/lib/access-token";
import { FakeStore, makeDeviceKey, signChallenge } from "./fakes";

process.env.LICENSE_KEY_LOOKUP_PEPPER = "route-test-pepper";
process.env.LICENSE_ACCESS_TOKEN_SECRET = "route-test-access-secret";
process.env.LICENSE_SIGNING_PRIVATE_KEY = randomBytes(32).toString("base64");
process.env.POLAR_WEBHOOK_SECRET = "route-test-webhook-secret";
process.env.POLAR_PRODUCT_PERSONAL_3 = "prod_personal_3";
process.env.POLAR_PRODUCT_CUSTOM = "prod_custom";

const store = new FakeStore();

const sentEmails: { to: string; licenseKey: string }[] = [];
let emailResult: { ok: true; id: string } | { ok: false; error: string } = {
  ok: true,
  id: "email_1",
};

mock.module("@/lib/email", () => ({
  sendLicenseEmail: async (input: { to: string; licenseKey: string }) => {
    sentEmails.push(input);
    return emailResult;
  },
  sendLicenseRecoveryEmail: async () => ({ ok: true, id: "email_recovery" }),
}));

mock.module("@/lib/db", () => ({ licenseStore: store }));
mock.module("@/lib/github", () => ({
  getLatestRelease: async () => ({
    assets: [
      { name: "Edith-v2.0.0.dmg", url: "https://upstream.test/dmg" },
      { name: "appcast.xml", url: "https://upstream.test/appcast" },
    ],
  }),
  findReleaseAsset: (
    assets: { name: string }[],
    predicate: (name: string) => boolean,
  ) => assets.find((asset) => predicate(asset.name)) ?? null,
  fetchReleaseAsset: async (asset: { name: string }) =>
    new Response(asset.name === "appcast.xml" ? "<rss/>" : "dmg-bytes"),
  rewriteAppcastEnclosureUrls: (xml: string) =>
    xml.replace(
      /(<enclosure\b[^>]*?\burl\s*=\s*)(["'])[^"']*\2/gi,
      (_m: string, prefix: string, quote: string) =>
        `${prefix}${quote}https://edith.pulkit.page/api/download/dmg${quote}`,
    ),
}));

const activationChallengeRoute = await import(
  "@/app/api/activation/challenge/route"
);
const activationRoute = await import("@/app/api/activation/route");
const refreshChallengeRoute = await import(
  "@/app/api/devices/refresh/challenge/route"
);
const refreshRoute = await import("@/app/api/devices/refresh/route");
const deactivateRoute = await import("@/app/api/devices/deactivate/route");
const webhookRoute = await import("@/app/api/payments/polar/webhook/route");
const dmgRoute = await import("@/app/api/download/dmg/route");
const appcastRoute = await import("@/app/api/appcast/route");
const legacyAppcastRoute = await import("@/app/api/v1/appcast/route");

let ipCounter = 0;

function nextIp(): string {
  ipCounter += 1;
  return `10.0.${Math.floor(ipCounter / 250)}.${ipCounter % 250}`;
}

function postJson(
  path: string,
  body: unknown,
  ip: string,
  headers: Record<string, string> = {},
): Request {
  return new Request(`https://edith.test${path}`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-forwarded-for": ip,
      ...headers,
    },
    body: JSON.stringify(body),
  });
}

function getRequest(
  path: string,
  ip: string,
  headers: Record<string, string> = {},
): Request {
  return new Request(`https://edith.test${path}`, {
    headers: { "x-forwarded-for": ip, ...headers },
  });
}

let keyCounter = 0;
let licenseKey = "EDITH-AAAA-BBBB-CCCC-DDDD";

async function activateViaRoutes(
  deviceId: string,
  key = licenseKey,
  keyPair = makeDeviceKey(),
) {
  const challengeResponse = await activationChallengeRoute.POST(
    postJson(
      "/api/activation/challenge",
      { licenseKey: key, deviceId, devicePublicKey: keyPair.encodedPublicKey },
      nextIp(),
    ),
  );
  const challenge = (await challengeResponse.json()) as {
    challengeId: string;
    nonce: string;
  };
  const activationResponse = await activationRoute.POST(
    postJson(
      "/api/activation",
      {
        licenseKey: key,
        challengeId: challenge.challengeId,
        nonce: challenge.nonce,
        deviceId,
        devicePublicKey: keyPair.encodedPublicKey,
        signature: signChallenge(
          keyPair.privateKey,
          "activate",
          challenge.challengeId,
          challenge.nonce,
        ),
        appVersion: "2.0.0",
      },
      nextIp(),
    ),
  );
  return { challenge, activationResponse, keyPair };
}

async function issueRefreshChallenge(
  deviceId: string,
  refreshCredential: string,
  purpose?: "refresh" | "deactivate",
) {
  const response = await refreshChallengeRoute.POST(
    postJson(
      "/api/devices/refresh/challenge",
      { deviceId, refreshCredential, ...(purpose ? { purpose } : {}) },
      nextIp(),
    ),
  );
  return {
    response,
    challenge: (await response.clone().json()) as {
      challengeId: string;
      nonce: string;
    },
  };
}

beforeEach(() => {
  store.reset();
  keyCounter += 1;
  licenseKey = `EDITH-${String(keyCounter).padStart(4, "0")}-AAAA-BBBB-CCCC`;
});

describe("v2 activation routes", () => {
  test("activation happy path issues entitlement, credential, and tokens", async () => {
    store.addLicense({ key: licenseKey, maxMachines: 3 });
    const { activationResponse } = await activateViaRoutes("device-1");

    expect(activationResponse.status).toBe(200);

    const body = (await activationResponse.json()) as Record<string, unknown>;

    expect(body).toMatchObject({
      ok: true,
      planId: "personal_3",
      machinesUsed: 1,
      maxMachines: 3,
    });
    expect(String(body.refreshCredential)).toStartWith("edithrc_");
    expect(String(body.accessToken)).toContain(".");
    expect(
      Number.isNaN(Date.parse(String(body.accessTokenExpiresAt))),
    ).toBe(false);

    const payloadSegment = String(body.entitlement).split(".")[0];
    const entitlement = JSON.parse(
      Buffer.from(payloadSegment, "base64url").toString("utf8"),
    ) as Record<string, unknown>;

    expect(entitlement).toMatchObject({
      version: 2,
      productId: "edith",
      deviceId: "device-1",
      planId: "personal_3",
      maxMachines: 3,
    });
  });

  test("unknown key gets generic invalid_credentials", async () => {
    store.addLicense({ key: licenseKey, maxMachines: 3 });
    const { activationResponse } = await activateViaRoutes(
      "device-1",
      "EDITH-0000-0000-0000-0000",
    );

    expect(activationResponse.status).toBe(403);
    expect(await activationResponse.json()).toEqual({
      error: "invalid_credentials",
    });
  });

  test("valid key over the limit gets counts", async () => {
    store.addLicense({ key: licenseKey, maxMachines: 1 });

    expect((await activateViaRoutes("device-1")).activationResponse.status).toBe(
      200,
    );

    const { activationResponse } = await activateViaRoutes("device-2");

    expect(activationResponse.status).toBe(403);
    expect(await activationResponse.json()).toEqual({
      error: "machine_limit_reached",
      machinesUsed: 1,
      maxMachines: 1,
    });
  });

  test("a challenge cannot be replayed through the route", async () => {
    store.addLicense({ key: licenseKey, maxMachines: 3 });
    const keyPair = makeDeviceKey();
    const { challenge, activationResponse } = await activateViaRoutes(
      "device-1",
      licenseKey,
      keyPair,
    );

    expect(activationResponse.status).toBe(200);

    const replay = await activationRoute.POST(
      postJson(
        "/api/activation",
        {
          licenseKey,
          challengeId: challenge.challengeId,
          nonce: challenge.nonce,
          deviceId: "device-2",
          devicePublicKey: keyPair.encodedPublicKey,
          signature: signChallenge(
            keyPair.privateKey,
            "activate",
            challenge.challengeId,
            challenge.nonce,
          ),
          appVersion: "2.0.0",
        },
        nextIp(),
      ),
    );

    expect(replay.status).toBe(403);
    expect(await replay.json()).toEqual({ error: "invalid_credentials" });
  });

  test("unknown body fields are rejected", async () => {
    const response = await activationRoute.POST(
      postJson(
        "/api/activation",
        { licenseKey, maxMachines: 99 },
        nextIp(),
      ),
    );

    expect(response.status).toBe(400);
  });

  test("challenge issuance is rate limited per ip with retry-after", async () => {
    store.addLicense({ key: licenseKey, maxMachines: 3 });
    const ip = nextIp();
    const keyPair = makeDeviceKey();
    let lastResponse: Response | null = null;

    for (let attempt = 0; attempt < 21; attempt += 1) {
      lastResponse = await activationChallengeRoute.POST(
        postJson(
          "/api/activation/challenge",
          {
            licenseKey,
            deviceId: "device-1",
            devicePublicKey: keyPair.encodedPublicKey,
          },
          ip,
        ),
      );
    }

    expect(lastResponse?.status).toBe(429);
    expect(Number(lastResponse?.headers.get("retry-after"))).toBeGreaterThan(0);
    expect(await lastResponse?.json()).toEqual({ error: "rate_limited" });
  });
});

describe("v2 device routes", () => {
  test("refresh rotates the credential through the routes", async () => {
    store.addLicense({ key: licenseKey, maxMachines: 1 });
    const { activationResponse, keyPair } = await activateViaRoutes("device-1");
    const session = (await activationResponse.json()) as {
      refreshCredential: string;
    };
    const { response, challenge } = await issueRefreshChallenge(
      "device-1",
      session.refreshCredential,
    );

    expect(response.status).toBe(200);

    const refreshed = await refreshRoute.POST(
      postJson(
        "/api/devices/refresh",
        {
          deviceId: "device-1",
          challengeId: challenge.challengeId,
          nonce: challenge.nonce,
          signature: signChallenge(
            keyPair.privateKey,
            "refresh",
            challenge.challengeId,
            challenge.nonce,
          ),
          appVersion: "2.0.1",
        },
        nextIp(),
      ),
    );

    expect(refreshed.status).toBe(200);

    const body = (await refreshed.json()) as { refreshCredential: string };

    expect(body.refreshCredential).toStartWith("edithrc_");
    expect(body.refreshCredential).not.toBe(session.refreshCredential);
  });

  test("a bad refresh credential gets generic invalid_credentials", async () => {
    store.addLicense({ key: licenseKey, maxMachines: 1 });
    await activateViaRoutes("device-1");

    const { response } = await issueRefreshChallenge(
      "device-1",
      "edithrc_not-the-real-credential",
    );

    expect(response.status).toBe(403);
  });

  test("deactivate frees the seat for another device", async () => {
    store.addLicense({ key: licenseKey, maxMachines: 1 });
    const { activationResponse, keyPair } = await activateViaRoutes("device-1");
    const session = (await activationResponse.json()) as {
      refreshCredential: string;
    };
    const { challenge } = await issueRefreshChallenge(
      "device-1",
      session.refreshCredential,
      "deactivate",
    );
    const deactivated = await deactivateRoute.POST(
      postJson(
        "/api/devices/deactivate",
        {
          deviceId: "device-1",
          challengeId: challenge.challengeId,
          nonce: challenge.nonce,
          signature: signChallenge(
            keyPair.privateKey,
            "deactivate",
            challenge.challengeId,
            challenge.nonce,
          ),
        },
        nextIp(),
      ),
    );

    expect(deactivated.status).toBe(200);
    expect(await deactivated.json()).toEqual({ ok: true });

    const replacement = await activateViaRoutes("device-2");

    expect(replacement.activationResponse.status).toBe(200);
  });

});

describe("protected downloads", () => {
  test("a bearer access token authorizes the dmg download", async () => {
    store.addLicense({ key: licenseKey, maxMachines: 1 });
    const { activationResponse } = await activateViaRoutes("device-1");
    const session = (await activationResponse.json()) as {
      accessToken: string;
    };
    const response = await dmgRoute.GET(
      getRequest("/api/download/dmg", nextIp(), {
        authorization: `Bearer ${session.accessToken}`,
      }),
    );

    expect(response.status).toBe(200);
    expect(await response.text()).toBe("dmg-bytes");
  });

  test("a bearer access token authorizes the appcast", async () => {
    store.addLicense({ key: licenseKey, maxMachines: 1 });
    const { activationResponse } = await activateViaRoutes("device-1");
    const session = (await activationResponse.json()) as {
      accessToken: string;
    };
    const response = await appcastRoute.GET(
      getRequest("/api/appcast", nextIp(), {
        authorization: `Bearer ${session.accessToken}`,
      }),
    );

    expect(response.status).toBe(200);
    expect(await response.text()).toBe("<rss/>");
  });

  test("the legacy v1 appcast path serves the same handler", () => {
    expect(legacyAppcastRoute.GET).toBe(appcastRoute.GET);
  });

  test("an expired access token is rejected", async () => {
    store.addLicense({ key: licenseKey, maxMachines: 1 });
    await activateViaRoutes("device-1");
    const expired = signAccessToken({
      deviceId: "device-1",
      licenseId: "license-1",
      now: Math.floor(Date.now() / 1000) - 90_000,
    });
    const response = await dmgRoute.GET(
      getRequest("/api/download/dmg", nextIp(), {
        authorization: `Bearer ${expired.token}`,
      }),
    );

    expect(response.status).toBe(403);
    expect(await response.json()).toEqual({ error: "unlicensed" });
  });

  test("a refunded license's bearer token gets 403", async () => {
    const license = store.addLicense({ key: licenseKey, maxMachines: 1 });
    const { activationResponse } = await activateViaRoutes("device-1");
    const session = (await activationResponse.json()) as {
      accessToken: string;
    };
    await store.updateLicenseStatus(license.id, "refunded", null);
    const response = await dmgRoute.GET(
      getRequest("/api/download/dmg", nextIp(), {
        authorization: `Bearer ${session.accessToken}`,
      }),
    );

    expect(response.status).toBe(403);
  });

  test("a deactivated device's token stops working", async () => {
    store.addLicense({ key: licenseKey, maxMachines: 1 });
    const { activationResponse } = await activateViaRoutes("device-1");
    const session = (await activationResponse.json()) as {
      accessToken: string;
    };
    await store.updateDeviceStatus("device-1", "deactivated", new Date());
    const response = await dmgRoute.GET(
      getRequest("/api/download/dmg", nextIp(), {
        authorization: `Bearer ${session.accessToken}`,
      }),
    );

    expect(response.status).toBe(403);
  });
});

let webhookCounter = 0;

function signPolar(rawBody: string, id: string, timestamp: number): string {
  return createHmac("sha256", Buffer.from("route-test-webhook-secret", "utf8"))
    .update(`${id}.${timestamp}.${rawBody}`, "utf8")
    .digest("base64");
}

function webhookRequest(
  payload: unknown,
  options: { signature?: string; id?: string } = {},
): Request {
  const rawBody = JSON.stringify(payload);
  webhookCounter += 1;
  const id = options.id ?? `msg_${webhookCounter}`;
  const timestamp = Math.floor(Date.now() / 1000);

  return new Request("https://edith.test/api/payments/polar/webhook", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-forwarded-for": nextIp(),
      "webhook-id": id,
      "webhook-timestamp": String(timestamp),
      "webhook-signature":
        options.signature ?? `v1,${signPolar(rawBody, id, timestamp)}`,
    },
    body: rawBody,
  });
}

function orderPaid(
  orderId: string,
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    type: "order.paid",
    data: {
      id: orderId,
      status: "paid",
      paid: true,
      product_id: "prod_personal_3",
      currency: "usd",
      subtotal_amount: 4500,
      customer_id: "cus_1",
      customer: { email: "buyer@example.com", name: "Buyer" },
      metadata: { plan_id: "personal_3", machines: 3 },
      ...overrides,
    },
  };
}

describe("polar webhook", () => {
  beforeEach(() => {
    sentEmails.length = 0;
    emailResult = { ok: true, id: "email_1" };
  });

  test("an invalid signature is rejected with 401", async () => {
    const response = await webhookRoute.POST(
      webhookRequest(orderPaid("order-1"), { signature: "v1,ZmFrZQ==" }),
    );

    expect(response.status).toBe(401);
    expect(store.paymentEvents.size).toBe(0);
    expect(store.licensesById.size).toBe(0);
  });

  test("order.paid mints a licence and emails the key", async () => {
    const response = await webhookRoute.POST(
      webhookRequest(orderPaid("order-1")),
    );

    expect(response.status).toBe(200);

    const body = (await response.json()) as Record<string, unknown>;

    expect(body).toMatchObject({
      ok: true,
      planId: "personal_3",
      maxMachines: 3,
    });
    expect(body.licenseKey).toBeUndefined();

    const license = await store.getLicenseById(String(body.licenseId));

    expect(license).toMatchObject({
      planId: "personal_3",
      maxMachines: 3,
      status: "active",
    });
    expect(sentEmails).toHaveLength(1);
    expect(sentEmails[0]?.to).toBe("buyer@example.com");
    expect(sentEmails[0]?.licenseKey).toMatch(
      /^EDITH-[A-Z0-9]{4}(?:-[A-Z0-9]{4}){3}$/,
    );
  });

  test("the buyer is linked to a user row by email", async () => {
    const response = await webhookRoute.POST(
      webhookRequest(orderPaid("order-1")),
    );
    const body = (await response.json()) as { licenseId: string };
    const userId = store.userIdsByEmail.get("buyer@example.com");

    expect(userId).toBeDefined();
    expect(store.licenseUserIds.get(body.licenseId)).toBe(String(userId));
  });

  test("a custom order mints the requested machine count", async () => {
    const response = await webhookRoute.POST(
      webhookRequest(
        orderPaid("order-custom", {
          product_id: "prod_custom",
          subtotal_amount: 13500,
          metadata: { plan_id: "custom", machines: 12 },
        }),
      ),
    );

    expect(response.status).toBe(200);

    const body = (await response.json()) as { licenseId: string };
    const license = await store.getLicenseById(body.licenseId);

    expect(license).toMatchObject({ planId: "custom", maxMachines: 12 });
  });

  test("a custom order above the cap is refused", async () => {
    const response = await webhookRoute.POST(
      webhookRequest(
        orderPaid("order-big", {
          product_id: "prod_custom",
          subtotal_amount: 52500,
          metadata: { plan_id: "custom", machines: 51 },
        }),
      ),
    );

    expect(response.status).toBe(422);
    expect(await response.json()).toEqual({ error: "invalid_order" });
    expect(store.licensesById.size).toBe(0);
  });

  test("an underpaid order is refused and mints nothing", async () => {
    const response = await webhookRoute.POST(
      webhookRequest(orderPaid("order-1", { subtotal_amount: 100 })),
    );

    expect(response.status).toBe(422);
    expect(await response.json()).toEqual({ error: "amount_mismatch" });
    expect(store.licensesById.size).toBe(0);
    expect(sentEmails).toHaveLength(0);
  });

  test("a discounted order still passes the subtotal check", async () => {
    const response = await webhookRoute.POST(
      webhookRequest(
        orderPaid("order-1", { subtotal_amount: 4500, net_amount: 3600 }),
      ),
    );

    expect(response.status).toBe(200);
  });

  test("a non-usd order skips the amount check", async () => {
    const response = await webhookRoute.POST(
      webhookRequest(
        orderPaid("order-inr", { currency: "inr", subtotal_amount: 375000 }),
      ),
    );

    expect(response.status).toBe(200);
  });

  test("falls back to the product id when metadata is missing", async () => {
    const response = await webhookRoute.POST(
      webhookRequest(orderPaid("order-1", { metadata: {} })),
    );

    expect(response.status).toBe(200);

    const body = (await response.json()) as { licenseId: string };
    const license = await store.getLicenseById(body.licenseId);

    expect(license).toMatchObject({ planId: "personal_3", maxMachines: 3 });
  });

  test("a custom order without metadata is refused rather than guessed", async () => {
    const response = await webhookRoute.POST(
      webhookRequest(
        orderPaid("order-1", { product_id: "prod_custom", metadata: {} }),
      ),
    );

    expect(response.status).toBe(422);
    expect(await response.json()).toEqual({ error: "unknown_plan" });
    expect(store.licensesById.size).toBe(0);
  });

  test("an unknown product records a failed event and mints nothing", async () => {
    const response = await webhookRoute.POST(
      webhookRequest(
        orderPaid("order-1", { product_id: "prod_mystery", metadata: {} }),
      ),
    );

    expect(response.status).toBe(422);
    expect(await response.json()).toEqual({ error: "unknown_plan" });
    expect(store.licensesById.size).toBe(0);

    const event = await store.getPaymentEvent("polar", "order.paid:order-1");

    expect(event).toMatchObject({
      processingState: "failed",
      error: "unknown_plan",
    });
  });

  test("an unpaid order is ignored without minting", async () => {
    const response = await webhookRoute.POST(
      webhookRequest(
        orderPaid("order-1", { status: "pending", paid: false }),
      ),
    );

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ ok: true, ignored: true });
    expect(store.licensesById.size).toBe(0);
    expect(sentEmails).toHaveLength(0);
  });

  test("a licence is still minted when the buyer has no email", async () => {
    const response = await webhookRoute.POST(
      webhookRequest(orderPaid("order-1", { customer: { email: null } })),
    );

    expect(response.status).toBe(200);
    expect(store.licensesById.size).toBe(1);
    expect(sentEmails).toHaveLength(0);
    expect(
      store.securityEvents.some(
        (event) => event.eventType === "license_delivery_skipped",
      ),
    ).toBe(true);
  });

  test("a failed send does not undo the licence", async () => {
    emailResult = { ok: false, error: "send_failed_500" };

    const response = await webhookRoute.POST(
      webhookRequest(orderPaid("order-1")),
    );

    expect(response.status).toBe(200);
    expect(store.licensesById.size).toBe(1);
    expect(
      store.securityEvents.some(
        (event) =>
          event.eventType === "license_delivery_failed" &&
          event.detail === "send_failed_500",
      ),
    ).toBe(true);
  });

  test("a replayed event returns the original result without a new licence", async () => {
    const payload = orderPaid("order-1");
    const first = await webhookRoute.POST(webhookRequest(payload));
    const firstBody = (await first.json()) as { licenseId: string };
    const replay = await webhookRoute.POST(webhookRequest(payload));

    expect(replay.status).toBe(200);
    expect(await replay.json()).toEqual({
      ok: true,
      licenseId: firstBody.licenseId,
      replayed: true,
    });
    expect(store.licensesById.size).toBe(1);
    expect(sentEmails).toHaveLength(1);
  });

  test("a concurrent duplicate hits the unique violation and one licence exists", async () => {
    const original = store.getPaymentEvent.bind(store);
    let lookups = 0;
    store.getPaymentEvent = async (provider, providerEventId) => {
      lookups += 1;
      return lookups <= 2 ? null : original(provider, providerEventId);
    };

    const payload = orderPaid("order-1");
    const first = await webhookRoute.POST(webhookRequest(payload));
    const second = await webhookRoute.POST(webhookRequest(payload));
    store.getPaymentEvent = original;

    expect(first.status).toBe(200);
    expect(second.status).toBe(200);
    expect((await second.json()) as Record<string, unknown>).toMatchObject({
      ok: true,
      replayed: true,
    });
    expect(store.licensesById.size).toBe(1);
  });

  test("order.refunded marks the licence refunded", async () => {
    const created = await webhookRoute.POST(
      webhookRequest(orderPaid("order-1")),
    );
    const createdBody = (await created.json()) as { licenseId: string };
    const refunded = await webhookRoute.POST(
      webhookRequest({
        type: "order.refunded",
        data: { id: "order-1" },
      }),
    );

    expect(refunded.status).toBe(200);

    const license = await store.getLicenseById(createdBody.licenseId);

    expect(license).toMatchObject({ status: "refunded", active: false });
  });

  test("a refund for an unknown order is refused", async () => {
    const response = await webhookRoute.POST(
      webhookRequest({ type: "order.refunded", data: { id: "order-ghost" } }),
    );

    expect(response.status).toBe(422);
    expect(await response.json()).toEqual({ error: "license_not_found" });
  });

  test("an unrelated event is acknowledged and ignored", async () => {
    const response = await webhookRoute.POST(
      webhookRequest({ type: "checkout.updated", data: { id: "chk-1" } }),
    );

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ ok: true, ignored: true });
    expect(store.licensesById.size).toBe(0);
  });
});

