import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import {
  activateDevice,
  deactivateDevice,
  productHardwareDigest,
  refreshDevice,
  verifyDeviceRefreshCredential,
} from "@/lib/license";
import {
  FakeStore,
  issueChallenge,
  makeDeviceKey,
  signChallenge,
  type StoredLicense,
} from "./fakes";

const previousPepper = process.env.LICENSE_KEY_LOOKUP_PEPPER;

beforeAll(() => {
  process.env.LICENSE_KEY_LOOKUP_PEPPER = "test-pepper-value";
});

afterAll(() => {
  if (previousPepper === undefined) {
    delete process.env.LICENSE_KEY_LOOKUP_PEPPER;
  } else {
    process.env.LICENSE_KEY_LOOKUP_PEPPER = previousPepper;
  }
});

async function activate(
  store: FakeStore,
  license: StoredLicense,
  deviceId: string,
  keyPair = makeDeviceKey(),
  hardwareUuidDigest?: string,
) {
  const { challengeId, nonce } = await issueChallenge(store, "activate", {
    licenseId: license.id,
    deviceId,
  });
  const result = await activateDevice(store, {
    licenseKey: license.key,
    challengeId,
    nonce,
    deviceId,
    devicePublicKey: keyPair.encodedPublicKey,
    signature: signChallenge(keyPair.privateKey, "activate", challengeId, nonce),
    appVersion: "2.0.0",
    hardwareUuidDigest,
  });
  return { result, keyPair };
}

const licenseKey = "EDITH-1111-2222-3333-4444";

describe("v2 activation", () => {
  test.each([1, 3, 5])(
    "fills every seat at allowance %i then rejects the next device",
    async (allowance) => {
      const store = new FakeStore();
      const license = store.addLicense({
        key: licenseKey,
        maxMachines: allowance,
      });

      for (let seat = 1; seat <= allowance; seat += 1) {
        const { result } = await activate(store, license, `device-${seat}`);

        expect(result).toMatchObject({
          ok: true,
          planId: "personal_3",
          machinesUsed: seat,
          maxMachines: allowance,
        });
      }

      const { result } = await activate(store, license, "device-extra");

      expect(result).toEqual({
        ok: false,
        error: "machine_limit_reached",
        machinesUsed: allowance,
        maxMachines: allowance,
      });
    },
  );

  test("unknown key returns invalid_credentials, not seat details", async () => {
    const store = new FakeStore();
    const license = store.addLicense({ key: licenseKey, maxMachines: 1 });
    const { result } = await activate(
      store,
      { ...license, key: "EDITH-0000-0000-0000-0000" },
      "device-1",
    );

    expect(result).toEqual({ ok: false, error: "invalid_credentials" });
  });

  test("re-activation of the same device is idempotent", async () => {
    const store = new FakeStore();
    const license = store.addLicense({ key: licenseKey, maxMachines: 1 });
    const first = await activate(store, license, "device-1");
    const second = await activate(store, license, "device-1", first.keyPair);

    expect(first.result.ok).toBe(true);
    expect(second.result).toMatchObject({
      ok: true,
      machinesUsed: 1,
      maxMachines: 1,
    });
    expect(await store.countActiveSeats(license.id)).toBe(1);
  });

  test("a consumed challenge cannot be replayed", async () => {
    const store = new FakeStore();
    const license = store.addLicense({ key: licenseKey, maxMachines: 3 });
    const keyPair = makeDeviceKey();
    const { challengeId, nonce } = await issueChallenge(store, "activate", {
      licenseId: license.id,
      deviceId: "device-1",
    });
    const input = {
      licenseKey: license.key,
      challengeId,
      nonce,
      deviceId: "device-1",
      devicePublicKey: keyPair.encodedPublicKey,
      signature: signChallenge(keyPair.privateKey, "activate", challengeId, nonce),
      appVersion: "2.0.0",
    };

    expect((await activateDevice(store, input)).ok).toBe(true);
    expect(await activateDevice(store, { ...input, deviceId: "device-2" })).toEqual({
      ok: false,
      error: "invalid_credentials",
    });
  });

  test("a challenge minted for one device cannot be consumed by another", async () => {
    const store = new FakeStore();
    const license = store.addLicense({ key: licenseKey, maxMachines: 3 });
    const keyPair = makeDeviceKey();
    const { challengeId, nonce } = await issueChallenge(store, "activate", {
      licenseId: license.id,
      deviceId: "device-a",
    });

    const result = await activateDevice(store, {
      licenseKey: license.key,
      challengeId,
      nonce,
      deviceId: "device-b",
      devicePublicKey: keyPair.encodedPublicKey,
      signature: signChallenge(keyPair.privateKey, "activate", challengeId, nonce),
      appVersion: "2.0.0",
    });

    expect(result).toEqual({ ok: false, error: "invalid_credentials" });
    expect(await store.countActiveSeats(license.id)).toBe(0);
  });

  test("a challenge minted under one license cannot activate another", async () => {
    const store = new FakeStore();
    const licenseA = store.addLicense({ key: licenseKey, maxMachines: 3 });
    const licenseB = store.addLicense({
      key: "EDITH-5555-6666-7777-8888",
      maxMachines: 3,
    });
    const keyPair = makeDeviceKey();
    const { challengeId, nonce } = await issueChallenge(store, "activate", {
      licenseId: licenseB.id,
      deviceId: "device-1",
    });

    const result = await activateDevice(store, {
      licenseKey: licenseA.key,
      challengeId,
      nonce,
      deviceId: "device-1",
      devicePublicKey: keyPair.encodedPublicKey,
      signature: signChallenge(keyPair.privateKey, "activate", challengeId, nonce),
      appVersion: "2.0.0",
    });

    expect(result).toEqual({ ok: false, error: "invalid_credentials" });
    expect(await store.countActiveSeats(licenseA.id)).toBe(0);
  });

  test("an expired challenge fails", async () => {
    const store = new FakeStore();
    const license = store.addLicense({ key: licenseKey, maxMachines: 3 });
    const keyPair = makeDeviceKey();
    const { challengeId, nonce } = await issueChallenge(
      store,
      "activate",
      { licenseId: license.id, deviceId: "device-1" },
      new Date(Date.now() - 1_000),
    );

    const result = await activateDevice(store, {
      licenseKey: license.key,
      challengeId,
      nonce,
      deviceId: "device-1",
      devicePublicKey: keyPair.encodedPublicKey,
      signature: signChallenge(keyPair.privateKey, "activate", challengeId, nonce),
      appVersion: "2.0.0",
    });

    expect(result).toEqual({ ok: false, error: "invalid_credentials" });
  });

  test("a signature from another key fails", async () => {
    const store = new FakeStore();
    const license = store.addLicense({ key: licenseKey, maxMachines: 3 });
    const device = makeDeviceKey();
    const attacker = makeDeviceKey();
    const { challengeId, nonce } = await issueChallenge(store, "activate", {
      licenseId: license.id,
      deviceId: "device-1",
    });

    const result = await activateDevice(store, {
      licenseKey: license.key,
      challengeId,
      nonce,
      deviceId: "device-1",
      devicePublicKey: device.encodedPublicKey,
      signature: signChallenge(
        attacker.privateKey,
        "activate",
        challengeId,
        nonce,
      ),
      appVersion: "2.0.0",
    });

    expect(result).toEqual({ ok: false, error: "invalid_credentials" });
    expect(await store.countActiveSeats(license.id)).toBe(0);
  });
});

describe("v2 refresh", () => {
  test("rotates the credential with a 60 second overlap", async () => {
    const store = new FakeStore();
    const license = store.addLicense({ key: licenseKey, maxMachines: 1 });
    const { result, keyPair } = await activate(store, license, "device-1");

    expect(result.ok).toBe(true);

    const oldCredential = result.ok ? result.refreshCredential : "";
    const { challengeId, nonce } = await issueChallenge(store, "refresh", {
      deviceId: "device-1",
    });
    const now = new Date();
    const refreshed = await refreshDevice(
      store,
      {
        deviceId: "device-1",
        challengeId,
        nonce,
        signature: signChallenge(keyPair.privateKey, "refresh", challengeId, nonce),
        appVersion: "2.0.1",
      },
      now,
    );

    expect(refreshed.ok).toBe(true);

    const newCredential = refreshed.ok ? refreshed.refreshCredential : "";

    expect(newCredential).not.toBe(oldCredential);
    expect(
      await verifyDeviceRefreshCredential(store, "device-1", newCredential, now),
    ).toBe(true);
    expect(
      await verifyDeviceRefreshCredential(
        store,
        "device-1",
        oldCredential,
        new Date(now.getTime() + 30_000),
      ),
    ).toBe(true);
    expect(
      await verifyDeviceRefreshCredential(
        store,
        "device-1",
        oldCredential,
        new Date(now.getTime() + 61_000),
      ),
    ).toBe(false);
  });

  test("a copied refresh credential without the private key fails", async () => {
    const store = new FakeStore();
    const license = store.addLicense({ key: licenseKey, maxMachines: 1 });
    const { result } = await activate(store, license, "device-1");

    expect(result.ok).toBe(true);

    const stolenCredential = result.ok ? result.refreshCredential : "";

    expect(
      await verifyDeviceRefreshCredential(store, "device-1", stolenCredential),
    ).toBe(true);

    const attacker = makeDeviceKey();
    const { challengeId, nonce } = await issueChallenge(store, "refresh", {
      deviceId: "device-1",
    });
    const refreshed = await refreshDevice(store, {
      deviceId: "device-1",
      challengeId,
      nonce,
      signature: signChallenge(attacker.privateKey, "refresh", challengeId, nonce),
      appVersion: "2.0.1",
    });

    expect(refreshed).toEqual({ ok: false, error: "invalid_credentials" });
  });
});

describe("v2 deactivation", () => {
  test("frees exactly one seat and revokes credentials", async () => {
    const store = new FakeStore();
    const license = store.addLicense({ key: licenseKey, maxMachines: 1 });
    const first = await activate(store, license, "device-1");

    expect(first.result.ok).toBe(true);
    expect((await activate(store, license, "device-2")).result).toMatchObject({
      ok: false,
      error: "machine_limit_reached",
    });

    const credential = first.result.ok ? first.result.refreshCredential : "";
    const { challengeId, nonce } = await issueChallenge(store, "deactivate", {
      deviceId: "device-1",
    });
    const deactivated = await deactivateDevice(store, {
      deviceId: "device-1",
      challengeId,
      nonce,
      signature: signChallenge(
        first.keyPair.privateKey,
        "deactivate",
        challengeId,
        nonce,
      ),
    });

    expect(deactivated).toEqual({ ok: true });
    expect(await store.countActiveSeats(license.id)).toBe(0);
    expect(
      await verifyDeviceRefreshCredential(store, "device-1", credential),
    ).toBe(false);
    expect(
      store.securityEvents.some(
        (event) => event.eventType === "device_deactivated",
      ),
    ).toBe(true);

    const replacement = await activate(store, license, "device-2");

    expect(replacement.result).toMatchObject({
      ok: true,
      machinesUsed: 1,
      maxMachines: 1,
    });
  });
});

describe("same-Mac reinstall dedupe", () => {
  const digestH = productHardwareDigest("11111111-2222-3333-4444-555555555555");
  const digestOther = productHardwareDigest(
    "99999999-8888-7777-6666-555555555555",
  );

  test("reinstall on the same Mac reuses the seat", async () => {
    const store = new FakeStore();
    const license = store.addLicense({ key: licenseKey, maxMachines: 1 });

    const first = await activate(
      store,
      license,
      "device-a",
      makeDeviceKey(),
      digestH,
    );
    expect(first.result).toMatchObject({ ok: true, machinesUsed: 1 });

    const second = await activate(
      store,
      license,
      "device-b",
      makeDeviceKey(),
      digestH,
    );

    expect(second.result).toMatchObject({ ok: true, machinesUsed: 1 });
    expect((await store.getDevice("device-a"))?.status).toBe("deactivated");
    expect((await store.getDevice("device-b"))?.status).toBe("active");
    expect(await store.countActiveSeats(license.id)).toBe(1);
    expect(
      store.securityEvents.some(
        (event) => event.eventType === "device_reclaimed",
      ),
    ).toBe(true);
  });

  test("a different Mac still hits the seat limit", async () => {
    const store = new FakeStore();
    const license = store.addLicense({ key: licenseKey, maxMachines: 1 });

    await activate(store, license, "device-a", makeDeviceKey(), digestH);
    const second = await activate(
      store,
      license,
      "device-b",
      makeDeviceKey(),
      digestOther,
    );

    expect(second.result).toEqual({
      ok: false,
      error: "machine_limit_reached",
      machinesUsed: 1,
      maxMachines: 1,
    });
  });

  test("activation without a digest keeps existing behavior", async () => {
    const store = new FakeStore();
    const license = store.addLicense({ key: licenseKey, maxMachines: 1 });

    await activate(store, license, "device-a");
    const second = await activate(store, license, "device-b");

    expect(second.result).toEqual({
      ok: false,
      error: "machine_limit_reached",
      machinesUsed: 1,
      maxMachines: 1,
    });
    expect((await store.getDevice("device-a"))?.status).toBe("active");
  });

  test("productHardwareDigest matches the known vector", () => {
    expect(
      productHardwareDigest("1AB2C3D4-5E6F-7A8B-9C0D-1E2F3A4B5C6D"),
    ).toBe(
      "394377a8cfd10eff5793965225efbe64c3f7e2f67b256675043681f39b59d2e2",
    );
  });
});
