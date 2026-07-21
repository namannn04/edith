import { describe, expect, test } from "bun:test";
import {
  customMachinesSchema,
  customPriceCents,
  customPricePaise,
  customTier,
  formatUsd,
  getTier,
  priceCentsFor,
  pricePaiseFor,
  tiers,
} from "@/lib/pricing";

describe("fixed tiers", () => {
  test("matches the published ladder", () => {
    expect(
      tiers.map((tier) => [
        tier.maxMachines,
        tier.priceCents,
        tier.pricePaise,
      ]),
    ).toEqual([
      [1, 2500, 210000],
      [3, 4500, 380000],
      [5, 6500, 550000],
    ]);
  });

  test("resolves by id", () => {
    expect(getTier("personal_3")?.priceCents).toBe(4500);
    expect(getTier("mystery_9")).toBeNull();
  });

  test("rejects a machine count the tier does not cover", () => {
    expect(() => priceCentsFor("personal_3", 4)).toThrow();
    expect(priceCentsFor("personal_3", 3)).toBe(4500);
    expect(() => pricePaiseFor("personal_3", 4)).toThrow();
    expect(pricePaiseFor("personal_3", 3)).toBe(380000);
  });
});

describe("custom pricing", () => {
  test("continues the ladder from the five-Mac base", () => {
    expect(customPriceCents(6)).toBe(7500);
    expect(customPriceCents(10)).toBe(11500);
    expect(customPriceCents(20)).toBe(21500);
    expect(customPriceCents(50)).toBe(51500);
  });

  test("stays cheaper per Mac than the tier below it", () => {
    const powerPerMac = 6500 / 5;

    for (let machines = customTier.minMachines; machines <= 50; machines += 1) {
      expect(customPriceCents(machines) / machines).toBeLessThan(powerPerMac);
    }
  });

  test("never undercuts stacking smaller licences", () => {
    expect(customPriceCents(6)).toBeLessThan(6500 + 2500);
  });

  test("increases strictly with machine count", () => {
    for (let machines = 7; machines <= 50; machines += 1) {
      expect(customPriceCents(machines)).toBeGreaterThan(
        customPriceCents(machines - 1),
      );
    }
  });

  test("uses the INR base-plus-marginal ladder", () => {
    expect(customPricePaise(6)).toBe(635000);
    expect(customPricePaise(10)).toBe(975000);
    expect(customPricePaise(20)).toBe(1825000);
    expect(customPricePaise(50)).toBe(4375000);
  });

  test("INR custom pricing stays below the five-Mac per-Mac rate", () => {
    const powerPerMac = 550000 / 5;

    for (let machines = customTier.minMachines; machines <= 50; machines += 1) {
      expect(customPricePaise(machines) / machines).toBeLessThan(powerPerMac);
    }
  });

  test("INR custom pricing increases strictly", () => {
    for (let machines = 7; machines <= 50; machines += 1) {
      expect(customPricePaise(machines)).toBeGreaterThan(
        customPricePaise(machines - 1),
      );
    }
  });

  test("rejects counts outside the custom range", () => {
    expect(() => customPriceCents(5)).toThrow();
    expect(() => customPriceCents(51)).toThrow();
    expect(() => customPriceCents(0)).toThrow();
    expect(() => customPriceCents(-3)).toThrow();
    expect(() => customPriceCents(7.5)).toThrow();
    expect(() => customPricePaise(5)).toThrow();
    expect(() => customPricePaise(51)).toThrow();
  });

  test("coerces numeric strings from query parameters", () => {
    expect(customMachinesSchema.parse("12")).toBe(12);
    expect(() => customMachinesSchema.parse("many")).toThrow();
  });

  test("caps at fifty machines", () => {
    expect(customTier.maxMachines).toBe(50);
    expect(() => customMachinesSchema.parse(51)).toThrow();
  });
});

describe("plan seed coverage", () => {
  test("every plan the pricing module can emit is seeded", async () => {
    const seed = await Bun.file(
      new URL("../drizzle/0005_polar_plans.sql", import.meta.url),
    ).text();

    for (const planId of [...tiers.map((tier) => tier.id), customTier.id]) {
      expect(seed).toContain(`'${planId}'`);
    }
  });

  test("seeded machine counts match the tiers", async () => {
    const seed = await Bun.file(
      new URL("../drizzle/0005_polar_plans.sql", import.meta.url),
    ).text();

    for (const tier of tiers) {
      expect(seed).toMatch(
        new RegExp(`'${tier.id}'[^\\n]*,\\s*${tier.maxMachines},`),
      );
    }

    expect(seed).toMatch(
      new RegExp(`'${customTier.id}'[^\\n]*,\\s*${customTier.maxMachines},`),
    );
  });
});

describe("formatting", () => {
  test("drops trailing zero cents", () => {
    expect(formatUsd(2500)).toBe("$25");
    expect(formatUsd(11500)).toBe("$115");
  });

  test("keeps meaningful cents", () => {
    expect(formatUsd(2599)).toBe("$25.99");
  });
});
