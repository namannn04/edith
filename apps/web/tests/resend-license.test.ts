import { randomBytes } from "node:crypto";
import { beforeEach, describe, expect, mock, test } from "bun:test";
import { FakeStore } from "./fakes";

process.env.LICENSE_KEY_LOOKUP_PEPPER = "resend-test-pepper";
process.env.LICENSE_ACCESS_TOKEN_SECRET = "resend-test-access-secret";
process.env.LICENSE_SIGNING_PRIVATE_KEY = randomBytes(32).toString("base64");

const store = new FakeStore();

const recoveryEmails: { to: string; licences: unknown[] }[] = [];

mock.module("@/lib/email", () => ({
  sendLicenseEmail: async () => ({ ok: true, id: "email_purchase" }),
  sendLicenseRecoveryEmail: async (to: string, licences: unknown[]) => {
    recoveryEmails.push({ to, licences });
    return { ok: true, id: "email_recovery" };
  },
}));

mock.module("@/lib/db", () => ({ licenseStore: store }));

const resendRoute = await import("@/app/api/licenses/resend/route");

let ipCounter = 0;

function nextIp(): string {
  ipCounter += 1;
  return `10.7.${Math.floor(ipCounter / 250)}.${ipCounter % 250}`;
}

function resendRequest(body: unknown): Request {
  return new Request("https://edith.test/api/licenses/resend", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-forwarded-for": nextIp(),
    },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

const neutral = {
  ok: true,
  message: "If that email has an Edith licence, the key is on its way to it.",
};

let emailCounter = 0;

function uniqueEmail(): string {
  emailCounter += 1;
  return `buyer${emailCounter}@example.com`;
}

async function seedLicence(
  email: string,
  options: { maxMachines?: number; planId?: string; status?: string } = {},
): Promise<string> {
  const userId = await store.upsertUserByEmail(email, "Buyer");
  const key = `EDITH-${String(emailCounter).padStart(4, "0")}-AAAA-BBBB-CCCC`;
  const { id } = await store.insertLicense({
    key,
    keyDigest: `digest-${key}`,
    keyLast4: "CCCC",
    label: null,
    planId: options.planId ?? "personal_3",
    maxMachines: options.maxMachines ?? 3,
    userId,
  });

  if (options.status) {
    await store.updateLicenseStatus(id, options.status, "test");
  }

  return key;
}

beforeEach(() => {
  store.reset();
  recoveryEmails.length = 0;
});

describe("license resend", () => {
  test("sends every active key for a known email", async () => {
    const email = uniqueEmail();
    const first = await seedLicence(email, { maxMachines: 3 });
    const second = await seedLicence(email, {
      maxMachines: 12,
      planId: "custom",
    });

    const response = await resendRoute.POST(resendRequest({ email }));

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual(neutral);
    expect(recoveryEmails).toHaveLength(1);
    expect(recoveryEmails[0]?.to).toBe(email);
    expect(recoveryEmails[0]?.licences).toEqual([
      { licenseKey: first, planName: "Personal", maxMachines: 3 },
      { licenseKey: second, planName: "Custom", maxMachines: 12 },
    ]);
  });

  test("an unknown email gets the same response and no email", async () => {
    const response = await resendRoute.POST(
      resendRequest({ email: "nobody@example.com" }),
    );

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual(neutral);
    expect(recoveryEmails).toHaveLength(0);
  });

  test("a known and an unknown email are indistinguishable", async () => {
    const known = uniqueEmail();
    await seedLicence(known);

    const hit = await resendRoute.POST(resendRequest({ email: known }));
    const miss = await resendRoute.POST(
      resendRequest({ email: "ghost@example.com" }),
    );

    expect(hit.status).toBe(miss.status);
    expect(await hit.json()).toEqual(await miss.json());
  });

  test("a legacy licence with no plan still gets a readable name", async () => {
    const email = uniqueEmail();
    const userId = await store.upsertUserByEmail(email, "Buyer");
    await store.insertLicense({
      key: "EDITH-9999-AAAA-BBBB-CCCC",
      keyDigest: "digest-legacy",
      keyLast4: "CCCC",
      label: null,
      planId: null as unknown as string,
      maxMachines: 1,
      userId,
    });

    await resendRoute.POST(resendRequest({ email }));

    expect(recoveryEmails[0]?.licences).toEqual([
      {
        licenseKey: "EDITH-9999-AAAA-BBBB-CCCC",
        planName: "Edith",
        maxMachines: 1,
      },
    ]);
  });

  test("refunded licences are not resent", async () => {
    const email = uniqueEmail();
    await seedLicence(email, { status: "refunded" });

    const response = await resendRoute.POST(resendRequest({ email }));

    expect(response.status).toBe(200);
    expect(recoveryEmails).toHaveLength(0);
  });

  test("a malformed body still returns the neutral response", async () => {
    const badBody = await resendRoute.POST(resendRequest("not json"));
    const badEmail = await resendRoute.POST(
      resendRequest({ email: "not-an-email" }),
    );
    const missing = await resendRoute.POST(resendRequest({}));

    for (const response of [badBody, badEmail, missing]) {
      expect(response.status).toBe(200);
      expect(await response.json()).toEqual(neutral);
    }

    expect(recoveryEmails).toHaveLength(0);
  });

  test("email lookup is case and whitespace insensitive", async () => {
    const email = uniqueEmail();
    await seedLicence(email);

    const response = await resendRoute.POST(
      resendRequest({ email: `  ${email.toUpperCase()}  ` }),
    );

    expect(response.status).toBe(200);
    expect(recoveryEmails).toHaveLength(1);
  });

  test("repeat requests for one address are throttled", async () => {
    const email = uniqueEmail();
    await seedLicence(email);

    for (let attempt = 0; attempt < 6; attempt += 1) {
      const response = await resendRoute.POST(resendRequest({ email }));
      expect(response.status).toBe(200);
      expect(await response.json()).toEqual(neutral);
    }

    expect(recoveryEmails.length).toBeLessThanOrEqual(2);
  });

  test("a store failure is not leaked to the caller", async () => {
    const email = uniqueEmail();
    const original = store.getActiveLicensesByEmail.bind(store);
    store.getActiveLicensesByEmail = async () => {
      throw new Error("database down");
    };

    const response = await resendRoute.POST(resendRequest({ email }));
    store.getActiveLicensesByEmail = original;

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual(neutral);
  });
});
