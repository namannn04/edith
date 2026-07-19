import { createPrivateKey, sign } from "node:crypto";

const ed25519Pkcs8Prefix = Buffer.from(
  "302e020100300506032b657004220420",
  "hex",
);
const receiptLifetimeSeconds = 30 * 86_400;

export type ReceiptInput = {
  machine: string;
  label: string;
  keyLast4: string;
  now: number;
};

function getSigningKey() {
  const encodedSeed = process.env.LICENSE_SIGNING_PRIVATE_KEY;

  if (!encodedSeed) {
    throw new Error("LICENSE_SIGNING_PRIVATE_KEY is missing");
  }

  if (!/^[A-Za-z0-9+/]{43}=$/.test(encodedSeed)) {
    throw new Error(
      "LICENSE_SIGNING_PRIVATE_KEY must be base64 for a 32-byte Ed25519 seed",
    );
  }

  const seed = Buffer.from(encodedSeed, "base64");

  if (seed.length !== 32 || seed.toString("base64") !== encodedSeed) {
    throw new Error(
      "LICENSE_SIGNING_PRIVATE_KEY must be base64 for a 32-byte Ed25519 seed",
    );
  }

  const der = Buffer.concat([ed25519Pkcs8Prefix, seed]);
  return createPrivateKey({ key: der, format: "der", type: "pkcs8" });
}

function base64Url(value: string | Buffer): string {
  return Buffer.from(value).toString("base64url");
}

export function signReceipt(input: ReceiptInput): string {
  const payload = JSON.stringify({
    machine: input.machine,
    label: input.label,
    issuedAt: input.now,
    expiresAt: input.now + receiptLifetimeSeconds,
    keyLast4: input.keyLast4,
  });
  const message = Buffer.from(payload, "utf8");
  const signature = sign(null, message, getSigningKey());
  return `${base64Url(message)}.${base64Url(signature)}`;
}
