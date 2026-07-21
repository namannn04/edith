"use client";

import { useState } from "react";
import {
  customPriceCents,
  customTier,
  formatUsd,
  tiers,
} from "@/lib/pricing";

type Status = { state: "idle" } | { state: "loading"; planId: string } | {
  state: "error";
  message: string;
};

async function startCheckout(
  planId: string,
  machines: number,
): Promise<string> {
  const response = await fetch("/api/checkout", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ planId, machines }),
  });

  if (!response.ok) {
    throw new Error("checkout_failed");
  }

  const body = (await response.json()) as { url?: string };

  if (!body.url) {
    throw new Error("checkout_failed");
  }

  return body.url;
}

export function PricingPlans() {
  const [machines, setMachines] = useState(10);
  const [status, setStatus] = useState<Status>({ state: "idle" });

  async function buy(planId: string, seats: number) {
    setStatus({ state: "loading", planId });

    try {
      window.location.href = await startCheckout(planId, seats);
    } catch {
      setStatus({
        state: "error",
        message: "Could not start checkout. Please try again.",
      });
    }
  }

  const loadingPlan = status.state === "loading" ? status.planId : null;

  return (
    <>
      <div className="grid gap-4 sm:grid-cols-3">
        {tiers.map((tier) => (
          <div
            key={tier.id}
            className="flex flex-col rounded-xl border border-line bg-card p-6"
          >
            <p className="font-medium text-[12px] text-accent uppercase tracking-[0.18em]">
              {tier.name}
            </p>
            <p className="mt-3 font-semibold text-[32px] tracking-[-0.02em]">
              {formatUsd(tier.priceCents)}
            </p>
            <p className="mt-1 text-[14px] text-muted">
              {tier.maxMachines === 1 ? "1 Mac" : `${tier.maxMachines} Macs`}
            </p>
            <button
              type="button"
              disabled={loadingPlan !== null}
              onClick={() => buy(tier.id, tier.maxMachines)}
              className="mt-6 rounded-lg bg-accent px-4 py-2.5 font-medium text-[14px] text-accent-fg disabled:opacity-60"
            >
              {loadingPlan === tier.id ? "Starting…" : "Buy"}
            </button>
          </div>
        ))}
      </div>

      <div className="mt-4 rounded-xl border border-line bg-card p-6">
        <p className="font-medium text-[12px] text-accent uppercase tracking-[0.18em]">
          {customTier.name}
        </p>
        <div className="mt-3 flex flex-wrap items-end gap-x-6 gap-y-4">
          <div>
            <p className="font-semibold text-[32px] tracking-[-0.02em]">
              {formatUsd(customPriceCents(machines))}
            </p>
            <p className="mt-1 text-[14px] text-muted">
              {machines} Macs, {formatUsd(customPriceCents(machines) / machines)}{" "}
              each
            </p>
          </div>
          <label className="flex items-center gap-3 text-[14px] text-muted">
            Macs
            <input
              type="number"
              min={customTier.minMachines}
              max={customTier.maxMachines}
              value={machines}
              onChange={(event) => {
                const next = Number(event.target.value);

                if (
                  Number.isInteger(next) &&
                  next >= customTier.minMachines &&
                  next <= customTier.maxMachines
                ) {
                  setMachines(next);
                }
              }}
              className="w-20 rounded-lg border border-line-2 bg-surface-2 px-3 py-2 text-fg"
            />
          </label>
          <button
            type="button"
            disabled={loadingPlan !== null}
            onClick={() => buy(customTier.id, machines)}
            className="rounded-lg bg-accent px-4 py-2.5 font-medium text-[14px] text-accent-fg disabled:opacity-60"
          >
            {loadingPlan === customTier.id ? "Starting…" : "Buy"}
          </button>
        </div>
        <p className="mt-4 text-[13px] text-subtle">
          {formatUsd(customTier.baseCents)} for {customTier.baseMachines} Macs,
          plus {formatUsd(customTier.perAdditionalMachineCents)} for each
          additional Mac, up to {customTier.maxMachines}. Need more?{" "}
          <a className="text-accent" href="mailto:kpulkit15234@gmail.com">
            Get in touch
          </a>
          .
        </p>
      </div>

      {status.state === "error" ? (
        <p className="mt-4 text-[14px] text-danger">{status.message}</p>
      ) : null}
    </>
  );
}
