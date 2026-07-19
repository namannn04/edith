import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "License | Edith for Mac",
  description: "How Edith licenses work across your Macs.",
};

export default function LicensePage() {
  return (
    <main className="prose-shell">
      <a className="back-link" href="/">
        Edith
      </a>
      <section className="prose-card">
        <p className="eyebrow">License</p>
        <h1>One key, your Macs.</h1>
        <p>
          Edith requires a license key. Each key is limited to a set number of
          Macs, based on the license you received.
        </p>
        <p>
          Reinstalling Edith on the same Mac does not use another seat. Edith
          recognizes the Mac and keeps it on the existing activation.
        </p>
      </section>
    </main>
  );
}
