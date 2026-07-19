import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";
import "./landing.css";

export const metadata: Metadata = {
  metadataBase: new URL("https://edith.pulkit.page"),
  title: "Edith",
  description:
    "Edith is a native macOS menu bar app for agent usage, music, clipboard, and system tools.",
  icons: {
    icon: [{ url: "/favicon-180.png", type: "image/png" }],
    apple: "/favicon-180.png",
  },
};

export const viewport: Viewport = {
  themeColor: "#0e0f11",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
