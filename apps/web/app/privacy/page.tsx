import type { Metadata } from "next";
import { SiteFooter, SiteHeader } from "../site-chrome";

export const metadata: Metadata = {
  title: "Privacy Policy · Edith",
  description:
    "Edith's privacy policy. Local-first by design: no accounts, no telemetry, your data stays on your Mac.",
  alternates: {
    canonical: "/privacy",
  },
};

export default function PrivacyPage() {
  return (
    <>
      <SiteHeader />
      <main className="legal">
        <h1>Privacy Policy</h1>
        <p className="updated">Last updated: July 11, 2026</p>

        <p>
          Edith is built local-first. The short version: the app has no
          accounts, collects no telemetry, and your data stays on your Mac
          unless you explicitly turn on iCloud backup, which stores it in your
          own iCloud Drive.
        </p>

        <h2>What the app stores, and where</h2>
        <ul>
          <li>
            Usage analytics (tokens, costs, rate-limit history) are computed on
            your Mac from local files that your AI tools already write, and are
            stored in the app&apos;s local data folder.
          </li>
          <li>
            Clipboard history, shelf files, music, and settings are stored
            locally on your Mac.
          </li>
          <li>
            Nothing above is transmitted to us. We run no servers that receive,
            process, or store your usage data.
          </li>
        </ul>

        <h2>Rate-limit checks</h2>
        <p>
          To show live session and weekly limits, the app queries your AI
          provider&apos;s API directly from your Mac using credentials already
          on your machine. Those requests go from you to your provider. Edith
          never sees them.
        </p>

        <h2>Optional iCloud backup</h2>
        <p>
          If you enable iCloud backup, the app copies selected data (settings,
          usage history, music, clipboard history, at your choice) into your own
          iCloud Drive so it can merge across your Macs. That data is governed
          by your Apple account and Apple&apos;s privacy terms. Turn the toggle
          off and the app stops syncing.
        </p>

        <h2>No accounts, no telemetry</h2>
        <ul>
          <li>No sign-up, login, or account of any kind.</li>
          <li>
            No analytics SDKs, crash reporters, or tracking pixels inside the
            app.
          </li>
          <li>
            No advertising, and nothing is ever sold or shared, because nothing
            is collected.
          </li>
        </ul>

        <h2>This website</h2>
        <p>
          edith.app is a static site. Our hosting provider keeps standard,
          short-lived server logs (such as IP address and requested page) to
          operate the service. The site sets no tracking cookies.
        </p>

        <h2>Payments</h2>
        <p>
          Purchases are handled by our payment processor. We receive the
          information needed to deliver your license (such as your email address
          and order reference), never your card details.
        </p>

        <h2>Changes</h2>
        <p>
          If this policy changes, the new version will be posted here with an
          updated date. Material changes will be noted in the app&apos;s release
          notes.
        </p>

        <h2>Contact</h2>
        <p>
          Questions about privacy? Email{" "}
          <a href="mailto:support@edith.app">support@edith.app</a>.
        </p>
      </main>
      <SiteFooter />
    </>
  );
}
