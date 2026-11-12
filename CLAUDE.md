# Charge Now: working rules

**Dims your screen before the battery dies. Nothing else.** Keep it that small: every feature must defend its place
against that line. It never changes a system setting, never uses the network, and the block is never a dead end.

A menu-bar-only Mac app (`LSUIElement`, an `NSStatusItem` menu and a full-screen overlay):

| | Where |
|---|---|
| Entry, menu, launch at login | `App/App.swift`, `App/AppDelegate.swift` |
| The overlay: windows, Esc and hold, what is drawn | `App/OverlayPanel.swift`, `App/OverlayView.swift` |
| Tokens (colors, gaps, sizes) | `App/Theme.swift` |
| When to warn and block (no UI, no battery access) | `Core/Policy.swift` |
| Battery readings from IOKit | `Core/Battery.swift` |
| Tests for `Core/` | `Tests/main.swift`, run by `scripts/test-core.sh` |
| Info.plist, icon | `App/Info.plist` (hand-written), `App/AppIcon.icns` (from `scripts/make-icon.swift`) |

**No Xcode project on purpose.** The scripts compile `App/*.swift Core/*.swift` with `swiftc` and put the bundle
together by hand, so the app builds with only the Command Line Tools. Bundle id `app.chargenow.mac`, product
"Charge Now", executable `ChargeNow`. A new source file needs no registration: put it in `App/` or `Core/`.

Mac only on purpose: an iPhone app cannot draw over other apps. See the parity table.

## Every change: build, restart, verify, push

1. Restart the app with the new build when a change is done, without asking:
   ```bash
   scripts/install-mac.sh     # design check, Core tests, build, quit the running copy, install to ~/Applications, reopen
   ```
2. Verify on screen, both stages. The battery is rarely low, so use the previews:
   ```bash
   build/ChargeNow-arm64 --preview block --seconds 4 &     # or: --preview warning
   sleep 2; screencapture -x /tmp/block.png                 # look at it; it closes by itself
   ```
   Run the bare binary in `build/`, not the installed app: it has no bundle id, so it neither fights the
   running copy nor touches the login item. The overlay covers the owner's screen while it shows, so keep it
   to a few seconds. `--render <folder>` writes both stages as PNGs without touching the screen (that is how
   `docs/warning.png` and `docs/block.png` are made), but it cannot show the blur.
   Report what was and wasn't seen. Two displays: the overlay must cover both.
3. Commit and push each finished fix to `main`; update the README and the parity table.

## Design

Read `App/Theme.swift` before touching the overlay; `scripts/check-design.sh` fails the build on a bare gap,
radius or color outside it. The owner's taste (monochrome ink, Stoic style): one small mark, one bold lowercase
headline ending in a period, one plain sentence under it, lots of air. The overlay is always dark, whatever the
system appearance: it is the screen, dimmed. White ink; the only hue is `Theme.danger`, on the battery's last
sliver in the block. Calm springs, nothing looping. The percent sits inside the battery mark, so it needs no label; the sentence
under the headline is only the time left, and is absent when macOS has no estimate.

The overlay is a non-activating `NSPanel` at the shielding window level on every screen. Non-activating
matters: a background app cannot reliably bring itself to the front on current macOS, and the panel can take
the keyboard without it, so Esc works. Clicks and keys are read in `OverlayWindow.sendEvent`. Input in the
first 0.8 s is ignored, so a click already under way does not dismiss a warning nobody saw.

The block must always say why, what to do now and the way in: "Plug in the charger to continue." and
"Or hold esc to keep working." Do not remove the hold without the owner asking.

## Method (installed skills)

Decisions are the owner's, facts are the agent's. Open design questions → `grilling`. Decisions with reasons →
`docs/adr/`. Logic in `Core/` → `tdd`, with `scripts/test-core.sh` as the runner. "It's broken" →
`diagnosing-bugs`. Before a release → `code-review`, then the `ship` skill for the first one.

## Plan

`docs/PLAN.md` is the plan: new asks go there first. Anything that needs the owner goes under "Waiting on you"
with its one question; parked ideas under "Owner decides later".

## Parity table

| Feature | Mac | iPhone / iPad |
|---|---|---|
| Warning at 10%, dismissed with a click or Esc | overlay on every display | n/a: iOS apps cannot draw over other apps |
| Block at 5% until the charger is connected, hold Esc to snooze one percent | overlay on every display | n/a |
| Preview either stage, launch at login | menu-bar menu | n/a |

## Debugging

- Battery right now: `pmset -g batt`. The app listens with `IOPSNotificationCreateRunLoopSource` and rereads
  once a minute as a safety net.
- Login item: `sfltool dumpbtm | grep -A8 app.chargenow.mac`. It is registered once, on the first start from
  a bundle (`didSetUpLoginItem` in the defaults), then only the menu changes it.
- Errors go to `NSLog("ChargeNow: …")`; in this shell `log` is shadowed:
  `/usr/bin/log show --last 5m --style compact --predicate 'eventMessage CONTAINS "ChargeNow:"'`.
- Signing: `scripts/signing.sh` picks a Developer ID or Apple Development certificate when the Mac has one,
  ad-hoc otherwise. The app asks for no permission, so an ad-hoc build loses nothing but the login item's
  identity across rebuilds.
