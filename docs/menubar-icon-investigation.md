# Menu Bar Icon Not Showing: Investigation Notes

Full record of the "Edith menu bar icon / status items don't appear" investigation,
including the earlier fix (PR #43), the exhaustive diagnosis, every dead end, the
root cause, and the fix that shipped in `v1.11.0`.

---

## 1. Symptom

- The Edith menu bar status items (the glasses icon that opens the panel, and the
  usage-% text `5h 4% 7d 91%`) intermittently disappear from the menu bar.
- The panel is unreachable via the icon; only the global hotkey `⌥⌘E` and the
  dashboard's "Open Menu Bar Panel" button still open it.
- Reported as **recurring** ("keeps happening again and again"). Survives reboot,
  reinstall, and earlier attempted fixes.

## 2. Environment

- Machine: 16" MacBook Pro, **notched** display.
- macOS: Darwin 25.5.0 (macOS 26 / Tahoe era).
- Display geometry (measured via `NSScreen`):
  - `frame` = `(0, 0, 1728, 1117)`, `visibleFrame` height = `1084`.
  - `safeAreaInsets.top` = 32.
  - `auxiliaryTopLeftArea` = `(0, 1085, 771, 32)` → usable menu bar left of notch = x `0..771`.
  - `auxiliaryTopRightArea` = `(956, 1085, 772, 32)` → usable menu bar right of notch = x `956..1728`.
  - **Notch occupies x `771..956`, screen/notch center ≈ `863`.**

## 3. Architecture context (relevant to the bug)

- **Two-process design** (from PR #18):
  - `Edith` (`com.pulkit.edith`) — the dashboard, a regular `.regular` app with a Dock icon.
  - `EdithMenuBar` (the helper) — the menu bar app, `LSUIElement` / `.accessory`,
    nested at `Edith.app/Contents/Library/LoginItems/EdithMenuBar.app`, launched as an
    `SMAppService` login item.
- Helper bundle id has been renamed multiple times to escape macOS state:
  `com.pulkit.edith.menubar` → `com.pulkit.edith.bar` → `com.pulkit.edith.panel`.
- Shared settings live in an app group suite `com.pulkit.edith.shared` (separate from
  the per-app pref domains, so renames don't lose settings).
- IPC between the two processes uses fixed `DistributedNotificationCenter` names
  (`com.pulkit.edith.openPanel`, etc.), independent of bundle id.
- Two menu bar entities historically existed:
  - The **glasses** — created by SwiftUI `MenuBarExtra` (autosave `Item-0`).
  - The **usage-% text** — a manual `NSStatusItem` (`LimitsStatusItem`, autosave `limits`),
    whose `clicked()` also opens the panel.

## 4. Earlier fix — PR #43 (`290607a`, "Fix invisible menu bar icons and menu bar panel height")

Context carried in from the previous session:

- macOS held a **per-bundle-id "hidden" record** for `com.pulkit.edith.menubar` that
  **parked its status items off-screen** and could **not** be reset from user space:
  preferences edits, `cfprefsd` restart, Control Center restart, the
  "Allow in Menu Bar" toggle, and a fresh autosave name **all failed**. An identical
  build under **any other bundle id** placed fine.
- **Fix:** rename the helper to `com.pulkit.edith.bar` so the system treats it as a
  fresh app; unregister the retired login item on next launch.
- Same PR also restored the panel to content-hugging height (dropped a
  "measure-into-its-own-ScrollView" approach that inflated every tab to the screen cap),
  and removed a leftover status-frame debug dump (broke the swift-format LineLength
  check) plus dead "force-visible" `UserDefaults` writes the system overrode anyway.

Key takeaway that guided this session: the recurring bug looked like the same
per-bundle-id poison, and renaming had historically been the escape hatch.

---

## 5. This session — Part A: panel layout fix (related, shipped first)

Reported first as "the panel layout is messed up" on the Music tab: the panel appeared
**shifted down**, with a **translucent area** around it and the **UI vertically centered**.

- First hypothesis (wrong): the Music track list (hard-capped at 520pt) made the panel
  taller than the screen. Tested a screen-aware `maxListHeight`; it was a **no-op** on
  this 1084pt-tall screen (`1084 − 360` clamps back to 520). Reverted.
- **Real cause:** `MenuBarExtra(.window)` grows its window to the **tallest tab ever
  shown** and **never shrinks it**. Per-tab content heights (measured via an offscreen
  `PanelShot` render): **Usage 808, Music 734, System 348, Calendar 214**. On any tab
  shorter than the current window, SwiftUI **centers** the content in the oversized
  window → the "shifted down / translucent / centered" look.
- **Fix (`82e1c03`):** `fitPanelHeight()` resizes the `MenuBarExtra` window to its
  content's `fittingSize`, **top-pinned**, on tab change and window events.
- **Verified live** by driving a tab-cycler and polling window geometry via
  `CGWindowList`: `top_y` stayed `24` while height tracked `808 → 734 → 348 → 214`.
  (Before the fix it was stuck at 808 for every tab.)

This confirmed the measurement toolkit (see §9) and is why the height fix is solid.

---

## 6. This session — Part B: the recurring hidden-icon investigation

The icon disappeared during heavy kill/relaunch testing. Treated initially as the PR #43
recurrence and the same remedy applied, then diagnosed exhaustively.

### 6.1 Attempt 1 — bundle-id rename (`15ecf27`)
- Renamed helper `com.pulkit.edith.bar` → `com.pulkit.edith.panel`
  (`HelperInfo.plist` CFBundleIdentifier, `Edith/App/App.swift`
  `helperBundleIdentifier` + `retiredHelperBundleIdentifier`, `reset.sh` lists).
- **User rebooted → still broken. Reinstalled to `/Applications` → still broken.**
- So the fresh `.panel` id was **also** flagged hidden. The rename did **not** fix it
  this time. This broke the "it's just per-bundle-id poison" theory.

### 6.2 What was measured (all via `CGWindowList`, not screenshots — see §9)
- A window at **x `765..962` (center 863 = notch center), layer 33, width 197**,
  owned by "Edith". Believed at the time to be the status item.
- Pref `NSStatusItem VisibleCC Item-0 = 0` in the helper's domain → the glasses item is
  flagged **not visible**. Forcing it to `1` got **rewritten back to `0`** on next launch.
- A **bare test `NSStatusItem` app** (unrelated, `com.test.*`) placed correctly at
  **x `1300`** (right side, visible). → the system menu bar is healthy; the problem is
  **Edith-specific**.

### 6.3 Everything ruled out (each tested in isolation, still failed)
- **Fresh bundle id** — a brand-new never-used id (`com.pulkit.edith.fresh<timestamp>`)
  still landed at 765 / hidden.
- **`autosaveName`** present vs absent — no change.
- **`NSStatusItem Preferred Position <autosave>` pref** (tried e.g. `1300`) — **ignored**.
- **`MenuBarExtra` vs manual `NSStatusItem`** — with `MenuBarExtra` removed, the manual
  `LimitsStatusItem` still failed; both fail.
- **Creation timing** — delaying item creation 4s after launch — no change.
- **Activation policy** — `.regular` + `NSApp.activate(ignoringOtherApps:)` — no change.
- **Doubling / ghost windows** — single clean instance still failed.
- **ControlCenter `MenuBarCustomizationState`** — backed up, cleared, `killall ControlCenter`,
  relaunched → **did not help** (restored from backup afterward).
- **Reboot** — the user's reboot did not fix it.

### 6.4 Gotchas discovered
- **Process-name trap:** the login-item helper's **process name is
  `com.pulkit.edith.<id>`, not `EdithMenuBar`**. So `pkill -x EdithMenuBar` **missed**
  the launchd-launched instance (e.g. PID 773). For much of the debugging **two helper
  instances ran simultaneously**, contaminating measurements. Kill with
  `pkill -f com.pulkit.edith.<id>`.
- **launchd keepalive:** killing the helper mid-session, the login item / main app
  relaunched it, so "no helper running" was often false.

### 6.5 The NotchShelf red herring (important)
- `NotchShelf` (a feature the user has **enabled**, `notchShelfEnabled = 1`) creates an
  `NSPanel` via `NotchShelfController` at:
  - origin `screenFrame.midX − width/2` (≈ x `765`),
  - level `NSWindow.Level.statusBar + 8` (= raw **33**), at the top of the screen.
- Collapsed width ≈ 197 → the panel sits at **x `765..962`, layer 33** — **identical**
  to what was being measured as "the status item."
- **A large part of the "the item is centered on the notch" conclusion was actually the
  NotchShelf panel, not the menu bar icon.** Disabling `notchShelfEnabled` removed that
  window.
- With NotchShelf **off**, `CGWindowList` showed **no Edith menu bar window at all** →
  the real status items aren't *misplaced*, they're **hidden / not created**
  (`VisibleCC Item-0 = 0`, and the usage item absent too).

### 6.6 The decisive comparison — TokenEater
- Sibling app `pulkitxm/TokenEater` (a **single-process** menu bar app) **never had this
  bug**. Its `StatusBarController`:
  - creates a plain **`NSStatusItem`** (`variableLength`, `isVisible = ...`),
  - shows the panel via a **transient `NSPopover`** (`popover.show(relativeTo:of:preferredEdge:)`),
  - is created in an **`AppDelegate.applicationDidFinishLaunching`**,
  - app scene is `Settings { EmptyView() }` — **no `MenuBarExtra` at all**.
- Edith used SwiftUI **`MenuBarExtra`** — the thing implicated in the placement/visibility
  failure on this notched macOS.

---

## 7. Root cause + the fix that shipped (`9b1c218`, in `v1.11.0`)

**Cloned TokenEater's approach** while keeping Edith's exact panel UI (`RootView`):

- New **`PanelController`** (mirrors `StatusBarController`):
  - `NSStatusBar.system.statusItem(withLength: .variableLength)`,
  - `autosaveName = "edithGlasses"` (a **fresh** name that dodges the poisoned `Item-0`
    record) and **`isVisible = true`** set explicitly (this is what the old code never did
    for the manual path — the default `Item-0` autosave restored `VisibleCC = 0`),
  - `button.image = Logo.menuBar`, click toggles a **transient `NSPopover`** hosting
    `RootView().environmentObject(services)`,
  - `NSHostingController.sizingOptions = [.preferredContentSize]` so the popover
    auto-resizes for tab switches and the expanding logs terminal,
  - a global mouse-down monitor closes the popover on outside click.
- Created in `MenuBarAppDelegate.applicationDidFinishLaunching`; the scene is now
  `Settings { EmptyView() }` (no `MenuBarExtra`).
- **Deleted** the `MenuBarExtra` window machinery: `fitPanelHeight`,
  `centerPanelUnderIcon`, `menuBarExtraStatusWindow`, `clickStatusItem`, the
  `MenuBarExtraWindow` notification observers, and `settleMiniPanel`. The popover
  auto-sizes/positions, so none of it is needed.
- **Detached mini-player removed:** `MiniPlayerPanel.swift` (the `MiniPanel` detached
  `NSPanel`) deleted; replaced by an **inline** now-playing bar rendered in `RootView`
  on non-Music tabs when music is playing.
- `ClipboardPanel` positioning switched from `menuBarExtraStatusWindow()?.frame` to
  `PanelController.shared?.statusItemFrame`.

### 7.1 The unresolved verification caveat (critical)
- With the manual item in place, debug logging showed:
  `button = true`, eventually `isVisible = true`, `image = true`, but the button's
  window stuck at **`(0, -22, 36, 22)` — unplaced** (not in the menu bar), and
  `CGWindowList` shows nothing on-screen.
- **Decisive test:** the **old `MenuBarExtra` code was git-stashed and rebuilt/installed
  mid-session — it ALSO placed no status item** the same way. Therefore **no status item
  places when the helper is launched mid-session** (`make install` / `open` /
  `openApplication`), *regardless of code*. This is a **launch-context limitation**, not
  a code defect.
- **Only a real logout/login (or reboot)** launches the login-item helper such that
  status items get a genuine menu bar slot. So the refactor is **committed and shipped
  but not yet verified on a real login**. That is the true test.

---

## 8. Commits and release

- `82e1c03` — Fix menu bar panel not shrinking to content height on tab switch (`fitPanelHeight`).
- `15ecf27` — Give menu bar helper a fresh bundle id (`.bar` → `.panel`) to escape parked status items.
- `9b1c218` — Replace `MenuBarExtra` with a manual `NSStatusItem` + `NSPopover` (TokenEater-style).
- `d6d9a2b` — Bump version to 1.11.0. Tag **`v1.11.0`** → release workflow built and
  published `Edith-v1.11.0.dmg`.

## 9. Measurement techniques used (reference)

- **`CGWindowListCopyWindowInfo`** is the source of truth for menu bar geometry — it sees
  every window regardless of owner. Filter `layer == 33` (third-party status items),
  `y <= 2`, or by `kCGWindowOwnerName` containing "edith". Prints `x`, width, layer,
  `kCGWindowOwnerPID`, `kCGWindowNumber`.
- **Screenshot filtering caveat:** the computer-use screenshot tool applies "native"
  filtering — windows owned by **non-granted** apps are excluded. The nested login-item
  helper (`com.pulkit.edith.panel`) is **not grantable** (`request_access` returns
  `not_installed` for nested login items), so its **panel/popover windows are invisible
  in screenshots**, even though menu bar status items normally composite in. Always
  corroborate with `CGWindowList`.
- **Offscreen `PanelShot` render:** temporarily host `RootView` in an offscreen
  `NSWindow` + `NSHostingView`, read `fittingSize`, `cacheDisplay` to PNG. Reliable for
  per-tab content heights (`ImageRenderer` fails on `ScrollView`).
- **File logging over stderr:** when the helper is launched by launchd/`openApplication`,
  stderr isn't captured — write debug to a file path (e.g. `/tmp/...log`) instead.
- **Relevant pref keys** (in `com.pulkit.edith.<id>` domain):
  - `NSStatusItem VisibleCC <autosave>` — Control-Center-managed visibility (`0` = hidden).
  - `NSStatusItem Preferred Position <autosave>` — saved x position (observed **ignored**
    here).
- **launchd / login item state:** `launchctl print-disabled gui/$(id -u) | grep edith`,
  `sfltool dumpbtm | grep -iA3 edith` (slow). Disable/kill with
  `launchctl bootout`/`disable` + `pkill -f com.pulkit.edith.<id>`.

## 10. Open questions / next steps

- **Does the manual `NSStatusItem` place at real login in the two-process helper?**
  TokenEater proves it works in a **single-process** app; Edith's helper is launched as a
  nested `SMAppService` login item. Verify by installing `v1.11.0` and logging out/in.
- If it **still** doesn't place after a clean login, the two-process split may be the
  issue and would need reconsidering (e.g., the menu bar living in the main app, or a
  different helper launch mechanism).
- The `NotchShelf` panel legitimately sits on the notch; keep it separate from any future
  "icon on the notch" diagnosis.
- Test-suite hygiene: `swift test` runs left **~968 `edith-tests-from/to-*.plist`** files
  in `~/Library/Preferences` (one suite per run, never cleaned up). Worth cleaning up in
  the test harness.
