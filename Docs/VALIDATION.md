# Validation and evidence

This document separates executed checks from remaining acceptance work. It contains no personal conversation records or workstation-specific session statistics.

## Executed locally

The native app compiled and linked with Swift 6.3.1 on Apple Silicon, macOS 26.6.2, using Apple Command Line Tools. `./Scripts/verify.sh --ui` built the bundle, validated its plists/ad-hoc signature, and passed the shared core groups plus native smoke checks. The public-source run passed 17/17 shared check groups and 40 native checks, including showcase isolation/search. The synthetic Overview and Sessions routes were also inspected through the installed native accessibility surface and captured for the README. Subsequent manual pill navigation was not established through that UI tool; the native regression results remain separate from the outstanding manual mouse matrix.

Shared checks exercise fixture identity/attribution, honest unknowns, persisted opt-out preferences, multi-display placement math, metadata normalization, read-only RPC sequencing, timeout behavior, 1,000-record deduplication, migrations preserving notes, consent revocation, retention/deletion, durable pagination, credential redaction, bounded previews with full-archive search/export, and independent backfill.

Native checks create actual AppKit windows in an isolated process/preferences domain. They exercise popover geometry, Studio lifecycle, nonactivating pill configuration, stable hover and direct capture actions. The regression checks inject an own-panel pointer location and call native handlers/button actions; no physical pointer automation is claimed. See [interaction specification](INTERACTIONS.md).

## Regressions that shaped the implementation

1. Bounded SwiftUI content alone did not keep popover chrome on screen. Tests reproduced an outer frame above the display; final native-window clamping handles the complete frame.
2. Hover attached to conditional SwiftUI content could exit when expansion replaced the subtree. Tracking now belongs to a persistent native host, with a cancelable, pointer-validated exit.
3. A sustained hover test exposed delayed Studio reappearance. Only actually minimized windows are now deminiaturized.
4. A pause-shaped status glyph opened Studio with the rest of the pill. It is now a separate native button with explicit hit routing and two-direction toggle checks.

An immediate focus assertion was also replaced with a bounded wait for real active/key-window state. Failed runs were used to diagnose issues; they were not reported as passes.

## Environment limits

Full Xcode is not installed on the local validation machine, so local XCTest is unavailable. The same shared checks execute through the dependency-free `VernierCoreChecks` executable; an XCTest wrapper and macOS GitHub Actions workflow are provided. CI results are visible in [Actions](https://github.com/romrom-20/Vernier/actions).

## Not yet verified

- Manual VoiceOver, keyboard-only navigation, larger text and contrast review.
- The full [manual mouse matrix](INTERACTIONS.md), crowded menu bars and actual multi-monitor/full-screen behavior.
- Actual hardware sleep/wake/reboot/login and clean-Mac installation.
- macOS 14/15 compatibility across supported hardware.
- Sustained CPU/memory/energy measurements and responsiveness targets.
- Developer ID signing, notarization, DMG and updater.
- Validity or usefulness of automated session reviews, comprehension measures or cognitive scores. These are not implemented results.

Live connector verification during development confirmed read-only local Codex history access. Reproducing it is optional and consented: `swift run VernierCoreChecks --codex-live` prints metadata counts only. Never attach real archives or personal provider data to a public issue.

## Exclusive surfaces and interaction focus — 0.5.0

Three supplied screenshots showed quick view layered over Studio, the menu surface opening independently, and an idle compact checkmark. All were inspected before editing. The capture status is now a quiet circular presence rather than a success/review mark. Body click pins controls; dedicated native capture and dashboard buttons have independent hit targets. Dashboard and quick view are mutually exclusive requested surfaces, including activation/reopen and late native callbacks.

`./Scripts/verify.sh --ui` passed **17 shared groups and 47 native checks**. New checks cover activation while quick view is open, dashboard replacing quick view, quick view hiding dashboard, four rapid transition cycles, body pinning without a dashboard, distinct dashboard hit testing, and only the dashboard arrow opening Studio. Existing hover, pause, source and storage checks remain green. No new ingestion permission or database schema was added.

The updated synthetic Overview was inspected through the native accessibility tree and visually captured for the README. It puts intent, steering and understanding before collapsed archive details. A later attempt to inspect quick view through the computer-use tool returned native timeout errors; reconnecting also timed out. That manual transition is not claimed as verified by the tool. The native in-process window checks above did verify the actual resulting window visibility and popover state. Manual physical mouse/full-screen/multi-monitor checks remain pending.

The prompt trail reuses the bounded session-scoped archive search, displays at most six user-side excerpts from the latest 100 saved messages, and labels approximate ordering and app-added context. It makes no automatic quality judgment. The WHOOP-inspired interaction-feedback vision is now explicit in the product thesis/roadmap, with automated trajectory assessment and personal trends still unimplemented research/engineering work.
