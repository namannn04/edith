import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";
import "./globals.css";

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
    <html
      lang="en"
      className="scroll-smooth [color-scheme:dark] motion-reduce:scroll-auto"
    >
      <body className="bg-bg font-sans text-fg antialiased [font-feature-settings:'ss01','cv11'] [letter-spacing:-0.011em] [line-height:1.5] [text-rendering:optimizeLegibility] selection:bg-accent/40 motion-reduce:[&_*]:animate-none! motion-reduce:[&_*]:transition-none! [&_h1]:text-balance [&_h1]:font-semibold [&_h1]:text-[clamp(38px,6vw,76px)] [&_h1]:leading-[1.05] [&_h1]:tracking-[-0.03em] [&_h2]:text-balance [&_h2]:font-semibold [&_h2]:text-[clamp(30px,4vw,50px)] [&_h2]:leading-[1.1] [&_h2]:tracking-[-0.02em] [&_h3]:text-balance [&_h3]:font-semibold [&_h3]:text-[clamp(28px,3vw,38px)] [&_h3]:leading-[1.1] [&_h3]:tracking-[-0.02em] [&_h4]:font-semibold [&_h4]:text-[17px] [&_h4]:tracking-[-0.01em]">
        {children}
      </body>
    </html>
  );
}
