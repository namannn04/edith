import { createHmac, randomBytes } from "node:crypto";
import { beforeEach, describe, expect, mock, test } from "bun:test";
import { signAccessToken } from "@/lib/access-token";
import { FakeStore, makeDeviceKey, signChallenge } from "./fakes";

process.env.LICENSE_KEY_LOOKUP_PEPPER = "route-test-pepper";
process.env.LICENSE_ACCESS_TOKEN_SECRET = "route-test-access-secret";
process.env.LICENSE_SIGNING_PRIVATE_KEY = randomBytes(32).toString("base64");
process.env.RAZORPAY_WEBHOOK_SECRET = "route-test-webhook-secret";

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
const webhookRoute = await import("@/app/api/payments/razorpay/webhook/route");
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

function signRazorpay(rawBody: string): string {
  return createHmac("sha256", Buffer.from("route-test-webhook-secret", "utf8"))
    .update(rawBody, "utf8")
    .digest("hex");
}

function webhookRequest(
  payload: unknown,
  options: { signature?: string; eventId?: string } = {},
): Request {
  const rawBody = JSON.stringify(payload);
  webhookCounter += 1;

  return new Request("https://edith.test/api/payments/razorpay/webhook", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-forwarded-for": nextIp(),
      "x-razorpay-event-id": options.eventId ?? `evt_${webhookCounter}`,
      "x-razorpay-signature": options.signature ?? signRazorpay(rawBody),
    },
    body: rawBody,
  });
}

type PaidOptions = {
  planId?: string;
  machines?: string;
  linkAmount?: number;
  amountPaid?: number;
  paymentAmount?: number;
  baseAmount?: number;
  paymentId?: string;
  email?: string | null;
  name?: string | null;
  offerId?: string | null;
};

function paymentLinkPaid(
  linkId: string,
  options: PaidOptions = {},
): Record<string, unknown> {
  const amount = options.linkAmount ?? 380000;
  const amountPaid = options.amountPaid ?? amount;
  const paymentId = options.paymentId ?? `pay_${linkId}`;

  return {
    event: "payment_link.paid",
    payload: {
      payment_link: {
        entity: {
          id: linkId,
          amount,
          amount_paid: amountPaid,
          currency: "INR",
          status: "paid",
          notes: {
            plan_id: options.planId ?? "personal_3",
            machines: options.machines ?? "3",
          },
          customer: {
            email:
              options.email === undefined ? "buyer@example.com" : options.email,
            name: options.name === undefined ? "Buyer" : options.name,
          },
          order_id: `order_${linkId}`,
        },
      },
      payment: {
        entity: {
          id: paymentId,
          amount: options.paymentAmount ?? amountPaid,
          base_amount: options.baseAmount ?? amount,
          currency: "INR",
          status: "captured",
          captured: true,
          email:
            options.email === undefined ? "buyer@example.com" : options.email,
          customer_id: "cust_1",
          order_id: `order_${linkId}`,
          offer_id: options.offerId ?? null,
        },
      },
      order: {
        entity: {
          id: `order_${linkId}`,
          amount: amountPaid,
          amount_paid: amountPaid,
          currency: "INR",
          status: "paid",
          customer_id: "cust_1",
          offer_id: options.offerId ?? null,
        },
      },
    },
  };
}

function refundCreated(
  refundId: string,
  paymentId: string,
): Record<string, unknown> {
  return {
    event: "refund.created",
    payload: {
      refund: {
        entity: {
          id: refundId,
          payment_id: paymentId,
          amount: 380000,
          currency: "INR",
          status: "processed",
        },
      },
      payment: {
        entity: {
          id: paymentId,
          amount: 380000,
          base_amount: 380000,
          currency: "INR",
          status: "captured",
          captured: true,
          order_id: "order_refunded",
        },
      },
    },
  };
}

describe("razorpay webhook", () => {
  beforeEach(() => {
    sentEmails.length = 0;
    emailResult = { ok: true, id: "email_1" };
  });

  test("an invalid signature is rejected with 401", async () => {
    const response = await webhookRoute.POST(
      webhookRequest(paymentLinkPaid("plink_1"), { signature: "00" }),
    );

    expect(response.status).toBe(401);
    expect(store.paymentEvents.size).toBe(0);
    expect(store.licensesById.size).toBe(0);
  });

  test("payment_link.paid mints a licence and emails the key", async () => {
    const response = await webhookRoute.POST(
      webhookRequest(paymentLinkPaid("plink_1")),
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
      webhookRequest(paymentLinkPaid("plink_1")),
    );
    const body = (await response.json()) as { licenseId: string };
    const userId = store.userIdsByEmail.get("buyer@example.com");

    expect(userId).toBeDefined();
    expect(store.licenseUserIds.get(body.licenseId)).toBe(String(userId));
  });

  test("a custom order mints the requested machine count", async () => {
    const response = await webhookRoute.POST(
      webhookRequest(
        paymentLinkPaid("plink_custom", {
          planId: "custom",
          machines: "12",
          linkAmount: 1145000,
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
        paymentLinkPaid("plink_big", {
          planId: "custom",
          machines: "51",
          linkAmount: 4460000,
        }),
      ),
    );

    expect(response.status).toBe(400);
    expect(await response.json()).toEqual({ error: "invalid_request" });
    expect(store.licensesById.size).toBe(0);
  });

  test("an underpaid order is refused and mints nothing", async () => {
    const response = await webhookRoute.POST(
      webhookRequest(paymentLinkPaid("plink_underpaid", { linkAmount: 100 })),
    );

    expect(response.status).toBe(422);
    expect(await response.json()).toEqual({ error: "amount_mismatch" });
    expect(store.licensesById.size).toBe(0);
    expect(sentEmails).toHaveLength(0);
  });

  test("a discounted payment is accepted", async () => {
    const response = await webhookRoute.POST(
      webhookRequest(
        paymentLinkPaid("plink_discounted", {
          amountPaid: 300000,
          paymentAmount: 300000,
          baseAmount: 380000,
          offerId: "offer_1",
        }),
      ),
    );

    expect(response.status).toBe(200);
    expect(store.licensesById.size).toBe(1);
  });

  test("an unknown plan is refused", async () => {
    const response = await webhookRoute.POST(
      webhookRequest(
        paymentLinkPaid("plink_unknown", {
          planId: "enterprise",
          machines: "3",
        }),
      ),
    );

    expect(response.status).toBe(422);
    expect(await response.json()).toEqual({ error: "invalid_order" });
    expect(store.licensesById.size).toBe(0);
  });

  test("a licence is still minted when the buyer has no email", async () => {
    const response = await webhookRoute.POST(
      webhookRequest(paymentLinkPaid("plink_no_email", { email: null })),
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
      webhookRequest(paymentLinkPaid("plink_email_failure")),
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
    const payload = paymentLinkPaid("plink_replay");
    const first = await webhookRoute.POST(
      webhookRequest(payload, { eventId: "evt_replay" }),
    );
    const firstBody = (await first.json()) as { licenseId: string };
    const replay = await webhookRoute.POST(
      webhookRequest(payload, { eventId: "evt_replay" }),
    );

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

    const payload = paymentLinkPaid("plink_concurrent");
    const first = await webhookRoute.POST(
      webhookRequest(payload, { eventId: "evt_concurrent" }),
    );
    const second = await webhookRoute.POST(
      webhookRequest(payload, { eventId: "evt_concurrent" }),
    );
    store.getPaymentEvent = original;

    expect(first.status).toBe(200);
    expect(second.status).toBe(200);
    expect((await second.json()) as Record<string, unknown>).toMatchObject({
      ok: true,
      replayed: true,
    });
    expect(store.licensesById.size).toBe(1);
  });

  test("refund.created marks the licence refunded", async () => {
    const paymentId = "pay_refunded";
    const created = await webhookRoute.POST(
      webhookRequest(paymentLinkPaid("plink_refunded", { paymentId })),
    );
    const createdBody = (await created.json()) as { licenseId: string };
    const refunded = await webhookRoute.POST(
      webhookRequest(refundCreated("rfnd_1", paymentId)),
    );

    expect(refunded.status).toBe(200);

    const license = await store.getLicenseById(createdBody.licenseId);

    expect(license).toMatchObject({ status: "refunded", active: false });
  });

  test("a partial refund does not revoke the licence", async () => {
    const paymentId = "pay_partial";
    const created = await webhookRoute.POST(
      webhookRequest(paymentLinkPaid("plink_partial", { paymentId })),
    );
    const createdBody = (await created.json()) as { licenseId: string };
    const partial = refundCreated("rfnd_partial", paymentId);
    const payload = partial.payload as Record<string, Record<string, Record<string, unknown>>>;
    payload.refund.entity.amount = 50000;
    payload.payment.entity.amount_refunded = 50000;

    const response = await webhookRoute.POST(webhookRequest(partial));

    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({ ok: true, partial: true });

    const license = await store.getLicenseById(createdBody.licenseId);

    expect(license).toMatchObject({ status: "active", active: true });
    expect(
      store.securityEvents.some(
        (event) => event.eventType === "partial_refund_recorded",
      ),
    ).toBe(true);
  });

  test("partial refunds that cumulatively reach the full amount do revoke", async () => {
    const paymentId = "pay_cumulative";
    const created = await webhookRoute.POST(
      webhookRequest(paymentLinkPaid("plink_cumulative", { paymentId })),
    );
    const createdBody = (await created.json()) as { licenseId: string };
    const second = refundCreated("rfnd_second", paymentId);
    const payload = second.payload as Record<string, Record<string, Record<string, unknown>>>;
    payload.refund.entity.amount = 180000;
    payload.payment.entity.amount_refunded = 380000;

    const response = await webhookRoute.POST(webhookRequest(second));

    expect(response.status).toBe(200);

    const license = await store.getLicenseById(createdBody.licenseId);

    expect(license).toMatchObject({ status: "refunded", active: false });
  });

  test("a refund for an unknown order is refused", async () => {
    const response = await webhookRoute.POST(
      webhookRequest(refundCreated("rfnd_ghost", "pay_ghost")),
    );

    expect(response.status).toBe(422);
    expect(await response.json()).toEqual({ error: "license_not_found" });
  });

  test("an unrelated event is acknowledged and ignored", async () => {
    const response = await webhookRoute.POST(
      webhookRequest({
        event: "payment_link.cancelled",
        payload: {
          payment_link: {
            entity: {
              id: "plink_cancelled",
              amount: 380000,
              amount_paid: 0,
              currency: "INR",
              status: "cancelled",
              notes: null,
            },
          },
        },
      }),
    );

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ ok: true, ignored: true });
    expect(store.licensesById.size).toBe(0);
  });
});
