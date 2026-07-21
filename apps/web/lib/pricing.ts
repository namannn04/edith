import { z } from "zod";

export type Tier = {
  id: string;
  name: string;
  maxMachines: number;
  priceCents: number;
};

export const tiers: readonly Tier[] = [
  { id: "individual_1", name: "Individual", maxMachines: 1, priceCents: 2500 },
  { id: "personal_3", name: "Personal", maxMachines: 3, priceCents: 4500 },
  { id: "power_5", name: "Power", maxMachines: 5, priceCents: 6500 },
];

export const customTier = {
  id: "custom",
  name: "Custom",
  minMachines: 6,
  maxMachines: 50,
  baseMachines: 5,
  baseCents: 6500,
  perAdditionalMachineCents: 1000,
} as const;

export const customMachinesSchema = z.coerce
  .number()
  .int()
  .min(customTier.minMachines)
  .max(customTier.maxMachines);

export function customPriceCents(machines: number): number {
  const count = customMachinesSchema.parse(machines);

  return (
    customTier.baseCents +
    (count - customTier.baseMachines) * customTier.perAdditionalMachineCents
  );
}

export function getTier(tierId: string): Tier | null {
  return tiers.find((tier) => tier.id === tierId) ?? null;
}

export function priceCentsFor(tierId: string, machines: number): number {
  if (tierId === customTier.id) {
    return customPriceCents(machines);
  }

  const tier = getTier(tierId);

  if (!tier) {
    throw new Error(`Unknown tier ${tierId}`);
  }

  if (tier.maxMachines !== machines) {
    throw new Error(
      `Tier ${tierId} covers ${tier.maxMachines} machines, got ${machines}`,
    );
  }

  return tier.priceCents;
}

export function formatUsd(cents: number): string {
  return `$${(cents / 100).toFixed(2).replace(/\.00$/, "")}`;
}
