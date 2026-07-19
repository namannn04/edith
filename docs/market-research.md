# Market Research — Paid macOS Productivity Apps (July 2026)

Feature-idea catalog for Edith. Five research passes across ~30 utility categories, ~160 apps. Prices pulled from official pricing pages as of July 2026 where possible; `~` means unverified/approximate — spot-check before quoting in marketing. **SUB** marks subscription-only or subscription-first apps: the best "replace this subscription" targets for Edith's pitch.

## Where Edith stands today

Agent usage + rate-limit tracking (rings, menu bar readout, smart notifications, analytics dashboard, heatmap), local music player + YouTube audio downloader, clipboard history, color picker, notch file shelf, focus dim, presenter mode with auto screen-share detection, keep awake, keyboard-cleaning lock, calendar with join links, world clocks, iCloud backup. $50 one-time, positioned against ~$56/mo of separate utilities.

---

## 1. The idea bank

Every buildable idea from the research, one line each. Effort: **S** (days), **M** (1–3 weeks), **L** (a month+). Details and sources are in the category catalogs below.

### Notch and menu bar

- **Claude-usage notch live activity** — progress ring hugging the notch while an agent runs, banner when the rate window resets. No competitor does this; fuses Edith's flagship with its notch real estate. (M)
- **HUD replacement** — volume/brightness/keyboard-backlight popups rendered around the notch. Table stakes in every paid notch app (Alcove, MediaMate, NotchNook). (M)
- **Now-playing island** — Edith's own player plus system media via waveform, in the notch. (M)
- **Dynamic-island alerts** — AirPods connected, charger plugged/unplugged, low battery, screen-recording indicator. (M)
- **Calendar peek + camera mirror in the notch** — Edith already owns both data sources. (S–M)
- **Floating-island mode** — same shelf/HUD surface on notchless and external displays (NotchNook, Seam do this). (M)
- **Menu bar icon manager** — hide/show with trigger rules (reveal battery icon under 20%, hide all on screen share). Bartender's stickiest feature; Bartender is $20 + $15/yr Pro and trust-damaged, Ice is dormant. (L)
- **Unread-badge counts** — chosen apps' Dock badges mirrored in menu bar/notch (Badgeify, $9/yr). (M)

### Files and shelf

- **Post-drop shelf actions** — convert/resize images, zip, PDF merge, rename by pattern (Dropover $7, FilePane). (M)
- **Shelf → shareable link** — upload to iCloud/S3/BYO bucket, link on clipboard (Dropover's most-loved paid feature; CleanShot Cloud charges $8/mo). (M)
- **AirDrop drop zone + Send to iPhone** in the shelf (Boring Notch ships AirDrop). (S)
- **Shake-mouse-to-summon floating shelf** (Dropover's signature gesture). (S)
- **Watched-folder auto-sort rules** — Hazel-lite for Downloads: move/rename/tag by pattern (Hazel $42). (L)
- **Drag app to shelf → full uninstall** with leftover sweep (Pearcleaner free, CleanMyMac $40/yr). (M)

### Capture and recording

- **Screenshots with auto-beautify** — padding, gradient background, social presets, drop to shelf (CleanShot X $29, Xnapper $15, Shottr $8). (M)
- **Auto-redaction** — Vision/regex blur of emails, API keys, IBANs before sharing; pairs with presenter mode (Xnapper). (M)
- **Pin screenshot as floating overlay** — always-on-top reference panel (CleanShot X). (S)
- **OCR hotkey** — drag box → text on clipboard, QR decode, copy-table-as-TSV (TextSniper $8; Apple Live Text is the free floor, speed is the paid wedge). (S)
- **Screen recorder with auto-zoom** — click-triggered zoom + cursor smoothing + webcam bubble (Screen Studio moved to $29/mo; CursorClip $59, ScreenBuddy $30 prove the counter-market). (L)
- **Quick GIF/MP4 area recording** straight to the shelf with trim. (M)
- **Presenter suite toggle** — cursor halo, click ripples, keystroke HUD, screen draw with auto-erase; auto-enabled when presenter mode detects Zoom/Meet/recording. Replaces Presentify + Mouseposé ($10/yr) + KeyCastr + Cursor Pro at once. (M)

### Audio and mic

- **Per-app volume mixer + output routing** — macOS's most famous missing feature (SoundSource $49; CoreAudio process taps on macOS 14.4+ make this feasible now). (L)
- **Global mic mute + push-to-talk** — hotkey, menu bar/notch mute indicator (Mic Drop $5, Shush $5; Krisp charges $96/yr). (S)
- **Mic/camera in-use indicator + log** — complements presenter mode (Micro Snitch $3.99, OverSight free). (S)
- **Bluetooth battery roster** — AirPods/Magic devices/iPhone with low-battery alerts (AirBuddy $9.99 — development quiet; Batteries $8.99). (M)
- **Ambient sound mixer** — bundled loops + synthesized white/pink/brown noise on AVAudioEngine inside the music module; auto-fade with focus sessions (Noizio ~$10; Endel $99/yr and Brain.fm $70/yr are the subscription targets). (M)

### Windows and display

- **Window snapping** — hotkey + drag-edge halves/quarters/thirds via AX API; table stakes, note macOS Tahoe native tiling covers basics (Magnet $5, Rectangle Pro $10). (M)
- **Saved window layouts** — capture arrangements, auto-restore per display configuration on dock/undock. The single most-praised paid feature in the category (Moom $15, MacLayout). (M–L)
- **Fuzzy window switcher** — type 3 letters, Enter; ScreenCaptureKit thumbnails (Contexts $10 is stagnant, AltTab has Tahoe wobbles). (M)
- **External-monitor DDC control** — brightness/volume/input sliders in menu bar (Lunar $23, DisplayBuddy $19+, BetterDisplay $22). (M)
- **XDR brightness unlock** — gamma-table trick, one toggle (Vivid €20, BrightIntosh $1.99). (S)
- **Meeting layout automation** — auto-apply a window layout + display preset when joining a call from Edith's calendar. Nobody has this tie-in. (M)
- **Focus-dim parity upgrades** — per-display intensity, animated fade, AppleScript/Shortcuts hooks (HazeOver $4.99). (S)

### Input, text, and clipboard

- **Hyper key** — Caps Lock → ⌃⌥⌘⇧ (Hyperkey free, Superkey ~$15; tiny build, iconic feature). (S)
- **Menu-item command palette** — ⇧⌘P fuzzy-search of the frontmost app's menus (Paletro $10). (M)
- **Text expansion** — abbreviations with {date}, {clipboard}, {cursor}, fill-in forms, layered on clipboard pins; CGEvent paste plumbing already exists (TextExpander $40/yr is the most-resented sub in the category; Typinator $30). (M)
- **Paste queue** — copy several items, ⌘V pastes them in order (CleanClip $13's hero feature, Paste $30/yr). (S)
- **Clipboard pinboards + smart lists** — named boards, saved filters by type/app/date, inline clip editing, link/color previews (Paste, PastePal $15, PasteNow). (M)
- **CloudKit sync** — clipboard/pins/snippets across Macs, "sync without the subscription" (Paste's main sub justification). (M)
- **Selection popup bar** — case convert, search, translate; smart detection: hex → color history, time → world-clock convert, unit/currency → convert (PopClip $15). (M)
- **:emoji: autocomplete** anywhere (Rocket $10 Pro). (M)
- **Scroll/mouse niceties** — per-device scroll direction, smooth scroll, middle-click emulation (Scroll Reverser, Mos free; Middle $6). (S)
- **Global command palette** — fuzzy-search every Edith feature + user quicklinks + inline calculator/unit/currency/timezone conversion; adaptive frecency ranking (Raycast Pro $96/yr, Monarch $30–39, Alfred ~$43). (L)

### Focus, time, and meetings

- **Focus sessions** — Pomodoro/52-17/Flowtime timers that engage focus dim, soft-block flagged apps (overlay nudge), set macOS Focus/DND, log to the existing heatmap (Session $40/yr, Focus $19–99, One Sec). (M)
- **Automatic local time tracking** — sample frontmost app + window title into per-app/project reports, folder-based project rules, idle detection, CSV export. The fattest subscription cluster (Timing $108+/yr, RescueTime ~$78/yr, Rize ~$120/yr) and a perfect privacy wedge. (L)
- **Unmissable meeting alert** — full-screen takeover 1–2 min before events with Join button (In Your Face charges $25/yr for exactly this). (S)
- **Copy-my-free-slots** — scan calendar gaps, emit formatted availability in the recipient's timezone via world clocks (poor-man's Fantastical Openings $57/yr / Vimcal $180/yr). (S–M)
- **Natural-language event/reminder entry** — NSDataDetector + EventKit quick-add (Fantastical's signature). (M)
- **Nagging reminders** — re-fire every N minutes until done (Due $10's whole product). (S)
- **Menu-bar current task** — One Thing-style text tied to the active focus session. (S)
- **Smart scratchpad** — notch/menu-bar notes with inline calc, unit/currency conversion, "timer 25" commands, auto-expiring notes, pin-from-clipboard (Antinote $5 is an r/macapps darling; Heynote blocks). (M)
- **Eye-strain breaks** — 20-20-20 reusing the focus-dim overlay; smart-pause during meetings/screen share via presenter detection (LookAway $15, DeskRest). (S–M)

### System, battery, and maintenance

- **Agent resource monitor** — per-process CPU/RAM for claude/node/bun with one-click kill of runaway agents. Nobody pairs system stats with AI workloads; unclaimed. (M)
- **System stats module** — CPU/RAM/network in Edith's ring language + threshold alerts (iStat Menus $12–29 vs free Stats). (M)
- **Battery health card** — cycle count, capacity trend, degradation alerts, multi-device battery (coconutBattery Plus $10, Batteries $9). Skip charge limiting: Sherlocked by Tahoe 26.4's native slider. (S–M)
- **App-update badge** — scan /Applications for Sparkle feeds + MAS receipts, "4 updates" in menu bar. MacUpdater died Jan 1 2026 because one-time pricing couldn't sustain a standalone updater — as one module of a $50 bundle the economics work. (M)
- **Dev-junk cleaner** — DerivedData, caches, stale node_modules, Docker images, sized and one-click purgeable; ideal for the AI-coder audience (CleanMyMac $40/yr is the most-escaped sub in Mac utilities). (M)
- **Disk-space view** — usage ring + top-10 space hogs (DaisyDisk $10). (M)
- **Bandwidth meter** — per-app top talkers next to the rate-limit brain. (M)
- **Link router** — set Edith as default browser, route by domain/source app (Slack links → work profile, localhost → dev browser), strip tracking params — also from clipboard history (Choosy $10, Velja $8, OpenIn $12). (M)

### AI, audience-native

- **Local dictation** — hold-to-talk WhisperKit into any text field; voice-prompt Claude Code. Dictation is the hottest Mac AI utility of 2025–26 (Wispr Flow $180/yr SUB is the target; superwhisper $249 lifetime, VoiceInk $25–40 prove the one-time counter-market). (L)
- **Select-text AI actions** — rewrite/summarize/translate via the user's own Claude key, BYO-key so no marginal cost (BoltAI ~$50, Alter, Xpop). (M)
- **Meeting notes, Granola-lite** — system audio + mic → local Whisper transcript → Claude summary, wired to calendar events (Granola $168/yr, bot-free is the 2025–26 breakout pattern). (L)
- **Clipboard/shelf MCP server** — expose pins, history, and shelf files to Claude Code and other agents locally (Paste shipped clipboard MCP June 2026; uniquely on-brand for Edith). (M)
- **Voice note → transcript on the shelf.** (S)

---

## 2. Catalog: windows, display, menu bar, switchers

### Window management

| App | Price (Jul '26) | Notes |
|---|---|---|
| [Magnet](https://magnet.crowdcafe.com) | $4.99 one-time | Mass-market snapper; drag-to-edge + hotkeys. Native Tahoe tiling eroded it. |
| [Rectangle Pro](https://rectangleapp.com/pro) | $9.99 one-time | Pinned layouts, app-specific snapping, edge stashing, iCloud sync. Free Rectangle is the floor. |
| [Moom 4](https://manytricks.com/moom/) | $15 one-time | Saved-layout king: capture arrangements, auto-restore per display config, palette on the zoom button. |
| [BetterSnapTool](https://folivora.ai) | $2.99 one-time | Cheap snapper, custom snap areas. |
| [Swish](https://highlyopinionated.co/swish/) | $16 one-time | Trackpad gestures on titlebars: swipe to snap/maximize/close, 30+ gestures. |
| [Loop](https://github.com/MrKai77/Loop) | Free OSS | Radial-menu window placement; the UI pattern worth copying. |
| [Lasso](https://thelasso.app) | €9.99 one-time | Keyboard/mouse grid overlay across displays. |
| [BetterStage](https://betterstage.app) | Freemium; $19.99+ lifetime | 2025–26 Stage Manager replacement: 9 named stages, per-monitor tiling modes, 15 snap zones. |
| [NeoTiler](https://getneotiler.com) | $9.99 lifetime | 2026 newcomer, keyboard + gesture tiling, anti-subscription marketing. |
| [MacTiler](https://mactiler.com) | $19.99 one-time | Newcomer, intelligent tiling + custom shortcuts. |
| [MacLayout](https://maclayout.com) | One-time (~) | Newcomer focused purely on save/restore layouts across monitor setups. |
| [Mosaic](https://lightpillar.com) | ~$12.99+ / Setapp | Drag-to-grid overlay, iPhone remote control. |
| Divvy / SizeUp / Stay | $13–15 one-time | Legacy grid/layout tools, mostly dormant; Stay's restore-on-monitor-change idea lives on in Moom. |
| AeroSpace / yabai / Amethyst | Free OSS | i3-style tiling for power users. |

Trend: Tahoe's native tiling killed basic snappers; paid apps differentiate on saved layouts, gestures, and named workspaces. Every 2025–26 entrant markets "one-time, no subscription" — bundling is Edith's edge here, not pricing.

### Display control

| App | Price (Jul '26) | Notes |
|---|---|---|
| [Lunar](https://lunar.fyi) | $23 one-time (Pro) | Reference monitor app: DDC control, ambient-light Sync Mode, sun-position dimming, sub-zero dim, XDR boost, per-app presets. |
| [Vivid](https://www.getvivid.app) | €20 one-time | Unlocks XDR 1000-nit brightness system-wide. |
| [BetterDisplay](https://betterdisplay.pro) | Freemium; $21.99 one-time Pro | HiDPI scaling, virtual displays, DDC, EDID overrides, PIP streaming of displays. |
| [DisplayBuddy](https://displaybuddy.app) | From $18.99 one-time | Menu-bar DDC sliders, presets, keyboard keys, smart-monitor support. |
| [MonitorControl](https://github.com/MonitorControl/MonitorControl) | Free OSS | DDC + native OSD; the free ceiling for basic control. |
| [BrightIntosh](https://brightintosh.de) | $1.99 one-time | Single-purpose XDR boost. |
| [MacBrightness](https://macbrightness.com) | $5 one-time | 2025–26 newcomer, XDR unlock with aggressive SEO. |

Trend: two sub-markets — XDR one-trick toggles ($2–20) and DDC control ($19–23), all one-time. Differentiators: ambient-light sync, presets, per-mode profiles.

### Menu bar managers

| App | Price (Jul '26) | Notes |
|---|---|---|
| [Bartender 6](https://www.macbartender.com) | $20 one-time + **Pro $15/yr SUB** ($80 lifetime) | Category leader, post-2024 ownership distrust. Base: hide/show + trigger-based reveal (battery %, Wi-Fi, screen share). Pro "Top Shelf" (May 2026) turns the notch into a widget peninsula: now-playing, weather, calendar with join button, 6-file shelf, visual clipboard carousel. |
| [Ice](https://icemenubar.app) | Free OSS | Was the free Bartender killer; development stalled Feb 2026 — churn opportunity. |
| Thaw | Free OSS | 2026 community fork of Ice for Tahoe + notch machines. |
| [Vanilla](https://matthewpalmer.net/vanilla/) | Free + $10 Pro | Simple hide-behind-arrow. |
| Barbee | $3.99 lifetime or $2.99/yr | Lifehacker's 2025 pick; auto-hide automation rules, offline-only. |
| [Badgeify](https://badgeify.app) | $9/yr SUB or $19 lifetime | Different angle: any app's unread badge in the menu bar. |
| [Spaced](https://sindresorhus.com/spaced) | Free | Menu bar separators/grouping. |

Trend: Bartender trust wobble + Ice dormancy + Tahoe's built-in icon hiding → survivors differentiate with triggers, automation, and notch UIs. Notch-as-Dynamic-Island is THE 2026 pattern, and Edith already owns a notch surface.

### App switchers and desktop organization

| App | Price (Jul '26) | Notes |
|---|---|---|
| [Contexts](https://contexts.co) | $9.99 one-time | Fuzzy-search window switcher; development stagnant — opening. |
| [Witch](https://manytricks.com/witch/) | $14 one-time | Window/tab-level switching, multiple custom switchers. |
| [rcmd](https://lowtechguys.com/rcmd/) | $12.99 (free tier + Pro IAP) | Right-⌘ + first letter to switch/launch/hide apps. |
| [AltTab](https://alt-tab-macos.netlify.app) | Free OSS | Windows-style previews; Tahoe compatibility wobbles in 2026. |
| [DockDoor](https://dockdoor.net) | Free OSS | Dock-hover window previews. |
| [Command-Tab Plus 2](https://noteifyapp.com/command-tab-plus/) | $14.99 one-time | Per-app hotkeys, badges, window mode. |
| [Manico](https://manico.im) | $15 one-time | Option-key app dock with number keys. |
| [DashPane](https://www.dashpane.pro) | $4.99 one-time | 2026 newcomer: Cmd-Tab replacement + fuzzy window search + edge sidebar. |
| [Mission Control Plus](https://www.fadel.io/missioncontrolplus) | $8.99 one-time | Close buttons + keyboard control in Mission Control. |
| [uBar](https://ubarapp.com) | $30 one-time | Windows-taskbar Dock replacement. |
| [DockFlow](https://dockflow.appitstudio.com) | €9.99/yr SUB or €39.99 lifetime | Dock presets per workflow, auto-switch on time/calendar/Focus mode. |
| [HazeOver](https://hazeover.com) | $4.99 | Dims all but front window — overlaps Edith's focus dim; extras: per-display intensity, fade animation, AppleScript hooks. |
| [Unclutter](https://unclutterapp.com) | $19.99–24 one-time | Pull-down desktop panel: files + notes + clipboard in one swipe. Charges $24 for a subset of what Edith has. |

Trend: free OSS owns visual switching; paid wins on speed and multi-mode bundles at $5–15. "Context/preset switching" triggered by Focus modes and calendars (DockFlow, BetterStage) is a natural Edith fit.

---

## 3. Catalog: capture, recording, audio, presentation

### Screenshots and annotation

| App | Price (Jul '26) | Notes |
|---|---|---|
| [CleanShot X](https://cleanshot.com) | $29 one-time + Cloud Pro $8/mo SUB | Category king: scrolling capture, OCR, GIF, pin-to-screen overlay, capture history tray, background/padding editor. |
| [Shottr](https://shottr.cc) | Freemium; Pro $8 one-time | Ultra-fast 2 MB native app: pixel rulers, color-distance sampling, OCR + QR decode, scrolling capture. |
| [Xnapper](https://xnapper.com) | $15 one-time | Beautiful-screenshot niche: auto-balance padding, gradient backgrounds, auto-redaction of emails/keys, social presets. |
| [Snagit](https://www.techsmith.com/snagit) | **$39/yr SUB-only since 2025** | Was perpetual; template step-guides, simplify/anonymize UI tool. Prime replacement target. |
| [Zight](https://zight.com) (ex-CloudApp) | SUB-only, ~$9–11/mo | Cloud capture links. |
| [ScreenSnap Pro](https://www.screensnap.pro) | $29 one-time | 2025 newcomer bundling screenshots + GIF + gradients + OCR, marketed against CleanShot's cloud sub. |
| [Screenotate](https://screenotate.com) | ~$29 one-time (~) | OCRs every screenshot + captures source window/URL metadata, searchable local history. |

### Screen recording

| App | Price (Jul '26) | Notes |
|---|---|---|
| [Screen Studio](https://screen.studio) | **$29/mo or $108/yr SUB**; $229 lifetime (1 yr updates) | Auto-zoom on click, cursor smoothing, motion blur, wallpaper backgrounds. Its 2025 price hike spawned a whole counter-market. |
| [ScreenFlow](https://www.telestream.net/screenflow/) | $169 one-time | Veteran recorder + timeline editor, still perpetual. |
| [Loom](https://www.loom.com) | SUB-only; Business $18/user/mo | Async video messages; free plan gutted post-Atlassian. |
| [Cap](https://cap.so) | OSS; desktop license $58 one-time; Pro ~$8/mo | Loom alternative, Instant vs Studio modes, self-hostable. |
| [Tella](https://www.tella.com) | SUB-only $13–19/mo | Browser/Mac recording + clip-based editing. |
| [Kap](https://getkap.co) / QuickRecorder | Free OSS | Simple menu-bar recorders; the free floor. |
| [CursorClip](https://cursorclip.com) | $59 one-time | Native "Screen Studio without the subscription": auto-zoom, cursor effects. |
| [ScreenBuddy](https://screenbuddy.xyz) | $29.99 one-time | Budget one-time Screen Studio alternative. |
| [FocuSee](https://focusee.imobie.com) | Sub from $8.95/mo + lifetime tier | Auto-editing recorder, cross-platform. |
| Rekort / SmoothCapture / Screen Charm / Matte / Reap | Various, mostly one-time | 2025–26 wave occupying the "one-time, native, auto-zoom" slot. |

Trend: incumbents subscription-ified (Snagit, Screen Studio, Loom, Apple's own Creator Studio Jan 2026) and a $15–60 one-time native counter-wave followed. Edith's pitch lands directly on this nerve.

### OCR and text extraction

| App | Price (Jul '26) | Notes |
|---|---|---|
| [TextSniper](https://textsniper.app) | $7.99 one-time | Hotkey → drag box → text on clipboard; QR/barcode, text-to-speech. The benchmark. |
| [Prizmo](https://creaceed.com/prizmo) | $79.99+ one-time or sub | Full document scanning, batch, searchable PDFs. |
| OwlOCR | Freemium; ~$10 Pro | Menu-bar OCR, batch, PDF OCR. |
| [TRex](https://github.com/amebalabs/TRex) | Free OSS | OCR with automation hooks. |

Trend: Apple Live Text commoditized basic OCR; paid tools survive on hotkey speed, batch, QR, structured output (tables), history, and staying offline.

### Audio control

| App | Price (Jul '26) | Notes |
|---|---|---|
| [SoundSource 6](https://rogueamoeba.com/soundsource/) | $49 one-time | Per-app volume, per-app output routing, per-app EQ from the menu bar. Gold standard; Apple still hasn't filled this hole. |
| [Audio Hijack](https://rogueamoeba.com/audiohijack/) | ~$77 one-time | Record/process any app's audio. Siblings: Loopback ~$109, Piezo ~$19, Airfoil ~$35. |
| [Boom 3D](https://www.globaldelight.com/boom/) | ~$20 one-time | Volume boost + 3D spatial + EQ presets. |
| [eqMac](https://eqmac.app) | Freemium; $40 lifetime Pro | System parametric EQ, per-app volume, headphone presets. |
| Sound Control | ~$38 one-time (~) | Per-app volume/EQ/routing mixer. |
| [Krisp](https://krisp.ai) | **SUB-only $8–15/mo** | AI noise cancellation + meeting notes. Top replacement target. |
| [Hush](https://hush.audio) | $49.99 one-time | On-device ML noise/reverb removal — "Krisp without the subscription." |
| [Background Music](https://github.com/kyrias/BackgroundMusic) | Free OSS | Per-app volume, auto-pause music. |
| [AirBuddy](https://airbuddy.app) | $9.99 one-time | AirPods popup, device battery roster, Magic Handoff. Development quiet — soft niche. |
| [ToothFairy](https://c-command.com/toothfairy/) | ~$5.99 one-time | One-click Bluetooth connect + hotkeys. |
| [Mic Drop](https://getmicdrop.com) / Shush | $4.99 one-time each | Global mic mute / push-to-talk. |

### Webcam and meeting tools

| App | Price (Jul '26) | Notes |
|---|---|---|
| [Camo](https://camo.com) | Freemium; $49.99/yr or $99.99 lifetime | iPhone/any camera as pro webcam: manual controls, overlays. Survived Continuity Camera by going pro. |
| [Hand Mirror](https://handmirror.app) | Free + Plus from $6.99 | One-click camera check in the menu bar; Plus adds sizes, pinning, capture. |
| [Bezel](https://nonstrict.eu/bezel/) | $29/yr or $99 lifetime | Mirror any iPhone on Mac with device frame; demo/dev favorite. |
| [Detail](https://detail.co) | **SUB $11.99/mo** | Multi-cam video studio + AI edits. |
| [Airtime Creator](https://www.airtime.com) (ex-mmhmm) | **SUB $10/mo**; Camera $20 one-time | Present inside your slides; branded camera looks. |
| FaceScreen | One-time (App Store) | Floating face/brand overlay for calls. |
| [In Your Face](https://www.inyourface.app) | $3.99/mo, $24.99/yr, or $69 one-time | Whole product = unmissable full-screen meeting alerts with join button. |

### Presentation and screencast aids

| App | Price (Jul '26) | Notes |
|---|---|---|
| [Presentify](https://presentifyapp.com) | ~$14.99 one-time (~) | Annotate anywhere, cursor halo, spotlight; auto-erase after N seconds is its most-loved detail. |
| [Mouseposé 4](https://boinx.com/mousepose/) | **$9.99/yr SUB** | The original cursor spotlight + keystroke display; now subscription — trivial to replace. |
| [KeyCastr](https://github.com/keycastr/keycastr) | Free OSS | Keystroke visualizer. |
| [Cursor Pro](https://appahead.studio/apps/cursor-pro/) | $7.99 one-time | Polished cursor halo + magnifier. |
| KeyScreen / ScreenBrush / Scribbble / Presenter Pointer | $5–15 one-time | Single-purpose overlay tools; nobody bundles them — that bundle is Edith-shaped. |
| [Klack](https://tryklack.com) | $4.99 one-time | Mechanical keyboard sounds system-wide. |

---

## 4. Catalog: launchers, text, automation, input, clipboard

### Launchers and command palettes

| App | Price (Jul '26) | Notes |
|---|---|---|
| [Raycast](https://www.raycast.com) | Free core; **Pro $96/yr SUB** (+$8/mo AI add-on) | Category king: launcher + clipboard + snippets + window management + 1,500 extensions; iOS/Windows in 2025. Pro: AI chat, cloud sync, themes, unlimited clipboard history. |
| [Alfred 5 Powerpack](https://www.alfredapp.com) | ~$43 one-time (£34); ~£59 lifetime | Drag-block Workflows, clipboard + snippets, file actions, folder-based sync. |
| [LaunchBar 6](https://www.obdev.at/products/launchbar/) | $29 one-time | Adaptive ranking that learns selections; send-to action chaining; perpetual nag trial. |
| [Monarch](https://www.monarchlauncher.com) | $30–39 one-time | 2025–26 privacy-first newcomer: launcher + calculator/converter + clipboard + notes + system controls, all local. Markets "software you own, not rent." |
| [SuperCmd](https://supercmd.sh) | Free OSS | "Open-source Raycast Pro" with Raycast-extension compatibility, local AI via Ollama. |
| Sol / [Brow](https://brow-app.com) | Free | OSS Spotlight replacements; Brow bundles 14 tools — same bundle thesis as Edith, free. |

Trend: Raycast subscription/account fatigue is actively spawning one-time and OSS alternatives; AI-in-the-launcher is table stakes now.

### Text expansion and snippets

| App | Price (Jul '26) | Notes |
|---|---|---|
| [TextExpander](https://textexpander.com) | **~$40/yr SUB-only** | Market leader: shared snippet groups, fill-in forms, inline search, stats. The most-complained-about pricing in the category. |
| [Typinator 10](https://ergonis.com/typinator) | $29.99 one-time (Mac-only tier) | Regex triggers, embedded scripts, quick-search popup, Apple Intelligence rewrites. |
| aText | ~$29.99 lifetime (~) | Budget king: rich text, scripts, date math. |
| [Espanso](https://espanso.org) | Free OSS | YAML config, forms, shell extensions, package hub. Developer favorite. |
| [Snippety](https://snippety.app) | $24.99 one-time (Mac+iOS) | Placeholders, templates, quick picker. |
| Rocket Typist / TypeFire | ~$20 one-time / free | Budget native expanders. |

### Automation

| App | Price (Jul '26) | Notes |
|---|---|---|
| [Keyboard Maestro](https://www.keyboardmaestro.com) | $36 one-time | Macro powerhouse: any trigger (hotkey, app, Wi-Fi, USB, time, folder), conditionals, UI scripting, conflict palettes. |
| [BetterTouchTool](https://folivora.ai) | ~$10 one-time (2 yr) / ~$25 lifetime | Absurd value: gestures, key remaps, window snapping, floating HUD menus, JS scripting. |
| [Hazel 6](https://www.noodlesoft.com) | $42 one-time | Watched-folder rules: auto-sort/rename/tag files, uninstall sweep, trash management. |
| [Dropzone 4](https://aptonic.com) | Freemium; Pro $1.99/mo (lifetime ~$35) | Drag files to an action grid: move, share, S3/FTP upload. Direct shelf competitor. |
| [Keysmith](https://www.keysmith.app) | $54 one-time (free 5 macros) | Records clicks/keystrokes into replayable UI macros. |
| [Bunch](https://bunchapp.co) | Free | Plain-text context launcher: open/close app sets per mode (writing, meeting). |
| Shortery | Freemium; small sub | Adds the triggers Apple forgot to Shortcuts: app launch, wake, Wi-Fi change, schedule. |
| [Supercharge](https://sindresorhus.com/supercharge) | $16 one-time | Sindre Sorhus's grab-bag of macOS quality-of-life tweaks, rapidly updated. |
| [Hammerspoon](https://www.hammerspoon.org) | Free OSS | Lua bridge to macOS APIs; the free power ceiling. |

### Keyboard productivity

| App | Price (Jul '26) | Notes |
|---|---|---|
| [Homerow](https://www.homerow.app) | $49.99 one-time (was ~$27 — pricing power) | Vimium for all of macOS: type 2-letter labels to click anything. |
| [Superkey](https://superkey.app) | ~$10–20 one-time | Type visible text to click it (OCR + AX); hyper-key bundled. |
| [Paletro](https://appmakes.io/paletro/) | ~$9.99 one-time | ⇧⌘P command palette for the frontmost app's menus. Small, beloved, very buildable. |
| [Leader Key](https://github.com/mikker/LeaderKey.app) | Free OSS | Vim-style leader sequences; r/macapps niche hit. |
| KeyClu / CheatSheet | Free | Hold ⌘ → shortcut cheat sheet overlay. |
| [Hyperkey](https://hyperkey.app) | Free | Caps Lock → hyper modifier; ubiquitous. |
| [Karabiner-Elements](https://karabiner-elements.pqrs.org) | Free OSS | Deep remapping baseline. |

### Mouse and trackpad

| App | Price (Jul '26) | Notes |
|---|---|---|
| [Mos](https://mos.caldis.me) / [LinearMouse](https://linearmouse.app) | Free OSS | Smooth scrolling, per-device acceleration/direction. |
| [BetterMouse](https://better-mouse.com) | ~$9.99 lifetime | Lightweight replacement for vendor mouse drivers. |
| [Mac Mouse Fix](https://macmousefix.com) | Few $ one-time | Trackpad-style gestures on a cheap mouse. |
| [Middle](https://middleclick.app) | ~$6 one-time | Middle-click via three-finger tap. |
| [Multitouch](https://multitouch.app) | ~$19.99 lifetime | Custom trackpad/Magic Mouse gestures → any action. |
| [Scroll Reverser](https://pilotmoon.com/scrollreverser/) | Free OSS | Separate scroll direction mouse vs trackpad. One checkbox, huge demand. |

### Selection popups and pickers

| App | Price (Jul '26) | Notes |
|---|---|---|
| [PopClip](https://www.popclip.app) | $14.99 one-time | iOS-style popup on text selection; moat = huge extension directory, JS/shell extension API. |
| [Rocket](https://matthewpalmer.net/rocket/) | Free; Pro $10 one-time | Slack-style :emoji: autocomplete anywhere. Still current (Emoji 17, Apr 2026). |
| PopChar | One-time / suite sub | Glyph picker with font search. |
| Xpop / OnText / Mutate | Free/new | 2025–26 clones whose hook is piping selections into an LLM. |

### Premium clipboard managers (features to absorb)

| App | Price (Jul '26) | Notes |
|---|---|---|
| [Paste](https://pasteapp.io) | **$29.99/yr SUB-first**; $89.99 lifetime | The flagship to undercut: iCloud sync, visual cards, pinboards, sequential multi-paste, per-app privacy, in-place editing, and clipboard MCP for AI tools (June 2026). |
| [PastePal](https://indiegoodies.com/pastepal) | $14.99 one-time | "Paste without the subscription": boards, iCloud sync, keyboard-first. |
| [CleanClip](https://cleanclip.cc) | $12.99 one-time | Paste Queue hero feature: copy five things, ⌘V pastes them in order. |
| [PasteNow](https://pastenow.app) | One-time (~$10–30) | Smart Lists (saved filters), exclusion rules, hex-color swatch previews. |
| Copy 'Em | ~$14.99 one-time | Paste stack, saved searches, transformations on paste, image OCR. |
| [Maccy](https://maccy.app) | Free OSS | The free baseline Edith must exceed: instant fuzzy search, pins. |

Trend: premium wedge = cross-device sync, boards/smart lists, paste queues, and (new in 2026) clipboard-as-AI-context. Subscription resentment is highest here.

---

## 5. Catalog: focus, time, calendar, notes, wellness, sound

### Focus, pomodoro, distraction blocking

| App | Price (Jul '26) | Notes |
|---|---|---|
| [Session](https://www.stayinsession.com) | ~$40/yr SUB-first | Pomodoro + blocking across devices; auto Slack status, intention in menu bar, analytics. |
| [Focus](https://heyfocus.com) | $19–99 one-time tiers | Hardcore Mode (can't quit), scheduled blocks, profiles. |
| [One Sec](https://one-sec.app) | $19.99/yr or $49.99 lifetime | Breathing-pause friction before opening flagged apps; intervention pattern worth copying. |
| [Freedom](https://freedom.to) | $39.99/yr or $99.50 forever | Cross-device blocking sync, locked mode. |
| [Cold Turkey](https://getcoldturkey.com) | $39 one-time | Nuclear blocker: frozen unquittable blocks, goal-based locks. |
| [Opal](https://www.opal.so) | **Pro $99.99/yr SUB** | Focus score, session difficulty levels, gamification. |
| [Hugo](https://www.tryhugo.app) | **Pro $99/yr SUB** | 2025–26 newcomer: AI watches tabs/apps vs your stated task, blocks off-task ones. |
| [Seam](https://getseam.app) | $19.90 one-time | **Direct Edith competitor**: notch Pomodoro + music + calendar + offline voice-to-text, island mode on external displays. |
| TomatoBar / Breaks | Free OSS | The free floor for timers. |

### Automatic time tracking (fattest subscription cluster)

| App | Price (Jul '26) | Notes |
|---|---|---|
| [Timing](https://timingapp.com) | **$108–264/yr SUB-only** | Mac-native automatic tracker: per-app/document/site, drag-to-assign timeline, AI day summaries. |
| [RescueTime](https://www.rescuetime.com) | **~$78–144/yr SUB-only** | Productivity pulse score, focus-session lockouts, weekly reports. |
| [Rize](https://rize.io) | **~$120–180/yr SUB-only** | AI categorization, overwork/break nudges. |
| [Klokki](https://klokki.com) | $30 one-time | Rule-based auto-tracking: folder/app/URL rules start timers. |
| [Timemator](https://timemator.com) | ~$39 one-time | Auto-tracking rules, offline, privacy-first. |
| [Daily](https://dailytimetracking.com) | $44.99/yr SUB | Periodic "what are you doing?" sampling — trivially replicable. |
| [Toggl Track](https://toggl.com) | Free tier; $10–20/user/mo | Menu-bar timer synced to cloud reports. |

### Calendar and meeting utilities

| App | Price (Jul '26) | Notes |
|---|---|---|
| [Fantastical](https://flexibits.com) | **$56.99/yr SUB-only** | The king. Paid moat: NLP entry, Openings (booking links), Proposals (vote on slots), calendar sets with auto-switch, travel time, weather, templates. |
| [BusyCal](https://www.busymac.com) | $49.99 one-time | "90% of Fantastical, no subscription": menu-bar calendar, tasks, weather. |
| [Dato](https://sindresorhus.com/dato) | $18 one-time | Menu-bar calendar + timezones + join buttons. View-only — a gap to beat. |
| [Itsycal](https://www.mowglii.com/itsycal/) / [MeetingBar](https://meetingbar.app) | Free | Free floors: month grid; next-meeting countdown + join from 50+ services. |
| [In Your Face](https://www.inyourface.app) | $24.99/yr or $69 one-time | Full-screen meeting alerts — people pay yearly for just this. |
| [Vimcal](https://www.vimcal.com) | **$180/yr SUB-only** | Keyboard-fastest calendar, booking links, timezone command center. |
| [Morgen](https://www.morgen.so) / [Amie](https://amie.so) | ~$15–20/mo SUB | Calendar + tasks + AI daily planning. |

### Menu-bar tasks and reminders

| App | Price (Jul '26) | Notes |
|---|---|---|
| [Due](https://www.dueapp.com) | $9.99 one-time (Mac) | Auto-snoozing reminders that re-nag until done. The persistence loop is the product. |
| [Godspeed](https://godspeedapp.com) | **$48/yr SUB-only** | Keyboard-first todo, global quick-add, email-to-task, API. |
| [One Thing](https://sindresorhus.com/one-thing) | Free | One task as menu-bar text; Shortcuts support. |
| [Things 3](https://culturedcode.com) | $49.99 one-time | Benchmark Quick Entry hotkey with autofill from frontmost app. |
| [TickTick](https://ticktick.com) | $35.99/yr | Quick-add, calendar view, built-in Pomodoro + habits. |

### Quick notes and scratchpads

| App | Price (Jul '26) | Notes |
|---|---|---|
| [Tot](https://tot.rocks) | Free on Mac | Seven color-coded dots of text. Free floor. |
| [Antinote](https://antinote.io) | ~$5 one-time | r/macapps darling: temporary-by-default notes, inline calculator, unit/currency conversion, "timer 25" commands. |
| [Drafts](https://getdrafts.com) | Pro $19.99/yr SUB | Capture-first inbox with an actions pipeline. |
| [Heynote](https://heynote.com) | Free OSS | Block-based scratch buffer: per-block syntax, math blocks with variables. |
| [Scratchpad](https://sindresorhus.com/scratchpad) | $4.99 one-time | One synced text field across devices. |
| Noticky / Noted | $1–6 one-time | Floating stickies above fullscreen apps; hotkey capture. |

### Break, eye-strain, posture

| App | Price (Jul '26) | Notes |
|---|---|---|
| [LookAway](https://lookaway.com) | $14.99 one-time | Category leader. Smart Pause during meetings/screen share/video, blink reminders, natural-pause interruption timing. |
| [Time Out](https://www.dejal.com/timeout/) | Free + supporter IAP | Infinitely customizable break schedules. |
| [DeskRest](https://deskrest.com) | $8.99–24.99 lifetime | 2025 newcomer: breaks + posture + video-call detection + end-of-day boundary. |
| [Stretchly](https://hovancik.net/stretchly/) | Free OSS | Cross-platform floor. |

### Ambient sound and focus music

| App | Price (Jul '26) | Notes |
|---|---|---|
| [Endel](https://endel.io) | **~$99/yr SUB-only** | Generative AI soundscapes adapting to time/weather/heart rate. |
| [Brain.fm](https://www.brain.fm) | **$69.99/yr SUB-only** | Science-backed focus music, ADHD mode, timed sessions. |
| [Portal](https://portal.app) | $69.99/yr or $299.99 lifetime | 3D spatial audio of real places, head-tracked AirPods, HomeKit lighting sync. |
| [Dark Noise](https://darknoise.app) / [Noizio](https://noizio.com) | ~$10 one-time | Sound libraries with per-sound mixing, Shortcuts. |
| [myNoise](https://mynoise.net) | Free/donation | 300+ generators; the free ceiling. |
| [Omix](https://www.omix.app) | $59/yr or $119 lifetime | 2025–26 macOS-native adaptive focus music. |

Trend: static sound libraries are cheap one-time; anything "adaptive/AI" charges $60–120/yr. Edith already owns the audio engine — a soundscape mixer attacks the subscription tier directly.

---

## 6. Catalog: system, battery, files, network, notch, AI, devices

### System monitoring

| App | Price (Jul '26) | Notes |
|---|---|---|
| [iStat Menus 7](https://bjango.com/mac/istatmenus/) | $11.99 MAS / ~$18–29 direct, one-time | Gold standard: historical graphs, combined items, threshold notifications on any metric, per-app network traffic. |
| [Stats](https://github.com/exelban/stats) | Free OSS | Covers ~90% of iStat; the price anchor. |
| [Sensei](https://cindori.com/sensei) | $29/yr SUB-first or $59 lifetime | Monitoring + cleanup + battery health + fan control dashboard. |
| [TG Pro](https://www.tunabellysoftware.com/tgpro/) | $20 one-time | Temperature/fan specialist: rule-based fan boost, sensor diagnostics. |
| [App Tamer](https://www.stclairsoft.com/AppTamer/) | $14.95 one-time | Throttles/pauses CPU-hog background apps. |
| QuitAll | $14.99 one-time / Setapp | Quit all apps; auto-quit idle apps; per-app CPU/RAM badges. |
| Pulse / MacPulse / MoniThor | $5.99 one-time and under | 2025–26 impulse-priced "iStat-lite" wave. |

### Battery

| App | Price (Jul '26) | Notes |
|---|---|---|
| [AlDente Pro](https://apphousekitchen.com) | $13.99/yr SUB or $24.99 lifetime | Charge limiter + heat protection + sailing mode. **macOS Tahoe 26.4 added a native charge-limit slider (80–100%, Apple silicon) — the basic use case is Sherlocked.** |
| [Batteries](https://www.fadel.io/batteries) | $8.99 one-time | All device batteries (iPhone, AirPods, Watch, peripherals) on the Mac with alerts. |
| [coconutBattery Plus](https://www.coconut-flavour.com/coconutbattery/) | $9.95 one-time | Battery health authority: capacity history, cycles, iOS health over Wi-Fi. |
| [BatFi](https://github.com/rurza/BatFi) | Free OSS | Open-source charge limiting. |
| TurtleBar / Juicy | $4.99 one-time / (~) | Newcomers: runtime predictions, health analytics. |

### Cleaning and maintenance

| App | Price (Jul '26) | Notes |
|---|---|---|
| [CleanMyMac](https://macpaw.com) | **$39.95/yr SUB-first** (~$119.95 one-time) | The subscription villain of Mac utilities: smart scan, uninstaller, updater, malware scan, Space Lens. |
| [DaisyDisk](https://daisydiskapp.com) | $9.99 one-time | Beloved sunburst disk-space map. |
| [Pearcleaner](https://github.com/alienator88/Pearcleaner) | Free OSS | Community's uninstaller + leftover cleanup. |
| [MacUpdater](https://www.corecode.io/macupdater/) | **Discontinued Jan 1, 2026** | The app-update checker died explicitly because standalone one-time pricing failed ([TidBITS](https://tidbits.com/2026/01/09/macupdater-shuts-down-leaving-users-searching-for-alternatives/)). Niche is open; bundle economics fix it. |
| [Latest](https://github.com/mangerlahn/Latest) | Free OSS | Simple update checker (Sparkle + MAS). |
| [OnyX](https://www.titanium-software.fr) | Free | Maintenance scripts staple. |

### File utilities

| App | Price (Jul '26) | Notes |
|---|---|---|
| [HoudahSpot 6](https://www.houdah.com/houdahSpot/) | $34 one-time | Pro Spotlight front-end: multi-criteria templates, saved searches. |
| [Find Any File](https://findanyfile.app) | $6 one-time | Raw disk search that beats Spotlight's index. |
| [ForkLift 4](https://binarynights.com) | $19.95 one-time | Dual-pane manager + SFTP/S3, batch rename. |
| [Transmit 5](https://panic.com/transmit/) | $45 one-time | File-transfer gold standard, 11+ cloud backends. |
| [Yoink](https://eternalstorms.at/yoink/) | $8.99 one-time | Drag shelf at screen edge; recent: clipboard widget, iOS companion, Photos drag-out. |
| [Dropover](https://dropoverapp.com) | Free + $7 unlock | **Direct shelf competitor.** Extras beyond Edith's shelf: shake-to-summon, multiple shelves, cloud upload → shareable link, post-drop actions (convert/resize/compress), pinned shelves, any display. |
| [Default Folder X](https://www.stclairsoft.com/DefaultFolderX/) | $34.95 one-time | Supercharged open/save dialogs. |
| Path Finder / FilePane | $39 / ~$4.99 | Dormant/abandoned — cautionary tales, and open feature ideas. |

### Network and privacy

| App | Price (Jul '26) | Notes |
|---|---|---|
| [Little Snitch 6](https://www.obdev.at) | $59 one-time | Outbound firewall: per-app rules, DNS encryption, blocklists, traffic chart. |
| [Micro Snitch](https://www.obdev.at/products/microsnitch/) | $3.99 one-time | Mic/camera in-use indicator + tamper-evident log. Two days of Swift for Edith. |
| [TripMode 3](https://tripmode.ch) | $14.99/yr or $49.99 lifetime | Per-app blocking on hotspots, data budgets. |
| [WiFi Explorer](https://www.intuitibits.com) | $19.99 one-time | Wi-Fi scanning/troubleshooting. |
| [LuLu](https://objective-see.org) / OverSight | Free (Objective-See) | Free firewall + mic/cam alerts; the free floor. |

### Link and URL routing

| App | Price (Jul '26) | Notes |
|---|---|---|
| [Choosy](https://choosy.app) | $10 one-time | Deepest rule engine: match URL, source app, time of day. |
| [Velja](https://sindresorhus.com/velja) | $8 one-time | Browser/profile/native-app routing, tracking-param stripping. 130k downloads while free. |
| [OpenIn](https://loshadki.app/openin/) | $11.99 one-time | Routes links, mailto, tel, and files; regex rewriting. |
| Burly / [Finicky](https://github.com/johnste/finicky) | Free | Radial profile picker; config-file routing for devs. |

### Notch apps (Edith's home turf)

| App | Price (Jul '26) | Notes |
|---|---|---|
| [NotchNook](https://lo.cafe/notchnook) | $25 one-time (5 Macs) or **$3/mo SUB** | The maximalist: file tray, music + visualizer, live activities, widgets, gesture navigation, calendar, camera mirror, multi-monitor, floating mode on notchless screens. |
| [Alcove](https://tryalcove.com) | $13.99 one-time | Polish-first native Swift: notification-style alerts (AirPods, charging, low battery), live activities (timers, recording indicator, now playing + waveform), HUD replacement, swipe gestures, **works on the lock screen**. |
| [The Boring Notch](https://theboring.name) | Free OSS (5k+ stars) | Music center + visualizer, shelf with AirDrop, calendar peek, camera mirror, HUD sliders, battery indicator. The free ceiling Edith must beat. |
| [Seam](https://getseam.app) | $19.90 one-time | Focus hub: Pomodoro with task name in the notch, music, calendar, battery, offline dictation, island mode. Aggressive SEO content marketing. |
| [MediaMate](https://wouter01.github.io/MediaMate/) | ~$9 one-time | Focused iOS-style HUD replacements + now playing. |
| TopNotch / Notchmeister | Free | Blackout wallpaper; whimsy effects. |
| Notchable / Brow / Notchy / Crest | Freemium/new | 2025–26 wave: notch task manager with AI voice entry; 7-module bundles; free clones. |

Full feature superset observed across notch apps (checklist): music HUD + visualizer, volume/brightness HUD replacement, island alert banners, live activities (timers, downloads, recording), calendar peek, Pomodoro with named task, camera mirror, AirDrop zone, battery status, lock-screen widgets, swipe gestures, weather, voice task entry, offline dictation, multi-monitor floating island.

### AI utilities

| App | Price (Jul '26) | Notes |
|---|---|---|
| [superwhisper](https://superwhisper.com) | $84.99/yr or **$249 lifetime** | Local Whisper dictation with per-context "modes," model choice. |
| [Wispr Flow](https://wisprflow.ai) | **$15/mo SUB-only ($180/yr)** | The polished cloud dictation darling: auto-edits, tone matching. Prime replacement target. |
| [MacWhisper](https://goodsnooze.gumroad.com/l/macwhisper) | Free; Pro ~€59 one-time | File/meeting transcription: batch, system audio, speaker labels. |
| [VoiceInk](https://tryvoiceink.com) | $25–39.99 one-time, OSS | Local dictation + AI enhancement; winning r/macapps mindshare as the one-time answer. |
| [BoltAI](https://boltai.com) | ~$37–70 one-time | Native multi-LLM client: BYO keys + local Ollama, AI Command on selected text anywhere, inline AI in any field. |
| [Alter](https://alterhq.com) | Free BYO-keys; paid plans | Screen-context copilot + meeting assistant; markets "replaces $550/yr of subscriptions." |
| [Highlight AI](https://highlightai.com) | Freemium | On-screen context assistant + memory. |
| [Granola](https://granola.ai) | Free tier; **Business $14/user/mo SUB** | Bot-free AI meeting notepad enhancing your typed notes from system audio; the 2025–26 breakout. |

Trend: dictation is the hottest Mac AI utility; subscriptions dominate the polished end while one-time/local is the loud counter-movement — literally Edith's pitch. BYO-key makes one-time AI pricing sustainable.

### Device integration

| App | Price (Jul '26) | Notes |
|---|---|---|
| [AirBuddy](https://airbuddy.app) | $9.99 one-time | AirPods popup, all-device battery, Magic Handoff. Development quiet — soft incumbent. |
| [Camo](https://camo.com) | $49.99/yr or $99.99 lifetime | iPhone as pro webcam; survived Continuity Camera with pro depth. |
| [Bezel](https://nonstrict.eu/bezel/) | $29/yr or $99 lifetime | Mirror any iPhone with device frame; dev/demo favorite. |
| [iMazing 3](https://imazing.com) | $39.99/yr SUB-first | Deep device manager: backups, exports. |

---

## 7. Cross-cutting takeaways

### The subscription-replacement scoreboard

Honest marketing ammo — subscription-only or subscription-first apps whose core value Edith could absorb:

| Category | App | Yearly cost |
|---|---|---|
| Dictation | Wispr Flow | $180 |
| Calendar | Vimcal / Fantastical | $180 / $57 |
| Meeting notes | Granola Business | $168 |
| Time tracking | Timing / Rize / RescueTime | $108–264 / ~$120 / ~$78 |
| Recording | Screen Studio / Loom | $108–348 / $216 |
| Focus | Opal / Hugo / Session | $100 / $99 / ~$40 |
| Soundscapes | Endel / Brain.fm | ~$99 / $70 |
| AI chat | Raycast Pro | $96–192 |
| Noise removal | Krisp | $96–180 |
| Launcher extras | Setapp (the umbrella rival) | $120 |
| Webcam studio | Detail / Airtime / Camo | $70 / $120 / $50 |
| Cleaning | CleanMyMac | $40 |
| Screenshots | Snagit / Zight | $39 / ~$108 |
| Text expansion | TextExpander | $40 |
| Clipboard | Paste | $30 |
| Menu bar | Bartender Pro | $15 |
| Battery | AlDente Pro | $14 |
| Cursor spotlight | Mouseposé | $10 |
| Badges | Badgeify | $9 |

### Open niches (verified)

- **App-update checker**: MacUpdater discontinued Jan 1, 2026 — its developer stated one-time pricing on a standalone updater was unsustainable. As one module in a bundle, the economics invert.
- **Agent resource monitoring**: nobody ties system stats to AI-coding workloads (per-process CPU/RAM for claude/node, kill runaway agents).
- **Claude usage as a notch live activity**: zero competitors; fuses Edith's two most distinctive assets.
- **Wounded incumbents**: Ice (dormant since Feb 2026), Bartender (trust wobble + Pro subscription), Contexts (stagnant), AirBuddy (quiet), Path Finder and FilePane (dead), AltTab (Tahoe issues) — each an acquisition-by-feature opportunity.

### Sherlock watch (don't build on these squares)

- macOS Tahoe native window tiling (killed basic snappers)
- Tahoe 26.4 native battery charge-limit slider, Apple silicon ([MacRumors](https://www.macrumors.com/2026/02/16/mac-charge-limit-macos-tahoe-26-4/))
- Tahoe built-in menu-bar icon hiding (basic tier)
- Live Text (basic OCR), Continuity Camera (basic webcam), iPhone Mirroring (basic mirroring)
- Apple Creator Studio, Jan 2026, subscription (basic recording/editing)

### Direct competitors on the same "bundle instead of subscriptions" thesis

Seam ($19.90, notch focus hub), Brow (free, 14 tools in the notch), Monarch ($30–39 launcher bundle), SuperCmd (free OSS Raycast clone), NotchNook ($25), Bartender 6 Pro Top Shelf ($15/yr — notch widgets + clipboard + shelf from a giant install base), Unclutter ($24), and Setapp ($9.99/mo) as the umbrella rival. One-time pricing alone is no longer differentiating — among 2025–26 indie entrants it's the norm. Edith's defensible wedge is the combination: AI-usage flagship + notch surface + breadth + native performance story.

### Pricing observations

- Winning one-time points: $5–20 (single utilities), $30–50 (launchers, automation, Homerow/Alfred/Hazel/KM). Edith's $50 sits at the top and is justified only by breadth — which is the pitch.
- MacUpdater's death is the strongest possible validation of Edith's model: single utilities can't sustain one-time pricing, bundles can.
- Perpetual-trial-with-soft-nags (PopClip, Rocket, LaunchBar) converts well and fits a no-account app.
- Nearly every paid app here also distributes via Setapp; several newcomers (Seam, Hugo, Omix, ScreenSnap Pro) grow via aggressive "best X for Mac 2026" SEO content — cheap channels worth copying.

---

## Sources

Key references (see linked pricing pages inline above): [TidBITS on MacUpdater's shutdown](https://tidbits.com/2026/01/09/macupdater-shuts-down-leaving-users-searching-for-alternatives/) · [CoreCode discontinuation notice](https://www.corecode.io/macupdater/sale-and-licensing.html) · [MacRumors on Tahoe 26.4 charge limit](https://www.macrumors.com/2026/02/16/mac-charge-limit-macos-tahoe-26-4/) · [AppleInsider on Tahoe 26.4](https://appleinsider.com/articles/26/02/17/macos-tahoe-264-adds-a-charge-limit-slider-to-preserve-your-macbook-battery) · [9to5Mac on Bartender Pro's notch peninsula](https://9to5mac.com/2026/05/12/bartender-pro-makes-the-macbook-notch-more-useful-with-widgets-files-clipboard-more/) · [Six Colors on Bartender 6 Pro](https://sixcolors.com/post/2026/05/bartender-6s-new-pro-feature-turns-the-macbook-notch-into-a-dynamic-peninsula/) · [TechSmith subscription transition FAQ](https://support.techsmith.com/hc/en-us/articles/27009223314701-TechSmith-Transition-to-Annual-Subscription-Pricing-Model-in-2025) · [Forbes on the missing Mac volume mixer](https://www.forbes.com/sites/barrycollins/2026/05/06/apple-still-hasnt-built-a-mac-volume-mixer-these-apps-fill-the-gap/) · [MacStories Bartender-alternatives roundup](https://www.macstories.net/roundups/managing-your-mac-menu-bar-a-roundup-of-my-favorite-bartender-alternatives/) · [TechCrunch on mmhmm → Airtime](https://techcrunch.com/2025/04/24/evernote-founders-video-startup-mmhmm-becomes-airtime-launches-new-products/) · plus official pricing pages linked on each app name throughout.
