import type { Metadata } from "next";
import { SiteFooter, SiteHeader } from "../site-chrome";

export const metadata: Metadata = {
  title: "Thanks · Edith",
  description: "Your Edith purchase is complete.",
  robots: { index: false },
};

export default function ThanksPage() {
  return (
    <>
      <SiteHeader />
      <main className="mx-auto max-w-190 px-6 pt-35 pb-24">
        <p className="font-medium text-[12px] text-accent uppercase tracking-[0.18em]">
          Order complete
        </p>
        <h1 className="mb-2 text-[clamp(2rem,5vw,2.8rem)] tracking-[-0.02em]">
          Check your inbox.
        </h1>
        <p className="mb-3 text-muted leading-[1.7]">
          Your licence key is on its way to the email address you used at
          checkout. It usually arrives within a minute.
        </p>
        <p className="mb-3 text-muted leading-[1.7]">
          To activate, open Edith, choose <strong>Enter License Key</strong>,
          and paste the key from the email.
        </p>
        <p className="text-muted leading-[1.7]">
          Nothing after a few minutes? Check spam, then email{" "}
          <a className="text-accent" href="mailto:kpulkit15234@gmail.com">
            kpulkit15234@gmail.com
          </a>{" "}
          and we will resend it.
        </p>
      </main>
      <SiteFooter />
    </>
  );
}
