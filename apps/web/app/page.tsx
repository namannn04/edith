import type { Metadata } from "next";
import LandingBehavior from "./landing-behavior";

const title = "Edith: Claude & Codex usage tracker and Mac menu bar toolkit";
const description =
  "Edith is a native macOS menu bar app: Claude and Codex rate-limit tracking, usage analytics and alerts, a local music player, clipboard history, and a full set of Mac utilities in one app.";
const socialDescription =
  "Native macOS menu bar app for Claude and Codex rate-limit tracking, usage analytics, local music, and system tools. One app instead of twelve.";

export const metadata: Metadata = {
  title,
  description,
  alternates: {
    canonical: "/",
  },
  openGraph: {
    type: "website",
    siteName: "Edith",
    title,
    description: socialDescription,
    url: "/",
    images: ["/app-icon-512.png"],
    videos: [
      {
        url: "/announcement.mp4",
        type: "video/mp4",
        width: 1920,
        height: 1080,
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title,
    description: socialDescription,
    images: ["/app-icon-512.png"],
  },
};

const structuredData = {
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "SoftwareApplication",
      name: "Edith",
      url: "https://edith.pulkit.page/",
      image: "https://edith.pulkit.page/app-icon-512.png",
      applicationCategory: "UtilitiesApplication",
      operatingSystem: "macOS 13+",
      downloadUrl: "https://edith.pulkit.page/api/v1/download/installer",
      description:
        "A native macOS menu bar app for Claude and Codex rate-limit tracking, usage analytics, a local music player, and system tools.",
      featureList: [
        "Claude and Codex rate-limit tracking with live countdowns",
        "Menu bar session and weekly usage readout",
        "Usage alerts and notifications",
        "Usage analytics dashboard with per-model charts",
        "Daily spend heatmap",
        "Local music player with Spotify and Apple Music control",
        "Clipboard history with instant paste",
        "Color picker",
        "Focus dim, prevent sleep, keyboard-clean lock",
        "Notch file shelf, alerts, and camera check",
        "Mic mute and per-app volume mixer",
        "Disk junk cleaner and running-apps monitor",
      ],
    },
    {
      "@type": "VideoObject",
      name: "Edith announcement film",
      description:
        "A two-minute tour of every feature in Edith, the macOS menu bar app.",
      contentUrl: "https://edith.pulkit.page/announcement.mp4",
      thumbnailUrl: "https://edith.pulkit.page/announcement-poster.jpg",
      uploadDate: "2026-07-16",
    },
  ],
};

export default function HomePage() {
  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData) }}
      />
      <header className="sticky top-0 z-40 border-b border-line bg-[color-mix(in_oklab,var(--color-bg)_72%,transparent)] backdrop-blur-[16px]">
        <div className="mx-auto w-full max-w-[1120px] px-6 flex h-14 items-center justify-between">
          <a href="#top" className="flex items-center gap-2 text-[15px] font-semibold">
            <img
              src="/app-icon-512.png"
              alt="Edith app icon"
              width="28"
              height="28"
              className="size-7 rounded-[22%] shadow-brand-icon"
            />
            <span>Edith</span>
          </a>
          <nav className="hidden gap-8 md:flex [&>a]:text-[13px] [&>a]:text-muted [&>a:hover]:text-fg">
            <a href="#features">Features</a>
            <a href="#performance">Performance</a>
          </nav>
          <a href="/api/v1/download/installer" className="inline-flex cursor-pointer items-center justify-center gap-2 rounded-full border border-transparent px-6 py-3 text-[14px] font-medium transition-[transform_0.35s_cubic-bezier(0.16,1,0.3,1),border-color_0.35s_ease,box-shadow_0.35s_ease] hover:-translate-y-px motion-reduce:transition-none bg-fg text-bg px-4! py-1.5! text-[13px]!">
            Download
          </a>
        </div>
      </header>

      <main id="top">
        <section className="relative overflow-hidden">
          <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(60%_50%_at_50%_8%,color-mix(in_oklab,var(--color-accent)_20%,transparent),transparent_70%),radial-gradient(50%_40%_at_82%_26%,color-mix(in_oklab,var(--color-accent)_9%,transparent),transparent_70%)]" aria-hidden="true"></div>
          <div className="mx-auto w-full max-w-[1120px] px-6 relative pt-24 pb-18 md:pt-36 md:pb-24 [&>h1]:mt-6 [&>h1]:animate-hero-rise [&>h1]:[animation-delay:160ms] [&>p:first-of-type]:mb-6 [&>p:first-of-type]:animate-hero-rise [&>p:first-of-type]:[animation-delay:80ms] [&>p:nth-of-type(3)]:mt-4 [&>p:nth-of-type(3)]:animate-hero-rise [&>p:nth-of-type(3)]:[animation-delay:380ms] motion-reduce:[&>h1]:animate-none motion-reduce:[&>p]:animate-none">
            <img
              src="/app-icon.png"
              alt="Edith app icon"
              width="88"
              height="88"
              className="mb-8 size-18 animate-[var(--animate-hero-rise),var(--animate-float-slow)] rounded-[22%] shadow-hero-icon md:size-22 motion-reduce:animate-none"
            />
            <p className="text-[12px] font-medium uppercase tracking-[0.18em] text-accent">For macOS</p>
            <h1>
              One menu bar app
              <br />
              instead of twelve.
            </h1>
            <p className="mt-6 max-w-[620px] animate-hero-rise text-balance text-[clamp(18px,2.2vw,22px)] text-muted [animation-delay:240ms] motion-reduce:animate-none">
              Edith is a native Mac app for Claude and Codex rate-limit
              tracking, usage analytics, local music, and system tools.
            </p>
            <div className="mt-10 flex animate-hero-rise flex-wrap gap-3 [animation-delay:320ms] motion-reduce:animate-none">
              <a href="/api/v1/download/installer" className="inline-flex cursor-pointer items-center justify-center gap-2 rounded-full border border-transparent px-6 py-3 text-[14px] font-medium transition-[transform_0.35s_cubic-bezier(0.16,1,0.3,1),border-color_0.35s_ease,box-shadow_0.35s_ease] hover:-translate-y-px motion-reduce:transition-none bg-fg text-bg">
                <svg className="size-3.5 fill-current" viewBox="0 0 24 24" aria-hidden="true">
                  <path d="M16.365 1.43c0 1.14-.42 2.23-1.24 3.05-.83.83-2.19 1.45-3.31 1.36-.14-1.1.43-2.24 1.2-2.98.85-.83 2.32-1.42 3.35-1.43zM20.5 17.29c-.57 1.31-.85 1.9-1.59 3.06-1.03 1.61-2.48 3.62-4.28 3.63-1.6.01-2.01-1.05-4.18-1.04-2.17.01-2.62 1.06-4.22 1.05-1.8-.02-3.18-1.83-4.21-3.44C-.36 16.72-1.02 10.6 2.87 8.4c1.4-.8 2.86-1.24 4.24-1.26 1.61-.03 3.13 1.09 4.19 1.09 1.05 0 2.87-1.35 4.85-1.15.83.03 3.16.33 4.66 2.52-.12.08-2.78 1.62-2.75 4.82.03 3.83 3.36 5.1 3.4 5.11-.03.09-.53 1.82-1.96 3.76z" />
                </svg>
                Download for macOS
              </a>
            </div>
            <p className="text-[12px] text-subtle">Requires macOS. Apple Silicon and Intel.</p>

            <div className="mx-auto mt-16 max-w-[900px] animate-hero-rise [animation-delay:480ms] motion-reduce:animate-none [&>p]:mt-4">
              <div className="relative overflow-hidden rounded-card border border-line-2 bg-surface shadow-demo [&:has(#presenter:checked)_[data-sensitive]]:blur-[7px] [&:has(#presenter:checked)_[data-sensitive]]:select-none [&:has(#presenter:checked)_[data-presenter-toggle]]:border-accent/[40%] [&:has(#presenter:checked)_[data-presenter-toggle]]:bg-accent/[15%] [&:has(#presenter:checked)_[data-presenter-icon]]:text-accent">
                <input type="checkbox" id="presenter" className="sr-only" />
                <div className="flex items-center gap-3 border-b border-line px-5 py-3">
                  <span className="flex gap-2 [&>i]:block [&>i]:size-3 [&>i]:rounded-full [&>i:nth-child(1)]:bg-window-close [&>i:nth-child(2)]:bg-window-minimize [&>i:nth-child(3)]:bg-window-expand">
                    <i></i>
                    <i></i>
                    <i></i>
                  </span>
                  <span className="text-[13px] font-medium text-muted">Edith</span>
                  <span className="flex-1"></span>
                  <span className="text-[12px] text-subtle font-mono tabular-nums">11:59 PM</span>
                </div>
                <div className="flex">
                  <aside className="hidden w-40 shrink-0 flex-col gap-1 border-r border-line p-3 md:flex [&>span]:rounded-lg [&>span]:px-3 [&>span]:py-2 [&>span]:text-[13px] [&>span]:text-muted [&>span:first-child]:bg-white/[5%] [&>span:first-child]:font-medium [&>span:first-child]:text-fg">
                    <span className="rounded-lg bg-white/[5%] px-3 py-2 text-[13px] font-medium text-fg">Home</span>
                    <span>Agent Usage</span>
                    <span>Music</span>
                    <span>Calendar</span>
                    <span className="mt-auto! text-[12px]! text-subtle!">Settings</span>
                  </aside>
                  <div className="min-w-0 flex-1 p-6">
                    <div className="mb-5">
                      <div className="font-serif text-[24px] font-semibold tracking-[-0.01em]">Good evening.</div>
                      <div className="mt-1 text-[13px] text-subtle [&>span]:text-muted">
                        This week <span className="font-mono tabular-nums transition-[filter_0.3s_ease] motion-reduce:transition-none" data-sensitive="">$2.1k</span>
                      </div>
                    </div>

                    <div className="grid grid-cols-3 gap-3">
                      <div className="rounded-xl border border-line bg-[color-mix(in_oklab,var(--color-bg)_40%,transparent)] p-3 text-center">
                        <div className="font-mono tabular-nums text-[18px] font-semibold">11:59</div>
                        <div className="font-mono tabular-nums text-[10px] text-subtle">PM</div>
                        <div className="mt-1 text-[11px] text-muted">Local</div>
                      </div>
                      <div className="rounded-xl border border-line bg-[color-mix(in_oklab,var(--color-bg)_40%,transparent)] p-3 text-center">
                        <div className="font-mono tabular-nums text-[18px] font-semibold">2:29</div>
                        <div className="font-mono tabular-nums text-[10px] text-subtle">PM</div>
                        <div className="mt-1 text-[11px] text-muted">New York</div>
                      </div>
                      <div className="rounded-xl border border-line bg-[color-mix(in_oklab,var(--color-bg)_40%,transparent)] p-3 text-center">
                        <div className="font-mono tabular-nums text-[18px] font-semibold">7:29</div>
                        <div className="font-mono tabular-nums text-[10px] text-subtle">PM</div>
                        <div className="mt-1 text-[11px] text-muted">London</div>
                      </div>
                    </div>

                    <div className="mt-3 grid grid-cols-3 gap-3 [&>span:nth-child(2)]:border-accent/[40%] [&>span:nth-child(2)]:bg-accent/[15%] [&>span:nth-child(2)>span:first-child]:text-accent">
                      <span className="flex flex-col items-center gap-1.5 rounded-xl border border-line bg-[color-mix(in_oklab,var(--color-bg)_40%,transparent)] p-3 text-center text-[12px] font-semibold text-fg [&>small]:text-[11px] [&>small]:font-normal [&>small]:leading-[1.3] [&>small]:text-subtle">
                        <span className="text-base text-subtle">⌨</span>
                        <span>Clean keys</span>
                      </span>
                      <span className="flex flex-col items-center gap-1.5 rounded-xl border border-line bg-[color-mix(in_oklab,var(--color-bg)_40%,transparent)] p-3 text-center text-[12px] font-semibold text-fg [&>small]:text-[11px] [&>small]:font-normal [&>small]:leading-[1.3] [&>small]:text-subtle border-accent/[40%]! bg-accent/[15%]! [&>span:first-child]:text-accent!">
                        <span className="text-base text-subtle">☾</span>
                        <span>Keep awake</span>
                      </span>
                      <label htmlFor="presenter" className="flex flex-col items-center gap-1.5 rounded-xl border border-line bg-[color-mix(in_oklab,var(--color-bg)_40%,transparent)] p-3 text-center text-[12px] font-semibold text-fg [&>small]:text-[11px] [&>small]:font-normal [&>small]:leading-[1.3] [&>small]:text-subtle cursor-pointer" data-presenter-toggle="">
                        <span className="text-base text-subtle" data-presenter-icon="">◍</span>
                        <span>Presenter</span>
                      </label>
                    </div>

                    <div className="mt-3 grid gap-3 md:grid-cols-[auto_1fr]">
                      <div className="rounded-xl border border-line bg-[color-mix(in_oklab,var(--color-bg)_40%,transparent)] p-4">
                        <div className="mb-5 text-[11px] font-medium uppercase tracking-[0.16em] text-subtle">Rate limits</div>
                        <div className="flex gap-5">
                          <div className="relative flex flex-1 flex-col items-center gap-1.5 [&>svg]:size-20">
                            <svg viewBox="0 0 80 80">
                              <circle
                                className="fill-none stroke-warm-10 [stroke-width:7]"
                                cx="40"
                                cy="40"
                                r="32"
                              />
                              <circle
                                className="fill-none [stroke-dasharray:201.06] [stroke-linecap:round] [stroke-width:7] stroke-sage"
                                cx="40"
                                cy="40"
                                r="32"
                                transform="rotate(-90 40 40)"
                                style={{ strokeDashoffset: 106.6 }}
                              />
                            </svg>
                            <span className="absolute inset-x-0 top-7 text-center text-base font-semibold font-mono tabular-nums">47%</span>
                            <span className="text-[9px] font-medium uppercase tracking-[0.16em] text-subtle">Session</span>
                            <span className="text-[10px] text-subtle font-mono tabular-nums">2h 47m</span>
                          </div>
                          <div className="relative flex flex-1 flex-col items-center gap-1.5 [&>svg]:size-20">
                            <svg viewBox="0 0 80 80">
                              <circle
                                className="fill-none stroke-warm-10 [stroke-width:7]"
                                cx="40"
                                cy="40"
                                r="32"
                              />
                              <circle
                                className="fill-none [stroke-dasharray:201.06] [stroke-linecap:round] [stroke-width:7] stroke-accent"
                                cx="40"
                                cy="40"
                                r="32"
                                transform="rotate(-90 40 40)"
                                style={{ strokeDashoffset: 64.3 }}
                              />
                            </svg>
                            <span className="absolute inset-x-0 top-7 text-center text-base font-semibold font-mono tabular-nums">68%</span>
                            <span className="text-[9px] font-medium uppercase tracking-[0.16em] text-subtle">Week</span>
                            <span className="text-[10px] text-subtle font-mono tabular-nums">3d 6h</span>
                          </div>
                        </div>
                      </div>
                      <div className="rounded-xl border border-line bg-[color-mix(in_oklab,var(--color-bg)_40%,transparent)] p-4">
                        <div className="mb-5 text-[11px] font-medium uppercase tracking-[0.16em] text-subtle flex items-baseline justify-between">
                          <span>Activity</span>
                          <span className="font-mono tabular-nums text-subtle">May to Jul</span>
                        </div>
                        <div
                          className="grid grid-flow-col grid-rows-7 gap-1"
                          data-rows="7"
                          data-cols="16"
                          aria-hidden="true"
                        ></div>
                      </div>
                    </div>

                    <div className="mt-3 flex items-center gap-4 rounded-xl border border-line bg-[color-mix(in_oklab,var(--color-bg)_40%,transparent)] p-3">
                      <span className="size-12 shrink-0 rounded-[10px] bg-[linear-gradient(145deg,var(--color-art-coral),var(--color-art-rust))]" data-art=""></span>
                      <div className="min-w-0 flex-1">
                        <div className="truncate text-[14px] font-semibold transition-[filter_0.3s_ease] motion-reduce:transition-none" data-title="" data-sensitive="">
                          Weightless
                        </div>
                        <div className="truncate text-[12px] text-muted transition-[filter_0.3s_ease] motion-reduce:transition-none" data-artist="" data-sensitive="">
                          Marconi Union
                        </div>
                        <div className="mt-2 h-1 overflow-hidden rounded-full bg-white/[10%] [&>span]:block [&>span]:h-full [&>span]:w-[18%] [&>span]:rounded-full [&>span]:bg-accent [&>span]:transition-[width] [&>span]:duration-100 [&>span]:ease-linear motion-reduce:[&>span]:transition-none">
                          <span data-progress=""></span>
                        </div>
                      </div>
                      <div className="flex items-center gap-3 text-muted">
                        <span>⏮</span>
                        <span className="flex size-8 items-center justify-center rounded-full bg-fg text-[12px] text-bg">❚❚</span>
                        <span>⏭</span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
              <p className="animate-hero-rise text-center text-[12px] text-subtle [animation-delay:380ms] motion-reduce:animate-none">
                The Home panel, running live. Click Presenter to blur the
                numbers.
              </p>
            </div>
          </div>
        </section>

        <section className="mx-auto w-full max-w-[1120px] px-6 pt-24 pb-24">
          <div className="grid gap-10 md:grid-cols-[5fr_7fr] [&>div>p]:mt-6 [&>div>p]:max-w-[560px]" data-reveal-group="">
            <p className="text-[12px] font-medium uppercase tracking-[0.18em] text-accent">The pitch</p>
            <div>
              <h2>
                Twelve menu bar utilities' worth of tools. One native app.
              </h2>
              <p className="text-muted text-[17px] leading-[1.6]">
                Every feature in Edith is normally its own app. We built the
                whole shelf into a single native binary that idles at twenty-two
                megabytes.
              </p>
            </div>
          </div>
        </section>

        <section id="features" className="mx-auto w-full max-w-[1120px] px-6 pb-24">
          <div className="overflow-hidden rounded-card border border-line bg-surface" data-reveal-group="">
            <div className="grid grid-cols-[1fr_1.2fr] items-start gap-6 border-b border-line px-6 py-5 last:border-b-0 bg-surface-2 text-[12px] font-medium uppercase tracking-[0.14em] text-muted">
              <span>The feature</span>
              <span>What you get in Edith</span>
            </div>
            <div className="grid grid-cols-[1fr_1.2fr] items-start gap-6 border-b border-line px-6 py-5 last:border-b-0">
              <span className="text-[15px] font-medium">AI usage &amp; rate limits</span>
              <span className="text-[15px] text-muted">
                Claude and Codex rings with live countdowns
              </span>
            </div>
            <div className="grid grid-cols-[1fr_1.2fr] items-start gap-6 border-b border-line px-6 py-5 last:border-b-0">
              <span className="text-[15px] font-medium">Menu bar stats</span>
              <span className="text-[15px] text-muted">
                Session and weekly %, tinted by a risk model
              </span>
            </div>
            <div className="grid grid-cols-[1fr_1.2fr] items-start gap-6 border-b border-line px-6 py-5 last:border-b-0">
              <span className="text-[15px] font-medium">Usage alerts</span>
              <span className="text-[15px] text-muted">
                Threshold, ahead-of-pace, burn, back-to-green, pre-reset
              </span>
            </div>
            <div className="grid grid-cols-[1fr_1.2fr] items-start gap-6 border-b border-line px-6 py-5 last:border-b-0">
              <span className="text-[15px] font-medium">Analytics dashboard</span>
              <span className="text-[15px] text-muted">
                KPIs, per-day and per-model charts, sortable table
              </span>
            </div>
            <div className="grid grid-cols-[1fr_1.2fr] items-start gap-6 border-b border-line px-6 py-5 last:border-b-0">
              <span className="text-[15px] font-medium">Spend heatmap</span>
              <span className="text-[15px] text-muted">
                GitHub-style daily calendar across your full history
              </span>
            </div>
            <div className="grid grid-cols-[1fr_1.2fr] items-start gap-6 border-b border-line px-6 py-5 last:border-b-0">
              <span className="text-[15px] font-medium">Music player</span>
              <span className="text-[15px] text-muted">
                Thumbnails, drag-to-seek, fades, auto-advance, media keys
              </span>
            </div>
            <div className="grid grid-cols-[1fr_1.2fr] items-start gap-6 border-b border-line px-6 py-5 last:border-b-0">
              <span className="text-[15px] font-medium">Clipboard history</span>
              <span className="text-[15px] text-muted">
                Everything you copied, instant paste on a hotkey
              </span>
            </div>
            <div className="grid grid-cols-[1fr_1.2fr] items-start gap-6 border-b border-line px-6 py-5 last:border-b-0">
              <span className="text-[15px] font-medium">Color picker</span>
              <span className="text-[15px] text-muted">
                System loupe on a hotkey, sampled hex to your clipboard
              </span>
            </div>
            <div className="grid grid-cols-[1fr_1.2fr] items-start gap-6 border-b border-line px-6 py-5 last:border-b-0">
              <span className="text-[15px] font-medium">Focus &amp; system utilities</span>
              <span className="text-[15px] text-muted">
                Focus dim, prevent-sleep, keyboard-clean lock, notch shelf
              </span>
            </div>
            <div className="grid grid-cols-[1fr_1.2fr] items-start gap-6 border-b border-line px-6 py-5 last:border-b-0">
              <span className="text-[15px] font-medium">Mic mute</span>
              <span className="text-[15px] text-muted">
                Every microphone muted system-wide on one hotkey
              </span>
            </div>
            <div className="grid grid-cols-[1fr_1.2fr] items-start gap-6 border-b border-line px-6 py-5 last:border-b-0">
              <span className="text-[15px] font-medium">Per-app volume</span>
              <span className="text-[15px] text-muted">
                Set each app's volume independently from the panel
              </span>
            </div>
            <div className="grid grid-cols-[1fr_1.2fr] items-start gap-6 border-b border-line px-6 py-5 last:border-b-0">
              <span className="text-[15px] font-medium">Disk cleaner</span>
              <span className="text-[15px] text-muted">
                Junk scanner for build caches, package managers, and logs
              </span>
            </div>
          </div>
        </section>

        <section id="film" className="mx-auto w-full max-w-[1120px] px-6 border-t border-line py-24 [&>video]:block [&>video]:h-auto [&>video]:w-full [&>video]:rounded-card [&>video]:border [&>video]:border-line-2 [&>video]:bg-black" data-reveal-group="">
          <div className="mx-auto mb-10 max-w-[620px] text-center [&>h2]:mt-3">
            <p className="text-[12px] font-medium uppercase tracking-[0.18em] text-accent">The film</p>
            <h2>See the whole app in two minutes.</h2>
          </div>
          <video
            controls
            playsInline
            preload="metadata"
            src="/announcement.mp4"
            poster="/announcement-poster.jpg"
            width="1920"
            height="1080"
            aria-label="Edith announcement film: a two-minute tour of every feature"
          ></video>
        </section>

        <section className="border-t border-line">
          <div className="mx-auto w-full max-w-[1120px] px-6 grid items-center gap-12 py-24 md:grid-cols-2 md:gap-16 md:py-32" data-reveal-group="">
            <div className="[&>h3]:mt-4 [&>p:last-child]:mt-5 [&>p:last-child]:max-w-[440px]">
              <p className="text-[12px] font-medium uppercase tracking-[0.18em] text-accent">Rate limits</p>
              <h3>Live rings for session and week.</h3>
              <p className="text-muted text-[17px] leading-[1.6]">
                Second-by-second countdowns to your next 5-hour session reset
                and to the weekly rollover, for Claude and Codex alike. A
                24-hour spark shows the shape of your day at a glance.
              </p>
            </div>
            <div>
              <div className="rounded-card border border-line-2 bg-surface p-6 shadow-card">
                <div className="mb-5 text-[11px] font-medium uppercase tracking-[0.16em] text-subtle flex items-baseline justify-between">
                  <span>Rate limits</span>
                  <span className="font-mono tabular-nums text-subtle">session, weekly</span>
                </div>
                <div className="flex gap-5 [&_svg]:size-24 [&_circle:nth-child(2)]:[stroke-dasharray:238.76] [&_circle:nth-child(2)]:[stroke-width:8] [&_svg+span]:top-[34px] [&_svg+span]:text-[20px]">
                  <div className="relative flex flex-1 flex-col items-center gap-1.5 [&>svg]:size-20">
                    <svg viewBox="0 0 96 96">
                      <circle className="fill-none stroke-warm-10 [stroke-width:7]" cx="48" cy="48" r="38" />
                      <circle
                        className="fill-none [stroke-dasharray:201.06] [stroke-linecap:round] [stroke-width:7] stroke-sage"
                        cx="48"
                        cy="48"
                        r="38"
                        transform="rotate(-90 48 48)"
                        style={{ strokeDashoffset: 126.5 }}
                      />
                    </svg>
                    <span className="absolute inset-x-0 top-7 text-center text-base font-semibold font-mono tabular-nums">47%</span>
                    <span className="text-[9px] font-medium uppercase tracking-[0.16em] text-subtle">Session (5h)</span>
                    <span className="text-[10px] text-subtle font-mono tabular-nums">resets 2h 47m</span>
                  </div>
                  <div className="relative flex flex-1 flex-col items-center gap-1.5 [&>svg]:size-20">
                    <svg viewBox="0 0 96 96">
                      <circle className="fill-none stroke-warm-10 [stroke-width:7]" cx="48" cy="48" r="38" />
                      <circle
                        className="fill-none [stroke-dasharray:201.06] [stroke-linecap:round] [stroke-width:7] stroke-accent"
                        cx="48"
                        cy="48"
                        r="38"
                        transform="rotate(-90 48 48)"
                        style={{ strokeDashoffset: 76.4 }}
                      />
                    </svg>
                    <span className="absolute inset-x-0 top-7 text-center text-base font-semibold font-mono tabular-nums">68%</span>
                    <span className="text-[9px] font-medium uppercase tracking-[0.16em] text-subtle">Weekly</span>
                    <span className="text-[10px] text-subtle font-mono tabular-nums">resets 3d 6h</span>
                  </div>
                </div>
                <div className="mt-6 flex h-10 items-end gap-[3px]" data-spark=""></div>
                <div className="font-mono tabular-nums text-subtle text-center text-[12px]">24-hour spark</div>
              </div>
            </div>
          </div>
        </section>

        <section className="border-t border-line">
          <div className="mx-auto w-full max-w-[1120px] px-6 grid items-center gap-12 py-24 md:grid-cols-2 md:gap-16 md:py-32 md:[&>:first-child]:order-2 md:[&>:last-child]:order-1" data-reveal-group="">
            <div className="[&>h3]:mt-4 [&>p:last-child]:mt-5 [&>p:last-child]:max-w-[440px]">
              <p className="text-[12px] font-medium uppercase tracking-[0.18em] text-accent">Codex</p>
              <h3>Claude and Codex, side by side.</h3>
              <p className="text-muted text-[17px] leading-[1.6]">
                Edith tracks both agents. Switch the rate-limit rings between
                providers, filter the dashboard by source, and see Codex chats
                right in the project drilldown next to your Claude sessions.
              </p>
            </div>
            <div>
              <div className="rounded-card border border-line-2 bg-surface p-6 shadow-card">
                <div className="mb-5 text-[11px] font-medium uppercase tracking-[0.16em] text-subtle flex items-baseline justify-between">
                  <span>Providers</span>
                  <span className="font-mono tabular-nums text-subtle">both tracked</span>
                </div>
                <div className="mb-5 flex flex-col gap-3">
                  <div className="grid grid-cols-[1fr_auto_auto] items-baseline gap-5 rounded-xl border border-line px-[18px] py-3.5 text-[14px]">
                    <span className="text-[15px] font-semibold">Claude</span>
                    <span className="font-mono tabular-nums">
                      47% <span className="text-subtle">session</span>
                    </span>
                    <span className="font-mono tabular-nums">
                      68% <span className="text-subtle">week</span>
                    </span>
                  </div>
                  <div className="grid grid-cols-[1fr_auto_auto] items-baseline gap-5 rounded-xl border border-line px-[18px] py-3.5 text-[14px]">
                    <span className="text-[15px] font-semibold">Codex</span>
                    <span className="font-mono tabular-nums">
                      12% <span className="text-subtle">session</span>
                    </span>
                    <span className="font-mono tabular-nums">
                      31% <span className="text-subtle">week</span>
                    </span>
                  </div>
                </div>
                <p className="text-center text-muted text-[12px]">
                  Toggle either provider off in Settings and its polling stops
                  entirely.
                </p>
              </div>
            </div>
          </div>
        </section>

        <section className="border-t border-line">
          <div className="mx-auto w-full max-w-[1120px] px-6 grid items-center gap-12 py-24 md:grid-cols-2 md:gap-16 md:py-32" data-reveal-group="">
            <div className="[&>h3]:mt-4 [&>p:last-child]:mt-5 [&>p:last-child]:max-w-[440px]">
              <p className="text-[12px] font-medium uppercase tracking-[0.18em] text-accent">Menu bar</p>
              <h3>Two numbers in your menu bar.</h3>
              <p className="text-muted text-[17px] leading-[1.6]">
                Session and weekly percentages, tinted by a time-aware risk
                model. Green when you have room. Amber when you're close. Red
                when the next prompt could push you over.
              </p>
            </div>
            <div>
              <div className="rounded-card border border-line-2 bg-surface p-6 shadow-card">
                <div className="flex h-9 items-center justify-end gap-4 rounded-lg border border-line bg-[color-mix(in_oklab,var(--color-bg)_60%,transparent)] px-4 text-[12px] text-muted font-mono tabular-nums">
                  <span>
                    <span className="text-sage">38%</span>{" "}
                    <span className="text-subtle">·</span>{" "}
                    <span className="text-accent">62%</span>
                  </span>
                  <span className="text-subtle">Wed 14:22</span>
                </div>
                <div className="mt-6 grid grid-cols-3 gap-3">
                  <span className="flex items-center gap-2 rounded-lg border border-line bg-[color-mix(in_oklab,var(--color-bg)_40%,transparent)] px-3 py-2 text-[11px] text-muted">
                    <i className="inline-block size-2 rounded-full bg-sage"></i>Safe
                  </span>
                  <span className="flex items-center gap-2 rounded-lg border border-line bg-[color-mix(in_oklab,var(--color-bg)_40%,transparent)] px-3 py-2 text-[11px] text-muted">
                    <i className="inline-block size-2 rounded-full bg-accent"></i>Close
                  </span>
                  <span className="flex items-center gap-2 rounded-lg border border-line bg-[color-mix(in_oklab,var(--color-bg)_40%,transparent)] px-3 py-2 text-[11px] text-muted">
                    <i className="inline-block size-2 rounded-full bg-danger"></i>Over
                  </span>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className="border-t border-line">
          <div className="mx-auto w-full max-w-[1120px] px-6 grid items-center gap-12 py-24 md:grid-cols-2 md:gap-16 md:py-32 md:[&>:first-child]:order-2 md:[&>:last-child]:order-1" data-reveal-group="">
            <div className="[&>h3]:mt-4 [&>p:last-child]:mt-5 [&>p:last-child]:max-w-[440px]">
              <p className="text-[12px] font-medium uppercase tracking-[0.18em] text-accent">Notifications</p>
              <h3>Alerts that stay out of your way.</h3>
              <p className="text-muted text-[17px] leading-[1.6]">
                Threshold, ahead-of-pace, burn, back-to-green, and pre-reset.
                All optional. A single button sends a test notification and
                reports back exactly why it did or didn't fire.
              </p>
            </div>
            <div>
              <div className="flex flex-col gap-3">
                <div className="flex items-start gap-3 rounded-card border border-line-2 bg-[color-mix(in_oklab,var(--color-surface)_90%,transparent)] p-4 shadow-notification [&>i]:mt-1.5 [&>i]:shrink-0">
                  <span className="size-9 shrink-0 rounded-[10px] bg-[linear-gradient(180deg,var(--color-accent),var(--color-art-rust))]"></span>
                  <div className="flex-1 [&>p]:mt-0.5 [&>p]:text-[13px] [&>p]:leading-[1.35] [&>p]:text-muted">
                    <div className="flex items-baseline justify-between [&>b]:text-[14px]">
                      <b>Ahead of pace</b>
                      <span className="font-mono tabular-nums text-subtle">Edith · now</span>
                    </div>
                    <p>
                      You're using this session faster than usual. 72% with 2h
                      47m left.
                    </p>
                  </div>
                  <i className="inline-block size-2 rounded-full bg-accent shadow-accent-glow"></i>
                </div>
                <div className="flex items-start gap-3 rounded-card border border-line-2 bg-[color-mix(in_oklab,var(--color-surface)_90%,transparent)] p-4 shadow-notification [&>i]:mt-1.5 [&>i]:shrink-0">
                  <span className="size-9 shrink-0 rounded-[10px] bg-[linear-gradient(180deg,var(--color-accent),var(--color-art-rust))]"></span>
                  <div className="flex-1 [&>p]:mt-0.5 [&>p]:text-[13px] [&>p]:leading-[1.35] [&>p]:text-muted">
                    <div className="flex items-baseline justify-between [&>b]:text-[14px]">
                      <b>Approaching weekly limit</b>
                      <span className="font-mono tabular-nums text-subtle">Edith · now</span>
                    </div>
                    <p>Week usage at 85%. Resets Sunday 4:00 PM.</p>
                  </div>
                  <i className="inline-block size-2 rounded-full bg-danger shadow-danger-glow"></i>
                </div>
                <div className="flex items-start gap-3 rounded-card border border-line-2 bg-[color-mix(in_oklab,var(--color-surface)_90%,transparent)] p-4 shadow-notification [&>i]:mt-1.5 [&>i]:shrink-0">
                  <span className="size-9 shrink-0 rounded-[10px] bg-[linear-gradient(180deg,var(--color-accent),var(--color-art-rust))]"></span>
                  <div className="flex-1 [&>p]:mt-0.5 [&>p]:text-[13px] [&>p]:leading-[1.35] [&>p]:text-muted">
                    <div className="flex items-baseline justify-between [&>b]:text-[14px]">
                      <b>Back in the green</b>
                      <span className="font-mono tabular-nums text-subtle">Edith · now</span>
                    </div>
                    <p>Session dropped below 60%. Room to keep going.</p>
                  </div>
                  <i className="inline-block size-2 rounded-full bg-sage shadow-sage-glow"></i>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className="border-t border-line">
          <div className="mx-auto w-full max-w-[1120px] px-6 grid items-center gap-12 py-24 md:grid-cols-2 md:gap-16 md:py-32" data-reveal-group="">
            <div className="[&>h3]:mt-4 [&>p:last-child]:mt-5 [&>p:last-child]:max-w-[440px]">
              <p className="text-[12px] font-medium uppercase tracking-[0.18em] text-accent">Heatmap</p>
              <h3>A year of usage at a glance.</h3>
              <p className="text-muted text-[17px] leading-[1.6]">
                A GitHub-style calendar of daily spend across your full history.
                Every day is a square, shaded by how much you spent. Hover any
                square for the exact number.
              </p>
            </div>
            <div>
              <div className="rounded-card border border-line-2 bg-surface p-6 shadow-card">
                <div className="mb-5 text-[11px] font-medium uppercase tracking-[0.16em] text-subtle flex items-baseline justify-between">
                  <span>Activity</span>
                  <span className="font-mono tabular-nums text-subtle">$1,284 · 13 weeks</span>
                </div>
                <div className="mb-1.5 grid grid-cols-3 text-[10px] font-mono tabular-nums text-subtle">
                  <span>May</span>
                  <span className="text-center">Jun</span>
                  <span className="text-right">Jul</span>
                </div>
                <div
                  className="grid grid-flow-col grid-rows-7 gap-1"
                  data-rows="7"
                  data-cols="20"
                  aria-hidden="true"
                ></div>
                <div className="mt-4 flex items-center justify-end gap-1.5 text-[10px] font-mono tabular-nums text-subtle">
                  Less<i className="inline-block size-3 rounded-[3px] bg-warm-5"></i>
                  <i className="inline-block size-3 rounded-[3px] bg-accent/[28%]"></i>
                  <i className="inline-block size-3 rounded-[3px] bg-accent/[50%]"></i>
                  <i className="inline-block size-3 rounded-[3px] bg-accent/[72%]"></i>
                  <i className="inline-block size-3 rounded-[3px] bg-accent"></i>More
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className="border-t border-line">
          <div className="mx-auto w-full max-w-[1120px] px-6 grid items-center gap-12 py-24 md:grid-cols-2 md:gap-16 md:py-32 md:[&>:first-child]:order-2 md:[&>:last-child]:order-1" data-reveal-group="">
            <div className="[&>h3]:mt-4 [&>p:last-child]:mt-5 [&>p:last-child]:max-w-[440px]">
              <p className="text-[12px] font-medium uppercase tracking-[0.18em] text-accent">Music</p>
              <h3>Your local music folder, done right.</h3>
              <p className="text-muted text-[17px] leading-[1.6]">
                Cover thumbnails, drag-to-seek, crossfades, auto-advance, and
                media keys. Point it at a folder and press play. No cloud, no
                accounts, no ads.
              </p>
            </div>
            <div>
              <div className="rounded-card border border-line-2 bg-surface p-6 shadow-card">
                <div className="mt-3 flex items-center gap-4 rounded-xl border border-line bg-[color-mix(in_oklab,var(--color-bg)_40%,transparent)] p-3 border-transparent! bg-transparent! p-0! [&>span:first-child]:size-16 [&>div>div:first-child]:text-[15px] [&>div>div:nth-child(3)]:h-1.5">
                  <span className="size-12 shrink-0 rounded-[10px] bg-[linear-gradient(145deg,var(--color-art-coral),var(--color-art-rust))]"></span>
                  <div className="min-w-0 flex-1">
                    <div className="truncate text-[14px] font-semibold">Weightless</div>
                    <div className="truncate text-[12px] text-muted">Marconi Union</div>
                    <div className="mt-2 h-1 overflow-hidden rounded-full bg-white/[10%] [&>span]:block [&>span]:h-full [&>span]:w-[18%] [&>span]:rounded-full [&>span]:bg-accent [&>span]:transition-[width] [&>span]:duration-100 [&>span]:ease-linear motion-reduce:[&>span]:transition-none">
                      <span style={{ width: "42%" }}></span>
                    </div>
                    <div className="mt-1.5 flex justify-between text-[11px] font-mono tabular-nums text-subtle">
                      <span>2:38</span>
                      <span>-3:34</span>
                    </div>
                  </div>
                </div>
                <div className="mt-4">
                  <div className="flex items-center gap-3 border-t border-line py-2.5 first:border-t-0">
                    <span className="size-8 shrink-0 rounded-md bg-[linear-gradient(145deg,var(--color-art-blue),var(--color-art-navy))]"></span>
                    <span className="min-w-0 flex-1 truncate text-[13px] text-muted">Clair de Lune · Debussy</span>
                    <span className="font-mono tabular-nums text-subtle">5:02</span>
                  </div>
                  <div className="flex items-center gap-3 border-t border-line py-2.5 first:border-t-0">
                    <span className="size-8 shrink-0 rounded-md bg-[linear-gradient(145deg,var(--color-art-green),var(--color-art-forest))]"></span>
                    <span className="min-w-0 flex-1 truncate text-[13px] text-muted">Time · Hans Zimmer</span>
                    <span className="font-mono tabular-nums text-subtle">4:35</span>
                  </div>
                  <div className="flex items-center gap-3 border-t border-line py-2.5 first:border-t-0">
                    <span className="size-8 shrink-0 rounded-md bg-[linear-gradient(145deg,var(--color-art-purple),var(--color-art-plum))]"></span>
                    <span className="min-w-0 flex-1 truncate text-[13px] text-muted">Intro · The xx</span>
                    <span className="font-mono tabular-nums text-subtle">2:07</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className="border-t border-line">
          <div className="mx-auto w-full max-w-[1120px] px-6 grid items-center gap-12 py-24 md:grid-cols-2 md:gap-16 md:py-32" data-reveal-group="">
            <div className="[&>h3]:mt-4 [&>p:last-child]:mt-5 [&>p:last-child]:max-w-[440px]">
              <p className="text-[12px] font-medium uppercase tracking-[0.18em] text-accent">Privacy</p>
              <h3>Presenter mode for the room.</h3>
              <p className="text-muted text-[17px] leading-[1.6]">
                One toggle blurs spend figures and track names so you can
                screen-share without exposing your bill. Watch it flip below.
                Usage stays local, with optional iCloud backup that merges
                across your machines.
              </p>
            </div>
            <div>
              <div className="rounded-card border border-line-2 bg-surface p-6 shadow-card [&[data-presenter-state=on]_[data-sensitive]]:blur-[7px] [&[data-presenter-state=on]_[data-sensitive]]:select-none" data-presenter-demo="" data-presenter-state="off">
                <div className="mb-5 text-[11px] font-medium uppercase tracking-[0.16em] text-subtle flex items-baseline justify-between">
                  <span>Usage</span>
                  <span className="inline-flex items-center gap-1.5 rounded-full border border-accent/[50%] bg-accent/[15%] px-2.5 py-1 text-[10px] font-medium uppercase tracking-[0.12em] text-accent" data-pbadge="">
                    Presenter on
                  </span>
                </div>
                <div className="grid grid-cols-4 gap-3">
                  <div className="rounded-[10px] border border-line bg-[color-mix(in_oklab,var(--color-bg)_40%,transparent)] p-3">
                    <div className="text-[9px] font-medium uppercase tracking-[0.12em] text-subtle">Cost this cycle</div>
                    <div className="mt-1.5 text-[18px] font-semibold font-mono tabular-nums transition-[filter_0.3s_ease] motion-reduce:transition-none" data-sensitive="">$3.8k</div>
                  </div>
                  <div className="rounded-[10px] border border-line bg-[color-mix(in_oklab,var(--color-bg)_40%,transparent)] p-3">
                    <div className="text-[9px] font-medium uppercase tracking-[0.12em] text-subtle">Tokens</div>
                    <div className="mt-1.5 text-[18px] font-semibold font-mono tabular-nums transition-[filter_0.3s_ease] motion-reduce:transition-none" data-sensitive="">5.19B</div>
                  </div>
                  <div className="rounded-[10px] border border-line bg-[color-mix(in_oklab,var(--color-bg)_40%,transparent)] p-3">
                    <div className="text-[9px] font-medium uppercase tracking-[0.12em] text-subtle">Cache hit</div>
                    <div className="mt-1.5 text-[18px] font-semibold font-mono tabular-nums">99.5%</div>
                  </div>
                  <div className="rounded-[10px] border border-line bg-[color-mix(in_oklab,var(--color-bg)_40%,transparent)] p-3">
                    <div className="text-[9px] font-medium uppercase tracking-[0.12em] text-subtle">Top model</div>
                    <div className="mt-1.5 text-[18px] font-semibold font-mono tabular-nums">opus-4-8</div>
                  </div>
                </div>
                <p className="mt-4 text-center text-muted text-[12px]" data-pnote="">
                  Spend and track names hidden for the room.
                </p>
              </div>
            </div>
          </div>
        </section>

        <section className="border-t border-line">
          <div className="mx-auto w-full max-w-[1120px] px-6 grid items-center gap-12 py-24 md:grid-cols-2 md:gap-16 md:py-32 md:[&>:first-child]:order-2 md:[&>:last-child]:order-1" data-reveal-group="">
            <div className="[&>h3]:mt-4 [&>p:last-child]:mt-5 [&>p:last-child]:max-w-[440px]">
              <p className="text-[12px] font-medium uppercase tracking-[0.18em] text-accent">System</p>
              <h3>Prevent sleep. Lock the keyboard.</h3>
              <p className="text-muted text-[17px] leading-[1.6]">
                Keep your Mac awake for a long build, even with the lid closed
                on power. Lock the keyboard to wipe it down without triggering
                shortcuts. Auto-restores in sixty seconds so you can't lock
                yourself out.
              </p>
            </div>
            <div>
              <div className="rounded-card border border-line-2 bg-surface p-6 shadow-card">
                <div className="mb-5 text-[11px] font-medium uppercase tracking-[0.16em] text-subtle">Quick actions</div>
                <div className="mt-3 grid grid-cols-3 gap-3 [&>span:nth-child(2)]:border-accent/[40%] [&>span:nth-child(2)]:bg-accent/[15%] [&>span:nth-child(2)>span:first-child]:text-accent grid-cols-3">
                  <span className="flex flex-col items-center gap-1.5 rounded-xl border border-line bg-[color-mix(in_oklab,var(--color-bg)_40%,transparent)] p-3 text-center text-[12px] font-semibold text-fg [&>small]:text-[11px] [&>small]:font-normal [&>small]:leading-[1.3] [&>small]:text-subtle">
                    <span className="text-base text-subtle">⌨</span>
                    <span>Clean keys</span>
                    <small>Lock the keyboard to wipe it</small>
                  </span>
                  <span className="flex flex-col items-center gap-1.5 rounded-xl border border-line bg-[color-mix(in_oklab,var(--color-bg)_40%,transparent)] p-3 text-center text-[12px] font-semibold text-fg [&>small]:text-[11px] [&>small]:font-normal [&>small]:leading-[1.3] [&>small]:text-subtle border-accent/[40%] bg-accent/[15%] [&>span:first-child]:text-accent">
                    <span className="text-base text-subtle">☾</span>
                    <span>Keep awake</span>
                    <small>Stop this Mac from sleeping</small>
                  </span>
                  <span className="flex flex-col items-center gap-1.5 rounded-xl border border-line bg-[color-mix(in_oklab,var(--color-bg)_40%,transparent)] p-3 text-center text-[12px] font-semibold text-fg [&>small]:text-[11px] [&>small]:font-normal [&>small]:leading-[1.3] [&>small]:text-subtle">
                    <span className="text-base text-subtle">◍</span>
                    <span>Presenter</span>
                    <small>Blur sensitive values</small>
                  </span>
                </div>
                <div className="mt-3 flex items-center gap-2 rounded-[10px] border border-dashed border-line-2 px-3 py-2.5 text-[12px] text-subtle">
                  <span>🔒</span>Keyboard relocks for 60s, then
                  restores itself. No way to get stuck.
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className="mx-auto w-full max-w-[1120px] px-6 border-t border-line py-24">
          <div className="mx-auto mb-14 max-w-[620px] text-center [&>h2]:mt-3" data-reveal-item="">
            <p className="text-[12px] font-medium uppercase tracking-[0.18em] text-accent">And the rest of the shelf</p>
            <h2>Everything else you'd otherwise install one by one.</h2>
          </div>
          <div className="grid grid-cols-1 gap-4 md:grid-cols-3" data-reveal-group="">
            <div className="rounded-card border border-line bg-surface p-6 transition-[transform_0.35s_cubic-bezier(0.16,1,0.3,1),border-color_0.35s_ease,box-shadow_0.35s_ease] hover:-translate-y-1 hover:border-accent/[35%] motion-reduce:transition-none [&>h4]:mt-5 [&>p]:mt-2 [&>p]:text-[14px] [&>p]:leading-[1.5] [&>p]:text-muted">
              <div className="flex h-[104px] items-center justify-center gap-2.5 overflow-hidden rounded-xl border border-line bg-surface-2 p-3.5">
                <span className="relative size-[38px] shrink-0 rounded-full border-2 border-accent bg-[conic-gradient(var(--color-line-2)_0_25%,transparent_0_50%,var(--color-line-2)_0_75%,transparent_0)_0_0/10px_10px,var(--color-surface)] after:absolute after:inset-1/2 after:m-[-4.5px] after:size-[9px] after:border-[1.5px] after:border-fg after:bg-accent after:content-['']"></span>
                <span className="inline-flex items-center gap-1.5 whitespace-nowrap rounded-full border border-line-2 px-[9px] py-[3px] text-[10.5px] text-muted font-mono tabular-nums border-accent/[40%]! text-accent!">&#35;F5A623</span>
              </div>
              <h4>Color picker</h4>
              <p>
                A system loupe on a hotkey. Sample any pixel and the hex lands
                on your clipboard.
              </p>
            </div>
            <div className="rounded-card border border-line bg-surface p-6 transition-[transform_0.35s_cubic-bezier(0.16,1,0.3,1),border-color_0.35s_ease,box-shadow_0.35s_ease] hover:-translate-y-1 hover:border-accent/[35%] motion-reduce:transition-none [&>h4]:mt-5 [&>p]:mt-2 [&>p]:text-[14px] [&>p]:leading-[1.5] [&>p]:text-muted">
              <div className="flex h-[104px] items-center justify-center gap-2.5 overflow-hidden rounded-xl border border-line bg-surface-2 p-3.5 relative">
                <span className="h-[46px] w-[72px] rounded-lg border border-line-2 bg-[linear-gradient(var(--color-line-2)_10px,transparent_0),var(--color-surface)] translate-x-2.5 -translate-y-1.5 opacity-[0.35]"></span>
                <span className="h-[46px] w-[72px] rounded-lg border border-line-2 bg-[linear-gradient(var(--color-line-2)_10px,transparent_0),var(--color-surface)] -translate-x-2.5 translate-y-1.5 shadow-window"></span>
              </div>
              <h4>Focus dim</h4>
              <p>
                Dims everything behind your active app so one window is all you
                see.
              </p>
            </div>
            <div className="rounded-card border border-line bg-surface p-6 transition-[transform_0.35s_cubic-bezier(0.16,1,0.3,1),border-color_0.35s_ease,box-shadow_0.35s_ease] hover:-translate-y-1 hover:border-accent/[35%] motion-reduce:transition-none [&>h4]:mt-5 [&>p]:mt-2 [&>p]:text-[14px] [&>p]:leading-[1.5] [&>p]:text-muted">
              <div className="flex h-[104px] items-center justify-center gap-2.5 overflow-hidden rounded-xl border border-line bg-surface-2 p-3.5 flex-col items-stretch! justify-center! gap-2!">
                <span className="-mt-3.5 h-[15px] w-[92px] self-center rounded-b-[10px] border border-t-0 border-line-2 bg-black"></span>
                <span className="flex justify-center gap-2">
                  <span className="h-[27px] w-[22px] rounded-[4px_8px_4px_4px] border border-line-2 bg-[linear-gradient(transparent_8px,var(--color-line-2)_8px,var(--color-line-2)_10px,transparent_10px,transparent_14px,var(--color-line-2)_14px,var(--color-line-2)_16px,transparent_16px),var(--color-surface)]"></span>
                  <span className="h-[27px] w-[22px] rounded-[4px_8px_4px_4px] border border-line-2 bg-[linear-gradient(transparent_8px,var(--color-line-2)_8px,var(--color-line-2)_10px,transparent_10px,transparent_14px,var(--color-line-2)_14px,var(--color-line-2)_16px,transparent_16px),var(--color-surface)]"></span>
                  <span className="h-[27px] w-[22px] rounded-[4px_8px_4px_4px] border border-line-2 bg-[linear-gradient(transparent_8px,var(--color-line-2)_8px,var(--color-line-2)_10px,transparent_10px,transparent_14px,var(--color-line-2)_14px,var(--color-line-2)_16px,transparent_16px),var(--color-surface)]"></span>
                </span>
              </div>
              <h4>Notch shelf</h4>
              <p>
                Park files under the notch mid-drag, then drop them wherever
                they belong.
              </p>
            </div>
            <div className="rounded-card border border-line bg-surface p-6 transition-[transform_0.35s_cubic-bezier(0.16,1,0.3,1),border-color_0.35s_ease,box-shadow_0.35s_ease] hover:-translate-y-1 hover:border-accent/[35%] motion-reduce:transition-none [&>h4]:mt-5 [&>p]:mt-2 [&>p]:text-[14px] [&>p]:leading-[1.5] [&>p]:text-muted">
              <div className="flex h-[104px] items-center justify-center gap-2.5 overflow-hidden rounded-xl border border-line bg-surface-2 p-3.5 flex-col items-stretch! justify-center! gap-2!">
                <span className="flex min-w-0 items-center gap-2 rounded-lg border border-line-2 bg-accent/[8%] px-2 py-1 [&>span:first-child]:flex-1 [&>span:first-child]:bg-[color-mix(in_oklab,var(--color-accent)_50%,var(--color-line-2))]">
                  <span className="h-1.5 shrink-0 rounded-full bg-line-2 w-3/5"></span>
                  <span className="inline-flex h-6 min-w-6 items-center justify-center rounded-md border border-line-2 border-b-2 bg-surface px-1.5 font-mono text-[11px] text-muted">⌘V</span>
                </span>
                <span className="flex min-w-0 items-center gap-2">
                  <span className="h-1.5 shrink-0 rounded-full bg-line-2 w-4/5"></span>
                </span>
                <span className="flex min-w-0 items-center gap-2">
                  <span className="h-1.5 shrink-0 rounded-full bg-line-2 w-2/5"></span>
                </span>
              </div>
              <h4>Clipboard history</h4>
              <p>
                Everything you copied, one shortcut away, with instant paste.
              </p>
            </div>
            <div className="rounded-card border border-line bg-surface p-6 transition-[transform_0.35s_cubic-bezier(0.16,1,0.3,1),border-color_0.35s_ease,box-shadow_0.35s_ease] hover:-translate-y-1 hover:border-accent/[35%] motion-reduce:transition-none [&>h4]:mt-5 [&>p]:mt-2 [&>p]:text-[14px] [&>p]:leading-[1.5] [&>p]:text-muted">
              <div className="flex h-[104px] items-center justify-center gap-2.5 overflow-hidden rounded-xl border border-line bg-surface-2 p-3.5 flex-col items-stretch! justify-center! gap-2!">
                <span className="flex min-w-0 items-center gap-2">
                  <i className="inline-block size-2 rounded-full bg-accent"></i>
                  <span className="truncate text-[11px] text-muted">10:00 Standup</span>
                  <span className="inline-flex items-center gap-1.5 whitespace-nowrap rounded-full border border-line-2 px-[9px] py-[3px] text-[10.5px] text-muted border-accent/[40%]! text-accent!">Join</span>
                </span>
                <span className="flex min-w-0 items-center gap-2">
                  <i className="inline-block size-2 rounded-full bg-sage"></i>
                  <span className="truncate text-[11px] text-muted">1:30 Design review</span>
                </span>
              </div>
              <h4>Calendar</h4>
              <p>
                Today's schedule in the panel and the app, with one-tap join
                links.
              </p>
            </div>
            <div className="rounded-card border border-line bg-surface p-6 transition-[transform_0.35s_cubic-bezier(0.16,1,0.3,1),border-color_0.35s_ease,box-shadow_0.35s_ease] hover:-translate-y-1 hover:border-accent/[35%] motion-reduce:transition-none [&>h4]:mt-5 [&>p]:mt-2 [&>p]:text-[14px] [&>p]:leading-[1.5] [&>p]:text-muted">
              <div className="flex h-[104px] items-center justify-center gap-2.5 overflow-hidden rounded-xl border border-line bg-surface-2 p-3.5">
                <span className="inline-flex items-center gap-1.5 whitespace-nowrap rounded-full border border-line-2 px-[9px] py-[3px] text-[10.5px] text-muted font-mono tabular-nums">SF 11:59</span>
                <span className="inline-flex items-center gap-1.5 whitespace-nowrap rounded-full border border-line-2 px-[9px] py-[3px] text-[10.5px] text-muted font-mono tabular-nums">NY 2:29</span>
                <span className="inline-flex items-center gap-1.5 whitespace-nowrap rounded-full border border-line-2 px-[9px] py-[3px] text-[10.5px] text-muted font-mono tabular-nums">LDN 7:29</span>
              </div>
              <h4>World clocks</h4>
              <p>Local time plus the offices you care about, at a glance.</p>
            </div>
            <div className="rounded-card border border-line bg-surface p-6 transition-[transform_0.35s_cubic-bezier(0.16,1,0.3,1),border-color_0.35s_ease,box-shadow_0.35s_ease] hover:-translate-y-1 hover:border-accent/[35%] motion-reduce:transition-none [&>h4]:mt-5 [&>p]:mt-2 [&>p]:text-[14px] [&>p]:leading-[1.5] [&>p]:text-muted">
              <div className="flex h-[104px] items-center justify-center gap-2.5 overflow-hidden rounded-xl border border-line bg-surface-2 p-3.5">
                <span className="inline-flex h-6 min-w-6 items-center justify-center rounded-md border border-line-2 border-b-2 bg-surface px-1.5 font-mono text-[11px] text-muted h-10 min-w-10 rounded-[9px] text-[17px]">⌥</span>
                <span className="inline-flex h-6 min-w-6 items-center justify-center rounded-md border border-line-2 border-b-2 bg-surface px-1.5 font-mono text-[11px] text-muted h-10 min-w-10 rounded-[9px] text-[17px]">⌘</span>
                <span className="inline-flex h-6 min-w-6 items-center justify-center rounded-md border border-line-2 border-b-2 bg-surface px-1.5 font-mono text-[11px] text-muted h-10 min-w-10 rounded-[9px] text-[17px]">E</span>
              </div>
              <h4>Global shortcut</h4>
              <p>
                Toggle the panel from anywhere. Defaults to Option-Command-E and
                re-records to taste.
              </p>
            </div>
            <div className="rounded-card border border-line bg-surface p-6 transition-[transform_0.35s_cubic-bezier(0.16,1,0.3,1),border-color_0.35s_ease,box-shadow_0.35s_ease] hover:-translate-y-1 hover:border-accent/[35%] motion-reduce:transition-none [&>h4]:mt-5 [&>p]:mt-2 [&>p]:text-[14px] [&>p]:leading-[1.5] [&>p]:text-muted">
              <div className="flex h-[104px] items-center justify-center gap-2.5 overflow-hidden rounded-xl border border-line bg-surface-2 p-3.5">
                <span className="relative mt-[9px] h-[15px] w-5 shrink-0 rounded bg-accent before:absolute before:left-[3px] before:top-[-9px] before:h-3 before:w-3.5 before:rounded-t-lg before:border-[2.5px] before:border-b-0 before:border-muted before:box-border before:content-['']"></span>
                <span className="truncate text-[11px] text-muted">Stays on this Mac</span>
              </div>
              <h4>Local first</h4>
              <p>
                Usage never leaves your Mac. Optional iCloud backup merges
                across machines.
              </p>
            </div>
            <div className="rounded-card border border-line bg-surface p-6 transition-[transform_0.35s_cubic-bezier(0.16,1,0.3,1),border-color_0.35s_ease,box-shadow_0.35s_ease] hover:-translate-y-1 hover:border-accent/[35%] motion-reduce:transition-none [&>h4]:mt-5 [&>p]:mt-2 [&>p]:text-[14px] [&>p]:leading-[1.5] [&>p]:text-muted">
              <div className="flex h-[104px] items-center justify-center gap-2.5 overflow-hidden rounded-xl border border-line bg-surface-2 p-3.5">
                <span className="relative h-[19px] w-3 shrink-0 rounded-full bg-muted before:absolute before:-inset-x-[5px] before:-bottom-[5px] before:h-3 before:rounded-b-[11px] before:border-2 before:border-t-0 before:border-muted before:content-[''] after:absolute after:left-1/2 after:-top-1.5 after:-bottom-2 after:w-[2.5px] after:rotate-45 after:rounded-[2px] after:bg-danger after:content-['']"></span>
                <span className="inline-flex items-center gap-1.5 whitespace-nowrap rounded-full border border-line-2 px-[9px] py-[3px] text-[10.5px] text-muted">
                  <i className="inline-block size-2 rounded-full bg-danger"></i>All mics muted
                </span>
              </div>
              <h4>Mic mute</h4>
              <p>
                Every microphone muted system-wide with one hotkey. The menu bar
                shows when you're safe.
              </p>
            </div>
            <div className="rounded-card border border-line bg-surface p-6 transition-[transform_0.35s_cubic-bezier(0.16,1,0.3,1),border-color_0.35s_ease,box-shadow_0.35s_ease] hover:-translate-y-1 hover:border-accent/[35%] motion-reduce:transition-none [&>h4]:mt-5 [&>p]:mt-2 [&>p]:text-[14px] [&>p]:leading-[1.5] [&>p]:text-muted">
              <div className="flex h-[104px] items-center justify-center gap-2.5 overflow-hidden rounded-xl border border-line bg-surface-2 p-3.5 flex-col items-stretch! justify-center! gap-2!">
                <span className="flex min-w-0 items-center gap-2">
                  <span className="truncate text-[11px] text-muted w-11 shrink-0">Safari</span>
                  <span className="h-1 min-w-[30px] flex-1 rounded-full bg-line-2 [&>i]:block [&>i]:h-full [&>i]:rounded-full [&>i]:bg-accent">
                    <i style={{ width: "35%" }}></i>
                  </span>
                </span>
                <span className="flex min-w-0 items-center gap-2">
                  <span className="truncate text-[11px] text-muted w-11 shrink-0">Music</span>
                  <span className="h-1 min-w-[30px] flex-1 rounded-full bg-line-2 [&>i]:block [&>i]:h-full [&>i]:rounded-full [&>i]:bg-accent">
                    <i style={{ width: "80%" }}></i>
                  </span>
                </span>
                <span className="flex min-w-0 items-center gap-2">
                  <span className="truncate text-[11px] text-muted w-11 shrink-0">Zoom</span>
                  <span className="h-1 min-w-[30px] flex-1 rounded-full bg-line-2 [&>i]:block [&>i]:h-full [&>i]:rounded-full [&>i]:bg-accent">
                    <i style={{ width: "55%" }}></i>
                  </span>
                </span>
              </div>
              <h4>Audio mixer</h4>
              <p>
                Per-app volume from the panel. Quiet the browser, keep the
                music.
              </p>
            </div>
            <div className="rounded-card border border-line bg-surface p-6 transition-[transform_0.35s_cubic-bezier(0.16,1,0.3,1),border-color_0.35s_ease,box-shadow_0.35s_ease] hover:-translate-y-1 hover:border-accent/[35%] motion-reduce:transition-none [&>h4]:mt-5 [&>p]:mt-2 [&>p]:text-[14px] [&>p]:leading-[1.5] [&>p]:text-muted">
              <div className="flex h-[104px] items-center justify-center gap-2.5 overflow-hidden rounded-xl border border-line bg-surface-2 p-3.5 flex-col items-stretch! justify-center! gap-2!">
                <span className="-mt-3.5 h-[15px] w-[92px] self-center rounded-b-[10px] border border-t-0 border-line-2 bg-black"></span>
                <span className="inline-flex items-center gap-1.5 whitespace-nowrap rounded-full border border-line-2 px-[9px] py-[3px] text-[10.5px] text-muted">
                  <i className="inline-block size-2 rounded-full bg-sage"></i>AirPods connected
                </span>
              </div>
              <h4>Notch alerts</h4>
              <p>
                Bluetooth, audio-output, and charger changes surface as small
                notices around the notch.
              </p>
            </div>
            <div className="rounded-card border border-line bg-surface p-6 transition-[transform_0.35s_cubic-bezier(0.16,1,0.3,1),border-color_0.35s_ease,box-shadow_0.35s_ease] hover:-translate-y-1 hover:border-accent/[35%] motion-reduce:transition-none [&>h4]:mt-5 [&>p]:mt-2 [&>p]:text-[14px] [&>p]:leading-[1.5] [&>p]:text-muted">
              <div className="flex h-[104px] items-center justify-center gap-2.5 overflow-hidden rounded-xl border border-line bg-surface-2 p-3.5">
                <span className="flex flex-1 items-center justify-between gap-3 rounded-lg border border-line-2 bg-surface px-3 py-[7px] text-[11px] text-fg font-mono tabular-nums">
                  CPU 3% · 6.2 GB<span className="text-subtle">Wed 14:22</span>
                </span>
              </div>
              <h4>CPU &amp; memory readout</h4>
              <p>
                Live stats in the menu bar, so a runaway process never sneaks up
                on you.
              </p>
            </div>
            <div className="rounded-card border border-line bg-surface p-6 transition-[transform_0.35s_cubic-bezier(0.16,1,0.3,1),border-color_0.35s_ease,box-shadow_0.35s_ease] hover:-translate-y-1 hover:border-accent/[35%] motion-reduce:transition-none [&>h4]:mt-5 [&>p]:mt-2 [&>p]:text-[14px] [&>p]:leading-[1.5] [&>p]:text-muted">
              <div className="flex h-[104px] items-center justify-center gap-2.5 overflow-hidden rounded-xl border border-line bg-surface-2 p-3.5 flex-col items-stretch! justify-center! gap-2!">
                <span className="flex min-w-0 items-center gap-2">
                  <span className="truncate text-[11px] text-muted">Build caches</span>
                  <span className="inline-flex items-center gap-1.5 whitespace-nowrap rounded-full border border-line-2 px-[9px] py-[3px] text-[10.5px] text-muted font-mono tabular-nums">8.2 GB</span>
                </span>
                <span className="flex min-w-0 items-center gap-2">
                  <span className="h-1 min-w-[30px] flex-1 rounded-full bg-line-2 [&>i]:block [&>i]:h-full [&>i]:rounded-full [&>i]:bg-accent">
                    <i style={{ width: "64%" }}></i>
                  </span>
                  <span className="truncate text-[11px] text-muted font-mono tabular-nums">12.4 GB found</span>
                </span>
              </div>
              <h4>Junk cleaner</h4>
              <p>
                Scan build caches, package managers, and old logs. Reclaim
                gigabytes, restorable from the Trash.
              </p>
            </div>
            <div className="rounded-card border border-line bg-surface p-6 transition-[transform_0.35s_cubic-bezier(0.16,1,0.3,1),border-color_0.35s_ease,box-shadow_0.35s_ease] hover:-translate-y-1 hover:border-accent/[35%] motion-reduce:transition-none [&>h4]:mt-5 [&>p]:mt-2 [&>p]:text-[14px] [&>p]:leading-[1.5] [&>p]:text-muted">
              <div className="flex h-[104px] items-center justify-center gap-2.5 overflow-hidden rounded-xl border border-line bg-surface-2 p-3.5 flex-col items-stretch! justify-center! gap-2!">
                <span className="flex min-w-0 items-center gap-2">
                  <span className="truncate text-[11px] text-muted">Chrome</span>
                  <span className="inline-flex items-center gap-1.5 whitespace-nowrap rounded-full border border-line-2 px-[9px] py-[3px] text-[10.5px] text-muted font-mono tabular-nums">42%</span>
                  <span className="inline-flex size-[18px] shrink-0 items-center justify-center rounded-md border border-line-2 text-[9px] text-danger">✕</span>
                </span>
                <span className="flex min-w-0 items-center gap-2">
                  <span className="truncate text-[11px] text-muted">node</span>
                  <span className="inline-flex items-center gap-1.5 whitespace-nowrap rounded-full border border-line-2 px-[9px] py-[3px] text-[10.5px] text-muted font-mono tabular-nums">31%</span>
                  <span className="inline-flex size-[18px] shrink-0 items-center justify-center rounded-md border border-line-2 text-[9px] text-danger">✕</span>
                </span>
              </div>
              <h4>Running apps</h4>
              <p>
                Sort every open app by CPU or memory and quit the heavy ones in
                a click.
              </p>
            </div>
            <div className="rounded-card border border-line bg-surface p-6 transition-[transform_0.35s_cubic-bezier(0.16,1,0.3,1),border-color_0.35s_ease,box-shadow_0.35s_ease] hover:-translate-y-1 hover:border-accent/[35%] motion-reduce:transition-none [&>h4]:mt-5 [&>p]:mt-2 [&>p]:text-[14px] [&>p]:leading-[1.5] [&>p]:text-muted">
              <div className="flex h-[104px] items-center justify-center gap-2.5 overflow-hidden rounded-xl border border-line bg-surface-2 p-3.5 flex-col items-stretch! justify-center! gap-2!">
                <span className="inline-flex items-center gap-1.5 whitespace-nowrap rounded-full border border-line-2 px-[9px] py-[3px] text-[10.5px] text-muted font-mono tabular-nums block! max-w-full self-start truncate">
                  youtube.com/watch?v=dQw4…
                </span>
                <span className="flex min-w-0 items-center gap-2">
                  <span className="h-1 min-w-[30px] flex-1 rounded-full bg-line-2 [&>i]:block [&>i]:h-full [&>i]:rounded-full [&>i]:bg-accent">
                    <i style={{ width: "64%" }}></i>
                  </span>
                  <span className="truncate text-[11px] text-muted font-mono tabular-nums">64%</span>
                </span>
              </div>
              <h4>YouTube audio</h4>
              <p>
                Paste links, get tagged audio files straight into your music
                folder, with live progress.
              </p>
            </div>
            <div className="rounded-card border border-line bg-surface p-6 transition-[transform_0.35s_cubic-bezier(0.16,1,0.3,1),border-color_0.35s_ease,box-shadow_0.35s_ease] hover:-translate-y-1 hover:border-accent/[35%] motion-reduce:transition-none [&>h4]:mt-5 [&>p]:mt-2 [&>p]:text-[14px] [&>p]:leading-[1.5] [&>p]:text-muted">
              <div className="flex h-[104px] items-center justify-center gap-2.5 overflow-hidden rounded-xl border border-line bg-surface-2 p-3.5 flex-col items-stretch! justify-center! gap-2!">
                <span className="flex min-w-0 items-center gap-2">
                  <span className="truncate text-[11px] text-muted">▸ edith</span>
                  <span className="inline-flex items-center gap-1.5 whitespace-nowrap rounded-full border border-line-2 px-[9px] py-[3px] text-[10.5px] text-muted font-mono tabular-nums">$412</span>
                </span>
                <span className="flex min-w-0 items-center gap-2 pl-4">
                  <span className="truncate text-[11px] text-muted">notch-motion</span>
                  <span className="inline-flex items-center gap-1.5 whitespace-nowrap rounded-full border border-line-2 px-[9px] py-[3px] text-[10.5px] text-muted font-mono tabular-nums">$268</span>
                </span>
              </div>
              <h4>Project drilldown</h4>
              <p>
                Spend by project, worktree, and chat, across Claude and Codex,
                so you know which repo eats the budget.
              </p>
            </div>
            <div className="rounded-card border border-line bg-surface p-6 transition-[transform_0.35s_cubic-bezier(0.16,1,0.3,1),border-color_0.35s_ease,box-shadow_0.35s_ease] hover:-translate-y-1 hover:border-accent/[35%] motion-reduce:transition-none [&>h4]:mt-5 [&>p]:mt-2 [&>p]:text-[14px] [&>p]:leading-[1.5] [&>p]:text-muted">
              <div className="flex h-[104px] items-center justify-center gap-2.5 overflow-hidden rounded-xl border border-line bg-surface-2 p-3.5 flex-col items-stretch! justify-center! gap-2!">
                <span className="flex min-w-0 items-center gap-2">
                  <i className="inline-block size-2 rounded-full bg-sage"></i>
                  <span className="truncate text-[11px] text-muted">Spotify · Weightless</span>
                </span>
                <span className="flex min-w-0 items-center gap-2">
                  <span className="h-1 min-w-[30px] flex-1 rounded-full bg-line-2 [&>i]:block [&>i]:h-full [&>i]:rounded-full [&>i]:bg-accent">
                    <i style={{ width: "42%" }}></i>
                  </span>
                  <span className="truncate text-[11px] text-muted font-mono tabular-nums">-3:34</span>
                </span>
              </div>
              <h4>Spotify &amp; Apple Music</h4>
              <p>
                Whatever is already playing shows up in the player with full
                controls, next to your local library.
              </p>
            </div>
            <div className="rounded-card border border-line bg-surface p-6 transition-[transform_0.35s_cubic-bezier(0.16,1,0.3,1),border-color_0.35s_ease,box-shadow_0.35s_ease] hover:-translate-y-1 hover:border-accent/[35%] motion-reduce:transition-none [&>h4]:mt-5 [&>p]:mt-2 [&>p]:text-[14px] [&>p]:leading-[1.5] [&>p]:text-muted">
              <div className="flex h-[104px] items-center justify-center gap-2.5 overflow-hidden rounded-xl border border-line bg-surface-2 p-3.5">
                <span className="relative h-[62px] w-[110px] rounded-[10px] border border-line-2 bg-black">
                  <span className="absolute left-1/2 top-1/2 size-6 -translate-x-1/2 -translate-y-[60%] rounded-full bg-surface-2 after:absolute after:left-1/2 after:top-[26px] after:h-[18px] after:w-[34px] after:-translate-x-1/2 after:rounded-t-[10px] after:bg-surface-2 after:content-['']"></span>
                  <span className="absolute right-[5px] bottom-[5px] flex size-[18px] items-center justify-center rounded-md bg-white/[12%] text-[10px] text-fg">⟳</span>
                </span>
              </div>
              <h4>Camera check</h4>
              <p>
                A quick mirror under the notch before the call, with a switcher
                for every connected camera.
              </p>
            </div>
          </div>
        </section>

        <section id="performance" className="mx-auto w-full max-w-[1120px] px-6 border-t border-line py-24">
          <div className="grid gap-12 md:grid-cols-[5fr_7fr] md:items-start [&>div:first-child>h2]:mt-4 [&>div:first-child>p:nth-of-type(2)]:mt-6 [&>div:first-child>p:nth-of-type(2)]:max-w-[440px] [&>div:first-child>p:nth-of-type(3)]:mt-4" data-reveal-group="">
            <div>
              <p className="text-[12px] font-medium uppercase tracking-[0.18em] text-accent">24/7, quietly</p>
              <h2>Built to sit in your menu bar forever.</h2>
              <p className="text-muted text-[17px] leading-[1.6]">
                Native SwiftUI, not Electron. Work stops when it isn't seen.
                Disabling a tab tears down its timers and background jobs.
                Per-frame UI only redraws while the panel is open.
              </p>
              <p className="text-[12px] text-subtle">
                Measured on Apple M4 Pro. CPU as a share of one core, memory as
                physical footprint.
              </p>
            </div>
            <div className="overflow-hidden rounded-card border border-line bg-surface">
              <div className="grid grid-cols-[1fr_1.2fr] items-start gap-6 border-b border-line px-6 py-5 last:border-b-0 bg-surface-2 text-[12px] font-medium uppercase tracking-[0.14em] text-muted grid-cols-[1.4fr_1fr_1fr]! items-center! p-6!">
                <span>State</span>
                <span className="text-right">CPU</span>
                <span className="text-right">Memory</span>
              </div>
              <div className="grid grid-cols-[1fr_1.2fr] items-start gap-6 border-b border-line px-6 py-5 last:border-b-0 grid-cols-[1.4fr_1fr_1fr]! items-center! p-6!">
                <span>Idle, panel closed</span>
                <span className="text-right font-mono tabular-nums text-muted">~0%</span>
                <span className="text-right font-mono tabular-nums text-muted">~22 MB</span>
              </div>
              <div className="grid grid-cols-[1fr_1.2fr] items-start gap-6 border-b border-line px-6 py-5 last:border-b-0 grid-cols-[1.4fr_1fr_1fr]! items-center! p-6!">
                <span>Music playing, panel closed</span>
                <span className="text-right font-mono tabular-nums text-muted">~1%</span>
                <span className="text-right font-mono tabular-nums text-muted">~40 MB</span>
              </div>
              <div className="grid grid-cols-[1fr_1.2fr] items-start gap-6 border-b border-line px-6 py-5 last:border-b-0 grid-cols-[1.4fr_1fr_1fr]! items-center! p-6!">
                <span>Paused</span>
                <span className="text-right font-mono tabular-nums text-muted">&lt;1%</span>
                <span className="text-right font-mono tabular-nums text-muted">~40 MB</span>
              </div>
            </div>
          </div>
        </section>

        <section className="mx-auto w-full max-w-[1120px] px-6 border-t border-line py-24 text-center [&>h2]:mx-auto [&>h2]:mt-4 [&>h2]:max-w-[760px] [&>p:last-child]:mt-6" data-reveal-group="">
          <p className="text-[12px] font-medium uppercase tracking-[0.18em] text-accent">Local first</p>
          <h2>Your usage never leaves your Mac.</h2>
          <p className="text-muted text-[17px] leading-[1.6] mx-auto max-w-[620px]">
            No account. No telemetry. Optional iCloud backup merges cleanly
            across machines so your history follows you between a MacBook and a
            Mac mini.
          </p>
        </section>

        <section id="download" className="mx-auto w-full max-w-[1120px] px-6 border-t border-line pt-24 pb-28 text-center [&>h2]:mx-auto [&>h2]:max-w-[640px] [&>a]:mt-8 [&>p]:mt-3" data-reveal-group="">
          <h2>Try Edith on your Mac.</h2>
          <a href="/api/v1/download/installer" className="inline-flex cursor-pointer items-center justify-center gap-2 rounded-full border border-transparent px-6 py-3 text-[14px] font-medium transition-[transform_0.35s_cubic-bezier(0.16,1,0.3,1),border-color_0.35s_ease,box-shadow_0.35s_ease] hover:-translate-y-px motion-reduce:transition-none bg-accent text-accent-fg">
            <svg className="size-3.5 fill-current" viewBox="0 0 24 24" aria-hidden="true">
              <path d="M16.365 1.43c0 1.14-.42 2.23-1.24 3.05-.83.83-2.19 1.45-3.31 1.36-.14-1.1.43-2.24 1.2-2.98.85-.83 2.32-1.42 3.35-1.43zM20.5 17.29c-.57 1.31-.85 1.9-1.59 3.06-1.03 1.61-2.48 3.62-4.28 3.63-1.6.01-2.01-1.05-4.18-1.04-2.17.01-2.62 1.06-4.22 1.05-1.8-.02-3.18-1.83-4.21-3.44C-.36 16.72-1.02 10.6 2.87 8.4c1.4-.8 2.86-1.24 4.24-1.26 1.61-.03 3.13 1.09 4.19 1.09 1.05 0 2.87-1.35 4.85-1.15.83.03 3.16.33 4.66 2.52-.12.08-2.78 1.62-2.75 4.82.03 3.83 3.36 5.1 3.4 5.11-.03.09-.53 1.82-1.96 3.76z" />
            </svg>
            Download for macOS
          </a>
          <p className="text-[12px] text-subtle">Requires macOS. Apple Silicon and Intel.</p>
        </section>
      </main>

      <footer className="border-t border-line">
        <div className="mx-auto w-full max-w-[1120px] px-6 flex flex-col gap-6 py-10 md:flex-row md:items-center md:justify-between">
          <div className="flex items-center gap-2 text-[15px] font-semibold">
            <img
              src="/app-icon-512.png"
              alt="Edith app icon"
              width="28"
              height="28"
              className="size-7 rounded-[22%] shadow-brand-icon"
            />
            <span className="text-muted text-[12px]">Edith. Made for macOS.</span>
          </div>
          <div className="flex gap-6 text-[13px] text-muted [&>a:hover]:text-fg">
            <a href="#features">Features</a>
            <a href="#download">Download</a>
            <a href="/terms">Terms</a>
            <a href="/privacy">Privacy</a>
          </div>
        </div>
      </footer>
      <LandingBehavior />
    </>
  );
}
