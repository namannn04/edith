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
      <header className="nav">
        <div className="page nav-inner">
          <a href="#top" className="brand">
            <img
              src="/app-icon-512.png"
              alt="Edith app icon"
              width="28"
              height="28"
              className="brand-icon"
            />
            <span>Edith</span>
          </a>
          <nav className="nav-links">
            <a href="#features">Features</a>
            <a href="#performance">Performance</a>
          </nav>
          <a href="/api/v1/download/installer" className="btn btn-solid btn-sm">
            Download
          </a>
        </div>
      </header>

      <main id="top">
        <section className="hero">
          <div className="hero-glow" aria-hidden="true"></div>
          <div className="page hero-inner">
            <img
              src="/app-icon.png"
              alt="Edith app icon"
              width="88"
              height="88"
              className="hero-icon"
            />
            <p className="eyebrow">For macOS</p>
            <h1>
              One menu bar app
              <br />
              instead of twelve.
            </h1>
            <p className="lede">
              Edith is a native Mac app for Claude and Codex rate-limit
              tracking, usage analytics, local music, and system tools.
            </p>
            <div className="hero-cta">
              <a href="/api/v1/download/installer" className="btn btn-solid">
                <svg className="apple" viewBox="0 0 24 24" aria-hidden="true">
                  <path d="M16.365 1.43c0 1.14-.42 2.23-1.24 3.05-.83.83-2.19 1.45-3.31 1.36-.14-1.1.43-2.24 1.2-2.98.85-.83 2.32-1.42 3.35-1.43zM20.5 17.29c-.57 1.31-.85 1.9-1.59 3.06-1.03 1.61-2.48 3.62-4.28 3.63-1.6.01-2.01-1.05-4.18-1.04-2.17.01-2.62 1.06-4.22 1.05-1.8-.02-3.18-1.83-4.21-3.44C-.36 16.72-1.02 10.6 2.87 8.4c1.4-.8 2.86-1.24 4.24-1.26 1.61-.03 3.13 1.09 4.19 1.09 1.05 0 2.87-1.35 4.85-1.15.83.03 3.16.33 4.66 2.52-.12.08-2.78 1.62-2.75 4.82.03 3.83 3.36 5.1 3.4 5.11-.03.09-.53 1.82-1.96 3.76z" />
                </svg>
                Download for macOS
              </a>
            </div>
            <p className="fine">Requires macOS. Apple Silicon and Intel.</p>

            <div className="hero-demo">
              <div className="demo">
                <input type="checkbox" id="presenter" className="vh" />
                <div className="demo-bar">
                  <span className="lights">
                    <i></i>
                    <i></i>
                    <i></i>
                  </span>
                  <span className="demo-title">Edith</span>
                  <span className="spacer"></span>
                  <span className="demo-clock mono">11:59 PM</span>
                </div>
                <div className="demo-body">
                  <aside className="demo-nav">
                    <span className="on">Home</span>
                    <span>Agent Usage</span>
                    <span>Music</span>
                    <span>Calendar</span>
                    <span className="demo-settings">Settings</span>
                  </aside>
                  <div className="demo-main">
                    <div className="greeting">
                      <div className="serif greet-title">Good evening.</div>
                      <div className="greet-sub">
                        This week <span className="mono sensitive">$2.1k</span>
                      </div>
                    </div>

                    <div className="clocks">
                      <div className="clock">
                        <div className="mono clock-t">11:59</div>
                        <div className="mono clock-ap">PM</div>
                        <div className="clock-l">Local</div>
                      </div>
                      <div className="clock">
                        <div className="mono clock-t">2:29</div>
                        <div className="mono clock-ap">PM</div>
                        <div className="clock-l">New York</div>
                      </div>
                      <div className="clock">
                        <div className="mono clock-t">7:29</div>
                        <div className="mono clock-ap">PM</div>
                        <div className="clock-l">London</div>
                      </div>
                    </div>

                    <div className="qa">
                      <span className="qa-tile">
                        <span className="qa-ic">⌨</span>
                        <span>Clean keys</span>
                      </span>
                      <span className="qa-tile on">
                        <span className="qa-ic">☾</span>
                        <span>Keep awake</span>
                      </span>
                      <label htmlFor="presenter" className="qa-tile qa-toggle">
                        <span className="qa-ic">◍</span>
                        <span>Presenter</span>
                      </label>
                    </div>

                    <div className="demo-grid">
                      <div className="panel">
                        <div className="panel-h">Rate limits</div>
                        <div className="rings">
                          <div className="ring">
                            <svg viewBox="0 0 80 80">
                              <circle
                                className="ring-bg"
                                cx="40"
                                cy="40"
                                r="32"
                              />
                              <circle
                                className="ring-fg sage"
                                cx="40"
                                cy="40"
                                r="32"
                                transform="rotate(-90 40 40)"
                                style={{ strokeDashoffset: 106.6 }}
                              />
                            </svg>
                            <span className="ring-val mono">47%</span>
                            <span className="ring-lab">Session</span>
                            <span className="ring-sub mono">2h 47m</span>
                          </div>
                          <div className="ring">
                            <svg viewBox="0 0 80 80">
                              <circle
                                className="ring-bg"
                                cx="40"
                                cy="40"
                                r="32"
                              />
                              <circle
                                className="ring-fg accentstroke"
                                cx="40"
                                cy="40"
                                r="32"
                                transform="rotate(-90 40 40)"
                                style={{ strokeDashoffset: 64.3 }}
                              />
                            </svg>
                            <span className="ring-val mono">68%</span>
                            <span className="ring-lab">Week</span>
                            <span className="ring-sub mono">3d 6h</span>
                          </div>
                        </div>
                      </div>
                      <div className="panel">
                        <div className="panel-h between">
                          <span>Activity</span>
                          <span className="mono muted2">May to Jul</span>
                        </div>
                        <div
                          className="heatmap"
                          data-rows="7"
                          data-cols="16"
                          aria-hidden="true"
                        ></div>
                      </div>
                    </div>

                    <div className="np">
                      <span className="np-art" data-art=""></span>
                      <div className="np-meta">
                        <div className="np-title sensitive" data-title="">
                          Weightless
                        </div>
                        <div className="np-artist sensitive" data-artist="">
                          Marconi Union
                        </div>
                        <div className="np-bar">
                          <span data-progress=""></span>
                        </div>
                      </div>
                      <div className="np-ctrl">
                        <span>⏮</span>
                        <span className="np-play">❚❚</span>
                        <span>⏭</span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
              <p className="fine center">
                The Home panel, running live. Click Presenter to blur the
                numbers.
              </p>
            </div>
          </div>
        </section>

        <section className="page pitch">
          <div className="pitch-grid">
            <p className="eyebrow">The pitch</p>
            <div>
              <h2>
                Twelve menu bar utilities' worth of tools. One native app.
              </h2>
              <p className="muted big">
                Every feature in Edith is normally its own app. We built the
                whole shelf into a single native binary that idles at twenty-two
                megabytes.
              </p>
            </div>
          </div>
        </section>

        <section id="features" className="page replaces">
          <div className="table">
            <div className="tr th">
              <span>The feature</span>
              <span>What you get in Edith</span>
            </div>
            <div className="tr">
              <span className="feat">AI usage &amp; rate limits</span>
              <span className="inc">
                Claude and Codex rings with live countdowns
              </span>
            </div>
            <div className="tr">
              <span className="feat">Menu bar stats</span>
              <span className="inc">
                Session and weekly %, tinted by a risk model
              </span>
            </div>
            <div className="tr">
              <span className="feat">Usage alerts</span>
              <span className="inc">
                Threshold, ahead-of-pace, burn, back-to-green, pre-reset
              </span>
            </div>
            <div className="tr">
              <span className="feat">Analytics dashboard</span>
              <span className="inc">
                KPIs, per-day and per-model charts, sortable table
              </span>
            </div>
            <div className="tr">
              <span className="feat">Spend heatmap</span>
              <span className="inc">
                GitHub-style daily calendar across your full history
              </span>
            </div>
            <div className="tr">
              <span className="feat">Music player</span>
              <span className="inc">
                Thumbnails, drag-to-seek, fades, auto-advance, media keys
              </span>
            </div>
            <div className="tr">
              <span className="feat">Clipboard history</span>
              <span className="inc">
                Everything you copied, instant paste on a hotkey
              </span>
            </div>
            <div className="tr">
              <span className="feat">Color picker</span>
              <span className="inc">
                System loupe on a hotkey, sampled hex to your clipboard
              </span>
            </div>
            <div className="tr">
              <span className="feat">Focus &amp; system utilities</span>
              <span className="inc">
                Focus dim, prevent-sleep, keyboard-clean lock, notch shelf
              </span>
            </div>
            <div className="tr">
              <span className="feat">Mic mute</span>
              <span className="inc">
                Every microphone muted system-wide on one hotkey
              </span>
            </div>
            <div className="tr">
              <span className="feat">Per-app volume</span>
              <span className="inc">
                Set each app's volume independently from the panel
              </span>
            </div>
            <div className="tr">
              <span className="feat">Disk cleaner</span>
              <span className="inc">
                Junk scanner for build caches, package managers, and logs
              </span>
            </div>
          </div>
        </section>

        <section id="film" className="page film">
          <div className="film-head">
            <p className="eyebrow">The film</p>
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

        <section className="feature">
          <div className="page feature-inner">
            <div className="feature-copy">
              <p className="eyebrow">Rate limits</p>
              <h3>Live rings for session and week.</h3>
              <p className="muted big">
                Second-by-second countdowns to your next 5-hour session reset
                and to the weekly rollover, for Claude and Codex alike. A
                24-hour spark shows the shape of your day at a glance.
              </p>
            </div>
            <div className="feature-media">
              <div className="card">
                <div className="panel-h between">
                  <span>Rate limits</span>
                  <span className="mono muted2">session, weekly</span>
                </div>
                <div className="rings big">
                  <div className="ring">
                    <svg viewBox="0 0 96 96">
                      <circle className="ring-bg" cx="48" cy="48" r="38" />
                      <circle
                        className="ring-fg sage"
                        cx="48"
                        cy="48"
                        r="38"
                        transform="rotate(-90 48 48)"
                        style={{ strokeDashoffset: 126.5 }}
                      />
                    </svg>
                    <span className="ring-val mono">47%</span>
                    <span className="ring-lab">Session (5h)</span>
                    <span className="ring-sub mono">resets 2h 47m</span>
                  </div>
                  <div className="ring">
                    <svg viewBox="0 0 96 96">
                      <circle className="ring-bg" cx="48" cy="48" r="38" />
                      <circle
                        className="ring-fg accentstroke"
                        cx="48"
                        cy="48"
                        r="38"
                        transform="rotate(-90 48 48)"
                        style={{ strokeDashoffset: 76.4 }}
                      />
                    </svg>
                    <span className="ring-val mono">68%</span>
                    <span className="ring-lab">Weekly</span>
                    <span className="ring-sub mono">resets 3d 6h</span>
                  </div>
                </div>
                <div className="spark" data-spark=""></div>
                <div className="mono muted2 center small">24-hour spark</div>
              </div>
            </div>
          </div>
        </section>

        <section className="feature">
          <div className="page feature-inner reverse">
            <div className="feature-copy">
              <p className="eyebrow">Codex</p>
              <h3>Claude and Codex, side by side.</h3>
              <p className="muted big">
                Edith tracks both agents. Switch the rate-limit rings between
                providers, filter the dashboard by source, and see Codex chats
                right in the project drilldown next to your Claude sessions.
              </p>
            </div>
            <div className="feature-media">
              <div className="card">
                <div className="panel-h between">
                  <span>Providers</span>
                  <span className="mono muted2">both tracked</span>
                </div>
                <div className="providers">
                  <div className="provider">
                    <span className="provider-name">Claude</span>
                    <span className="mono">
                      47% <span className="muted2">session</span>
                    </span>
                    <span className="mono">
                      68% <span className="muted2">week</span>
                    </span>
                  </div>
                  <div className="provider">
                    <span className="provider-name">Codex</span>
                    <span className="mono">
                      12% <span className="muted2">session</span>
                    </span>
                    <span className="mono">
                      31% <span className="muted2">week</span>
                    </span>
                  </div>
                </div>
                <p className="center muted small">
                  Toggle either provider off in Settings and its polling stops
                  entirely.
                </p>
              </div>
            </div>
          </div>
        </section>

        <section className="feature">
          <div className="page feature-inner">
            <div className="feature-copy">
              <p className="eyebrow">Menu bar</p>
              <h3>Two numbers in your menu bar.</h3>
              <p className="muted big">
                Session and weekly percentages, tinted by a time-aware risk
                model. Green when you have room. Amber when you're close. Red
                when the next prompt could push you over.
              </p>
            </div>
            <div className="feature-media">
              <div className="card">
                <div className="menubar mono">
                  <span>
                    <span className="sage">38%</span>{" "}
                    <span className="muted2">·</span>{" "}
                    <span className="accent">62%</span>
                  </span>
                  <span className="muted2">Wed 14:22</span>
                </div>
                <div className="risk">
                  <span className="risk-item">
                    <i className="dot sage-bg"></i>Safe
                  </span>
                  <span className="risk-item">
                    <i className="dot accent-bg"></i>Close
                  </span>
                  <span className="risk-item">
                    <i className="dot danger-bg"></i>Over
                  </span>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className="feature">
          <div className="page feature-inner reverse">
            <div className="feature-copy">
              <p className="eyebrow">Notifications</p>
              <h3>Alerts that stay out of your way.</h3>
              <p className="muted big">
                Threshold, ahead-of-pace, burn, back-to-green, and pre-reset.
                All optional. A single button sends a test notification and
                reports back exactly why it did or didn't fire.
              </p>
            </div>
            <div className="feature-media">
              <div className="notifs">
                <div className="notif">
                  <span className="notif-ic"></span>
                  <div className="notif-b">
                    <div className="notif-h">
                      <b>Ahead of pace</b>
                      <span className="mono muted2">Edith · now</span>
                    </div>
                    <p>
                      You're using this session faster than usual. 72% with 2h
                      47m left.
                    </p>
                  </div>
                  <i className="dot accent-bg glow"></i>
                </div>
                <div className="notif">
                  <span className="notif-ic"></span>
                  <div className="notif-b">
                    <div className="notif-h">
                      <b>Approaching weekly limit</b>
                      <span className="mono muted2">Edith · now</span>
                    </div>
                    <p>Week usage at 85%. Resets Sunday 4:00 PM.</p>
                  </div>
                  <i className="dot danger-bg glow"></i>
                </div>
                <div className="notif">
                  <span className="notif-ic"></span>
                  <div className="notif-b">
                    <div className="notif-h">
                      <b>Back in the green</b>
                      <span className="mono muted2">Edith · now</span>
                    </div>
                    <p>Session dropped below 60%. Room to keep going.</p>
                  </div>
                  <i className="dot sage-bg glow"></i>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className="feature">
          <div className="page feature-inner">
            <div className="feature-copy">
              <p className="eyebrow">Heatmap</p>
              <h3>A year of usage at a glance.</h3>
              <p className="muted big">
                A GitHub-style calendar of daily spend across your full history.
                Every day is a square, shaded by how much you spent. Hover any
                square for the exact number.
              </p>
            </div>
            <div className="feature-media">
              <div className="card">
                <div className="panel-h between">
                  <span>Activity</span>
                  <span className="mono muted2">$1,284 · 13 weeks</span>
                </div>
                <div className="heat-months mono muted2">
                  <span>May</span>
                  <span className="center">Jun</span>
                  <span className="right">Jul</span>
                </div>
                <div
                  className="heatmap"
                  data-rows="7"
                  data-cols="20"
                  aria-hidden="true"
                ></div>
                <div className="heat-legend mono muted2">
                  Less<i className="hl l0"></i>
                  <i className="hl l1"></i>
                  <i className="hl l2"></i>
                  <i className="hl l3"></i>
                  <i className="hl l4"></i>More
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className="feature">
          <div className="page feature-inner reverse">
            <div className="feature-copy">
              <p className="eyebrow">Music</p>
              <h3>Your local music folder, done right.</h3>
              <p className="muted big">
                Cover thumbnails, drag-to-seek, crossfades, auto-advance, and
                media keys. Point it at a folder and press play. No cloud, no
                accounts, no ads.
              </p>
            </div>
            <div className="feature-media">
              <div className="card">
                <div className="np np-plain">
                  <span className="np-art static-art"></span>
                  <div className="np-meta">
                    <div className="np-title">Weightless</div>
                    <div className="np-artist">Marconi Union</div>
                    <div className="np-bar">
                      <span style={{ width: "42%" }}></span>
                    </div>
                    <div className="np-times mono muted2">
                      <span>2:38</span>
                      <span>-3:34</span>
                    </div>
                  </div>
                </div>
                <div className="track-list">
                  <div className="track">
                    <span className="track-art a1"></span>
                    <span className="track-name">Clair de Lune · Debussy</span>
                    <span className="mono muted2">5:02</span>
                  </div>
                  <div className="track">
                    <span className="track-art a2"></span>
                    <span className="track-name">Time · Hans Zimmer</span>
                    <span className="mono muted2">4:35</span>
                  </div>
                  <div className="track">
                    <span className="track-art a3"></span>
                    <span className="track-name">Intro · The xx</span>
                    <span className="mono muted2">2:07</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className="feature">
          <div className="page feature-inner">
            <div className="feature-copy">
              <p className="eyebrow">Privacy</p>
              <h3>Presenter mode for the room.</h3>
              <p className="muted big">
                One toggle blurs spend figures and track names so you can
                screen-share without exposing your bill. Watch it flip below.
                Usage stays local, with optional iCloud backup that merges
                across your machines.
              </p>
            </div>
            <div className="feature-media">
              <div className="card" data-presenter-demo="">
                <div className="panel-h between">
                  <span>Usage</span>
                  <span className="pbadge" data-pbadge="">
                    Presenter on
                  </span>
                </div>
                <div className="kpis4">
                  <div className="kpi">
                    <div className="kpi-l">Cost this cycle</div>
                    <div className="kpi-v mono psens">$3.8k</div>
                  </div>
                  <div className="kpi">
                    <div className="kpi-l">Tokens</div>
                    <div className="kpi-v mono psens">5.19B</div>
                  </div>
                  <div className="kpi">
                    <div className="kpi-l">Cache hit</div>
                    <div className="kpi-v mono">99.5%</div>
                  </div>
                  <div className="kpi">
                    <div className="kpi-l">Top model</div>
                    <div className="kpi-v mono">opus-4-8</div>
                  </div>
                </div>
                <p className="center muted small" data-pnote="">
                  Spend and track names hidden for the room.
                </p>
              </div>
            </div>
          </div>
        </section>

        <section className="feature">
          <div className="page feature-inner reverse">
            <div className="feature-copy">
              <p className="eyebrow">System</p>
              <h3>Prevent sleep. Lock the keyboard.</h3>
              <p className="muted big">
                Keep your Mac awake for a long build, even with the lid closed
                on power. Lock the keyboard to wipe it down without triggering
                shortcuts. Auto-restores in sixty seconds so you can't lock
                yourself out.
              </p>
            </div>
            <div className="feature-media">
              <div className="card">
                <div className="panel-h">Quick actions</div>
                <div className="qa qa3">
                  <span className="qa-tile">
                    <span className="qa-ic">⌨</span>
                    <span>Clean keys</span>
                    <small>Lock the keyboard to wipe it</small>
                  </span>
                  <span className="qa-tile on">
                    <span className="qa-ic">☾</span>
                    <span>Keep awake</span>
                    <small>Stop this Mac from sleeping</small>
                  </span>
                  <span className="qa-tile">
                    <span className="qa-ic">◍</span>
                    <span>Presenter</span>
                    <small>Blur sensitive values</small>
                  </span>
                </div>
                <div className="sys-note">
                  <span className="lock">🔒</span>Keyboard relocks for 60s, then
                  restores itself. No way to get stuck.
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className="page more">
          <div className="more-head">
            <p className="eyebrow">And the rest of the shelf</p>
            <h2>Everything else you'd otherwise install one by one.</h2>
          </div>
          <div className="more-grid">
            <div className="mcard">
              <div className="mviz">
                <span className="vloupe"></span>
                <span className="vchip mono accent">#F5A623</span>
              </div>
              <h4>Color picker</h4>
              <p>
                A system loupe on a hotkey. Sample any pixel and the hex lands
                on your clipboard.
              </p>
            </div>
            <div className="mcard">
              <div className="mviz viz-stack">
                <span className="vwin dimmed"></span>
                <span className="vwin lit"></span>
              </div>
              <h4>Focus dim</h4>
              <p>
                Dims everything behind your active app so one window is all you
                see.
              </p>
            </div>
            <div className="mcard">
              <div className="mviz viz-col">
                <span className="vnotch"></span>
                <span className="vfiles">
                  <span className="vfile"></span>
                  <span className="vfile"></span>
                  <span className="vfile"></span>
                </span>
              </div>
              <h4>Notch shelf</h4>
              <p>
                Park files under the notch mid-drag, then drop them wherever
                they belong.
              </p>
            </div>
            <div className="mcard">
              <div className="mviz viz-col">
                <span className="vrow on">
                  <span className="vtext w60"></span>
                  <span className="vkey">⌘V</span>
                </span>
                <span className="vrow">
                  <span className="vtext w80"></span>
                </span>
                <span className="vrow">
                  <span className="vtext w40"></span>
                </span>
              </div>
              <h4>Clipboard history</h4>
              <p>
                Everything you copied, one shortcut away, with instant paste.
              </p>
            </div>
            <div className="mcard">
              <div className="mviz viz-col">
                <span className="vrow">
                  <i className="dot accent-bg"></i>
                  <span className="vlabel">10:00 Standup</span>
                  <span className="vchip accent">Join</span>
                </span>
                <span className="vrow">
                  <i className="dot sage-bg"></i>
                  <span className="vlabel">1:30 Design review</span>
                </span>
              </div>
              <h4>Calendar</h4>
              <p>
                Today's schedule in the panel and the app, with one-tap join
                links.
              </p>
            </div>
            <div className="mcard">
              <div className="mviz">
                <span className="vchip mono">SF 11:59</span>
                <span className="vchip mono">NY 2:29</span>
                <span className="vchip mono">LDN 7:29</span>
              </div>
              <h4>World clocks</h4>
              <p>Local time plus the offices you care about, at a glance.</p>
            </div>
            <div className="mcard">
              <div className="mviz">
                <span className="vkey big">⌥</span>
                <span className="vkey big">⌘</span>
                <span className="vkey big">E</span>
              </div>
              <h4>Global shortcut</h4>
              <p>
                Toggle the panel from anywhere. Defaults to Option-Command-E and
                re-records to taste.
              </p>
            </div>
            <div className="mcard">
              <div className="mviz">
                <span className="vlock"></span>
                <span className="vlabel">Stays on this Mac</span>
              </div>
              <h4>Local first</h4>
              <p>
                Usage never leaves your Mac. Optional iCloud backup merges
                across machines.
              </p>
            </div>
            <div className="mcard">
              <div className="mviz">
                <span className="vmic"></span>
                <span className="vchip">
                  <i className="dot danger-bg"></i>All mics muted
                </span>
              </div>
              <h4>Mic mute</h4>
              <p>
                Every microphone muted system-wide with one hotkey. The menu bar
                shows when you're safe.
              </p>
            </div>
            <div className="mcard">
              <div className="mviz viz-col">
                <span className="vrow">
                  <span className="vlabel vw">Safari</span>
                  <span className="vbar">
                    <i style={{ width: "35%" }}></i>
                  </span>
                </span>
                <span className="vrow">
                  <span className="vlabel vw">Music</span>
                  <span className="vbar">
                    <i style={{ width: "80%" }}></i>
                  </span>
                </span>
                <span className="vrow">
                  <span className="vlabel vw">Zoom</span>
                  <span className="vbar">
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
            <div className="mcard">
              <div className="mviz viz-col">
                <span className="vnotch"></span>
                <span className="vchip">
                  <i className="dot sage-bg"></i>AirPods connected
                </span>
              </div>
              <h4>Notch alerts</h4>
              <p>
                Bluetooth, audio-output, and charger changes surface as small
                notices around the notch.
              </p>
            </div>
            <div className="mcard">
              <div className="mviz">
                <span className="vmenubar mono">
                  CPU 3% · 6.2 GB<span className="vtime">Wed 14:22</span>
                </span>
              </div>
              <h4>CPU &amp; memory readout</h4>
              <p>
                Live stats in the menu bar, so a runaway process never sneaks up
                on you.
              </p>
            </div>
            <div className="mcard">
              <div className="mviz viz-col">
                <span className="vrow">
                  <span className="vlabel">Build caches</span>
                  <span className="vchip mono">8.2 GB</span>
                </span>
                <span className="vrow">
                  <span className="vbar">
                    <i style={{ width: "64%" }}></i>
                  </span>
                  <span className="vlabel mono">12.4 GB found</span>
                </span>
              </div>
              <h4>Junk cleaner</h4>
              <p>
                Scan build caches, package managers, and old logs. Reclaim
                gigabytes, restorable from the Trash.
              </p>
            </div>
            <div className="mcard">
              <div className="mviz viz-col">
                <span className="vrow">
                  <span className="vlabel">Chrome</span>
                  <span className="vchip mono">42%</span>
                  <span className="vquit">✕</span>
                </span>
                <span className="vrow">
                  <span className="vlabel">node</span>
                  <span className="vchip mono">31%</span>
                  <span className="vquit">✕</span>
                </span>
              </div>
              <h4>Running apps</h4>
              <p>
                Sort every open app by CPU or memory and quit the heavy ones in
                a click.
              </p>
            </div>
            <div className="mcard">
              <div className="mviz viz-col">
                <span className="vchip mono vurl">
                  youtube.com/watch?v=dQw4…
                </span>
                <span className="vrow">
                  <span className="vbar">
                    <i style={{ width: "64%" }}></i>
                  </span>
                  <span className="vlabel mono">64%</span>
                </span>
              </div>
              <h4>YouTube audio</h4>
              <p>
                Paste links, get tagged audio files straight into your music
                folder, with live progress.
              </p>
            </div>
            <div className="mcard">
              <div className="mviz viz-col">
                <span className="vrow">
                  <span className="vlabel">▸ edith</span>
                  <span className="vchip mono">$412</span>
                </span>
                <span className="vrow indent">
                  <span className="vlabel">notch-motion</span>
                  <span className="vchip mono">$268</span>
                </span>
              </div>
              <h4>Project drilldown</h4>
              <p>
                Spend by project, worktree, and chat, across Claude and Codex,
                so you know which repo eats the budget.
              </p>
            </div>
            <div className="mcard">
              <div className="mviz viz-col">
                <span className="vrow">
                  <i className="dot sage-bg"></i>
                  <span className="vlabel">Spotify · Weightless</span>
                </span>
                <span className="vrow">
                  <span className="vbar">
                    <i style={{ width: "42%" }}></i>
                  </span>
                  <span className="vlabel mono">-3:34</span>
                </span>
              </div>
              <h4>Spotify &amp; Apple Music</h4>
              <p>
                Whatever is already playing shows up in the player with full
                controls, next to your local library.
              </p>
            </div>
            <div className="mcard">
              <div className="mviz">
                <span className="vcam">
                  <span className="vface"></span>
                  <span className="vswitch">⟳</span>
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

        <section id="performance" className="page perf">
          <div className="perf-grid">
            <div>
              <p className="eyebrow">24/7, quietly</p>
              <h2>Built to sit in your menu bar forever.</h2>
              <p className="muted big">
                Native SwiftUI, not Electron. Work stops when it isn't seen.
                Disabling a tab tears down its timers and background jobs.
                Per-frame UI only redraws while the panel is open.
              </p>
              <p className="fine">
                Measured on Apple M4 Pro. CPU as a share of one core, memory as
                physical footprint.
              </p>
            </div>
            <div className="table perf-table">
              <div className="tr th perf-tr">
                <span>State</span>
                <span className="right">CPU</span>
                <span className="right">Memory</span>
              </div>
              <div className="tr perf-tr">
                <span>Idle, panel closed</span>
                <span className="right mono">~0%</span>
                <span className="right mono">~22 MB</span>
              </div>
              <div className="tr perf-tr">
                <span>Music playing, panel closed</span>
                <span className="right mono">~1%</span>
                <span className="right mono">~40 MB</span>
              </div>
              <div className="tr perf-tr">
                <span>Paused</span>
                <span className="right mono">&lt;1%</span>
                <span className="right mono">~40 MB</span>
              </div>
            </div>
          </div>
        </section>

        <section className="page local">
          <p className="eyebrow">Local first</p>
          <h2>Your usage never leaves your Mac.</h2>
          <p className="muted big center-narrow">
            No account. No telemetry. Optional iCloud backup merges cleanly
            across machines so your history follows you between a MacBook and a
            Mac mini.
          </p>
        </section>

        <section id="download" className="page download">
          <h2>Try Edith on your Mac.</h2>
          <a href="/api/v1/download/installer" className="btn btn-accent">
            <svg className="apple" viewBox="0 0 24 24" aria-hidden="true">
              <path d="M16.365 1.43c0 1.14-.42 2.23-1.24 3.05-.83.83-2.19 1.45-3.31 1.36-.14-1.1.43-2.24 1.2-2.98.85-.83 2.32-1.42 3.35-1.43zM20.5 17.29c-.57 1.31-.85 1.9-1.59 3.06-1.03 1.61-2.48 3.62-4.28 3.63-1.6.01-2.01-1.05-4.18-1.04-2.17.01-2.62 1.06-4.22 1.05-1.8-.02-3.18-1.83-4.21-3.44C-.36 16.72-1.02 10.6 2.87 8.4c1.4-.8 2.86-1.24 4.24-1.26 1.61-.03 3.13 1.09 4.19 1.09 1.05 0 2.87-1.35 4.85-1.15.83.03 3.16.33 4.66 2.52-.12.08-2.78 1.62-2.75 4.82.03 3.83 3.36 5.1 3.4 5.11-.03.09-.53 1.82-1.96 3.76z" />
            </svg>
            Download for macOS
          </a>
          <p className="fine">Requires macOS. Apple Silicon and Intel.</p>
        </section>
      </main>

      <footer className="footer">
        <div className="page footer-inner">
          <div className="brand">
            <img
              src="/app-icon-512.png"
              alt="Edith app icon"
              width="28"
              height="28"
              className="brand-icon"
            />
            <span className="muted small">Edith. Made for macOS.</span>
          </div>
          <div className="footer-links">
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
