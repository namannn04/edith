import {
  createPublicKey,
  generateKeyPairSync,
  verify,
} from "node:crypto";
import { describe, expect, test } from "bun:test";
import { signReceipt } from "@/lib/receipt";

const ed25519SpkiPrefix = Buffer.from("302a300506032b6570032100", "hex");

describe("signed receipts", () => {
  test("round-trips the payload and Ed25519 signature", () => {
    const { privateKey, publicKey } = generateKeyPairSync("ed25519");
    const privateDer = privateKey.export({ format: "der", type: "pkcs8" });
    const publicDer = publicKey.export({ format: "der", type: "spki" });
    const seed = privateDer.subarray(-32);
    const rawPublicKey = publicDer.subarray(-32);
    const verificationKey = createPublicKey({
      key: Buffer.concat([ed25519SpkiPrefix, rawPublicKey]),
      format: "der",
      type: "spki",
    });
    const previousSigningKey = process.env.LICENSE_SIGNING_PRIVATE_KEY;
    process.env.LICENSE_SIGNING_PRIVATE_KEY = seed.toString("base64");

    try {
      const receipt = signReceipt({
        machine: "hardware-uuid",
        label: "Personal",
        keyLast4: "4444",
        now: 1_700_000_000,
      });
      const segments = receipt.split(".");

      expect(segments).toHaveLength(2);

      const [payloadSegment, signatureSegment] = segments;

      expect(payloadSegment).not.toMatch(/[+/=]/);
      expect(signatureSegment).not.toMatch(/[+/=]/);

      const payloadBytes = Buffer.from(payloadSegment, "base64url");
      const signature = Buffer.from(signatureSegment, "base64url");
      const payloadText = payloadBytes.toString("utf8");

      expect(payloadText).toBe(
        '{"machine":"hardware-uuid","label":"Personal","issuedAt":1700000000,"expiresAt":1702592000,"keyLast4":"4444"}',
      );
      expect(JSON.parse(payloadText)).toEqual({
        machine: "hardware-uuid",
        label: "Personal",
        issuedAt: 1_700_000_000,
        expiresAt: 1_702_592_000,
        keyLast4: "4444",
      });
      expect(signature).toHaveLength(64);
      expect(verify(null, payloadBytes, verificationKey, signature)).toBe(true);
    } finally {
      if (previousSigningKey === undefined) {
        delete process.env.LICENSE_SIGNING_PRIVATE_KEY;
      } else {
        process.env.LICENSE_SIGNING_PRIVATE_KEY = previousSigningKey;
      }
    }
  });
});
