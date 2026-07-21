"use client";

import { useState } from "react";
import {
  customPriceCents,
  customTier,
  formatUsd,
  resolveMachines,
  tiers,
} from "@/lib/pricing";

type Status =
  | { state: "idle" }
  | { state: "loading"; planId: string }
  | { state: "error"; message: string };

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

function macCountLabel(machines: number): string {
  return machines === 1 ? "1 Mac" : `${machines} Macs`;
}

function tierDescription(machines: number): string {
  if (machines === 1) {
    return "For your everyday Mac.";
  }

  if (machines === 3) {
    return "For a desk, laptop, and one more.";
  }

  return "For a full personal Mac setup.";
}

export function PricingPlans() {
  const [machines, setMachines] = useState(10);
  const [seatInput, setSeatInput] = useState("10");
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
  const customPrice = customPriceCents(machines);
  const seatInputValid = resolveMachines(customTier.id, Number(seatInput)) !== null;

  return (
    <>
      <div className="mb-6 flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p className="font-medium text-[12px] text-accent uppercase tracking-[0.18em]">
            Choose your licence
          </p>
          <h2 className="mt-2">One app. However many Macs you call yours.</h2>
        </div>
        <p className="max-w-75 text-[13px] text-subtle leading-[1.6] sm:text-right">
          More seats lower the effective price per Mac.
        </p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {tiers.map((tier) => {
          const isPopular = tier.maxMachines === 3;

          return (
            <article
              key={tier.id}
              className={`relative flex min-w-0 flex-col rounded-card border bg-card p-6 transition-[transform_0.35s_cubic-bezier(0.16,1,0.3,1),box-shadow_0.35s_ease] hover:-translate-y-1 hover:shadow-card motion-reduce:transition-none ${
                isPopular
                  ? "border-line-2 bg-surface-2 shadow-card lg:-translate-y-2 lg:hover:-translate-y-3"
                  : "border-line"
              }`}
            >
              <div className="flex min-h-7 items-center justify-between gap-2">
                <p className="font-medium text-[12px] text-accent uppercase tracking-[0.18em]">
                  {tier.name}
                </p>
                {isPopular ? (
                  <span className="whitespace-nowrap rounded-full bg-accent px-2.5 py-1 font-semibold text-[10px] text-accent-fg uppercase tracking-[0.1em]">
                    Most popular
                  </span>
                ) : null}
              </div>

              <div className="mt-7">
                <p className="font-semibold text-[38px] tabular-nums tracking-[-0.035em]">
                  {formatUsd(tier.priceCents)}
                </p>
                <p className="mt-1 text-[12px] text-subtle">One-time purchase</p>
              </div>

              <div className="my-6 border-line border-t"></div>

              <p className="font-medium text-[18px]">{macCountLabel(tier.maxMachines)}</p>
              <p className="mt-1 text-[13px] text-muted leading-[1.5]">
                {tierDescription(tier.maxMachines)}
              </p>
              <p className="mt-5 text-[12px] text-subtle">
                <span className="font-mono font-semibold text-[15px] text-fg tabular-nums">
                  {formatUsd(tier.priceCents / tier.maxMachines)}
                </span>{" "}
                per Mac
              </p>

              <div className="mt-auto pt-7">
                <button
                  type="button"
                  disabled={loadingPlan !== null}
                  onClick={() => buy(tier.id, tier.maxMachines)}
                  className="inline-flex w-full cursor-pointer items-center justify-center rounded-lg bg-accent px-4 py-3 font-semibold text-[14px] text-accent-fg transition-[transform_0.35s_cubic-bezier(0.16,1,0.3,1),opacity_0.35s_ease] hover:-translate-y-px focus-visible:outline-2 focus-visible:outline-accent focus-visible:outline-offset-2 disabled:cursor-wait disabled:opacity-60 motion-reduce:transition-none"
                >
                  {loadingPlan === tier.id
                    ? "Starting…"
                    : `Buy for ${macCountLabel(tier.maxMachines)}`}
                </button>
              </div>
            </article>
          );
        })}

        <article className="relative flex min-w-0 flex-col rounded-card border border-line bg-card p-6 transition-[transform_0.35s_cubic-bezier(0.16,1,0.3,1),box-shadow_0.35s_ease] hover:-translate-y-1 hover:shadow-card motion-reduce:transition-none">
          <div className="flex min-h-7 items-center justify-between gap-2">
            <p className="font-medium text-[12px] text-accent uppercase tracking-[0.18em]">
              {customTier.name}
            </p>
            <span className="whitespace-nowrap rounded-full border border-line-2 bg-surface px-2.5 py-1 font-medium text-[10px] text-muted uppercase tracking-[0.1em]">
              {customTier.minMachines}–{customTier.maxMachines} Macs
            </span>
          </div>

          <output className="mt-7 block" aria-live="polite">
            <span className="block font-semibold text-[38px] tabular-nums tracking-[-0.035em]">
              {formatUsd(customPrice)}
            </span>
            <span className="mt-1 block text-[12px] text-subtle">
              One-time purchase
            </span>
          </output>

          <div className="my-6 border-line border-t"></div>

          <label
            htmlFor="custom-machines"
            className="font-medium text-[12px] text-muted"
          >
            Number of Macs
          </label>
          <div className="mt-2 flex items-center rounded-lg border border-line-2 bg-surface-2 focus-within:outline-2 focus-within:outline-accent focus-within:outline-offset-2">
            <input
              id="custom-machines"
              type="number"
              min={customTier.minMachines}
              max={customTier.maxMachines}
              value={seatInput}
              aria-invalid={!seatInputValid}
              onChange={(event) => {
                const raw = event.target.value;
                setSeatInput(raw);

                const resolved = resolveMachines(customTier.id, Number(raw));

                if (raw !== "" && resolved !== null) {
                  setMachines(resolved);
                }
              }}
              onBlur={() => setSeatInput(String(machines))}
              className="min-w-0 flex-1 bg-surface-2 px-3 py-2.5 font-mono text-[16px] text-fg tabular-nums outline-none"
            />
            <span className="shrink-0 pr-3 text-[12px] text-subtle">Macs</span>
          </div>
          <div className="mt-2 flex justify-between font-mono text-[10px] text-subtle tabular-nums">
            <span className={seatInputValid ? undefined : "text-danger"}>
              {customTier.minMachines} minimum
            </span>
            <span className={seatInputValid ? undefined : "text-danger"}>
              {customTier.maxMachines} maximum
            </span>
          </div>

          <p className="mt-5 text-[12px] text-subtle">
            <span className="font-mono font-semibold text-[15px] text-fg tabular-nums">
              {formatUsd(customPrice / machines)}
            </span>{" "}
            per Mac
          </p>

          <p className="mt-4 text-[11px] text-subtle leading-[1.5]">
            {formatUsd(customTier.baseCents)} for {customTier.baseMachines} Macs,
            then {formatUsd(customTier.perAdditionalMachineCents)} per additional
            Mac.
          </p>

          <div className="mt-auto pt-7">
            <button
              type="button"
              disabled={loadingPlan !== null}
              onClick={() => buy(customTier.id, machines)}
              className="inline-flex w-full cursor-pointer items-center justify-center rounded-lg bg-accent px-4 py-3 font-semibold text-[14px] text-accent-fg transition-[transform_0.35s_cubic-bezier(0.16,1,0.3,1),opacity_0.35s_ease] hover:-translate-y-px focus-visible:outline-2 focus-visible:outline-accent focus-visible:outline-offset-2 disabled:cursor-wait disabled:opacity-60 motion-reduce:transition-none"
            >
              {loadingPlan === customTier.id
                ? "Starting…"
                : `Buy for ${macCountLabel(machines)}`}
            </button>
          </div>
        </article>
      </div>

      {status.state === "error" ? (
        <p
          className="mt-5 rounded-lg border border-line-2 bg-surface px-4 py-3 text-[14px] text-danger"
          role="alert"
        >
          {status.message}
        </p>
      ) : null}
    </>
  );
}
