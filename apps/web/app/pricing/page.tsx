import type { Metadata } from "next";
import { SiteFooter, SiteHeader } from "../site-chrome";
import { PricingPlans } from "./pricing-plans";

export const metadata: Metadata = {
  title: "Pricing · Edith",
  description:
    "Edith is a one-time purchase. Pay once, use it forever, on as many Macs as your plan covers.",
  alternates: {
    canonical: "/pricing",
  },
};

export default function PricingPage() {
  return (
    <>
      <SiteHeader />
      <main className="mx-auto max-w-260 px-6 pt-35 pb-24">
        <p className="font-medium text-[12px] text-accent uppercase tracking-[0.18em]">
          Pricing
        </p>
        <h1 className="mb-2 text-[clamp(2rem,5vw,2.8rem)] tracking-[-0.02em]">
          Pay once. Keep it forever.
        </h1>
        <p className="mb-10 max-w-150 text-muted leading-[1.7]">
          Every plan is a one-time purchase with no renewal. Pick the number of
          Macs you need now; you can always buy another licence later.
        </p>
        <PricingPlans />
        <p className="mt-10 max-w-150 text-[13px] text-subtle leading-[1.7]">
          Prices are in USD. Local payment methods, including UPI for buyers in
          India, appear automatically at checkout where available. Your licence
          key is emailed as soon as the payment settles.
        </p>
      </main>
      <SiteFooter />
    </>
  );
}
