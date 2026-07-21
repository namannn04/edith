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
      <main className="relative overflow-hidden">
        <div
          className="pointer-events-none absolute top-12 left-1/2 h-96 w-96 -translate-x-1/2 rounded-full bg-accent/10 blur-3xl"
          aria-hidden="true"
        ></div>

        <section className="relative mx-auto w-full max-w-280 px-6 pt-22 pb-14 text-center md:pt-30 md:pb-18">
          <div className="animate-hero-rise motion-reduce:animate-none">
            <p className="font-medium text-[12px] text-accent uppercase tracking-[0.18em]">
              Simple pricing
            </p>
            <h1 className="mx-auto mt-5 max-w-220">
              Pay once. <span className="font-serif text-accent">Keep it forever.</span>
            </h1>
            <p className="mx-auto mt-6 max-w-160 text-balance text-[17px] text-muted leading-[1.65] md:text-[19px]">
              Choose how many Macs you want to cover. Every Edith licence is a
              one-time purchase with no subscription, renewal, or expiry.
            </p>
          </div>

          <div className="mx-auto mt-8 flex w-fit max-w-full animate-hero-rise flex-wrap items-center justify-center gap-x-5 gap-y-2 rounded-full border border-line-2 bg-surface px-5 py-3 text-[12px] text-muted [animation-delay:140ms] motion-reduce:animate-none">
            <span className="inline-flex items-center gap-2">
              <span className="size-1.5 rounded-full bg-sage"></span>
              No subscription
            </span>
            <span className="inline-flex items-center gap-2">
              <span className="size-1.5 rounded-full bg-sage"></span>
              No renewal
            </span>
            <span className="inline-flex items-center gap-2">
              <span className="size-1.5 rounded-full bg-sage"></span>
              No expiry
            </span>
          </div>
        </section>

        <section className="relative mx-auto w-full max-w-280 px-6 pb-20 md:pb-28">
          <PricingPlans />

          <div className="mt-12 overflow-hidden rounded-card border border-line bg-surface md:mt-16">
            <div className="grid sm:grid-cols-2 lg:grid-cols-4">
              <div className="border-line p-5 sm:border-r sm:border-b lg:border-b-0">
                <p className="font-medium text-[11px] text-accent uppercase tracking-[0.16em]">
                  One payment
                </p>
                <p className="mt-2 text-[14px] text-muted leading-[1.55]">
                  No subscription, renewal, or expiry.
                </p>
              </div>
              <div className="border-line p-5 max-sm:border-t sm:border-b lg:border-r lg:border-b-0">
                <p className="font-medium text-[11px] text-accent uppercase tracking-[0.16em]">
                  One seat
                </p>
                <p className="mt-2 text-[14px] text-muted leading-[1.55]">
                  Each seat covers one Mac.
                </p>
              </div>
              <div className="border-line p-5 max-sm:border-t sm:border-r">
                <p className="font-medium text-[11px] text-accent uppercase tracking-[0.16em]">
                  Local checkout
                </p>
                <p className="mt-2 text-[14px] text-muted leading-[1.55]">
                  Available local methods, including UPI in India, appear at
                  checkout.
                </p>
              </div>
              <div className="border-line p-5 max-sm:border-t">
                <p className="font-medium text-[11px] text-accent uppercase tracking-[0.16em]">
                  Instant delivery
                </p>
                <p className="mt-2 text-[14px] text-muted leading-[1.55]">
                  Your licence key is emailed when payment settles.
                </p>
              </div>
            </div>
          </div>

          <p className="mt-5 text-center text-[12px] text-subtle">
            All prices are in USD. Need more than 50 Macs?{" "}
            <a
              className="text-accent underline-offset-4 hover:underline focus-visible:rounded-sm focus-visible:outline-2 focus-visible:outline-accent focus-visible:outline-offset-4"
              href="mailto:kpulkit15234@gmail.com"
            >
              Get in touch
            </a>
            .
          </p>
        </section>
      </main>
      <SiteFooter />
    </>
  );
}
