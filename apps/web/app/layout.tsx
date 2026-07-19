import type { Metadata } from "next";
import type { ReactNode } from "react";
import "./globals.css";

export const metadata: Metadata = {
  metadataBase: new URL("https://edith.pulkit.page"),
  title: "Edith for Mac",
  description:
    "Your Mac's quiet copilot for agent usage, music, clipboard, and a smarter notch.",
  openGraph: {
    title: "Edith for Mac",
    description:
      "Your Mac's quiet copilot for agent usage, music, clipboard, and a smarter notch.",
    url: "https://edith.pulkit.page",
    siteName: "Edith",
    type: "website",
  },
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
