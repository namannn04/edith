import type { Metadata } from "next";
import { SiteFooter, SiteHeader } from "../site-chrome";

export const metadata: Metadata = {
  title: "License · Edith",
  description: "How Edith licenses work across your Macs.",
  alternates: {
    canonical: "/license",
  },
};

export default function LicensePage() {
  return (
    <>
      <SiteHeader />
      <main className="mx-auto max-w-[760px] px-6 pt-[140px] pb-24 [&>h1]:mb-2! [&>h1]:text-[clamp(2rem,5vw,2.8rem)]! [&>h1]:tracking-[-0.02em]! [&>h2]:mt-10! [&>h2]:mb-3! [&>h2]:text-[20px]! [&>p]:mb-3 [&>p]:text-muted [&>p]:leading-[1.7] [&>ul]:mb-4 [&>ul]:list-disc [&>ul]:pl-[22px] [&_a]:text-accent [&_li]:mb-3 [&_li]:text-muted [&_li]:leading-[1.7]">
        <p className="font-medium text-[12px] text-accent uppercase tracking-[0.18em]">License</p>
        <h1>One key, your Macs.</h1>
        <p>
          Edith requires a license key. Each key is limited to a set number of
          Macs, based on the license you received.
        </p>
        <p>
          Reinstalling Edith on the same Mac does not use another seat. Edith
          recognizes the Mac and keeps it on the existing activation.
        </p>
      </main>
      <SiteFooter />
    </>
  );
}
