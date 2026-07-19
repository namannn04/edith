import { createHash } from "node:crypto";
import {
  challengeMessage,
  nonceDigest,
  publicKeyThumbprint,
  validateDevicePublicKey,
  verifyChallengeSignature,
} from "@/lib/device-auth";
import { keyLookupDigest, normalizeLicenseKey } from "@/lib/license-key";
import { effectiveAllowance } from "@/lib/plans";
import {
  generateRefreshCredential,
  refreshCredentialDigest,
  verifyRefreshCredential,
} from "@/lib/refresh-credential";

export type LicenseRecord = {
  id: string;
  label: string | null;
  planId: string | null;
  status: string;
  active: boolean;
  maxMachines: number;
  customMaxMachines: number | null;
  keyLast4: string | null;
};

export type DeviceRecord = {
  id: string;
  licenseId: string;
  publicKey: string;
  publicKeyThumbprint: string;
  status: string;
  credentialGeneration: number;
};

export type DeviceInput = {
  id: string;
  licenseId: string;
  publicKey: string;
  publicKeyThumbprint: string;
  hardwareUuidDigest: string | null;
  deviceName: string | null;
  appVersion: string | null;
};

export type ChallengeRecord = {
  id: string;
  purpose: string;
  nonceDigest: string;
  licenseId: string | null;
  deviceId: string | null;
  expiresAt: Date;
};

export type ChallengeInput = {
  id: string;
  purpose: string;
  nonceDigest: string;
  licenseId: string | null;
  deviceId: string | null;
  expiresAt: Date;
};

export type CredentialRecord = {
  id: string;
  deviceId: string;
  tokenDigest: string;
  generation: number;
  expiresAt: Date | null;
  revokedAt: Date | null;
};

export type CredentialInput = {
  deviceId: string;
  tokenDigest: string;
  generation: number;
  issuedAt: Date;
};

export type NewLicenseInput = {
  key: string;
  keyDigest: string;
  keyLast4: string;
  label: string | null;
  planId: string;
  maxMachines: number;
};

export type PlanPriceRecord = {
  id: string;
  maxMachines: number;
};

export type PaymentEventRecord = {
  id: string;
  provider: string;
  providerEventId: string;
  eventType: string;
  processingState: string;
  licenseId: string | null;
  error: string | null;
};

export type PaymentEventInput = {
  provider: string;
  providerEventId: string;
  eventType: string;
  orderId: string | null;
  customerId: string | null;
  priceId: string | null;
  processingState: string;
};

export type PaymentEventPatch = {
  processingState: string;
  licenseId?: string | null;
  error?: string | null;
  processedAt?: Date;
};

export type SecurityEventInput = {
  eventType: string;
  licenseId?: string | null;
  deviceId?: string | null;
  actor: string;
  previousStatus?: string | null;
  nextStatus?: string | null;
  detail?: string | null;
};

export function productHardwareDigest(rawUuid: string): string {
  return createHash("sha256").update(`edith:${rawUuid}`, "utf8").digest("hex");
}

export interface LicenseAccess {
  getLicenseByKeyDigest(
    digest: string,
    key: string,
  ): Promise<LicenseRecord | null>;
  getLicenseById(licenseId: string): Promise<LicenseRecord | null>;
  updateLicenseStatus(
    licenseId: string,
    status: string,
    reason: string | null,
  ): Promise<void>;
  countActiveSeats(licenseId: string): Promise<number>;
  getDevice(deviceId: string): Promise<DeviceRecord | null>;
  insertDevice(input: DeviceInput): Promise<void>;
  updateDeviceStatus(
    deviceId: string,
    status: string,
    now: Date,
  ): Promise<void>;
  touchDeviceVerification(
    deviceId: string,
    appVersion: string | null,
    now: Date,
  ): Promise<void>;
  setDeviceHardwareDigest(deviceId: string, digest: string): Promise<void>;
  reclaimSeatsByHardwareDigest(
    licenseId: string,
    hardwareUuidDigest: string,
    exceptDeviceId: string,
    now: Date,
  ): Promise<void>;
  insertChallenge(input: ChallengeInput): Promise<void>;
  consumeChallenge(
    challengeId: string,
    now: Date,
  ): Promise<ChallengeRecord | null>;
  insertCredential(input: CredentialInput): Promise<void>;
  getActiveCredentials(deviceId: string, now: Date): Promise<CredentialRecord[]>;
  revokeCredentials(deviceId: string, reason: string, now: Date): Promise<void>;
  rotateCredential(
    deviceId: string,
    tokenDigest: string,
    generation: number,
    now: Date,
  ): Promise<void>;
  insertLicense(input: NewLicenseInput): Promise<{ id: string }>;
  getPlanByPriceId(
    provider: string,
    priceId: string,
  ): Promise<PlanPriceRecord | null>;
  getLicenseIdByOrderId(
    provider: string,
    orderId: string,
  ): Promise<string | null>;
  getPaymentEvent(
    provider: string,
    providerEventId: string,
  ): Promise<PaymentEventRecord | null>;
  insertPaymentEvent(input: PaymentEventInput): Promise<PaymentEventRecord>;
  updatePaymentEvent(id: string, patch: PaymentEventPatch): Promise<void>;
  insertSecurityEvent(input: SecurityEventInput): Promise<void>;
}

export interface LicenseStore extends LicenseAccess {
  runExclusive<T>(
    key: string,
    operation: (access: LicenseAccess) => Promise<T>,
  ): Promise<T>;
}

export type DeviceSessionSuccess = {
  ok: true;
  licenseId: string;
  planId: string | null;
  machinesUsed: number;
  maxMachines: number;
  deviceKeyThumbprint: string;
  refreshCredential: string;
};

export type DeviceFailure =
  | { ok: false; error: "invalid_credentials" }
  | {
      ok: false;
      error: "machine_limit_reached";
      machinesUsed: number;
      maxMachines: number;
    };

export type ActivateDeviceInput = {
  licenseKey: string;
  challengeId: string;
  nonce: string;
  deviceId: string;
  devicePublicKey: string;
  signature: string;
  appVersion: string;
  deviceName?: string;
  hardwareUuidDigest?: string;
};

export type RefreshDeviceInput = {
  deviceId: string;
  challengeId: string;
  nonce: string;
  signature: string;
  appVersion: string;
};

export type DeactivateDeviceInput = {
  deviceId: string;
  challengeId: string;
  nonce: string;
  signature: string;
};

const invalidCredentials: DeviceFailure = {
  ok: false,
  error: "invalid_credentials",
};

function isActiveLicense(
  license: LicenseRecord | null,
): license is LicenseRecord {
  return license !== null && license.active && license.status === "active";
}

async function consumeVerifiedChallenge(
  access: LicenseAccess,
  input: { challengeId: string; nonce: string; signature: string },
  purpose: string,
  publicKey: string,
  now: Date,
): Promise<ChallengeRecord | null> {
  const challenge = await access.consumeChallenge(input.challengeId, now);

  if (
    !challenge ||
    challenge.purpose !== purpose ||
    challenge.expiresAt.getTime() <= now.getTime() ||
    nonceDigest(input.nonce) !== challenge.nonceDigest
  ) {
    return null;
  }

  const message = challengeMessage(purpose, challenge.id, input.nonce);

  if (!verifyChallengeSignature(publicKey, message, input.signature)) {
    return null;
  }

  return challenge;
}

async function issueCredential(
  access: LicenseAccess,
  device: { id: string; credentialGeneration: number },
  now: Date,
): Promise<string> {
  const credential = generateRefreshCredential();
  const generation = device.credentialGeneration + 1;

  if (device.credentialGeneration === 0) {
    await access.insertCredential({
      deviceId: device.id,
      tokenDigest: refreshCredentialDigest(credential),
      generation,
      issuedAt: now,
    });
  } else {
    await access.rotateCredential(
      device.id,
      refreshCredentialDigest(credential),
      generation,
      now,
    );
  }

  return credential;
}

async function sessionSuccess(
  access: LicenseAccess,
  license: LicenseRecord,
  thumbprint: string,
  refreshCredential: string,
): Promise<DeviceSessionSuccess> {
  return {
    ok: true,
    licenseId: license.id,
    planId: license.planId,
    machinesUsed: await access.countActiveSeats(license.id),
    maxMachines: effectiveAllowance(license),
    deviceKeyThumbprint: thumbprint,
    refreshCredential,
  };
}

export async function activateDevice(
  store: LicenseStore,
  input: ActivateDeviceInput,
  now = new Date(),
): Promise<DeviceSessionSuccess | DeviceFailure> {
  if (!validateDevicePublicKey(input.devicePublicKey)) {
    return invalidCredentials;
  }

  const key = normalizeLicenseKey(input.licenseKey);
  const digest = keyLookupDigest(key);
  return store.runExclusive(digest, async (access) => {
    const license = await access.getLicenseByKeyDigest(digest, key);

    if (!isActiveLicense(license)) {
      return invalidCredentials;
    }

    const challenge = await consumeVerifiedChallenge(
      access,
      input,
      "activate",
      input.devicePublicKey,
      now,
    );

    if (
      !challenge ||
      challenge.deviceId !== input.deviceId ||
      (challenge.licenseId ?? license.id) !== license.id
    ) {
      return invalidCredentials;
    }

    const thumbprint = publicKeyThumbprint(input.devicePublicKey);
    const existing = await access.getDevice(input.deviceId);

    if (existing) {
      if (
        existing.licenseId !== license.id ||
        existing.publicKeyThumbprint !== thumbprint
      ) {
        return invalidCredentials;
      }

      if (existing.status === "active") {
        const credential = await issueCredential(access, existing, now);
        await access.touchDeviceVerification(
          existing.id,
          input.appVersion,
          now,
        );
        return sessionSuccess(access, license, thumbprint, credential);
      }

      if (input.hardwareUuidDigest) {
        await access.reclaimSeatsByHardwareDigest(
          license.id,
          input.hardwareUuidDigest,
          input.deviceId,
          now,
        );
      }

      const machinesUsed = await access.countActiveSeats(license.id);
      const maxMachines = effectiveAllowance(license);

      if (machinesUsed >= maxMachines) {
        return {
          ok: false,
          error: "machine_limit_reached",
          machinesUsed,
          maxMachines,
        };
      }

      await access.updateDeviceStatus(existing.id, "active", now);
      if (input.hardwareUuidDigest) {
        await access.setDeviceHardwareDigest(
          existing.id,
          input.hardwareUuidDigest,
        );
      }
      const credential = await issueCredential(access, existing, now);
      await access.touchDeviceVerification(existing.id, input.appVersion, now);
      await access.insertSecurityEvent({
        eventType: "device_reactivated",
        licenseId: license.id,
        deviceId: existing.id,
        actor: "customer",
      });
      return sessionSuccess(access, license, thumbprint, credential);
    }

    if (input.hardwareUuidDigest) {
      await access.reclaimSeatsByHardwareDigest(
        license.id,
        input.hardwareUuidDigest,
        input.deviceId,
        now,
      );
    }

    const machinesUsed = await access.countActiveSeats(license.id);
    const maxMachines = effectiveAllowance(license);

    if (machinesUsed >= maxMachines) {
      return {
        ok: false,
        error: "machine_limit_reached",
        machinesUsed,
        maxMachines,
      };
    }

    await access.insertDevice({
      id: input.deviceId,
      licenseId: license.id,
      publicKey: input.devicePublicKey,
      publicKeyThumbprint: thumbprint,
      hardwareUuidDigest: input.hardwareUuidDigest ?? null,
      deviceName: input.deviceName ?? null,
      appVersion: input.appVersion,
    });
    const credential = await issueCredential(
      access,
      { id: input.deviceId, credentialGeneration: 0 },
      now,
    );
    await access.insertSecurityEvent({
      eventType: "device_activated",
      licenseId: license.id,
      deviceId: input.deviceId,
      actor: "customer",
    });
    return sessionSuccess(access, license, thumbprint, credential);
  });
}

export async function refreshDevice(
  store: LicenseStore,
  input: RefreshDeviceInput,
  now = new Date(),
): Promise<DeviceSessionSuccess | DeviceFailure> {
  return store.runExclusive(input.deviceId, async (access) => {
    const device = await access.getDevice(input.deviceId);

    if (!device || device.status !== "active") {
      return invalidCredentials;
    }

    const license = await access.getLicenseById(device.licenseId);

    if (!isActiveLicense(license)) {
      return invalidCredentials;
    }

    const challenge = await consumeVerifiedChallenge(
      access,
      input,
      "refresh",
      device.publicKey,
      now,
    );

    if (!challenge || challenge.deviceId !== device.id) {
      return invalidCredentials;
    }

    const credential = await issueCredential(access, device, now);
    await access.touchDeviceVerification(device.id, input.appVersion, now);
    return sessionSuccess(
      access,
      license,
      device.publicKeyThumbprint,
      credential,
    );
  });
}

export async function deactivateDevice(
  store: LicenseStore,
  input: DeactivateDeviceInput,
  now = new Date(),
): Promise<{ ok: true } | DeviceFailure> {
  return store.runExclusive(input.deviceId, async (access) => {
    const device = await access.getDevice(input.deviceId);

    if (!device || device.status !== "active") {
      return invalidCredentials;
    }

    const challenge = await consumeVerifiedChallenge(
      access,
      input,
      "deactivate",
      device.publicKey,
      now,
    );

    if (!challenge || challenge.deviceId !== device.id) {
      return invalidCredentials;
    }

    await access.updateDeviceStatus(device.id, "deactivated", now);
    await access.revokeCredentials(device.id, "deactivated", now);
    await access.insertSecurityEvent({
      eventType: "device_deactivated",
      licenseId: device.licenseId,
      deviceId: device.id,
      actor: "customer",
    });
    return { ok: true };
  });
}

export async function verifyDeviceRefreshCredential(
  store: LicenseAccess,
  deviceId: string,
  credential: string,
  now = new Date(),
): Promise<boolean> {
  if (!credential.startsWith("edithrc_")) {
    return false;
  }

  const credentials = await store.getActiveCredentials(deviceId, now);
  return credentials.some((record) =>
    verifyRefreshCredential(credential, record.tokenDigest),
  );
}
