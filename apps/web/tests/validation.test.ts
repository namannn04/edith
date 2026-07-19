import { describe, expect, test } from "bun:test";
import {
  deactivateBodySchema,
  licenseKeySchema,
  parseBearerToken,
  refreshChallengeBodySchema,
  refreshBodySchema,
} from "@/lib/validation";

const validKey = "EDITH-AB12-CD34-EF56-GH78";
const uuid = "0b6f9f9e-1c2d-4e3f-8a9b-0c1d2e3f4a5b";

describe("parseBearerToken", () => {
  test("extracts the token from a valid Bearer header", () => {
    const headers = new Headers({ authorization: "Bearer abc123" });
    expect(parseBearerToken(headers)).toBe("abc123");
  });

  test("returns null when the header is missing", () => {
    expect(parseBearerToken(new Headers())).toBeNull();
  });

  test("returns null for an empty token", () => {
    const headers = new Headers({ authorization: "Bearer " });
    expect(parseBearerToken(headers)).toBeNull();
  });

  test("returns null for a different scheme", () => {
    const headers = new Headers({ authorization: "Basic abc123" });
    expect(parseBearerToken(headers)).toBeNull();
  });

  test("accepts any casing of the scheme", () => {
    expect(
      parseBearerToken(new Headers({ authorization: "bearer tok" })),
    ).toBe("tok");
    expect(
      parseBearerToken(new Headers({ authorization: "BEARER tok" })),
    ).toBe("tok");
  });

  test("tolerates surrounding and internal extra whitespace", () => {
    const headers = new Headers({ authorization: "   Bearer    tok   " });
    expect(parseBearerToken(headers)).toBe("tok");
  });

  test("returns null when the token contains spaces", () => {
    const headers = new Headers({ authorization: "Bearer a b" });
    expect(parseBearerToken(headers)).toBeNull();
  });
});

describe("licenseKeySchema", () => {
  test("accepts EDITH-XXXX-XXXX-XXXX-XXXX shapes", () => {
    expect(licenseKeySchema.safeParse(validKey).success).toBe(true);
    expect(licenseKeySchema.safeParse("EDITH-0000-1111-2222-3333").success).toBe(
      true,
    );
  });

  test("rejects wrong segment counts", () => {
    expect(licenseKeySchema.safeParse("EDITH-AB12-CD34-EF56").success).toBe(
      false,
    );
    expect(
      licenseKeySchema.safeParse("EDITH-AB12-CD34-EF56-GH78-IJ90").success,
    ).toBe(false);
  });

  test("rejects lowercase", () => {
    expect(
      licenseKeySchema.safeParse("EDITH-ab12-cd34-ef56-gh78").success,
    ).toBe(false);
  });

  test("rejects a wrong prefix", () => {
    expect(
      licenseKeySchema.safeParse("EDYTH-AB12-CD34-EF56-GH78").success,
    ).toBe(false);
  });
});

describe("refreshChallengeBodySchema refreshCredential", () => {
  test("accepts edithrc_ tokens", () => {
    const body = { deviceId: "dev-1", refreshCredential: "edithrc_abc-DEF_123" };
    expect(refreshChallengeBodySchema.safeParse(body).success).toBe(true);
  });

  test("rejects tokens without the edithrc_ prefix", () => {
    const body = { deviceId: "dev-1", refreshCredential: "rc_abc123" };
    expect(refreshChallengeBodySchema.safeParse(body).success).toBe(false);
  });
});

describe("strict body schemas", () => {
  const refreshBody = {
    deviceId: "dev-1",
    challengeId: uuid,
    nonce: "nonce_abc",
    signature: "sig_abc",
    appVersion: "1.0.0",
  };
  const deactivateBody = {
    deviceId: "dev-1",
    challengeId: uuid,
    nonce: "nonce_abc",
    signature: "sig_abc",
  };

  test("refreshBodySchema accepts a minimal valid body", () => {
    expect(refreshBodySchema.safeParse(refreshBody).success).toBe(true);
  });

  test("refreshBodySchema rejects unknown extra keys", () => {
    expect(
      refreshBodySchema.safeParse({ ...refreshBody, extra: 1 }).success,
    ).toBe(false);
  });

  test("refreshBodySchema rejects missing required keys", () => {
    const { appVersion, ...rest } = refreshBody;
    expect(refreshBodySchema.safeParse(rest).success).toBe(false);
  });

  test("deactivateBodySchema accepts a minimal valid body", () => {
    expect(deactivateBodySchema.safeParse(deactivateBody).success).toBe(true);
  });

  test("deactivateBodySchema rejects unknown extra keys", () => {
    expect(
      deactivateBodySchema.safeParse({ ...deactivateBody, extra: 1 }).success,
    ).toBe(false);
  });

  test("deactivateBodySchema rejects missing required keys", () => {
    const { signature, ...rest } = deactivateBody;
    expect(deactivateBodySchema.safeParse(rest).success).toBe(false);
  });
});
