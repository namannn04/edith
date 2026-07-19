import { z } from "zod";

export const licenseKeySchema = z
  .string()
  .regex(/^EDITH-[A-Z0-9]{4}(?:-[A-Z0-9]{4}){3}$/);

const base64UrlSchema = z
  .string()
  .min(1)
  .max(2048)
  .regex(/^[A-Za-z0-9_-]+$/);

export const deviceIdSchema = z.string().trim().min(1).max(255);

const challengeIdSchema = z.string().uuid();
const appVersionSchema = z.string().trim().min(1).max(64);
const deviceNameSchema = z.string().trim().min(1).max(255);
const hardwareUuidDigestSchema = z.string().regex(/^[a-f0-9]{64}$/);

export const activationChallengeBodySchema = z
  .object({
    licenseKey: licenseKeySchema,
    deviceId: deviceIdSchema,
    devicePublicKey: base64UrlSchema,
    purpose: z.enum(["activate"]).optional(),
  })
  .strict();

export const activationBodySchema = z
  .object({
    licenseKey: licenseKeySchema,
    challengeId: challengeIdSchema,
    nonce: base64UrlSchema,
    deviceId: deviceIdSchema,
    devicePublicKey: base64UrlSchema,
    signature: base64UrlSchema,
    appVersion: appVersionSchema,
    deviceName: deviceNameSchema.optional(),
    hardwareUuidDigest: hardwareUuidDigestSchema.optional(),
  })
  .strict();

export const refreshChallengeBodySchema = z
  .object({
    deviceId: deviceIdSchema,
    refreshCredential: z
      .string()
      .max(128)
      .regex(/^edithrc_[A-Za-z0-9_-]+$/),
    purpose: z.enum(["refresh", "deactivate"]).optional(),
  })
  .strict();

export const refreshBodySchema = z
  .object({
    deviceId: deviceIdSchema,
    challengeId: challengeIdSchema,
    nonce: base64UrlSchema,
    signature: base64UrlSchema,
    appVersion: appVersionSchema,
  })
  .strict();

export const deactivateBodySchema = z
  .object({
    deviceId: deviceIdSchema,
    challengeId: challengeIdSchema,
    nonce: base64UrlSchema,
    signature: base64UrlSchema,
  })
  .strict();

export function parseBearerToken(headers: Headers): string | null {
  const header = headers.get("authorization");

  if (!header) {
    return null;
  }

  const match = /^Bearer\s+(\S+)$/i.exec(header.trim());
  return match ? match[1] : null;
}
