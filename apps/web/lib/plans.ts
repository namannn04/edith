import { z } from "zod";
import { customTier, tiers } from "@/lib/pricing";

export const paymentProvider = "razorpay";

export type Plan = {
  id: string;
  name: string;
  provider: string;
  maxMachines: number;
  billingModel: string;
};

const planCatalog: Record<string, Plan> = Object.fromEntries(
  tiers.map((tier) => [
    tier.id,
    {
      id: tier.id,
      name: tier.name,
      provider: paymentProvider,
      maxMachines: tier.maxMachines,
      billingModel: "one_time",
    },
  ]),
);

export type Ceilings = {
  standardMaxMachinesCap: number;
  customMaxMachinesCap: number;
};

const capSchema = z.coerce.number().int().positive();

function readCap(name: string, fallback: number): number {
  const raw = process.env[name];

  if (raw === undefined || raw === "") {
    return fallback;
  }

  return capSchema.parse(raw);
}

export function readCeilings(): Ceilings {
  return {
    standardMaxMachinesCap: readCap("LICENSE_STANDARD_MAX_MACHINES_CAP", 5),
    customMaxMachinesCap: readCap(
      "LICENSE_CUSTOM_MAX_MACHINES_CAP",
      customTier.maxMachines,
    ),
  };
}

export function getPlan(planId: string): Plan | null {
  return planCatalog[planId] ?? null;
}

export function validatePlanAllowance(
  planId: string,
  allowance: number,
  ceilings: Ceilings,
): void {
  if (!Number.isInteger(allowance) || allowance < 1) {
    throw new Error(`Plan ${planId} allowance must be a positive integer`);
  }

  if (planId === "custom") {
    if (allowance > ceilings.customMaxMachinesCap) {
      throw new Error(
        `Custom allowance ${allowance} exceeds cap ${ceilings.customMaxMachinesCap}`,
      );
    }

    return;
  }

  if (!getPlan(planId)) {
    throw new Error(`Unknown plan ${planId}`);
  }

  if (allowance > ceilings.standardMaxMachinesCap) {
    throw new Error(
      `Plan ${planId} allowance ${allowance} exceeds cap ${ceilings.standardMaxMachinesCap}`,
    );
  }
}

export function effectiveAllowance(license: {
  customMaxMachines: number | null;
  maxMachines: number;
}): number {
  return license.customMaxMachines ?? license.maxMachines;
}
